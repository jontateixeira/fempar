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
module output_handler_cell_fe_function_names
    use types_names
    use list_types_names
    use hash_table_names
    use allocatable_array_names

    use reference_fe_names
    use base_static_triangulation_names
    use fe_space_names
    use fe_function_names
    use environment_names
    use field_names
  
    ! Linear algebra
    use vector_names
    use serial_scalar_array_names

    use output_handler_fe_field_names
    use output_handler_patch_names
    use output_handler_fe_iterator_names
    use output_handler_parameters_names
  
implicit none
# include "debug.i90"
private  

    type :: fill_patch_field_procedure_t
        procedure(fill_patch_field_interface), nopass, pointer :: p => NULL()
    end type
  
    type :: output_handler_cell_fe_function_t
    private
        integer(ip)                                    :: number_dimensions = 0
        integer(ip)                                    :: number_nodes      = 0
        integer(ip)                                    :: number_cells      = 0
        type(fe_accessor_t), pointer                   :: current_fe => NULL()
        type(quadrature_t),        allocatable         :: quadratures(:)
        type(fe_map_t),            allocatable         :: fe_maps(:)
        type(volume_integrator_t), allocatable         :: volume_integrators(:)
        type(hash_table_ip_ip_t)                       :: quadratures_and_maps_position ! Key = max_order_within_fe
        type(hash_table_ip_ip_t)                       :: volume_integrators_position   ! Key = [max_order_within_fe,
                                                                                        !       reference_fe_id]
        type(fill_patch_field_procedure_t), allocatable:: fill_patch_field(:)

        contains
            procedure, non_overridable :: create                              => output_handler_cell_fe_function_create
            procedure, non_overridable :: get_number_nodes                    => output_handler_cell_fe_function_get_number_nodes
            procedure, non_overridable :: get_number_cells                    => output_handler_cell_fe_function_get_number_cells
            procedure, non_overridable :: fill_patch                          => output_handler_cell_fe_function_fill_patch
            procedure, non_overridable :: free                                => output_handler_cell_fe_function_free

            ! Strategy procedures to fill patch field data
            procedure, non_overridable, private :: apply_fill_patch_field_strategy => &
                                                            output_handler_cell_fe_function_apply_fill_patch_field_strategy
            procedure, non_overridable, private :: fill_patch_scalar_field_val     => &
                                                            output_handler_cell_fe_function_fill_patch_scalar_field_val
            procedure, non_overridable, private :: fill_patch_scalar_field_grad    => &
                                                            output_handler_cell_fe_function_fill_patch_scalar_field_grad
            procedure, non_overridable, private :: fill_patch_vector_field_val     => &
                                                            output_handler_cell_fe_function_fill_patch_vector_field_val
            procedure, non_overridable, private :: fill_patch_vector_field_grad    => &
                                                            output_handler_cell_fe_function_fill_patch_vector_field_grad
            procedure, non_overridable, private :: fill_patch_vector_field_div     => &
                                                            output_handler_cell_fe_function_fill_patch_vector_field_div
            procedure, non_overridable, private :: fill_patch_vector_field_curl    => &
                                                            output_handler_cell_fe_function_fill_patch_vector_field_curl
            procedure, non_overridable, private :: fill_patch_tensor_field_val     => &
                                                            output_handler_cell_fe_function_fill_patch_tensor_field_val

            procedure, non_overridable, private :: generate_vol_integ_pos_key => output_handler_cell_fe_function_generate_vol_integ_pos_key
            procedure, non_overridable, private :: get_number_reference_fes   => output_handler_cell_fe_function_get_number_reference_fes
            procedure, non_overridable, private :: get_quadrature             => output_handler_cell_fe_function_get_quadrature
            procedure, non_overridable, private :: get_fe_map                 => output_handler_cell_fe_function_get_fe_map
            procedure, non_overridable, private :: get_volume_integrator      => output_handler_cell_fe_function_get_volume_integrator      
    end type output_handler_cell_fe_function_t


    interface 
        subroutine fill_patch_field_interface(this, fe_function, field_id, patch_field)
            import ip
            import fe_function_t
            import output_handler_patch_field_t
            import output_handler_cell_fe_function_t
            class(output_handler_cell_fe_function_t), intent(inout) :: this
            type(fe_function_t),                      intent(in)    :: fe_function
            integer(ip),                              intent(in)    :: field_id
            type(output_handler_patch_field_t),       intent(inout) :: patch_field
        end subroutine fill_patch_field_interface
    end interface
  
public :: output_handler_cell_fe_function_t
  
contains

!  ! Includes with all the TBP and supporting subroutines for the types above.
!  ! In a future, we would like to use the submodule features of FORTRAN 2008.

    subroutine output_handler_cell_fe_function_create ( this, fe_space, output_handler_fe_iterator, &
                                                        number_fields, fe_fields, num_refinements )
    !-----------------------------------------------------------------
    !< Create output_handler_cell_fe_function
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        class(serial_fe_space_t),                 intent(in)    :: fe_space
        class(output_handler_fe_iterator_t),      intent(inout) :: output_handler_fe_iterator
        integer(ip),                              intent(in)    :: number_fields
        type(output_handler_fe_field_t),          intent(in)    :: fe_fields(1:number_fields)
        integer(ip), optional,                    intent(in)    :: num_refinements
        class(base_static_triangulation_t), pointer             :: triangulation
        type(fe_accessor_t)                                     :: fe
        class(reference_fe_t),            pointer               :: reference_fe
        class(lagrangian_reference_fe_t), pointer               :: reference_fe_geo
        class(environment_t),             pointer               :: environment
        integer(ip)                                             :: current_quadrature_and_map
        integer(ip)                                             :: current_volume_integrator
        integer(ip)                                             :: max_order_within_fe, max_order_field_id
        integer(ip)                                             :: vol_integ_pos_key
        integer(ip)                                             :: istat, field_id, quadrature_and_map_pos
        integer(ip)                                             :: reference_fe_id
        integer(ip)                                             :: number_field
        character(len=:), allocatable                           :: field_type
        character(len=:), allocatable                           :: diff_operator
    !-----------------------------------------------------------------
        environment => fe_space%get_environment()
        if (environment%am_i_l1_task()) then

            triangulation => fe_space%get_triangulation()
            this%number_dimensions = triangulation%get_num_dimensions()
            this%number_cells       = 0
            this%number_nodes       = 0

            allocate ( this%quadratures(fe_space%get_number_reference_fes()), stat=istat); check (istat==0)
            allocate ( this%fe_maps(fe_space%get_number_reference_fes()), stat=istat); check (istat==0)
            allocate ( this%volume_integrators(fe_space%get_number_reference_fes()), stat=istat); check (istat==0)

            ! Create quadratures, fe_maps, and volume_integrators
            call this%quadratures_and_maps_position%init()
            call this%volume_integrators_position%init()
            current_quadrature_and_map = 1
            current_volume_integrator  = 1

            call output_handler_fe_iterator%init()
            do while ( .not. output_handler_fe_iterator%has_finished() ) 
                call output_handler_fe_iterator%current(fe)
                reference_fe_geo => fe%get_reference_fe_geo()
                max_order_within_fe = fe%get_max_order()
                call this%quadratures_and_maps_position%put(key = max_order_within_fe, &
                                                            val = current_quadrature_and_map, &
                                                            stat = istat)
                if (istat == now_stored) then
                    ! Create quadrature and fe_map associated to current max_order_within_fe
                    call reference_fe_geo%create_data_out_quadrature(num_refinements = max_order_within_fe-1, &
                                                                     quadrature      = this%quadratures(current_quadrature_and_map))
                    call this%fe_maps(current_quadrature_and_map)%create(this%quadratures(current_quadrature_and_map),&
                                                                         reference_fe_geo)
                    current_quadrature_and_map = current_quadrature_and_map + 1
                end if
                do field_id=1, fe_space%get_number_fields()
                    vol_integ_pos_key = this%generate_vol_integ_pos_key(fe_space%get_number_reference_fes(), &
                                                                        max_order_within_fe, &
                                                                        fe%get_reference_fe_id(field_id))
                    call this%volume_integrators_position%put(key=vol_integ_pos_key, &
                                                              val=current_volume_integrator, &
                                                              stat=istat)
                    if (istat == now_stored) then
                        call this%quadratures_and_maps_position%get(key = max_order_within_fe, &
                                                                    val = quadrature_and_map_pos, &
                                                                    stat = istat)
                        assert ( istat == key_found )
                        call this%volume_integrators(current_volume_integrator)%create(this%quadratures(quadrature_and_map_pos),&
                                                                                       fe%get_reference_fe(field_id))
                        current_volume_integrator = current_volume_integrator + 1
                    end if
                end do
                if ( fe%is_local() ) then
                    this%number_cells = this%number_cells + reference_fe_geo%get_number_subcells(max_order_within_fe-1)
                    this%number_nodes = this%number_nodes + &
                            (reference_fe_geo%get_number_subcells(max_order_within_fe-1)*reference_fe_geo%get_number_vertices())
                endif
                call output_handler_fe_iterator%next()
            end do

            ! Configure fill_patch_field strategy for each field
            if(allocated(this%fill_patch_field)) deallocate(this%fill_patch_field)
            allocate(this%fill_patch_field(number_fields))

            do number_field = 1, number_fields
                field_type    = fe_space%get_field_type(fe_fields(number_field)%get_field_id())
                diff_operator = fe_fields(number_field)%get_diff_operator()
                call this%apply_fill_patch_field_strategy(field_type, diff_operator, this%fill_patch_field(number_field)%p)
            end do
        end if
    end subroutine output_handler_cell_fe_function_create


    function output_handler_cell_fe_function_get_number_nodes(this) result(number_nodes)
    !-----------------------------------------------------------------
    !< Return number of nodes
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t),  intent(in) :: this
        integer(ip)                                           :: number_nodes
    !-----------------------------------------------------------------
        number_nodes = this%number_nodes
    end function output_handler_cell_fe_function_get_number_nodes


    function output_handler_cell_fe_function_get_number_cells(this) result(number_cells)
    !-----------------------------------------------------------------
    !< Return number of cells
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t),  intent(in) :: this
        integer(ip)                                           :: number_cells
    !-----------------------------------------------------------------
        number_cells = this%number_cells
    end function output_handler_cell_fe_function_get_number_cells


    subroutine output_handler_cell_fe_function_fill_patch(this, fe_accessor, number_fields, fe_fields, patch)
    !-----------------------------------------------------------------
    !< Fill a patch given a fe_accessor
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t),  intent(inout) :: this
        type(fe_accessor_t),               target, intent(in)    :: fe_accessor
        integer(ip),                               intent(in)    :: number_fields
        type(output_handler_fe_field_t),           intent(in)    :: fe_fields(1:number_fields)
        type(output_handler_patch_t),              intent(inout) :: patch
        integer(ip)                                              :: reference_fe_id
        integer(ip)                                              :: number_field
        integer(ip)                                              :: field_id
        integer(ip)                                              :: max_order_within_fe
        class(serial_fe_space_t),          pointer               :: fe_space
        type(fe_function_t),               pointer               :: fe_function
        class(lagrangian_reference_fe_t),  pointer               :: reference_fe_geo
        class(environment_t),              pointer               :: environment
        type(point_t),                     pointer               :: coordinates(:)
        type(fe_map_t),                    pointer               :: fe_map
        type(quadrature_t),                pointer               :: quadrature
        type(output_handler_patch_field_t),pointer               :: patch_field
        type(allocatable_array_ip2_t),     pointer               :: patch_subcells_connectivity
        character(len=:), allocatable                            :: field_type
        character(len=:), allocatable                            :: diff_operator
    !-----------------------------------------------------------------
        this%current_fe => fe_accessor
        fe_space => fe_accessor%get_fe_space()
        environment => fe_space%get_environment()
        if (environment%am_i_l1_task()) then
            max_order_within_fe =  fe_accessor%get_max_order()
            reference_fe_geo    => fe_accessor%get_reference_fe_geo()
            fe_map              => this%get_fe_map()
            coordinates         => fe_map%get_coordinates()
            call this%current_fe%get_coordinates(coordinates)

            quadrature => this%get_quadrature()
            call fe_map%update(quadrature)

            ! Set subcell information into patch
            call patch%set_cell_type(reference_fe_geo%get_topology())
            call patch%set_number_dimensions(reference_fe_geo%get_number_dimensions())
            call patch%set_number_vertices_per_subcell(quadrature%get_number_quadrature_points())
            call patch%set_number_subcells(reference_fe_geo%get_number_subcells(num_refinements=max_order_within_fe-1))
            call patch%set_number_vertices_per_subcell(reference_fe_geo%get_number_vertices())

            ! Set patch coordinates from fe_map
            call patch%set_coordinates(fe_map%get_quadrature_points_coordinates())

            ! Set patch connectivities from reference_fe_geo given num_refinements
            patch_subcells_connectivity => patch%get_subcells_connectivity()
            call patch_subcells_connectivity%create(reference_fe_geo%get_number_vertices(), &
                                                    reference_fe_geo%get_number_subcells(num_refinements=max_order_within_fe-1))
            call reference_fe_geo%get_subcells_connectivity(num_refinements=max_order_within_fe-1, &
                                                            connectivity=patch_subcells_connectivity%a)

            ! Fill patch field data
            do number_field = 1, number_fields
                field_type    = fe_space%get_field_type(fe_fields(number_field)%get_field_id())
                diff_operator = fe_fields(number_field)%get_diff_operator()

                fe_function  => fe_fields(number_field)%get_fe_function()
                field_id     =  fe_fields(number_field)%get_field_id()
                patch_field  => patch%get_field(number_field)

                assert(associated(this%fill_patch_field(number_field)%p))
                call this%fill_patch_field(number_field)%p(this, fe_function, field_id, patch_field)
            end do
        end if
    end subroutine output_handler_cell_fe_function_fill_patch


    subroutine output_handler_cell_fe_function_apply_fill_patch_field_strategy(this, field_type, diff_operator, proc)
    !-----------------------------------------------------------------
    !< Choose strategy to fill patch field.
    !< Patch field calculation is distributed in several procedures
    !< in order to apply some diff operators
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t),       intent(inout) :: this
        character(len=:), allocatable,                  intent(in)    :: field_type
        character(len=:), allocatable,                  intent(in)    :: diff_operator
        procedure(fill_patch_field_interface), pointer, intent(inout) :: proc
    !-----------------------------------------------------------------
        select case(field_type)
            ! Select procedures to fill patch field from a scalar field  (Value or Grad)
            case ( field_type_scalar )
                select case (diff_operator)
                    case (no_diff_operator)
                        proc => output_handler_cell_fe_function_fill_patch_scalar_field_val
                    case (grad_diff_operator)
                        proc => output_handler_cell_fe_function_fill_patch_scalar_field_grad
                    case DEFAULT
                        check(.false.)
                end select
            ! Select procedures to fill patch field from a vector field (Value or Grad or Div or Curl)
            case ( field_type_vector )
                select case (diff_operator)
                    case (no_diff_operator)
                        proc => output_handler_cell_fe_function_fill_patch_vector_field_val
                    case (grad_diff_operator)
                        proc => output_handler_cell_fe_function_fill_patch_vector_field_grad
                    case (div_diff_operator)
                        proc => output_handler_cell_fe_function_fill_patch_vector_field_div
                    case (curl_diff_operator)
                        proc => output_handler_cell_fe_function_fill_patch_vector_field_curl
                    case DEFAULT
                        check(.false.)
                end select
            ! Select procedures to fill patch field from a tensor field (only Value)
            case ( field_type_tensor )
                select case (diff_operator)
                    case (no_diff_operator)
                        proc => output_handler_cell_fe_function_fill_patch_tensor_field_val
                    case DEFAULT
                        check(.false.)
                end select
        end select
    end subroutine output_handler_cell_fe_function_apply_fill_patch_field_strategy


    subroutine output_handler_cell_fe_function_fill_patch_scalar_field_val(this, fe_function, field_id, patch_field)
    !-----------------------------------------------------------------
    !< Fill the patch with field values given a scalar fe_field
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        type(fe_function_t),                      intent(in)    :: fe_function
        integer(ip),                              intent(in)    :: field_id
        type(output_handler_patch_field_t),       intent(inout) :: patch_field
        integer(ip)                                             :: reference_fe_id
        class(reference_fe_t),                    pointer       :: reference_fe
        type(fe_map_t),                           pointer       :: fe_map
        type(volume_integrator_t),                pointer       :: volume_integrator
        type(allocatable_array_rp1_t),            pointer       :: patch_field_nodal_values
        real(rp),              allocatable                      :: scalar_function_values(:)
        type(allocatable_array_rp1_t),            pointer       :: patch_field_scalar_function_values
    !-----------------------------------------------------------------
        ! Get reference_Fe
        reference_fe => this%current_fe%get_reference_fe(field_id)
        reference_fe_id = this%current_fe%get_reference_fe_id(field_id)
        assert(reference_fe%get_field_type() == field_type_scalar)

        ! Get and Update volume integrator
        fe_map            => this%get_fe_map()
        volume_integrator => this%get_volume_integrator(field_id) 
        call volume_integrator%update(fe_map)

        ! Gather DoFs of current cell + field_id on nodal_values 
        patch_field_nodal_values => patch_field%get_nodal_values()
        call patch_field_nodal_values%create(reference_fe%get_number_shape_functions())
        call fe_function%gather_nodal_values(this%current_fe, field_id, patch_field_nodal_values%a)

        ! Calculate scalar field values
        call patch_field%set_field_type(field_type_scalar)
        patch_field_scalar_function_values => patch_field%get_scalar_function_values()
        call patch_field_scalar_function_values%move_alloc_out(scalar_function_values) 
        call volume_integrator%evaluate_fe_function(patch_field_nodal_values%a, scalar_function_values)
        call patch_field_scalar_function_values%move_alloc_in(scalar_function_values) 

    end subroutine output_handler_cell_fe_function_fill_patch_scalar_field_val


    subroutine output_handler_cell_fe_function_fill_patch_scalar_field_grad(this, fe_function, field_id, patch_field)
    !-----------------------------------------------------------------
    !< Fill the patch with field gradients given a scalar fe_field
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        type(fe_function_t),                      intent(in)    :: fe_function
        integer(ip),                              intent(in)    :: field_id
        type(output_handler_patch_field_t),       intent(inout) :: patch_field
        integer(ip)                                             :: reference_fe_id
        class(reference_fe_t),                    pointer       :: reference_fe
        type(fe_map_t),                           pointer       :: fe_map
        type(volume_integrator_t),                pointer       :: volume_integrator
        type(allocatable_array_rp1_t),            pointer       :: patch_field_nodal_values
        type(vector_field_t),  allocatable                      :: vector_function_values(:)
        type(allocatable_array_vector_field_t),   pointer       :: patch_field_vector_function_values
    !-----------------------------------------------------------------
        ! Get reference_Fe
        reference_fe => this%current_fe%get_reference_fe(field_id)
        reference_fe_id = this%current_fe%get_reference_fe_id(field_id)
        assert(reference_fe%get_field_type() == field_type_scalar)

        ! Get and Update volume integrator
        fe_map            => this%get_fe_map()
        volume_integrator => this%get_volume_integrator(field_id) 
        call volume_integrator%update(fe_map)

        ! Gather DoFs of current cell + field_id on nodal_values 
        patch_field_nodal_values => patch_field%get_nodal_values()
        call patch_field_nodal_values%create(reference_fe%get_number_shape_functions())
        call fe_function%gather_nodal_values(this%current_fe, field_id, patch_field_nodal_values%a)

        ! Calculate scalar field gradients
        call patch_field%set_field_type(field_type_vector)
        patch_field_vector_function_values => patch_field%get_vector_function_values()
        call patch_field_vector_function_values%move_alloc_out(vector_function_values) 
        call volume_integrator%evaluate_gradient_fe_function(patch_field_nodal_values%a, vector_function_values)
        call patch_field_vector_function_values%move_alloc_in(vector_function_values) 

    end subroutine output_handler_cell_fe_function_fill_patch_scalar_field_grad


    subroutine output_handler_cell_fe_function_fill_patch_vector_field_val(this, fe_function, field_id, patch_field)
    !-----------------------------------------------------------------
    !< Fill the patch with field gradients given a scalar fe_field
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        type(fe_function_t),                      intent(in)    :: fe_function
        integer(ip),                              intent(in)    :: field_id
        type(output_handler_patch_field_t),       intent(inout) :: patch_field
        integer(ip)                                             :: reference_fe_id
        class(reference_fe_t),                    pointer       :: reference_fe
        type(fe_map_t),                           pointer       :: fe_map
        type(volume_integrator_t),                pointer       :: volume_integrator
        type(allocatable_array_rp1_t),            pointer       :: patch_field_nodal_values
        type(vector_field_t),  allocatable                      :: vector_function_values(:)
        type(allocatable_array_vector_field_t),   pointer       :: patch_field_vector_function_values
    !-----------------------------------------------------------------
        ! Get reference_Fe
        reference_fe => this%current_fe%get_reference_fe(field_id)
        reference_fe_id = this%current_fe%get_reference_fe_id(field_id)
        assert(reference_fe%get_field_type() == field_type_vector)

        ! Get and Update volume integrator
        fe_map            => this%get_fe_map()
        volume_integrator => this%get_volume_integrator(field_id) 
        call volume_integrator%update(fe_map)

        ! Gather DoFs of current cell + field_id on nodal_values 
        patch_field_nodal_values => patch_field%get_nodal_values()
        call patch_field_nodal_values%create(reference_fe%get_number_shape_functions())
        call fe_function%gather_nodal_values(this%current_fe, field_id, patch_field_nodal_values%a)

        ! Calculate vector field values
        call patch_field%set_field_type(field_type_vector)
        patch_field_vector_function_values => patch_field%get_vector_function_values()
        call patch_field_vector_function_values%move_alloc_out(vector_function_values) 
        call volume_integrator%evaluate_fe_function(patch_field_nodal_values%a, vector_function_values)
        call patch_field_vector_function_values%move_alloc_in(vector_function_values) 

    end subroutine output_handler_cell_fe_function_fill_patch_vector_field_val


    subroutine output_handler_cell_fe_function_fill_patch_vector_field_grad(this, fe_function, field_id, patch_field)
    !-----------------------------------------------------------------
    !< Fill the patch with field gradients given a vector fe_field
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        type(fe_function_t),                      intent(in)    :: fe_function
        integer(ip),                              intent(in)    :: field_id
        type(output_handler_patch_field_t),       intent(inout) :: patch_field
        integer(ip)                                             :: reference_fe_id
        class(reference_fe_t),                    pointer       :: reference_fe
        type(fe_map_t),                           pointer       :: fe_map
        type(volume_integrator_t),                pointer       :: volume_integrator
        type(allocatable_array_rp1_t),            pointer       :: patch_field_nodal_values
        type(tensor_field_t),  allocatable                      :: tensor_function_values(:)
        type(allocatable_array_tensor_field_t),   pointer       :: patch_field_tensor_function_values
    !-----------------------------------------------------------------
        ! Get reference_Fe
        reference_fe => this%current_fe%get_reference_fe(field_id)
        reference_fe_id = this%current_fe%get_reference_fe_id(field_id)
        assert(reference_fe%get_field_type() == field_type_vector)

        ! Get and Update volume integrator
        fe_map            => this%get_fe_map()
        volume_integrator => this%get_volume_integrator(field_id) 
        call volume_integrator%update(fe_map)

        ! Gather DoFs of current cell + field_id on nodal_values 
        patch_field_nodal_values => patch_field%get_nodal_values()
        call patch_field_nodal_values%create(reference_fe%get_number_shape_functions())
        call fe_function%gather_nodal_values(this%current_fe, field_id, patch_field_nodal_values%a)

        ! Calculate vector field gradients
        call patch_field%set_field_type(field_type_tensor)
        patch_field_tensor_function_values => patch_field%get_tensor_function_values()
        call patch_field_tensor_function_values%move_alloc_out(tensor_function_values) 
        call volume_integrator%evaluate_gradient_fe_function(patch_field_nodal_values%a, tensor_function_values)
        call patch_field_tensor_function_values%move_alloc_in(tensor_function_values) 

    end subroutine output_handler_cell_fe_function_fill_patch_vector_field_grad


    subroutine output_handler_cell_fe_function_fill_patch_vector_field_div(this, fe_function, field_id, patch_field)
    !-----------------------------------------------------------------
    !< Fill the patch with field divergence given a vector fe_field
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        type(fe_function_t),                      intent(in)    :: fe_function
        integer(ip),                              intent(in)    :: field_id
        type(output_handler_patch_field_t),       intent(inout) :: patch_field
        integer(ip)                                             :: reference_fe_id
        class(reference_fe_t),                    pointer       :: reference_fe
        type(fe_map_t),                           pointer       :: fe_map
        type(volume_integrator_t),                pointer       :: volume_integrator
        type(allocatable_array_rp1_t),            pointer       :: patch_field_nodal_values
        real(rp),              allocatable                      :: scalar_function_values(:)
        type(tensor_field_t),  allocatable                      :: tensor_function_values(:)
        type(allocatable_array_rp1_t),            pointer       :: patch_field_scalar_function_values
        type(allocatable_array_tensor_field_t),   pointer       :: patch_field_tensor_function_values
        integer(ip)                                             :: shape_function
        integer(ip)                                             :: dim
    !-----------------------------------------------------------------
        ! Get reference_Fe
        reference_fe => this%current_fe%get_reference_fe(field_id)
        reference_fe_id = this%current_fe%get_reference_fe_id(field_id)
        assert(reference_fe%get_field_type() == field_type_vector)

        ! Get and Update volume integrator
        fe_map            => this%get_fe_map()
        volume_integrator => this%get_volume_integrator(field_id) 
        call volume_integrator%update(fe_map)

        ! Gather DoFs of current cell + field_id on nodal_values 
        patch_field_nodal_values => patch_field%get_nodal_values()
        call patch_field_nodal_values%create(reference_fe%get_number_shape_functions())
        call fe_function%gather_nodal_values(this%current_fe, field_id, patch_field_nodal_values%a)

        call patch_field%set_field_type(field_type_scalar)

        ! get scalar and tensor function values
        patch_field_scalar_function_values => patch_field%get_scalar_function_values()
        patch_field_tensor_function_values => patch_field%get_tensor_function_values()
        call patch_field_scalar_function_values%move_alloc_out(scalar_function_values) 
        call patch_field_tensor_function_values%move_alloc_out(tensor_function_values) 

        ! Calculate gradients
        call volume_integrator%evaluate_gradient_fe_function(patch_field_nodal_values%a, tensor_function_values)

        ! Calculate divergence
        scalar_function_values = 0._rp
        do shape_function = 1, reference_fe%get_number_shape_functions()
            do dim = 1, this%number_dimensions
                scalar_function_values(shape_function) = &
                    scalar_function_values(shape_function) + tensor_function_values(shape_function)%get(dim, dim)
            enddo
        enddo 

        ! return scalar and tensor function values
        call patch_field_scalar_function_values%move_alloc_in(scalar_function_values)
        call patch_field_tensor_function_values%move_alloc_in(tensor_function_values)

    end subroutine output_handler_cell_fe_function_fill_patch_vector_field_div


    subroutine output_handler_cell_fe_function_fill_patch_vector_field_curl(this, fe_function, field_id, patch_field)
    !-----------------------------------------------------------------
    !< Fill the patch with field gradients given a vector fe_field
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        type(fe_function_t),                      intent(in)    :: fe_function
        integer(ip),                              intent(in)    :: field_id
        type(output_handler_patch_field_t),       intent(inout) :: patch_field
        integer(ip)                                             :: reference_fe_id
        class(reference_fe_t),                    pointer       :: reference_fe
        type(fe_map_t),                           pointer       :: fe_map
        type(volume_integrator_t),                pointer       :: volume_integrator
        type(allocatable_array_rp1_t),            pointer       :: patch_field_nodal_values
        real(rp),              allocatable                      :: scalar_function_values(:)
        type(vector_field_t),  allocatable                      :: vector_function_values(:)
        type(tensor_field_t),  allocatable                      :: tensor_function_values(:)
        type(allocatable_array_rp1_t),            pointer       :: patch_field_scalar_function_values
        type(allocatable_array_vector_field_t),   pointer       :: patch_field_vector_function_values
        type(allocatable_array_tensor_field_t),   pointer       :: patch_field_tensor_function_values
        integer(ip)                                             :: shape_function
    !-----------------------------------------------------------------
        ! Get reference_Fe
        reference_fe => this%current_fe%get_reference_fe(field_id)
        reference_fe_id = this%current_fe%get_reference_fe_id(field_id)
        assert(reference_fe%get_field_type() == field_type_vector)

        ! Get and Update volume integrator
        fe_map            => this%get_fe_map()
        volume_integrator => this%get_volume_integrator(field_id) 
        call volume_integrator%update(fe_map)

        ! Gather DoFs of current cell + field_id on nodal_values 
        patch_field_nodal_values => patch_field%get_nodal_values()
        call patch_field_nodal_values%create(reference_fe%get_number_shape_functions())
        call fe_function%gather_nodal_values(this%current_fe, field_id, patch_field_nodal_values%a)

        ! get vector and tensor function values
        patch_field_vector_function_values => patch_field%get_vector_function_values()
        patch_field_tensor_function_values => patch_field%get_tensor_function_values()
        call patch_field_tensor_function_values%move_alloc_out(tensor_function_values) 

        ! Calculate gradients
        call volume_integrator%evaluate_gradient_fe_function(patch_field_nodal_values%a, tensor_function_values)

        if(this%number_dimensions == 2) then
            call patch_field%set_field_type(field_type_scalar)
            patch_field_scalar_function_values => patch_field%get_scalar_function_values()
            call patch_field_scalar_function_values%move_alloc_out(scalar_function_values) 
            ! Calculate curl
            do shape_function = 1, reference_fe%get_number_shape_functions()
                scalar_function_values(shape_function) = &
                        tensor_function_values(shape_function)%get(1,2)-tensor_function_values(shape_function)%get(2,1)
            enddo
            call patch_field_scalar_function_values%move_alloc_in(scalar_function_values)     

        elseif(this%number_dimensions == 3) then
            call patch_field%set_field_type(field_type_vector)
            call patch_field_vector_function_values%move_alloc_out(vector_function_values) 
            ! Calculate curl
            do shape_function = 1, reference_fe%get_number_shape_functions()
                call vector_function_values(shape_function)%set(1, &
                        tensor_function_values(shape_function)%get(2,3)-tensor_function_values(shape_function)%get(3,2))
                call vector_function_values(shape_function)%set(2, &
                        tensor_function_values(shape_function)%get(3,1)-tensor_function_values(shape_function)%get(1,3))
                call vector_function_values(shape_function)%set(3, &
                        tensor_function_values(shape_function)%get(1,2)-tensor_function_values(shape_function)%get(2,1))
            enddo
            call patch_field_vector_function_values%move_alloc_in(vector_function_values) 
        endif

        ! return tensor function values
        call patch_field_tensor_function_values%move_alloc_in(tensor_function_values)

    end subroutine output_handler_cell_fe_function_fill_patch_vector_field_curl


    subroutine output_handler_cell_fe_function_fill_patch_tensor_field_val(this, fe_function, field_id, patch_field)
    !-----------------------------------------------------------------
    !< Fill the patch with field values given a tensor fe_field
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        type(fe_function_t),                      intent(in)    :: fe_function
        integer(ip),                              intent(in)    :: field_id
        type(output_handler_patch_field_t),       intent(inout) :: patch_field
        integer(ip)                                             :: reference_fe_id
        class(reference_fe_t),                    pointer       :: reference_fe
        type(fe_map_t),                           pointer       :: fe_map
        type(volume_integrator_t),                pointer       :: volume_integrator
        type(allocatable_array_rp1_t),            pointer       :: patch_field_nodal_values
        type(tensor_field_t),  allocatable                      :: tensor_function_values(:)
        type(allocatable_array_tensor_field_t),   pointer       :: patch_field_tensor_function_values
    !-----------------------------------------------------------------
        ! Get reference_Fe
        reference_fe => this%current_fe%get_reference_fe(field_id)
        reference_fe_id = this%current_fe%get_reference_fe_id(field_id)
        assert(reference_fe%get_field_type() == field_type_tensor)

        ! Get and Update volume integrator
        fe_map            => this%get_fe_map()
        volume_integrator => this%get_volume_integrator(field_id) 
        call volume_integrator%update(fe_map)

        ! Gather DoFs of current cell + field_id on nodal_values 
        patch_field_nodal_values => patch_field%get_nodal_values()
        call patch_field_nodal_values%create(reference_fe%get_number_shape_functions())
        call fe_function%gather_nodal_values(this%current_fe, field_id, patch_field_nodal_values%a)

        ! Calculate tensor field values
        call patch_field%set_field_type(field_type_tensor)
        patch_field_tensor_function_values => patch_field%get_tensor_function_values()
        call patch_field_tensor_function_values%move_alloc_out(tensor_function_values) 
        call volume_integrator%evaluate_fe_function(patch_field_nodal_values%a, tensor_function_values )
        call patch_field_tensor_function_values%move_alloc_in(tensor_function_values)

    end subroutine output_handler_cell_fe_function_fill_patch_tensor_field_val


    subroutine output_handler_cell_fe_function_free ( this )
    !-----------------------------------------------------------------
    !< Free procedure
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(inout) :: this
        integer(ip)                                             :: istat, i
    !-----------------------------------------------------------------
        call this%quadratures_and_maps_position%free()
        call this%volume_integrators_position%free()

        if(allocated(this%quadratures)) then
            do i=1, size(this%quadratures)
                call this%quadratures(i)%free()
            end do
            deallocate(this%quadratures, stat=istat)
            check(istat==0)
        end if

        if(allocated(this%fe_maps)) then
            do i=1, size(this%fe_maps)
                call this%fe_maps(i)%free()
            end do
            deallocate(this%fe_maps, stat=istat)
            check(istat==0)
        end if

        if(allocated(this%volume_integrators)) then
            do i=1, size(this%volume_integrators)
                call this%volume_integrators(i)%free()
            end do
            deallocate(this%volume_integrators, stat=istat)
            check(istat==0)
        end if

        this%number_cells = 0
        this%number_nodes = 0
    end subroutine output_handler_cell_fe_function_free


    function output_handler_cell_fe_function_generate_vol_integ_pos_key (this, num_reference_fes, max_order_within_fe, reference_fe_id ) result(vol_integ_pos_key)
    !-----------------------------------------------------------------
    !< Generate vol_integ_pos_key
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(in) :: this
        integer(ip),                              intent(in) :: num_reference_fes
        integer(ip),                              intent(in) :: max_order_within_fe
        integer(ip),                              intent(in) :: reference_fe_id
        integer(ip)                                          :: vol_integ_pos_key
    !-----------------------------------------------------------------
        vol_integ_pos_key = reference_fe_id + (max_order_within_fe)*num_reference_fes
      end function output_handler_cell_fe_function_generate_vol_integ_pos_key


    function output_handler_cell_fe_function_get_quadrature ( this ) result(quadrature)
    !-----------------------------------------------------------------
    !< Return the quadrature
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), target, intent(in) :: this
        type(quadrature_t),                       pointer            :: quadrature
        integer(ip)                                                  :: quadratures_position
        integer(ip)                                                  :: istat
    !-----------------------------------------------------------------
        assert ( associated(this%current_fe) )
        call this%quadratures_and_maps_position%get(key=this%current_fe%get_max_order(), &
             val=quadratures_position, &
             stat=istat)
        assert ( .not. istat == key_not_found )
        quadrature => this%quadratures(quadratures_position)
    end function output_handler_cell_fe_function_get_quadrature


    function output_handler_cell_fe_function_get_fe_map ( this ) result(fe_map)
    !-----------------------------------------------------------------
    !< Return the fe_map
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), target, intent(in) :: this
        type(fe_map_t),                           pointer            :: fe_map
        integer(ip)                                                  :: fe_maps_position
        integer(ip)                                                  :: istat
    !-----------------------------------------------------------------
        assert ( associated(this%current_fe) )
        call this%quadratures_and_maps_position%get(key=this%current_fe%get_max_order(), &
             val=fe_maps_position, &
             stat=istat)
        assert ( .not. istat == key_not_found )
        fe_map => this%fe_maps(fe_maps_position)
    end function output_handler_cell_fe_function_get_fe_map


    function output_handler_cell_fe_function_get_volume_integrator ( this, field_id ) result(volume_integrator)
    !-----------------------------------------------------------------
    !< Return the volume integrator corresponding with the field_id
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), target, intent(in) :: this
        integer(ip),                                      intent(in) :: field_id
        type(volume_integrator_t),                pointer            :: volume_integrator
        integer(ip)                                                  :: vol_integ_pos_key
        integer(ip)                                                  :: vol_integ_pos
        integer(ip)                                                  :: istat
    !-----------------------------------------------------------------
        assert ( associated(this%current_fe) )

        vol_integ_pos_key = &
             this%generate_vol_integ_pos_key(this%get_number_reference_fes(), &
             this%current_fe%get_max_order(), &
             this%current_fe%get_reference_fe_id(field_id))

        call this%volume_integrators_position%get(key=vol_integ_pos_key, &
             val=vol_integ_pos, &
             stat=istat)
        assert ( .not. istat == key_not_found )
        volume_integrator => this%volume_integrators(vol_integ_pos)
    end function output_handler_cell_fe_function_get_volume_integrator


    function output_handler_cell_fe_function_get_number_reference_fes ( this ) result(number_reference_fes)
    !-----------------------------------------------------------------
    !< Return the number of reference fes
    !-----------------------------------------------------------------
        class(output_handler_cell_fe_function_t), intent(in)   :: this
        integer(ip)                                            :: number_reference_fes
        class(serial_fe_space_t), pointer                      :: serial_fe_space
    !-----------------------------------------------------------------
        assert ( associated(this%current_fe) )
        serial_fe_space => this%current_fe%get_fe_space()
        number_reference_fes = serial_fe_space%get_number_reference_fes()
    end function output_handler_cell_fe_function_get_number_reference_fes

end module output_handler_cell_fe_function_names
