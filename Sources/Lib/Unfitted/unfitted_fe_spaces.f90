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

module unfitted_fe_spaces_names
  use fempar_names
  use unfitted_triangulations_names
  use piecewise_fe_map_names
  use hp_adaptive_fe_space_names

  implicit none
# include "debug.i90"
  private

  type, extends(fe_iterator_t) :: unfitted_fe_iterator_t

    private
    class(unfitted_integration_manager_t), pointer :: unfitted_integration_manager => NULL()

  contains

    ! Creation / deletion methods
    procedure :: create => unfitted_fe_iterator_create
    procedure :: free   => unfitted_fe_iterator_free

    ! Getters that override
    procedure          :: get_quadrature        => unfitted_fe_iterator_get_quadrature
    procedure          :: get_fe_map            => unfitted_fe_iterator_get_fe_map
    procedure          :: get_cell_integrator   => unfitted_fe_iterator_get_cell_integrator

    ! Getters that extend
    procedure          :: get_boundary_quadrature          => unfitted_fe_iterator_get_boundary_quadrature
    procedure          :: get_boundary_piecewise_fe_map    => unfitted_fe_iterator_get_boundary_piecewise_fe_map
    procedure          :: get_boundary_fe_map              => unfitted_fe_iterator_get_boundary_fe_map
    procedure          :: get_boundary_cell_integrator     => unfitted_fe_iterator_get_boundary_cell_integrator

    ! Updater that overrides
    procedure :: update_integration     => unfitted_fe_iterator_update_integration
    
    ! Updater that extends
    procedure :: update_boundary_integration  => unfitted_fe_iterator_update_boundary_integration

    ! Private TBPs
    procedure, non_overridable, private :: update_cut_quadratures => unfitted_fe_iterator_update_cut_quadratures
    procedure, non_overridable, private :: update_cut_fe_maps     => unfitted_fe_iterator_update_cut_fe_maps
    procedure, non_overridable, private :: update_cut_cell_integrators  => unfitted_fe_iterator_update_cut_cell_integrators
    procedure, non_overridable, private :: update_cut_boundary_quadratures => unfitted_fe_iterator_update_cut_boundary_quadratures
    procedure, non_overridable, private :: update_cut_boundary_fe_maps     => unfitted_fe_iterator_update_cut_boundary_fe_maps
    procedure, non_overridable, private :: update_cut_boundary_cell_integrators  => &
    unfitted_fe_iterator_update_cut_boundary_cell_integrators

  end type unfitted_fe_iterator_t

  type, extends(unfitted_fe_iterator_t) :: unfitted_hp_adaptive_fe_iterator_t
      type (hp_adaptive_fe_iterator_t) :: adaptive_fe
    contains

      ! We need to override the functions that change the state
      procedure :: create               => unfitted_hp_adaptive_fe_iterator_create
      procedure :: free                 => unfitted_hp_adaptive_fe_iterator_free
      procedure :: next                 => unfitted_hp_adaptive_fe_iterator_next
      procedure :: first                => unfitted_hp_adaptive_fe_iterator_first
      procedure :: last                 => unfitted_hp_adaptive_fe_iterator_last
      procedure :: set_lid              => unfitted_hp_adaptive_fe_iterator_set_lid

      ! Overridden in hp_adaptive_fe_iterator_t
      procedure :: assemble             => unfitted_hp_adaptive_fe_iterator_assemble

  end type unfitted_hp_adaptive_fe_iterator_t


  type :: unfitted_integration_manager_t

    private

    class(serial_fe_space_t), pointer :: fe_space       => NULL()
    class(marching_cubes_t),  pointer :: marching_cubes => NULL()

    ! All the machinery for integrating in subcells
    type(quadrature_t)                     :: quadrature_subelem
    type(tet_lagrangian_reference_fe_t)    :: geo_reference_subelem
    type(fe_map_t)                         :: fe_map_subelem
    type(quadrature_t),        allocatable :: cut_quadratures(:)
    type(fe_map_t),            allocatable :: cut_fe_maps(:)
    type(cell_integrator_t),   allocatable :: cut_cell_integrators(:,:)

    ! All the machinery for integrating in subfaces
    type(quadrature_t)                     :: quadrature_subface
    type(quadrature_t),        allocatable :: cut_boundary_quadratures_cell_dim(:)
    type(piecewise_fe_map_t),  allocatable :: cut_boundary_piecewise_fe_maps(:)
    type(fe_map_t),            allocatable :: cut_boundary_fe_maps(:)
    type(cell_integrator_t),   allocatable :: cut_boundary_cell_integrators(:,:)    

    ! Auxiliary dummy empty quadratures
    type(quadrature_t)             :: empty_quadrature
    type(fe_map_t)                 :: empty_fe_map
    type(piecewise_fe_map_t)       :: empty_piecewise_fe_map
    type(cell_integrator_t), allocatable  :: empty_cell_integrator(:)
    
    contains

      ! Creation / Deletion methods
      procedure, non_overridable :: create => uim_create
      procedure, non_overridable :: free   => uim_free
      
      !Private TBPs
      procedure, non_overridable, private :: check_assumptions      => uim_check_assumptions
      procedure, non_overridable, private :: init_reference_subelem => uim_init_reference_subelem
      procedure, non_overridable, private :: free_reference_subelem => uim_free_reference_subelem
      procedure, non_overridable, private :: init_reference_subface => uim_init_reference_subface
      procedure, non_overridable, private :: free_reference_subface => uim_free_reference_subface
      procedure, non_overridable, private :: init_cut_integration   => uim_init_cut_integration
      procedure, non_overridable, private :: free_cut_integration   => uim_free_cut_integration
      procedure, non_overridable, private :: init_cut_boundary_integration   => uim_init_cut_boundary_integration
      procedure, non_overridable, private :: free_cut_boundary_integration   => uim_free_cut_boundary_integration

  end type unfitted_integration_manager_t

  type, extends(serial_fe_space_t) :: serial_unfitted_fe_space_t
    private

      class(serial_unfitted_triangulation_t), pointer :: unfitted_triangulation =>  NULL()
      type(unfitted_integration_manager_t) :: unfitted_integration

    contains

      ! Creation / deletion methods
      procedure,  private :: serial_fe_space_create_same_reference_fes_on_all_cells => sufs_create_same_reference_fes_on_all_cells
      procedure,  private :: serial_fe_space_create_different_between_cells         => sufs_space_create_different_between_cells
      procedure           :: free  => sufs_free

      ! Creation of the iterator
      procedure :: create_fe_iterator           => sufs_create_fe_iterator

  end type serial_unfitted_fe_space_t

  type, extends(serial_hp_adaptive_fe_space_t) :: serial_unfitted_hp_adaptive_fe_space_t
    private

      class(unfitted_p4est_serial_triangulation_t), pointer :: unfitted_triangulation =>  NULL()
      type(unfitted_integration_manager_t) :: unfitted_integration
      integer(ip), allocatable :: aggregate_ids(:)

    contains

      ! Creation / deletion methods
      procedure           :: serial_fe_space_create_same_reference_fes_on_all_cells => suhpafs_create_same_reference_fes_on_all_cells
      procedure           :: serial_fe_space_create_different_between_cells         => suhpafs_space_create_different_between_cells
      procedure           :: free  => suhpafs_free
      
      ! Creation of the iterator
      procedure :: create_fe_iterator                                               => suhpafs_create_fe_iterator
      
      ! Creation of constrained degrees of freedom
      procedure          :: fill_dof_info                                           => suhpafs_fill_dof_info 
      procedure, private :: fill_elem2dof_and_count_dofs                            => suhpafs_procedure_fill_elem2dof_and_count_dofs

      ! Getters
      procedure, non_overridable :: get_aggregate_ids                               => suhpafs_get_aggregate_ids

      ! Private TBPs
      procedure, private, non_overridable :: allocate_and_fill_aggregate_ids        => suhpafs_allocate_and_fill_aggregate_ids
      procedure, private, non_overridable :: setup_cut_cells_constraints            => suhpafs_setup_cut_cells_constraints
      

  end type serial_unfitted_hp_adaptive_fe_space_t

  type, extends(par_fe_space_t) :: par_unfitted_fe_space_t
    private

      class(par_unfitted_triangulation_t), pointer :: unfitted_triangulation =>  NULL()
      type(unfitted_integration_manager_t) :: unfitted_integration

    contains

      ! Creation / deletion methods
      procedure,  private :: par_fe_space_create_same_reference_fes_on_all_cells => pufs_create_same_reference_fes_on_all_cells
      procedure,  private :: par_fe_space_create_different_between_cells         => pufs_create_different_between_cells
      procedure           :: free  => pufs_free

      ! Creation of the iterator
      procedure :: create_fe_iterator           => pufs_create_fe_iterator

  end type par_unfitted_fe_space_t


  public :: unfitted_fe_iterator_t
  public :: unfitted_hp_adaptive_fe_iterator_t
  public :: serial_unfitted_fe_space_t
  public :: serial_unfitted_hp_adaptive_fe_space_t
  public :: par_unfitted_fe_space_t

contains

#include "sbm_unfitted_fe_iterator.i90"
#include "sbm_unfitted_hp_adaptive_fe_iterator.i90"
#include "sbm_unfitted_integration_manager.i90"
#include "sbm_serial_unfitted_fe_space.i90"
#include "sbm_serial_unfitted_hp_adaptive_fe_space.i90"
#include "sbm_par_unfitted_fe_space.i90"

end module unfitted_fe_spaces_names
