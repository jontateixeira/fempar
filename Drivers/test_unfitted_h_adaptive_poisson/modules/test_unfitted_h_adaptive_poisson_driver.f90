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

#define ENABLE_MKL

module test_unfitted_h_adaptive_poisson_driver_names
  use fempar_names
  use unfitted_triangulations_names
  use unfitted_fe_spaces_names
  use level_set_functions_gallery_names
  use unfitted_vtk_writer_names
  use unfitted_solution_checker_names
  use level_set_functions_gallery_names
  use unfitted_vtk_writer_names
  use test_poisson_params_names
  use poisson_unfitted_cG_discrete_integration_names
  use poisson_conditions_names
  use poisson_analytical_functions_names
  use vector_poisson_discrete_integration_names
  use vector_poisson_conditions_names
  use vector_poisson_analytical_functions_names
  use IR_Precision ! VTK_IO
  use Lib_VTK_IO ! VTK_IO
    
# include "debug.i90"

  implicit none
  private

  integer(ip), parameter :: SERIAL_UNF_POISSON_SET_ID_FULL = 1
  integer(ip), parameter :: SERIAL_UNF_POISSON_SET_ID_VOID = 2
  
  type test_unfitted_h_adaptive_poisson_driver_t 
     private 
     
     ! Place-holder for parameter-value set provided through command-line interface
     type(test_poisson_params_t)   :: test_params
     type(ParameterList_t)         :: parameter_list
     
     ! Cells and lower dimension objects container
     type(unfitted_p4est_serial_triangulation_t) :: triangulation

     ! Level set funciton describing the gemetry
     class(level_set_function_t), allocatable :: level_set_function

     ! Discrete weak problem integration-related data type instances 
     type(serial_unfitted_hp_adaptive_fe_space_t) :: fe_space 
     type(p_reference_fe_t), allocatable          :: reference_fes(:) 
     
     type(poisson_unfitted_cG_discrete_integration_t) :: poisson_cG_integration
     type(poisson_conditions_t)                   :: poisson_conditions
     type(poisson_analytical_functions_t)         :: poisson_analytical_functions
     
     type(vector_poisson_discrete_integration_t)  :: vector_poisson_integration
     type(vector_poisson_analytical_functions_t)  :: vector_poisson_analytical_functions
     type(vector_poisson_conditions_t)            :: vector_poisson_conditions
     
     ! Place-holder for the coefficient matrix and RHS of the linear system
     type(fe_affine_operator_t)                   :: fe_affine_operator
     
     ! Direct and Iterative linear solvers data type
#ifdef ENABLE_MKL     
     type(direct_solver_t)                     :: direct_solver
#else     
     type(iterative_linear_solver_t)           :: iterative_linear_solver
#endif     
 
     ! Poisson problem solution FE function
     type(fe_function_t)                       :: solution
   contains
     procedure                  :: run_simulation
     procedure        , private :: parse_command_line_parameters
     procedure        , private :: setup_levelset
     procedure        , private :: setup_triangulation
     procedure        , private :: set_cells_for_refinement
     procedure        , private :: set_cells_for_coarsening
     procedure        , private :: fill_cells_set
     procedure        , private :: setup_reference_fes
     procedure        , private :: setup_fe_space
     procedure        , private :: refine_and_coarsen
     procedure        , private :: setup_system
     procedure        , private :: setup_solver
     procedure        , private :: assemble_system
     procedure        , private :: solve_system     
     procedure        , private :: check_solution
     procedure        , private :: check_solution_vector
     procedure        , private :: write_solution
     procedure        , private :: write_filling_curve
     procedure        , private :: free
  end type test_unfitted_h_adaptive_poisson_driver_t

  ! Types
  public :: test_unfitted_h_adaptive_poisson_driver_t

contains

  subroutine parse_command_line_parameters(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t ), intent(inout) :: this
    call this%test_params%create()
    call this%test_params%parse(this%parameter_list)
  end subroutine parse_command_line_parameters

  subroutine setup_levelset(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t ), target, intent(inout) :: this

    integer(ip) :: num_dime
    integer(ip) :: istat
    class(level_set_function_t), pointer :: levset

    ! Get number of dimensions form input
    assert( this%parameter_list%isPresent    (key = number_of_dimensions_key) )
    assert( this%parameter_list%isAssignable (key = number_of_dimensions_key, value=num_dime) )
    istat = this%parameter_list%get          (key = number_of_dimensions_key, value=num_dime); check(istat==0)

    !TODO we assume it is a sphere
    select case ('sphere')
      case ('sphere')
        allocate( level_set_sphere_t:: this%level_set_function, stat= istat ); check(istat==0)
      case ('cylinder')
        allocate( level_set_cylinder_t:: this%level_set_function, stat= istat ); check(istat==0)
      case ('cheese_block')
        allocate( level_set_cheese_block_t:: this%level_set_function, stat= istat ); check(istat==0)
      case default
        check(.false.)
    end select


    ! Set options of the base class
    call this%level_set_function%set_num_dimensions(num_dime)
    call this%level_set_function%set_tolerance(1.0e-6)

    ! Set options of the derived classes
    levset => this%level_set_function
    select type ( levset )
      class is (level_set_sphere_t)
        call levset%set_radius(0.9)!0.625_rp)
      class default
        check(.false.)
    end select

  end subroutine setup_levelset

  subroutine setup_triangulation(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    class(vef_iterator_t),allocatable :: vef

    class(cell_iterator_t), allocatable :: cell
    integer(ip) :: ilev
    integer(ip) :: max_levels


    ! Create the triangulation, with the levelsetfunction
    call this%triangulation%create(this%parameter_list,this%level_set_function)

    ! Impose Dirichlet in the boundary of the background mesh
    if ( trim(this%test_params%get_triangulation_type()) == 'structured' ) then
       call this%triangulation%create_vef_iterator(vef)
       do while ( .not. vef%has_finished() )
          if(vef%is_at_boundary()) then
             call vef%set_set_id(1)
          else
             call vef%set_set_id(0)
          end if
          call vef%next()
       end do
       call this%triangulation%free_vef_iterator(vef)
    end if
    
    max_levels = 3
    do ilev = 1, max_levels
      ! Refine one level uniformly
      call this%triangulation%create_cell_iterator(cell)
      do while (.not. cell%has_finished())
        call cell%set_for_refinement()
        call cell%next()
      end do
      call this%triangulation%refine_and_coarsen()
      call this%triangulation%free_cell_iterator(cell)
    end do
    
    !! Refine one level uniformly
    !call this%triangulation%create_cell_iterator(cell)
    !do while (.not. cell%has_finished())
    !  call cell%set_for_refinement()
    !  call cell%next()
    !end do
    !call this%triangulation%refine_and_coarsen()    
    !call this%triangulation%free_cell_iterator(cell)
    
    !! Refine one level uniformly
    !call this%triangulation%create_cell_iterator(cell)
    !do while (.not. cell%has_finished())
    !  call cell%set_for_refinement()
    !  call cell%next()
    !end do
    !call this%triangulation%refine_and_coarsen()    
    !call this%triangulation%free_cell_iterator(cell)
    
    ! Update the marching cubes accordingly (TODO: move this inside refine and coarsen)
    call this%triangulation%update_cut_cells(this%level_set_function)
    
    !call this%triangulation%print()

  end subroutine setup_triangulation
  
  subroutine set_cells_for_refinement(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    class(cell_iterator_t)      , allocatable :: cell
    type(point_t), allocatable :: coords(:)
    integer(ip) :: istat, k
    real(rp) ::  x,y
    real(rp), parameter :: Re = 0.46875
    real(rp), parameter :: Ri = 0.15625
    real(rp) :: R
    integer(ip), parameter :: max_num_cell_nodes = 4
    integer(ip), parameter :: max_level = 2
    real(rp) :: val

    call this%triangulation%create_cell_iterator(cell)
    allocate(coords(max_num_cell_nodes),stat=istat); check(istat==0)

    do while ( .not. cell%has_finished() )

      !if ( mod(cell%get_lid()-1,2) == 0 ) then
      !  call cell%set_for_refinement()
      !end if

      call cell%get_coordinates(coords)
      do k=1,cell%get_num_nodes()
        call this%level_set_function%get_value_space(coords(k),val)
        if ( (val<0) .and. (cell%get_level()< max_level) .or. (cell%get_level() == 0)) then
          call cell%set_for_refinement()
          exit
        end if
      end do

      !x = 0.0
      !y = 0.0
      !do k=1,max_num_cell_nodes
      ! x = x + (1.0/max_num_cell_nodes)*coords(k)%get(1)
      ! y = y + (1.0/max_num_cell_nodes)*coords(k)%get(2)
      !end do
      !R = sqrt( (x-0.5)**2 + (y-0.5)**2 )
      !if ( ((R - Re) < 0.0) .and. ((R - Ri) > 0.0) .and. (cell%get_level()<= max_level) .or. (cell%get_level() == 0) )then
      !  call cell%set_for_refinement()
      !end if
      
      !if ( (cell%get_level()<= max_level) .or. (cell%get_level() == 0) ) then
      !  call cell%set_for_refinement()
      !end if

      !write(*,*) 'cid= ', cell%get_lid(), ' l= ', cell%get_level()

      call cell%next()
    end do

    deallocate(coords,stat=istat); check(istat==0)
    call this%triangulation%free_cell_iterator(cell)

  end subroutine set_cells_for_refinement
  
  subroutine set_cells_for_coarsening(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    class(cell_iterator_t)      , allocatable :: cell
    call this%triangulation%create_cell_iterator(cell)
    !do while ( .not. cell%has_finished() )
    !  call cell%set_for_coarsening()
    !  call cell%next()
    !end do
    call this%triangulation%free_cell_iterator(cell)
  end subroutine set_cells_for_coarsening
  
  subroutine fill_cells_set(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    integer(ip), allocatable :: cell_set_ids(:)
    class(cell_iterator_t), allocatable :: cell
    integer(ip) :: set_id
    
    call memalloc(this%triangulation%get_num_cells(),cell_set_ids)
    call this%triangulation%create_cell_iterator(cell)
    do while( .not. cell%has_finished() )
      if (cell%is_exterior()) then
        set_id = SERIAL_UNF_POISSON_SET_ID_VOID
      else
        set_id = SERIAL_UNF_POISSON_SET_ID_FULL
      end if
      cell_set_ids(cell%get_lid()) = set_id
      call cell%next()
    end do
    call this%triangulation%fill_cells_set(cell_set_ids)
    call this%triangulation%free_cell_iterator(cell)
    call memfree(cell_set_ids)
    
    !call memalloc(this%triangulation%get_num_cells(),cell_set_ids)
    !call this%triangulation%create_cell_iterator(cell)
    !do while( .not. cell%has_finished() )
    !  if (cell%is_local()) then
    !     cell_set_ids(cell%get_lid()) = cell%get_lid()
    !  end if
    !  call cell%next()
    !end do
    !call this%triangulation%free_cell_iterator(cell)
    !call this%triangulation%fill_cells_set(cell_set_ids)
    !call memfree(cell_set_ids)
    
  end subroutine fill_cells_set
  
  subroutine setup_reference_fes(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    integer(ip) :: istat    
    class(cell_iterator_t)          , allocatable :: cell
    class(lagrangian_reference_fe_t), pointer     :: reference_fe_geo
    character(:)                    , allocatable :: field_type
    
    type(interpolation_t), pointer :: h_refinement_interpolation
    integer(ip), pointer :: h_refinement_subface_permutation(:,:,:)
    integer(ip), pointer :: h_refinement_subedge_permutation(:,:,:)
    
    allocate(this%reference_fes(2), stat=istat)
    check(istat==0)
    
    field_type = field_type_scalar
    if ( this%test_params%get_laplacian_type() == 'vector' ) then
      field_type = field_type_vector
    end if
    
    call this%triangulation%create_cell_iterator(cell)
    reference_fe_geo => cell%get_reference_fe_geo()
    this%reference_fes(SERIAL_UNF_POISSON_SET_ID_FULL) =  make_reference_fe ( topology = reference_fe_geo%get_topology(), &
                                                 fe_type = fe_type_lagrangian, &
                                                 number_dimensions = this%triangulation%get_num_dimensions(), &
                                                 order = this%test_params%get_reference_fe_order(), &
                                                 field_type = field_type, &
                                                 conformity = .true. )
    this%reference_fes(SERIAL_UNF_POISSON_SET_ID_VOID) =  make_reference_fe ( topology = reference_fe_geo%get_topology(), &
                                                 fe_type = fe_type_void, &
                                                 number_dimensions = this%triangulation%get_num_dimensions(), &
                                                 order = this%test_params%get_reference_fe_order(), &
                                                 field_type = field_type, &
                                                 conformity = .true. )
    call this%triangulation%free_cell_iterator(cell)
    
    ! TODO Needed?
    select type( reference_fe => this%reference_fes(1)%p )
    type is (hex_lagrangian_reference_fe_t)
       h_refinement_interpolation       => reference_fe%get_h_refinement_interpolation()
       h_refinement_subface_permutation => reference_fe%get_h_refinement_subface_permutation()
       h_refinement_subedge_permutation => reference_fe%get_h_refinement_subedge_permutation()
    class default
      assert(.false.)
    end select
    
  end subroutine setup_reference_fes

  subroutine setup_fe_space(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this

    integer(ip) :: set_ids_to_reference_fes(1,2)

    set_ids_to_reference_fes(1,SERIAL_UNF_POISSON_SET_ID_FULL) = SERIAL_UNF_POISSON_SET_ID_FULL
    set_ids_to_reference_fes(1,SERIAL_UNF_POISSON_SET_ID_VOID) = SERIAL_UNF_POISSON_SET_ID_VOID
    
    if ( this%test_params%get_laplacian_type() == 'scalar' ) then
      call this%poisson_analytical_functions%set_num_dimensions(this%triangulation%get_num_dimensions())
      call this%poisson_conditions%set_boundary_function(this%poisson_analytical_functions%get_boundary_function())
      call this%fe_space%create( triangulation       = this%triangulation,      &
                                 conditions          = this%poisson_conditions, &
                                 reference_fes            = this%reference_fes,&
                                 set_ids_to_reference_fes = set_ids_to_reference_fes)
    else
      mcheck(.false., 'Not yed tested for vector problems')
      !call this%vector_poisson_analytical_functions%set_num_dimensions(this%triangulation%get_num_dimensions())
      !call this%vector_poisson_conditions%set_boundary_function(this%vector_poisson_analytical_functions%get_boundary_function()) 
      !call this%fe_space%create( triangulation       = this%triangulation,             &
      !                           conditions          = this%vector_poisson_conditions, &
      !                           reference_fes            = this%reference_fes,&
      !                           set_ids_to_reference_fes = set_ids_to_reference_fes)
    end if
    
    call this%fe_space%initialize_fe_integration()    
    if ( this%test_params%get_laplacian_type() == 'scalar' ) then
      call this%fe_space%interpolate_dirichlet_values(this%poisson_conditions)
    else
      call this%fe_space%interpolate_dirichlet_values(this%vector_poisson_conditions)
    end if
    
  end subroutine setup_fe_space
  
  subroutine refine_and_coarsen(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    integer(ip) :: i
    
    integer(ip) :: set_ids_to_reference_fes(1,2)

    set_ids_to_reference_fes(1,SERIAL_UNF_POISSON_SET_ID_FULL) = SERIAL_UNF_POISSON_SET_ID_FULL
    set_ids_to_reference_fes(1,SERIAL_UNF_POISSON_SET_ID_VOID) = SERIAL_UNF_POISSON_SET_ID_VOID
    
    do i=1, 10
       
       call this%triangulation%clear_refinement_and_coarsening_flags()
       if ( mod(i,3) == 0 ) then 
          call this%set_cells_for_coarsening()
       else
         call this%set_cells_for_refinement()
       end if
       !call this%fill_cells_set()
       call this%triangulation%refine_and_coarsen()
       
       if ( this%test_params%get_laplacian_type() == 'scalar' ) then
         call this%fe_space%refine_and_coarsen(this%solution) 
       else
         mcheck(.false.,'Only tested for scalar problems')
         !call this%fe_space%refine_and_coarsen( triangulation       = this%triangulation,             &
         !                                       conditions          = this%vector_poisson_conditions, &
         !                                       fe_function         = this%solution,           &
         !                                       set_ids_to_reference_fes = set_ids_to_reference_fes)
       end if
       
       call this%fe_space%initialize_fe_integration()
       
       !if ( this%test_params%get_laplacian_type() == 'scalar' ) then
       !  call this%check_solution()
       !else
       !  call this%check_solution_vector()
       !end if
       
    end do  
    
    call this%triangulation%update_cut_cells(this%level_set_function)
    
  end subroutine refine_and_coarsen
  
  subroutine setup_system (this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this

    if ( this%test_params%get_laplacian_type() == 'scalar' ) then    
      call this%poisson_cG_integration%set_analytical_functions(this%poisson_analytical_functions)
      call this%fe_affine_operator%create ( sparse_matrix_storage_format      = csr_format,                               &
                                            diagonal_blocks_symmetric_storage = [ .true. ],                               &
                                            diagonal_blocks_symmetric         = [ .true. ],                               &
                                            diagonal_blocks_sign              = [ SPARSE_MATRIX_SIGN_POSITIVE_DEFINITE ], &
                                            fe_space                          = this%fe_space,                            &
                                            discrete_integration              = this%poisson_cG_integration )
    else
       call this%vector_poisson_integration%set_source_term(this%vector_poisson_analytical_functions%get_source_term())
       call this%fe_affine_operator%create ( sparse_matrix_storage_format      = csr_format,                               &
                                             diagonal_blocks_symmetric_storage = [ .true. ],                               &
                                             diagonal_blocks_symmetric         = [ .true. ],                               &
                                             diagonal_blocks_sign              = [ SPARSE_MATRIX_SIGN_POSITIVE_DEFINITE ], &
                                             fe_space                          = this%fe_space,                            &
                                             discrete_integration              = this%vector_poisson_integration )
    end if
    
  end subroutine setup_system
  
  subroutine setup_solver (this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    integer :: FPLError
    type(parameterlist_t) :: parameter_list
    integer :: iparm(64)
    class(matrix_t), pointer       :: matrix

    call parameter_list%init()
#ifdef ENABLE_MKL
    FPLError = parameter_list%set(key = direct_solver_type,        value = pardiso_mkl)
    FPLError = FPLError + parameter_list%set(key = pardiso_mkl_matrix_type,   value = pardiso_mkl_spd)
    FPLError = FPLError + parameter_list%set(key = pardiso_mkl_message_level, value = 0)
    iparm = 0
    FPLError = FPLError + parameter_list%set(key = pardiso_mkl_iparm,         value = iparm)
    assert(FPLError == 0)
    
    call this%direct_solver%set_type_from_pl(parameter_list)
    call this%direct_solver%set_parameters_from_pl(parameter_list)
    
    matrix => this%fe_affine_operator%get_matrix()
    select type(matrix)
    class is (sparse_matrix_t)  
       call this%direct_solver%set_matrix(matrix)
    class DEFAULT
       assert(.false.) 
    end select
#else    
    FPLError = parameter_list%set(key = ils_rtol, value = 1.0e-12_rp)
    !FPLError = FPLError + parameter_list%set(key = ils_output_frequency, value = 30)
    FPLError = parameter_list%set(key = ils_max_num_iterations, value = 5000)
    assert(FPLError == 0)
    call this%iterative_linear_solver%create(this%fe_space%get_environment())
    call this%iterative_linear_solver%set_type_from_string(cg_name)
    call this%iterative_linear_solver%set_parameters_from_pl(parameter_list)
    call this%iterative_linear_solver%set_operators(this%fe_affine_operator, .identity. this%fe_affine_operator) 
#endif
    call parameter_list%free()
  end subroutine setup_solver
  
  
  subroutine assemble_system (this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    class(matrix_t)                  , pointer       :: matrix
    class(vector_t)                  , pointer       :: rhs
    call this%fe_affine_operator%numerical_setup()
    rhs                => this%fe_affine_operator%get_translation()
    matrix             => this%fe_affine_operator%get_matrix()
    
    select type(matrix)
    class is (sparse_matrix_t)  
       !call matrix%print_matrix_market(6) 
    class DEFAULT
       assert(.false.) 
    end select
    
    select type(rhs)
    class is (serial_scalar_array_t)  
    !call rhs%print(6) 
    class DEFAULT
       assert(.false.) 
    end select
  end subroutine assemble_system
  
  
  subroutine solve_system(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    class(matrix_t)                         , pointer       :: matrix
    class(vector_t)                         , pointer       :: rhs
    class(vector_t)                         , pointer       :: dof_values

    matrix     => this%fe_affine_operator%get_matrix()
    rhs        => this%fe_affine_operator%get_translation()
    dof_values => this%solution%get_dof_values()
    
#ifdef ENABLE_MKL    
    call this%direct_solver%solve(this%fe_affine_operator%get_translation(), dof_values)
#else
    call this%iterative_linear_solver%solve(this%fe_affine_operator%get_translation(), &
                                            dof_values)
#endif    
    
    call this%solution%update_fixed_dof_values(this%fe_space)
    
    !select type (dof_values)
    !class is (serial_scalar_array_t)  
    !   call dof_values%print(6)
    !class DEFAULT
    !   assert(.false.) 
    !end select
    
    !select type (matrix)
    !class is (sparse_matrix_t)  
    !   call this%direct_solver%update_matrix(matrix, same_nonzero_pattern=.true.)
    !   call this%direct_solver%solve(rhs , dof_values )
    !class DEFAULT
    !   assert(.false.) 
    !end select
  end subroutine solve_system
  
  subroutine check_solution(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    type(error_norms_scalar_t) :: error_norm
    real(rp) :: mean, l1, l2, lp, linfty, h1, h1_s, w1p_s, w1p, w1infty_s, w1infty
    real(rp) :: error_tolerance
    
    call error_norm%create(this%fe_space,1)
    mean = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, mean_norm)   
    l1 = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, l1_norm)   
    l2 = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, l2_norm)   
    lp = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, lp_norm)   
    linfty = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, linfty_norm)   
    h1_s = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, h1_seminorm) 
    h1 = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, h1_norm) 
    w1p_s = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, w1p_seminorm)   
    w1p = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, w1p_norm)   
    w1infty_s = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, w1infty_seminorm) 
    w1infty = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, w1infty_norm)

#ifdef ENABLE_MKL    
    error_tolerance = 1.0e-08
#else
    error_tolerance = 1.0e-06
#endif    
    
    write(*,'(a20,e32.25)') 'mean_norm:', mean; check ( abs(mean) < error_tolerance )
    write(*,'(a20,e32.25)') 'l1_norm:', l1; check ( l1 < error_tolerance )
    write(*,'(a20,e32.25)') 'l2_norm:', l2; check ( l2 < error_tolerance )
    write(*,'(a20,e32.25)') 'lp_norm:', lp; check ( lp < error_tolerance )
    write(*,'(a20,e32.25)') 'linfnty_norm:', linfty; check ( linfty < error_tolerance )
    write(*,'(a20,e32.25)') 'h1_seminorm:', h1_s; check ( h1_s < error_tolerance )
    write(*,'(a20,e32.25)') 'h1_norm:', h1; check ( h1 < error_tolerance )
    write(*,'(a20,e32.25)') 'w1p_seminorm:', w1p_s; check ( w1p_s < error_tolerance )
    write(*,'(a20,e32.25)') 'w1p_norm:', w1p; check ( w1p < error_tolerance )
    write(*,'(a20,e32.25)') 'w1infty_seminorm:', w1infty_s; check ( w1infty_s < error_tolerance )
    write(*,'(a20,e32.25)') 'w1infty_norm:', w1infty; check ( w1infty < error_tolerance )
    call error_norm%free()
  end subroutine check_solution
  
  subroutine check_solution_vector(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(in) :: this
    type(error_norms_vector_t) :: error_norm
    real(rp) :: mean, l1, l2, lp, linfty, h1, h1_s, w1p_s, w1p, w1infty_s, w1infty
    real(rp) :: error_tolerance
    
    call error_norm%create(this%fe_space,1)
    mean = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, mean_norm)   
    l1 = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, l1_norm)   
    l2 = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, l2_norm)   
    lp = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, lp_norm)   
    linfty = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, linfty_norm)   
    h1_s = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, h1_seminorm) 
    h1 = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, h1_norm) 
    w1p_s = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, w1p_seminorm)   
    w1p = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, w1p_norm)   
    w1infty_s = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, w1infty_seminorm) 
    w1infty = error_norm%compute(this%vector_poisson_analytical_functions%get_solution_function(), this%solution, w1infty_norm)

#ifdef ENABLE_MKL    
    error_tolerance = 1.0e-08
#else
    error_tolerance = 1.0e-06
#endif    
    
    write(*,'(a20,e32.25)') 'mean_norm:', mean; check ( abs(mean) < error_tolerance )
    write(*,'(a20,e32.25)') 'l1_norm:', l1; check ( l1 < error_tolerance )
    write(*,'(a20,e32.25)') 'l2_norm:', l2; check ( l2 < error_tolerance )
    write(*,'(a20,e32.25)') 'lp_norm:', lp; check ( lp < error_tolerance )
    write(*,'(a20,e32.25)') 'linfnty_norm:', linfty; check ( linfty < error_tolerance )
    write(*,'(a20,e32.25)') 'h1_seminorm:', h1_s; check ( h1_s < error_tolerance )
    write(*,'(a20,e32.25)') 'h1_norm:', h1; check ( h1 < error_tolerance )
    write(*,'(a20,e32.25)') 'w1p_seminorm:', w1p_s; check ( w1p_s < error_tolerance )
    write(*,'(a20,e32.25)') 'w1p_norm:', w1p; check ( w1p < error_tolerance )
    write(*,'(a20,e32.25)') 'w1infty_seminorm:', w1infty_s; check ( w1infty_s < error_tolerance )
    write(*,'(a20,e32.25)') 'w1infty_norm:', w1infty; check ( w1infty < error_tolerance )
    call error_norm%free()
  end subroutine check_solution_vector
  
  subroutine write_solution(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(in) :: this
    type(output_handler_t)                   :: oh
    character(len=:), allocatable            :: path
    character(len=:), allocatable            :: prefix
    real(rp),allocatable :: cell_vector(:)
    integer(ip) :: N, P, pid, i
    class(cell_iterator_t), allocatable :: cell
    
    real(rp),allocatable :: aggrs_ids(:)
    integer(ip), pointer :: aggregate_ids(:)
    
    type(unfitted_vtk_writer_t) :: vtk_writer

    if(this%test_params%get_write_solution()) then
        path = this%test_params%get_dir_path_out()
        prefix = this%test_params%get_prefix()
        call oh%create()
        call oh%attach_fe_space(this%fe_space)
        call oh%add_fe_function(this%solution, 1, 'solution')
        call oh%add_fe_function(this%solution, 1, 'grad_solution', grad_diff_operator)
        call memalloc(this%triangulation%get_num_cells(),cell_vector,__FILE__,__LINE__)
        call memalloc(this%triangulation%get_num_cells(),aggrs_ids,__FILE__,__LINE__)
        
        aggregate_ids => this%fe_space%get_aggregate_ids()
        aggrs_ids(:) = real(aggregate_ids,kind=rp)
        
        N=this%triangulation%get_num_cells()
        P=6
        call this%triangulation%create_cell_iterator(cell)
        do pid=0, P-1
            i=0
            do while ( i < (N*(pid+1))/P - (N*pid)/P ) 
              cell_vector(cell%get_lid()) = pid 
              call cell%next()
              i=i+1
            end do
        end do
        call this%triangulation%free_cell_iterator(cell)

        call oh%add_cell_vector(cell_vector,'cell_set_ids')
        
        call oh%add_cell_vector(aggrs_ids,'aggregate_ids')

        call oh%open(path, prefix)
        call oh%write()
        call oh%close()
        call oh%free()
        call memfree(cell_vector,__FILE__,__LINE__)
        call memfree(aggrs_ids,__FILE__,__LINE__)

        ! Write the unfitted mesh
        call vtk_writer%attach_triangulation(this%triangulation)
        call vtk_writer%write_to_vtk_file('out_mesh.vtu')
        call vtk_writer%free()
        
        ! Write the solution
        call vtk_writer%attach_fe_function(this%solution,this%fe_space)
        call vtk_writer%write_to_vtk_file('out_mesh_solution.vtu')
        call vtk_writer%free()
        

    endif
  end subroutine write_solution

  subroutine write_filling_curve(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(in) :: this

    integer(ip) :: Nn, Ne
    real(rp), allocatable :: x(:), y(:), z(:)
    integer(ip), allocatable :: cell_type(:), offset(:), connect(:)
    class(cell_iterator_t)      , allocatable :: cell
    type(point_t), allocatable :: coords(:)
    integer(ip) :: istat, k
    real(rp) ::  xc,yc
    integer(ip), parameter :: max_num_cell_nodes = 4
    integer(ip), parameter :: vtk_1d_elem_id = 3
    character(len=*), parameter :: filename_out = 'output/filling_curve.vtu'
    integer(ip) :: E_IO
    if(this%test_params%get_write_solution()) then

      Nn = this%triangulation%get_num_cells()
      Ne = Nn - 1

      call memalloc ( Nn, x, __FILE__, __LINE__ )
      call memalloc ( Nn, y, __FILE__, __LINE__ )
      call memalloc ( Nn, z, __FILE__, __LINE__ )
      call memalloc ( Ne, cell_type, __FILE__, __LINE__ )
      call memalloc ( Ne, offset   , __FILE__, __LINE__ )
      call memalloc ( 2*Ne, connect  , __FILE__, __LINE__ )

      call this%triangulation%create_cell_iterator(cell)
      allocate(coords(max_num_cell_nodes),stat=istat); check(istat==0)

      do while ( .not. cell%has_finished() )

        call cell%get_coordinates(coords)
        xc = 0.0
        yc = 0.0
        do k=1,max_num_cell_nodes
          xc = xc + (1.0/max_num_cell_nodes)*coords(k)%get(1)
          yc = yc + (1.0/max_num_cell_nodes)*coords(k)%get(2)
        end do

        x(cell%get_lid()) = xc;
        y(cell%get_lid()) = yc;
        z(cell%get_lid()) = 0.0;

        if (cell%get_lid()>1) then
          connect(  2*(cell%get_lid()-1)-1  ) = cell%get_lid()-2
          connect(  2*(cell%get_lid()-1)    ) = cell%get_lid()-1
          offset( cell%get_lid()-1 ) = 2*(cell%get_lid()-1)
          cell_type( cell%get_lid()-1 ) = vtk_1d_elem_id
        end if

        call cell%next()
      end do

      deallocate(coords,stat=istat); check(istat==0)
      call this%triangulation%free_cell_iterator(cell)

      E_IO = VTK_INI_XML(output_format = 'ascii', filename = filename_out, mesh_topology = 'UnstructuredGrid')
      E_IO = VTK_GEO_XML(NN = Nn, NC = Ne, X = x, Y = y, Z = z)
      E_IO = VTK_CON_XML(NC = Ne, connect = connect, offset = offset, cell_type = int(cell_type,I1P) )
      E_IO = VTK_GEO_XML()
      E_IO = VTK_END_XML()

      call memfree ( x, __FILE__, __LINE__ )
      call memfree ( y, __FILE__, __LINE__ )
      call memfree ( z, __FILE__, __LINE__ )
      call memfree ( cell_type, __FILE__, __LINE__ )
      call memfree ( offset   , __FILE__, __LINE__ )
      call memfree ( connect  , __FILE__, __LINE__ )

    endif
  end subroutine write_filling_curve
  
  subroutine run_simulation(this) 
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this    
    call this%free()
    call this%parse_command_line_parameters()
    call this%setup_levelset()
    call this%setup_triangulation()
    call this%fill_cells_set()
    call this%setup_reference_fes()
    
    !! It is conter intuitive that this is needed for adapting the mesh
    !call this%setup_fe_space()
    !call this%setup_system()
    !call this%assemble_system()
    !call this%solution%create(this%fe_space) 
    
    !! Adapt mesh
    !call this%refine_and_coarsen()
    !call this%fill_cells_set()
    
    ! Setup fe space and co for the new mesh 
    call this%setup_fe_space()
    call this%setup_system()
    call this%assemble_system()
    call this%setup_solver()
    call this%solution%create(this%fe_space) 
    call this%solve_system()
    !if ( this%test_params%get_laplacian_type() == 'scalar' ) then
    !  call this%check_solution()
    !else
    !  call this%check_solution_vector()
    !end if
    call this%write_solution()
    call this%write_filling_curve()
    call this%free()
  end subroutine run_simulation
  
  subroutine free(this)
    implicit none
    class(test_unfitted_h_adaptive_poisson_driver_t), intent(inout) :: this
    integer(ip) :: i, istat
    
    call this%solution%free()
    
#ifdef ENABLE_MKL        
    call this%direct_solver%free()
#else
    call this%iterative_linear_solver%free()
#endif
    
    call this%fe_affine_operator%free()
    call this%fe_space%free()
    if ( allocated(this%reference_fes) ) then
      do i=1, size(this%reference_fes)
        call this%reference_fes(i)%p%free()
      end do
      deallocate(this%reference_fes, stat=istat)
      check(istat==0)
    end if
    call this%triangulation%free()
    call this%test_params%free()
  end subroutine free  
  

  
end module test_unfitted_h_adaptive_poisson_driver_names
