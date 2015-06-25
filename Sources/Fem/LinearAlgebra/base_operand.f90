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
module base_operand_names
use types_names
  use memory_guard_names
  use integrable_names
  implicit none

  private
  ! Abstract operand
  type, abstract, extends(integrable) :: base_operand
   contains
     procedure (dot_interface) , deferred  :: dot
     procedure (copy_interface), deferred  :: copy
     procedure (init_interface), deferred  :: init
     procedure (scal_interface), deferred  :: scal
     procedure (axpby_interface), deferred :: axpby ! y <- a*x + b*y
     procedure (nrm2_interface), deferred  :: nrm2
     procedure (clone_interface), deferred :: clone
     procedure (comm_interface), deferred  :: comm
     
     procedure :: sum_operand
     procedure :: sub_operand
     procedure :: minus_operand
     procedure, pass(left)  :: scal_left_operand
     procedure, pass(right) :: scal_right_operand
     procedure :: assign_operand

     generic  :: operator(+) => sum_operand
     generic  :: operator(-) => sub_operand, minus_operand
     generic  :: operator(*) => scal_left_operand, scal_right_operand
     generic  :: assignment(=) => assign_operand
  end type base_operand

 ! Abstract interfaces
  abstract interface
     ! alpha <- op1^T * op2
     function dot_interface(op1,op2) result(alpha)
       import :: base_operand, rp
       implicit none
       class(base_operand), intent(in)  :: op1,op2
       real(rp) :: alpha
     end function dot_interface
     ! op1 <- op2 
     subroutine copy_interface(op1,op2)
       import :: base_operand
       implicit none
       class(base_operand), intent(inout) :: op1
       class(base_operand), intent(in)    :: op2
     end subroutine copy_interface
     ! op1 <- alpha * op2
     subroutine scal_interface(op1,alpha,op2)
       import :: base_operand, rp
       implicit none
       class(base_operand), intent(inout) :: op1
       real(rp), intent(in) :: alpha
       class(base_operand), intent(in) :: op2
     end subroutine scal_interface
     ! op <- alpha
     subroutine init_interface(op,alpha)
       import :: base_operand, rp
       implicit none
       class(base_operand), intent(inout) :: op
       real(rp), intent(in) :: alpha
     end subroutine init_interface
     ! op1 <- alpha*op2 + beta*op1
     subroutine axpby_interface(op1, alpha, op2, beta)
       import :: base_operand, rp
       implicit none
       class(base_operand), intent(inout) :: op1
       real(rp), intent(in) :: alpha
       class(base_operand), intent(in) :: op2
       real(rp), intent(in) :: beta
     end subroutine axpby_interface
     ! alpha <- nrm2(op)
     function nrm2_interface(op) result(alpha)
       import :: base_operand, rp
       implicit none
       class(base_operand), intent(in)  :: op
       real(rp) :: alpha
     end function nrm2_interface
     ! op1 <- clone(op2) 
     subroutine clone_interface(op1,op2)
       import :: base_operand
       implicit none
       class(base_operand)         ,intent(inout) :: op1
       class(base_operand), target ,intent(in)    :: op2
     end subroutine clone_interface
     ! op <- comm(op)
     subroutine comm_interface(op)
       import :: base_operand
       implicit none
       class(base_operand), intent(inout) :: op
     end subroutine comm_interface
  end interface

  public :: base_operand

contains  
  ! res <- op1 + op2
  function sum_operand(op1,op2) result (res)
    implicit none
    class(base_operand), intent(in)  :: op1, op2
    class(base_operand), allocatable :: res
    
    call op1%GuardTemp()
    call op2%GuardTemp()

    allocate(res, mold=op1)
    call res%clone(op1)
    call res%copy(op1)
    ! res <- 1.0*op2 + 1.0*res
    call res%axpby(1.0, op2, 1.0)

    call op1%CleanTemp()
    call op2%CleanTemp()
    call res%SetTemp()
  end function sum_operand

  ! res <- op1 - op2
  function sub_operand(op1,op2) result (res)
    implicit none
    class(base_operand), intent(in)  :: op1, op2
    class(base_operand), allocatable :: res

    call op1%GuardTemp()
    call op2%GuardTemp()

    allocate(res, mold=op1)
    call res%clone(op1)
    call res%copy(op1)
    ! res <- -1.0*op2 + 1.0*res
    call res%axpby(-1.0, op2, 1.0)

    call op1%CleanTemp()
    call op2%CleanTemp()
    call res%SetTemp()
  end function sub_operand
  
  ! res <- -op
  function minus_operand(op) result (res)
    implicit none
    class(base_operand), intent(in)   :: op
    class(base_operand), allocatable  :: res

    call op%GuardTemp()
    
    allocate(res, mold=op)
    call res%clone(op)
    call res%scal(-1.0, op)

    call op%CleanTemp()
    call res%SetTemp()
  end function minus_operand

    ! res <- op*alpha
  function scal_left_operand(left,alpha) result (res)
    implicit none
    class(base_operand), intent(in)   :: left
    real (rp), intent(in)             :: alpha
    class(base_operand), allocatable  :: res

    call left%GuardTemp()
    
    allocate(res, mold=left)
    call res%clone(left)
    call res%scal(alpha, left)

    call left%CleanTemp()
    call res%SetTemp()
  end function scal_left_operand

  ! res <- alpha*op
  function scal_right_operand(alpha,right) result (res)
    implicit none
    real (rp), intent(in)             :: alpha
    class(base_operand), intent(in)   :: right
    class(base_operand), allocatable  :: res

    call right%GuardTemp()
    
    allocate(res, mold=right)
    call res%clone(right)
    call res%scal(alpha, right)
    
    call right%CleanTemp()
    call res%SetTemp()
  end function scal_right_operand

  ! op1 <- op2
  subroutine assign_operand(op1,op2) 
    implicit none
    class(base_operand), intent(inout):: op1
    class(base_operand), intent(in):: op2

    call op2%GuardTemp()
    
    call op1%clone(op2)
    call op1%copy(op2)
    
    call op2%CleanTemp()
  end subroutine assign_operand

end module base_operand_names
