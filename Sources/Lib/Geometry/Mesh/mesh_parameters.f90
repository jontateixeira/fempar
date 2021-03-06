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
module mesh_parameters_names
  use types_names
  implicit none

  character(len=*), parameter :: mesh_dir_path_key       = 'MESH_DIR_PATH'
  character(len=*), parameter :: mesh_prefix_key         = 'MESH_PREFIX'
  
  character(len=*), parameter :: mesh_dir_path_cla_name  = '--'//mesh_dir_path_key
  character(len=*), parameter :: mesh_prefix_cla_name    = '--'//mesh_prefix_key
  
  character(len=*), parameter :: mesh_default_dir_path   = '.'  
  character(len=*), parameter :: mesh_default_prefix     = 'mesh'

  character(len=*), parameter :: mesh_dir_path_cla_help  = 'The relative or full file system path to the folder where the mesh data files are located'
  character(len=*), parameter :: mesh_prefix_cla_help    = 'Token string which is used as a prefix to compose the names of the mesh data files'

  integer(ip), parameter :: c_order = 0
  integer(ip), parameter :: z_order = 1
  
end module mesh_parameters_names
