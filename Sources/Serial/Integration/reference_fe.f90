! Copyright (C) 2014 Santiago Badia, Alberto F. Martín and Javier Principe
!
! This file is part of FEMPAR (Finite Element Multiphysics PARallel library)
!
! FEMPAR is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! FEMPAR is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with FEMPAR. If not, see <http://www.gnu.org/licenses/>.
!
! Additional permission under GNU GPL version 3 section 7
!
! If you modify this Program, or any covered work, by linking or combining it 
! with the Intel Math Kernel Library and/or the Watson Sparse Matrix Package 
! and/or the HSL Mathematical Software Library (or a modified version of them), 
! containing parts covered by the terms of their respective licenses, the
! licensors of this Program grant you additional permission to convey the 
! resulting work. 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
module reference_fe_names
  use allocatable_array_ip1_names
  use field_names
  use types_names
  use list_types_names
  use memor_names
  implicit none
# include "debug.i90"

  private

  ! This module includes all the reference FE related machinery that is required
  ! to integrate FE schemes. It includes the following types:
  !
  ! * reference_fe_t: the basic reference_fe object, which is an abstract type
  ! * quad_lagrangian_reference_fe_t: one particular concrete version of the 
  !   reference fe_t
  ! * quadrature_t: Set of points and weights to perform numerical integration.
  !   It is created by the concrete reference_fe_t by providing the maximum order
  !   to be integrated exactly for zero order terms, e.g., mass matrix
  ! * interpolation_t: The value of the reference FE shape functions (first and second
  !   order derivatives) on the quadrature points. It is generated by a concrete 
  !   reference_fe_t and a quadrature_t. It is computed in the concrete reference_fe_t
  ! * fe_map_t: It provides the mapping from a physical FE to the reference FE
  !   (jacobian, etc.)
  ! * volume_integrator_t: It aggregates all the aforementioned structures to be
  !   used in the FE element integration subroutine. In particular, one 
  !   reference_fe_t for the unknowns and one for the geometry (for non-isoparametric
  !   cases), one quadrature, and the corresponding interpolation. Further, it 
  !   includes the physical FE to the reference one in a fe_map_t and the
  !   composition of the FE map and the interpolation, to provide derivatives in the
  !   physical space

  type quadrature_t
     private
     integer(ip)           ::   &
          number_dimensions,    &
          number_quadrature_points
     real(rp), allocatable :: &
          coordinates(:,:),   &   
          weight(:)                         
   contains
     procedure, non_overridable :: create => quadrature_create
     procedure, non_overridable :: free   => quadrature_free
     procedure, non_overridable :: print  => quadrature_print
     procedure, non_overridable :: get_number_dimensions => quadrature_get_number_dimensions
     procedure, non_overridable :: get_number_quadrature_points => quadrature_get_number_quadrature_points
     procedure, non_overridable :: get_weight => quadrature_get_weight
  end type quadrature_t

  type p_quadrature_t
     type(quadrature_t), pointer :: p => NULL()
   contains
     procedure :: allocate => p_quadrature_allocate
     procedure :: free     => p_quadrature_free
  end type p_quadrature_t

  ! Types
  public :: quadrature_t, p_quadrature_t

  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  type interpolation_t
     private
     integer(ip)                ::  &
          number_dimensions,        &      
          number_shape_functions,   &      
          number_evaluation_points, &      
          number_entries_symmetric_tensor
     real(rp), allocatable      ::  &
          shape_functions(:,:),     &   
          shape_derivatives(:,:,:), &   
          hessian(:,:,:)     
   contains
     procedure, non_overridable :: create => interpolation_create
     procedure, non_overridable :: free   => interpolation_free
     procedure, non_overridable :: copy   => interpolation_copy
     procedure, non_overridable :: print  => interpolation_print
     !procedure, non_overridable :: get_number_dimensions => interpolation_get_number_dimensions
     !procedure, non_overridable :: get_number_shape_functions => interpolation_get_number_shape_functions
     !procedure, non_overridable :: get_number_evaluation_points => interpolation_get_number_evaluation_points
     !procedure, non_overridable :: get_number_entries_symmetric_tensor => interpolation_get_number_entries_symmetric_tensor
     !procedure, non_overridable :: get_shape_function => interpolation_get_shape_function
     !procedure, non_overridable :: get_shape_derivative => interpolation_get_shape_derivative
     !procedure, non_overridable :: get_hessian  => interpolation_get_hessian
  end type interpolation_t

  public :: interpolation_t
  
  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  type interpolation_face_restriction_t
     private
     integer(ip)                           :: number_shape_functions
     integer(ip)                           :: number_evaluation_points
     integer(ip)                           :: number_faces
     integer(ip)                           :: active_face_id
     type(interpolation_t), allocatable :: interpolation(:)
     type(interpolation_t)              :: interpolation_o_map
   contains
     procedure, non_overridable :: create => interpolation_face_restriction_create
     procedure, non_overridable :: free   => interpolation_face_restriction_free
  end type interpolation_face_restriction_t

  public :: interpolation_face_restriction_t

 !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  type fe_map_t
     private
     ! Map's Jacobian (number_dimensions,number_dimensions,number_evaluation_points)
     real(rp), allocatable    :: jacobian(:,:,:)    
     ! Map's Jacobian inverse (number_dimensions,number_dimensions,number_evaluation_points)       
     real(rp), allocatable    :: inv_jacobian(:,:,:)     
     ! Map's Jacobian det (number_evaluation_points)  
     real(rp), allocatable    :: det_jacobian(:)  
     ! Map's 2nd derivatives (number_dime,number_dime,number_dime,number_evaluation_points)         
     real(rp), allocatable    :: d2sdx(:,:,:,:)     
     ! Coordinates of git  points (number_dimensions,number_evaluation_points)       
     real(rp), allocatable    :: coordinates_quadrature(:,:)  
     ! Coordinates of evaluation points (number_dimensions,number_corners of element/face)  
     real(rp), allocatable    :: coordinates_vertices(:,:)  
     ! Vector normals outside the face (only allocated when using fe_map to integrate on faces) 
     real(rp), allocatable    :: normals(:,:)  
     ! Geometry interpolation_t in the reference element domain    
     type(interpolation_t) :: interpolation_geometry   
     ! Characteristic length of the reference element
     real(rp)                 :: reference_fe_characteristic_length
     ! Number of dimensions
     integer(ip)              :: number_dimensions
     ! Number of quadrature points
     integer(ip)              :: number_quadrature_points
   contains
     procedure, non_overridable :: create                  => fe_map_create
     procedure, non_overridable :: create_on_face          => fe_map_create_on_face
     procedure, non_overridable :: fe_map_face_map_create  => fe_map_face_map_create
     procedure, non_overridable :: update                  => fe_map_update
     procedure, non_overridable :: face_map_update         => fe_map_face_map_update
     procedure, non_overridable :: free                    => fe_map_free
     procedure, non_overridable :: print                   => fe_map_print
     procedure, non_overridable :: get_det_jacobian        => fe_map_get_det_jacobian
     procedure, non_overridable :: compute_h               => fe_map_compute_h
     procedure, non_overridable :: compute_h_min           => fe_map_compute_h_min
     procedure, non_overridable :: compute_h_max           => fe_map_compute_h_max
     procedure, non_overridable :: get_coordinates         => fe_map_get_coordinates
     procedure, non_overridable :: get_inv_jacobian_tensor => fe_map_get_inv_jacobian_tensor
     procedure, non_overridable :: get_reference_h         => fe_map_get_reference_h
  end type fe_map_t

  type p_fe_map_t
     class(fe_map_t), pointer :: p => NULL()   
   contains
     procedure :: allocate => p_fe_map_allocate
     procedure :: free     => p_fe_map_free
  end type p_fe_map_t

  public :: fe_map_t, p_fe_map_t
  
  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  type fe_map_face_restriction_t
     private
     integer(ip)                 :: number_faces = 0
     integer(ip)                 :: active_face_id
     type(fe_map_t), allocatable :: fe_map(:)
   contains
     procedure, non_overridable :: create => fe_map_face_restriction_create
     procedure, non_overridable :: update => fe_map_face_restriction_update
     procedure, non_overridable :: free   => fe_map_face_restriction_free
     procedure, non_overridable :: get_coordinates => fe_map_face_restriction_get_coordinates
  end type fe_map_face_restriction_t

  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  character(*), parameter :: field_type_scalar           = 'scalar'
  character(*), parameter :: field_type_vector           = 'vector'
  character(*), parameter :: field_type_tensor           = 'tensor'
  character(*), parameter :: field_type_symmetric_tensor = 'symmetric_tensor'
  
  character(*), parameter :: topology_quad = "quad"
  character(*), parameter :: topology_tet  = "tet"
  character(*), parameter :: fe_type_lagrangian = "Lagrangian"
  
  ! Abstract reference_fe
  type, abstract ::  reference_fe_t
     private
     character(:), allocatable :: &
          topology,               &    ! topology of element, 'tet', 'quad', 'prism', ...
          fe_type,                &    ! 'Lagrangian', 'RT', ...
          field_type                   ! 'scalar', 'vector', 'tensor', 'symmetric_tensor'

     integer(ip)              ::    &        
          number_dimensions,        &
          order,                    &
          number_field_components

     logical                  ::    &
          continuity                  ! CG(.true.)/DG(.false.)

     integer(ip)              ::    &
          number_vefs,              &        
          number_nodes,             &        
          number_vefs_dimension(5)

     type(allocatable_array_ip1_t)  :: orientation        ! orientation of the vefs 
     type(list_t)                   :: interior_nodes_vef ! interior nodes per vef
     type(list_t)                   :: nodes_vef          ! all nodes per vef
     type(list_t)                   :: vertices_vef       ! vertices per vef
     type(list_t)                   :: vefs_vef           ! all vefs per vef
   contains
     ! TBPs
     ! Fill topology, fe_type, number_dimensions, order, continuity 
     procedure(create_interface)                        , deferred :: create 
     ! TBP to create a quadrature for a reference_fe_t
     procedure(create_quadrature_interface)             , deferred :: create_quadrature
     !procedure(create_quadrature_on_faces_interface)    , deferred :: create_quadrature_on_faces
     procedure(create_face_quadrature_interface)        , deferred :: create_face_quadrature
     ! TBP to create an interpolation from a quadrature_t and reference_fe_t, 
     ! i.e., the value of the shape functions of the reference element on the quadrature points. 
     procedure(create_interpolation_interface)          , deferred :: create_interpolation 
     procedure(create_face_interpolation_interface)     , deferred :: create_face_interpolation
     procedure(create_face_local_interpolation_interface),deferred :: create_face_local_interpolation
     procedure(update_interpolation_interface)          , deferred :: update_interpolation
     procedure(update_interpolation_face_interface)     , deferred :: update_interpolation_face
     procedure(get_bc_component_node_interface)         , deferred :: get_bc_component_node
     
     procedure(get_value_scalar_interface)           , deferred :: get_value_scalar
     procedure(get_value_vector_interface)           , deferred :: get_value_vector
     !procedure(get_value_tensor_interface)          , deferred :: get_value_tensor           ! Pending
     !procedure(get_value_symmetric_tensor_interface), deferred :: get_value_symmetric_tensor ! Pending
     generic :: get_value => get_value_scalar,get_value_vector!                                      &
!          &                !,get_value_tensor,get_value_symmetric_tensor
    
     procedure(get_gradient_scalar_interface)          , deferred :: get_gradient_scalar
     procedure(get_gradient_vector_interface)          , deferred :: get_gradient_vector
     !procedure(get_gradient_tensor_interface)          , deferred :: get_gradient_tensor ! Pending
     generic :: get_gradient => get_gradient_scalar,get_gradient_vector!                             &
!          &                   !,get_value_tensor,get_value_symmetric_tensor
                                                                                     
     !procedure(get_symmetric_gradient_vector_interface), deferred :: get_symmetric_gradient_vector ! Pending
     !generic :: get_symmetric_gradient => get_symmetric_gradient_scalar

     procedure(get_divergence_vector_interface)        , deferred :: get_divergence_vector ! Pending
   !  procedure(get_divergence_tensor_interface)        , deferred :: get_divergence_tensor ! Pending
     generic :: get_divergence => get_divergence_vector !, get_divergence_tensor
                                                                                     
     procedure(get_curl_vector_interface)              , deferred :: get_curl_vector ! Pending
     generic :: get_curl => get_curl_vector

     procedure(evaluate_fe_function_scalar_interface), deferred :: evaluate_fe_function_scalar
     procedure(evaluate_fe_function_vector_interface), deferred :: evaluate_fe_function_vector
     procedure(evaluate_fe_function_tensor_interface), deferred :: evaluate_fe_function_tensor
     generic :: evaluate_fe_function => evaluate_fe_function_scalar, &
                                      & evaluate_fe_function_vector, &
                                      & evaluate_fe_function_tensor
     
     ! This subroutine gives the reodering (o2n) of the nodes of an vef given an orientation 'o'
     ! and a delay 'r' wrt to a refence element sharing the same vef.
     procedure (permute_order_vef_interface)    , deferred :: permute_order_vef
     procedure (get_characteristic_length_interface) , deferred :: get_characteristic_length

     ! generic part of the subroutine above
     procedure :: permute_nodes_per_vef => reference_fe_permute_nodes_per_vef
     procedure :: free  => reference_fe_free
     procedure :: print => reference_fe_print

     ! Set number_dimensions, order, continuity, field_type, number_field_components
     procedure :: set_common_data => reference_fe_set_common_data
     procedure :: set_topology => reference_fe_set_topology
     procedure :: set_fe_type => reference_fe_set_fe_type

     ! Getters
     procedure :: get_topology => reference_fe_get_topology
     procedure :: get_fe_type => reference_fe_get_fe_type
     procedure :: get_field_type => reference_fe_get_field_type
     procedure :: get_number_dimensions => reference_fe_get_number_dimensions
     procedure :: get_order => reference_fe_get_order
     procedure :: get_continuity => reference_fe_get_continuity
     procedure :: get_number_field_components => reference_fe_get_number_field_components
     procedure :: get_number_vefs => reference_fe_get_number_vefs
     procedure :: get_number_vertices => reference_fe_get_number_vertices
     procedure :: get_first_vertex_id => reference_fe_get_first_vertex_id
     procedure :: get_number_vertices_per_vertex => reference_fe_get_number_vertices_per_vertex
     procedure :: get_number_vertices_per_edge => reference_fe_get_number_vertices_per_edge
     procedure :: get_number_vertices_per_face => reference_fe_get_number_vertices_per_face
     procedure :: get_number_edges => reference_fe_get_number_edges
     procedure :: get_first_edge_id => reference_fe_get_first_edge_id
     procedure :: get_number_faces => reference_fe_get_number_faces
     procedure :: get_first_face_id => reference_fe_get_first_face_id
     procedure :: get_number_vefs_of_dimension  => reference_fe_get_number_vefs_of_dimension
     procedure :: get_first_vef_id_of_dimension => reference_fe_get_first_vef_id_of_dimension 
     procedure :: get_number_nodes => reference_fe_get_number_nodes
     procedure :: get_vef_dimension  => reference_fe_get_vef_dimension
     procedure :: get_interior_nodes_vef  => reference_fe_get_interior_nodes_vef
     procedure :: get_nodes_vef  =>     reference_fe_get_nodes_vef
     procedure :: get_vertices_vef  =>   reference_fe_get_vertices_vef
     procedure :: get_vefs_vef   =>   reference_fe_get_vefs_vef
     procedure :: get_node_vef => reference_fe_get_node_vef
     procedure :: get_interior_node_vef => reference_fe_get_interior_node_vef
     procedure :: get_number_nodes_vef => reference_fe_get_number_nodes_vef
     procedure :: get_number_interior_nodes_vef => reference_fe_get_number_interior_nodes_vef
     procedure :: get_number_vertices_vef => reference_fe_get_number_vertices_vef
     procedure :: get_orientation => reference_fe_get_orientation     
  end type reference_fe_t

  type p_reference_fe_t
    class(reference_fe_t), pointer :: p => NULL()
  contains
    procedure :: free => p_reference_fe_free
  end type p_reference_fe_t

  abstract interface
     subroutine create_interface ( this, number_dimensions, order, field_type, continuity )
       import :: reference_fe_t, ip
       implicit none 
       class(reference_fe_t), intent(inout) :: this 
       integer(ip)          , intent(in)    :: number_dimensions
       integer(ip)          , intent(in)    :: order
       character(*)         , intent(in)    :: field_type
       logical, optional    , intent(in)    :: continuity
     end subroutine create_interface
     
     subroutine create_quadrature_interface ( this, quadrature, max_order )
       import :: reference_fe_t, quadrature_t, ip
       implicit none 
       class(reference_fe_t), intent(in)    :: this
       type(quadrature_t), intent(inout) :: quadrature
       integer(ip), optional, intent(in)    :: max_order
     end subroutine create_quadrature_interface
 
     subroutine create_face_quadrature_interface ( this, quadrature, max_order  )
       import :: reference_fe_t, quadrature_t, ip
       implicit none
       class(reference_fe_t), intent(in)    :: this
       type(quadrature_t), intent(inout) :: quadrature
       integer(ip), optional, intent(in)    :: max_order
     end subroutine create_face_quadrature_interface
     
     subroutine create_interpolation_interface ( this, quadrature, interpolation, compute_hessian )
       import :: reference_fe_t, quadrature_t, interpolation_t
       implicit none 
       class(reference_fe_t)   , intent(in)    :: this 
       type(quadrature_t)   , intent(in)    :: quadrature
       type(interpolation_t), intent(inout) :: interpolation
       logical       , optional, intent(in)    :: compute_hessian
     end subroutine create_interpolation_interface

     subroutine create_face_local_interpolation_interface ( this, quadrature, interpolation )
       import :: reference_fe_t, quadrature_t, interpolation_t
       implicit none
       class(reference_fe_t)   , intent(in)    :: this
       type(quadrature_t)   , intent(in)    :: quadrature
       type(interpolation_t), intent(inout) :: interpolation
     end subroutine create_face_local_interpolation_interface

     subroutine create_face_interpolation_interface ( this, local_face_id , local_quadrature,       &
          &                                           face_interpolation)
       import :: reference_fe_t, ip, quadrature_t, interpolation_t
       implicit none 
       class(reference_fe_t)     , intent(in)    :: this
       integer(ip)               , intent(in)    :: local_face_id
       type(quadrature_t)     , intent(in)    :: local_quadrature
       type(interpolation_t)  , intent(inout) :: face_interpolation
     end subroutine create_face_interpolation_interface
 
     function get_bc_component_node_interface( this, node )
       import :: reference_fe_t, ip
       implicit none
       class(reference_fe_t), intent(in) :: this 
       integer(ip), intent(in) :: node
       integer(ip) :: get_bc_component_node_interface
     end function get_bc_component_node_interface

     subroutine get_value_scalar_interface( this, actual_cell_interpolation, ishape, qpoint,        &
          &                                 scalar_field )
       import :: reference_fe_t, interpolation_t, ip, rp
       implicit none
       class(reference_fe_t)   , intent(in)  :: this 
       type(interpolation_t), intent(in)  :: actual_cell_interpolation 
       integer(ip)             , intent(in)  :: ishape
       integer(ip)             , intent(in)  :: qpoint
       real(rp)                , intent(out) :: scalar_field
     end subroutine get_value_scalar_interface
     
     subroutine get_value_vector_interface( this, actual_cell_interpolation, ishape, qpoint,        &
          &                                 vector_field )
       import :: reference_fe_t, interpolation_t, vector_field_t, ip
       implicit none
       class(reference_fe_t)   , intent(in)  :: this 
       type(interpolation_t), intent(in)  :: actual_cell_interpolation 
       integer(ip)             , intent(in)  :: ishape
       integer(ip)             , intent(in)  :: qpoint
       type(vector_field_t)    , intent(out) :: vector_field
     end subroutine get_value_vector_interface
     
     subroutine get_gradient_scalar_interface( this, actual_cell_interpolation, ishape, qpoint,     &
          &                                    vector_field )
       import :: reference_fe_t, interpolation_t, vector_field_t, ip
       implicit none
       class(reference_fe_t)   , intent(in)  :: this 
       type(interpolation_t), intent(in)  :: actual_cell_interpolation 
       integer(ip)             , intent(in)  :: ishape
       integer(ip)             , intent(in)  :: qpoint
       type(vector_field_t)    , intent(out) :: vector_field
     end subroutine get_gradient_scalar_interface
     
     subroutine get_gradient_vector_interface( this, actual_cell_interpolation, ishape, qpoint,     &
          &                                    tensor_field )
       import :: reference_fe_t, interpolation_t, tensor_field_t, ip
       implicit none
       class(reference_fe_t)   , intent(in)  :: this 
       type(interpolation_t), intent(in)  :: actual_cell_interpolation 
       integer(ip)             , intent(in)  :: ishape
       integer(ip)             , intent(in)  :: qpoint
       type(tensor_field_t)    , intent(out) :: tensor_field
     end subroutine get_gradient_vector_interface

     subroutine get_divergence_vector_interface( this, actual_cell_interpolation, ishape, qpoint,        &
          &                                 scalar_field )
      import :: reference_fe_t, interpolation_t, ip, rp
       implicit none
       class(reference_fe_t)   , intent(in)  :: this 
       type(interpolation_t), intent(in)  :: actual_cell_interpolation 
       integer(ip)             , intent(in)  :: ishape
       integer(ip)             , intent(in)  :: qpoint
       real(rp)                , intent(out) :: scalar_field
     end subroutine get_divergence_vector_interface

     subroutine get_curl_vector_interface( this, actual_cell_interpolation, ishape, qpoint,     &
          &                                    vector_field )
       import :: reference_fe_t, interpolation_t, vector_field_t, ip
       implicit none
       class(reference_fe_t)   , intent(in)  :: this 
       type(interpolation_t), intent(in)  :: actual_cell_interpolation 
       integer(ip)             , intent(in)  :: ishape
       integer(ip)             , intent(in)  :: qpoint
       type(vector_field_t)    , intent(out) :: vector_field
     end subroutine get_curl_vector_interface

     subroutine evaluate_fe_function_scalar_interface( this, &
                                                     & actual_cell_interpolation, &
                                                     & nodal_values, &
                                                     & quadrature_points_values)
       import :: reference_fe_t, interpolation_t, rp
       implicit none
       class(reference_fe_t)   , intent(in)    :: this 
       type(interpolation_t), intent(in)    :: actual_cell_interpolation 
       real(rp)                , intent(in)    :: nodal_values(:)
       real(rp)                , intent(inout) :: quadrature_points_values(:)
     end subroutine evaluate_fe_function_scalar_interface

     subroutine evaluate_fe_function_vector_interface( this, &
                                                     & actual_cell_interpolation, &
                                                     & nodal_values, &
                                                     & quadrature_points_values)
       import :: reference_fe_t, interpolation_t, rp, vector_field_t
       implicit none
       class(reference_fe_t)   , intent(in)    :: this 
       type(interpolation_t), intent(in)    :: actual_cell_interpolation 
       real(rp)                , intent(in)    :: nodal_values(:)
       type(vector_field_t)    , intent(inout) :: quadrature_points_values(:)
     end subroutine evaluate_fe_function_vector_interface

     subroutine evaluate_fe_function_tensor_interface( this, &
                                                     & actual_cell_interpolation, &
                                                     & nodal_values, &
                                                     & quadrature_points_values)
       import :: reference_fe_t, interpolation_t, rp, tensor_field_t
       implicit none
       class(reference_fe_t)   , intent(in)    :: this 
       type(interpolation_t), intent(in)    :: actual_cell_interpolation 
       real(rp)                , intent(in)    :: nodal_values(:)
       type(tensor_field_t)    , intent(inout) :: quadrature_points_values(:)
     end subroutine evaluate_fe_function_tensor_interface     
     
     subroutine permute_order_vef_interface( this, o2n,p,o,r,nd )
       import :: reference_fe_t, ip
       implicit none
       class(reference_fe_t), intent(in) :: this 
       integer(ip), intent(in)    :: p,o,r,nd
       integer(ip), intent(inout) :: o2n(:)
     end subroutine permute_order_vef_interface

     function get_characteristic_length_interface( this)
       import :: reference_fe_t, rp
       implicit none 
       class(reference_fe_t), intent(in) :: this 
       real(rp)  :: get_characteristic_length_interface 
     end function get_characteristic_length_interface

     subroutine update_interpolation_interface ( this, fe_map, interpolation_reference_cell,        &
          &                            interpolation_real_cell )
       import :: reference_fe_t, fe_map_t, interpolation_t
       implicit none 
       class(reference_fe_t)    , intent(in)    :: this 
       type(fe_map_t)           , intent(in)    :: fe_map
       type(interpolation_t) , intent(in)    :: interpolation_reference_cell
       type(interpolation_t) , intent(inout) :: interpolation_real_cell
     end subroutine update_interpolation_interface

     subroutine update_interpolation_face_interface ( this, local_face_id,fe_map_face_restriction,  &
          &                                           interpolation_face_restriction)
       import :: reference_fe_t, ip, fe_map_face_restriction_t,  interpolation_face_restriction_t
       implicit none 
       class(reference_fe_t)                 , intent(in)    :: this 
       integer(ip)                           , intent(in)    :: local_face_id
       type(fe_map_face_restriction_t)       , intent(in)    :: fe_map_face_restriction
       type(interpolation_face_restriction_t), intent(inout) :: interpolation_face_restriction
     end subroutine update_interpolation_face_interface
     
  end interface

  public :: reference_fe_t, p_reference_fe_t
  public :: field_type_scalar, field_type_vector, field_type_tensor, field_type_symmetric_tensor
  public :: topology_quad, topology_tet, fe_type_lagrangian

  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  type, extends(reference_fe_t) :: quad_lagrangian_reference_fe_t
     private
     integer(ip)              :: number_nodes_scalar
     integer(ip), allocatable :: node_component_array(:,:)
   contains 
     ! Deferred TBP implementors
     procedure :: create                    => quad_lagrangian_reference_fe_create
     procedure :: create_quadrature         => quad_lagrangian_reference_fe_create_quadrature
     !procedure :: create_quadrature_on_faces                                                           &
     !     &                           => quad_lagrangian_reference_fe_create_quadrature_on_faces
     procedure :: create_face_quadrature    => quad_lagrangian_reference_fe_create_face_quadrature
     procedure :: create_interpolation      => quad_lagrangian_reference_fe_create_interpolation
     procedure :: create_face_interpolation => quad_lagrangian_reference_fe_create_face_interpolation
     procedure :: create_face_local_interpolation                                                      &
          &                          => quad_lagrangian_reference_fe_create_face_local_interpolation
     procedure :: update_interpolation      => quad_lagrangian_reference_fe_update_interpolation
     procedure :: update_interpolation_face => quad_lagrangian_reference_fe_update_interpolation_face
     procedure :: get_bc_component_node     => quad_lagrangian_reference_fe_get_bc_component_node
     procedure :: permute_order_vef         => quad_lagrangian_reference_fe_permute_order_vef

     procedure :: get_value_scalar          => quad_lagrangian_reference_fe_get_value_scalar
     procedure :: get_value_vector          => quad_lagrangian_reference_fe_get_value_vector
     procedure :: get_gradient_scalar       => quad_lagrangian_reference_fe_get_gradient_scalar
     procedure :: get_gradient_vector       => quad_lagrangian_reference_fe_get_gradient_vector
     procedure :: get_divergence_vector     => quad_lagrangian_reference_fe_get_divergence_vector
     procedure :: get_curl_vector           => quad_lagrangian_reference_fe_get_curl_vector

     procedure :: evaluate_fe_function_scalar => quad_lagrangian_reference_fe_evaluate_fe_function_scalar
     procedure :: evaluate_fe_function_vector => quad_lagrangian_reference_fe_evaluate_fe_function_vector
     procedure :: evaluate_fe_function_tensor => quad_lagrangian_reference_fe_evaluate_fe_function_tensor

     ! Concrete TBPs of this derived data type
     procedure :: fill                      => quad_lagrangian_reference_fe_fill
     procedure :: free                      => quad_lagrangian_reference_fe_free
     procedure :: get_characteristic_length &
          &                          => quad_lagrangian_reference_fe_get_characteristic_length
  end type quad_lagrangian_reference_fe_t
  
  public :: quad_lagrangian_reference_fe_t

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type volume_integrator_t 
  private
  integer(ip)                    :: number_shape_functions
  integer(ip)                    :: number_evaluation_points
  class(reference_fe_t), pointer :: reference_fe
  type(interpolation_t)       :: interpolation      ! Unknown interpolation_t in the reference element domain
  type(interpolation_t)       :: interpolation_o_map! Unknown interpolation_t in the physical element domain
contains

  procedure, non_overridable :: create => volume_integrator_create
  procedure, non_overridable :: free   => volume_integrator_free
  procedure, non_overridable :: update => volume_integrator_update
  procedure, non_overridable :: print  => volume_integrator_print
  
  procedure, non_overridable :: get_interpolation_reference_cell =>                                 &
       &                                   volume_integrator_get_interpolation_reference_cell
  procedure, non_overridable :: get_interpolation_real_cell =>                                 &
       &                                   volume_integrator_get_interpolation_real_cell


  procedure, non_overridable, private :: get_value_scalar           => volume_integrator_get_value_scalar
  procedure, non_overridable, private :: get_value_vector           => volume_integrator_get_value_vector
  procedure, non_overridable, private :: get_value_tensor           => volume_integrator_get_value_tensor
  procedure, non_overridable, private :: get_value_symmetric_tensor => volume_integrator_get_value_symmetric_tensor
  generic            :: get_value => get_value_scalar, &
                                     get_value_vector, &
                                     get_value_tensor, &
                                     get_value_symmetric_tensor
    
  procedure, non_overridable, private :: get_gradient_scalar => volume_integrator_get_gradient_scalar
  procedure, non_overridable, private :: get_gradient_vector => volume_integrator_get_gradient_vector
  generic                             :: get_gradient => get_gradient_scalar, &
                                                         get_gradient_vector 

  procedure, non_overridable, private :: get_symmetric_gradient_vector => volume_integrator_get_symmetric_gradient_vector
  generic                             :: get_symmetric_gradient => get_symmetric_gradient_vector
  
  procedure, non_overridable, private :: get_divergence_vector => volume_integrator_get_divergence_vector
  procedure, non_overridable, private :: get_divergence_tensor => volume_integrator_get_divergence_tensor
  generic                             :: get_divergence => get_divergence_vector, &
                                                           get_divergence_tensor

														   procedure, non_overridable, private :: get_curl_vector => volume_integrator_get_curl_vector
  generic                             :: get_curl => get_curl_vector
  
  ! We might want to have the following in the future:
  !  (x) get_hessian (scalar,vector)
  !  (x) get_third_derivative (scalar,vector)
  ! But note that in such a case we would require higher-to-2 rank tensors
  ! (i.e., type(tensor_field_t) is a rank-2 tensor)
  
  procedure, non_overridable, private :: volume_integrator_evaluate_fe_function_scalar
  procedure, non_overridable, private :: volume_integrator_evaluate_fe_function_vector
  procedure, non_overridable, private :: volume_integrator_evaluate_fe_function_tensor
  generic :: evaluate_fe_function => volume_integrator_evaluate_fe_function_scalar, &
                                   & volume_integrator_evaluate_fe_function_vector, &
                                   & volume_integrator_evaluate_fe_function_tensor

end type volume_integrator_t

type p_volume_integrator_t
  type(volume_integrator_t), pointer :: p => NULL() 
contains
  procedure :: allocate => p_volume_integrator_allocate 
  procedure :: free     => p_volume_integrator_free
end type p_volume_integrator_t

public :: volume_integrator_t, p_volume_integrator_t

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type face_map_t
   private
   logical                         :: is_boundary
   type(fe_map_t)                  :: face_map
   type(fe_map_face_restriction_t) :: fe_maps(2)
 contains
   procedure, non_overridable :: create               => face_map_create
   procedure, non_overridable :: free                 => face_map_free
   procedure, non_overridable :: update               => face_map_update
   procedure, non_overridable :: compute_characteristic_length &
        &                                             => face_map_compute_characteristic_length
   procedure, non_overridable :: get_face_coordinates => face_map_get_face_coordinates
   procedure, non_overridable :: get_coordinates_neighbour                                          &
        &                                             => face_map_get_coordinates_neighbour
   procedure, non_overridable :: get_neighbour_fe_map => face_map_get_neighbour_fe_map
   procedure, non_overridable :: get_normals          => face_map_get_normals
   procedure, non_overridable :: get_det_jacobian     => face_map_get_det_jacobian
end type face_map_t

public :: face_map_t

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type face_integrator_t
   private
   logical                                :: is_boundary
   type(interpolation_face_restriction_t) :: interpolation_face_restriction(2)
   type(p_reference_fe_t)                 :: reference_fe(2)
 contains
   procedure, non_overridable :: create            => face_integrator_create
   procedure, non_overridable :: update            => face_integrator_update
   procedure, non_overridable :: free              => face_integrator_free
   procedure, non_overridable :: get_value_scalar  => face_integrator_get_value_scalar
   generic :: get_value => get_value_scalar
   procedure, non_overridable :: get_gradient_scalar                                              &
        &                                          => face_integrator_get_gradient_scalar
   generic :: get_gradient => get_gradient_scalar
end type face_integrator_t

type p_face_integrator_t
  type(face_integrator_t)          , pointer :: p => NULL()
end type p_face_integrator_t

public :: face_integrator_t, p_face_integrator_t

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

contains

  ! Includes with all the TBP and supporting subroutines for the types above.
  ! In a future, we would like to use the submodule features of FORTRAN 2008.

#include "sbm_quadrature.i90"

#include "sbm_interpolation.i90"

#include "sbm_reference_fe.i90"

#include "sbm_quad_lagrangian_reference_fe.i90"

#include "sbm_volume_integrator.i90"

#include "sbm_face_integrator.i90"

end module reference_fe_names
