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

#include "debug.i90"
#include "std_vector_macros.i90"
module std_vector_integer_igp_names
  use types_names
  use memor_names
  implicit none
  private
  
  STD_VECTOR_TYPE(integer(igp),integer_igp)
    
  public :: std_vector_integer_igp_t
  
contains
  
  STD_VECTOR_PUSH_BACK(integer(igp),integer_igp)
  STD_VECTOR_ERASE(integer(igp),integer_igp)
  STD_VECTOR_RESIZE(integer(igp),integer_igp)
  STD_VECTOR_SHRINK_TO_FIT(integer(igp),integer_igp)
  STD_VECTOR_COPY_FROM_STD_VECTOR(integer(igp),integer_igp)
  STD_VECTOR_COPY_FROM_INTRINSIC_ARRAY(integer(igp),integer_igp)
  STD_VECTOR_FREE(integer(igp),integer_igp)
  STD_VECTOR_GET(integer(igp),integer_igp)
  STD_VECTOR_SET(integer(igp),integer_igp)
  STD_VECTOR_INIT(integer(igp),integer_igp)
  STD_VECTOR_CAT(integer(igp),integer_igp)
  STD_VECTOR_SIZE(integer(igp),integer_igp)
  STD_VECTOR_CAPACITY(integer(igp),integer_igp)
  STD_VECTOR_GET_POINTER_SINGLE_ENTRY(integer(igp),integer_igp)
  STD_VECTOR_GET_POINTER_TO_RANGE(integer(igp),integer_igp)
  STD_VECTOR_GET_RAW_POINTER(integer(igp),integer_igp)

  
end module std_vector_integer_igp_names
