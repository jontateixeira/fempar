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

module vector_poisson_analytical_functions_names
  use fempar_names
  use poisson_analytical_functions_names
  implicit none
# include "debug.i90"
  private

  type, extends(vector_function_t) :: base_vector_function_t
    integer(ip) :: num_dims = -1  
  contains
    procedure :: set_num_dims    => base_vector_function_set_num_dims
  end type base_vector_function_t
  
  
  type, extends(base_vector_function_t) :: source_term_t
   contains
     procedure :: get_value_space => source_term_get_value_space
  end type source_term_t

  type, extends(base_scalar_function_t) :: boundary_function_Hx_t
   contains
     procedure :: get_value_space => boundary_function_Hx_get_value_space  
  end type boundary_function_Hx_t
		
		  type, extends(base_scalar_function_t) :: boundary_function_Hy_t
   contains
     procedure :: get_value_space => boundary_function_Hy_get_value_space  
  end type boundary_function_Hy_t
		
		  type, extends(base_scalar_function_t) :: boundary_function_Hz_t
   contains
     procedure :: get_value_space => boundary_function_Hz_get_value_space  
  end type boundary_function_Hz_t

  type, extends(base_vector_function_t) :: solution_function_t
   contains
     procedure :: get_value_space    => solution_function_get_value_space
     procedure :: get_gradient_space => solution_function_get_gradient_space
  end type solution_function_t

  type vector_poisson_analytical_functions_t
     private
     type(source_term_t)            :: source_term
     type(boundary_function_Hx_t)   :: boundary_function_Hx
					type(boundary_function_Hy_t)   :: boundary_function_Hy
					type(boundary_function_Hz_t)   :: boundary_function_Hz
     type(solution_function_t)      :: solution_function
   contains
     procedure :: set_num_dims               => poisson_analytical_functions_set_num_dims
     procedure :: get_source_term            => poisson_analytical_functions_get_source_term
     procedure :: get_boundary_function_Hx   => poisson_analytical_functions_get_boundary_function_Hx
					procedure :: get_boundary_function_Hy   => poisson_analytical_functions_get_boundary_function_Hy
					procedure :: get_boundary_function_Hz   => poisson_analytical_functions_get_boundary_function_Hz
     procedure :: get_solution_function      => poisson_analytical_functions_get_solution_function
  end type vector_poisson_analytical_functions_t

  public :: vector_poisson_analytical_functions_t, boundary_function_Hx_t, boundary_function_Hy_t, boundary_function_Hz_t

contains  

  subroutine base_vector_function_set_num_dims ( this, num_dims )
    implicit none
    class(base_vector_function_t), intent(inout)    :: this
    integer(ip), intent(in) ::  num_dims
    this%num_dims = num_dims
  end subroutine base_vector_function_set_num_dims

  !===============================================================================================
  subroutine source_term_get_value_space ( this, point, result )
    implicit none
    class(source_term_t), intent(in)    :: this
    type(point_t)       , intent(in)    :: point
    type(vector_field_t), intent(inout) :: result

      call result%set(1, -point%get(2) ) 
      call result%set(2,  point%get(1) ) 
    if ( this%num_dims == 3 ) then 
      call result%set(3, 0.0_rp )
    end if
  end subroutine source_term_get_value_space

  !===============================================================================================
  subroutine boundary_function_Hx_get_value_space ( this, point, result )
    implicit none
    class(boundary_function_Hx_t), intent(in)    :: this
    type(point_t)           , intent(in)    :: point
    real(rp)                , intent(inout) :: result
    result = -point%get(2) 
  end subroutine boundary_function_Hx_get_value_space
		
		  !===============================================================================================
  subroutine boundary_function_Hy_get_value_space ( this, point, result )
    implicit none
    class(boundary_function_Hy_t), intent(in)    :: this
    type(point_t)           , intent(in)    :: point
    real(rp)                , intent(inout) :: result
    result = point%get(1) 
  end subroutine boundary_function_Hy_get_value_space
		
		  !===============================================================================================
  subroutine boundary_function_Hz_get_value_space ( this, point, result )
    implicit none
    class(boundary_function_Hz_t), intent(in)    :: this
    type(point_t)           , intent(in)    :: point
    real(rp)                , intent(inout) :: result
    result = 0.0_rp 
  end subroutine boundary_function_Hz_get_value_space

  !===============================================================================================
  subroutine solution_function_get_value_space ( this, point, result )
    implicit none
    class(solution_function_t), intent(in)    :: this
    type(point_t)           , intent(in)    :: point
    type(vector_field_t)    , intent(inout) :: result

      call result%set(1, -point%get(2) ) 
      call result%set(2,  point%get(1) ) 
    if ( this%num_dims == 3 ) then
      call result%set(3, 0.0_rp )
    end if
  end subroutine solution_function_get_value_space
  
  !===============================================================================================
  subroutine solution_function_get_gradient_space ( this, point, result )
    implicit none
    class(solution_function_t), intent(in)    :: this
    type(point_t)             , intent(in)    :: point
    type(tensor_field_t)      , intent(inout) :: result
    
				call result%set(1,2,  1.0_rp) 
				call result%set(2,1, -1.0_rp) 

  end subroutine solution_function_get_gradient_space
  
  !===============================================================================================
  subroutine poisson_analytical_functions_set_num_dims ( this, num_dims )
    implicit none
    class(vector_poisson_analytical_functions_t), intent(inout)    :: this
    integer(ip), intent(in) ::  num_dims
    call this%source_term%set_num_dims(num_dims)
    call this%boundary_function_Hx%set_num_dims(num_dims)
				call this%boundary_function_Hy%set_num_dims(num_dims)
				call this%boundary_function_Hz%set_num_dims(num_dims)
    call this%solution_function%set_num_dims(num_dims)
  end subroutine poisson_analytical_functions_set_num_dims 
  
  !===============================================================================================
  function poisson_analytical_functions_get_source_term ( this )
    implicit none
    class(vector_poisson_analytical_functions_t), target, intent(in)    :: this
    class(vector_function_t), pointer :: poisson_analytical_functions_get_source_term
    poisson_analytical_functions_get_source_term => this%source_term
  end function poisson_analytical_functions_get_source_term
  
  !===============================================================================================
  function poisson_analytical_functions_get_boundary_function_Hx ( this )
    implicit none
    class(vector_poisson_analytical_functions_t), target, intent(in)    :: this
    class(boundary_function_Hx_t), pointer :: poisson_analytical_functions_get_boundary_function_Hx
    poisson_analytical_functions_get_boundary_function_Hx => this%boundary_function_Hx
  end function poisson_analytical_functions_get_boundary_function_Hx
		
		  !===============================================================================================
  function poisson_analytical_functions_get_boundary_function_Hy ( this )
    implicit none
    class(vector_poisson_analytical_functions_t), target, intent(in)    :: this
    class(boundary_function_Hy_t), pointer :: poisson_analytical_functions_get_boundary_function_Hy
    poisson_analytical_functions_get_boundary_function_Hy => this%boundary_function_Hy
  end function poisson_analytical_functions_get_boundary_function_Hy
		
		  !===============================================================================================
  function poisson_analytical_functions_get_boundary_function_Hz ( this )
    implicit none
    class(vector_poisson_analytical_functions_t), target, intent(in)    :: this
    class(boundary_function_Hz_t), pointer :: poisson_analytical_functions_get_boundary_function_Hz
    poisson_analytical_functions_get_boundary_function_Hz => this%boundary_function_Hz
  end function poisson_analytical_functions_get_boundary_function_Hz
  
  !===============================================================================================
  function poisson_analytical_functions_get_solution_function ( this )
    implicit none
    class(vector_poisson_analytical_functions_t), target, intent(in)    :: this
    class(vector_function_t), pointer :: poisson_analytical_functions_get_solution_function
    poisson_analytical_functions_get_solution_function => this%solution_function
  end function poisson_analytical_functions_get_solution_function

end module vector_poisson_analytical_functions_names
!***************************************************************************************************


