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
module migratory_element_names
use types_names
  implicit none
  private

  type, abstract :: migratory_element_t
   contains
     procedure (size_interface)  , deferred :: size
     procedure (pack_interface)  , deferred :: pack
     procedure (unpack_interface), deferred :: unpack
  end type migratory_element_t

  ! Abstract interfaces
  abstract interface
     subroutine size_interface(my,n)
       import :: migratory_element_t, ip
       implicit none
       class(migratory_element_t), intent(in)  :: my
       integer(ip)           , intent(out) :: n
     end subroutine size_interface

     subroutine pack_interface(my,n,buffer)
       import :: migratory_element_t, ip, ieep
       implicit none
       class(migratory_element_t), intent(in)  :: my
       integer(ip)             , intent(in)  :: n
       integer(ieep)           , intent(out) :: buffer(n)
     end subroutine pack_interface

     subroutine unpack_interface(my,n,buffer)
       import :: migratory_element_t, ip, ieep
       implicit none
       class(migratory_element_t), intent(inout) :: my
       integer(ip)             , intent(in)    :: n
       integer(ieep)           , intent(in)    :: buffer(n)
     end subroutine unpack_interface

  end interface

  public :: migratory_element_t
  
end module migratory_element_names