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
!
! Execution context: 
! =================
! This is an abstract class that defines services the need to be provided by
! concrete implementations of an execution context. This context contains a
! set of tasks labelled 0 to n-1. One of them is the root task (tipically 0)
! and one of which is the master task (tipically n-1). 
!
! This class is exploited by the multilevel environment to manage communications
! between the tasks on different levels and between tasks on the same level.
! Therefore, this class (execution_context_t) only manages a set of tasks, without
! any hierarchical organization of them.
!
! The first (and most natural) implementation of this class is mpi_context_t
! which actually implementes communications defined here. There is also a class
! serial_context_t which provides a fake implementation to build a serial
! environment.
!
module execution_context_names
  use types_names
  use memor_names

#include "debug.i90"
  private

  integer(ip), parameter :: undefined_color=-1
  public :: undefined_color

  type, abstract :: execution_context_t
     private 
     integer :: num_tasks    = -1
     integer :: current_task = -1
   contains
     procedure, non_overridable  :: get_num_tasks => execution_context_get_num_tasks
     procedure, non_overridable  :: set_num_tasks => execution_context_set_num_tasks
     procedure, non_overridable  :: get_current_task => execution_context_get_current_task
     procedure, non_overridable  :: set_current_task => execution_context_set_current_task

     procedure (execution_context_create)             , deferred :: create
     procedure (execution_context_assign)             , deferred :: assign
     generic :: assignment(=) => assign
     procedure (execution_context_split_by_condition) , deferred :: split_by_condition
     procedure (execution_context_split_by_color    ) , deferred :: split_by_color
     procedure (execution_context_free              ) , deferred :: free
     procedure (execution_context_nullify           ) , deferred :: nullify
     procedure (execution_context_am_i_member       ) , deferred :: am_i_member       
     procedure (execution_context_barrier           ) , deferred :: barrier           
     procedure (execution_context_sum_scalar_rp     ) , deferred :: sum_scalar_rp     
     procedure (execution_context_sum_vector_rp     ) , deferred :: sum_vector_rp     
     procedure (execution_context_max_scalar_rp     ) , deferred :: max_scalar_rp     
     procedure (execution_context_max_vector_rp     ) , deferred :: max_vector_rp     
     procedure (execution_context_scatter_scalar_ip ) , deferred :: scatter           
     procedure (execution_context_gather_scalar_ip  ) , deferred :: gather            
     procedure (execution_context_bcast_scalar_ip   ) , deferred :: bcast             
     procedure (execution_context_bcast_subcontext  ) , deferred :: bcast_subcontext  

     procedure (execution_context_neighbours_exchange_rp                 ), deferred, private    :: neighbours_exchange_rp                 
     procedure (execution_context_neighbours_exchange_ip                 ), deferred, private    :: neighbours_exchange_ip                 
     procedure (execution_context_neighbours_exchange_igp                ), deferred, private    :: neighbours_exchange_igp                
     procedure (execution_context_neighbours_exchange_single_ip          ), deferred, private    :: neighbours_exchange_single_ip          
     procedure (execution_context_neighbours_exchange_wo_pack_unpack_ieep), deferred, private    :: neighbours_exchange_wo_pack_unpack_ieep
     generic :: neighbours_exchange  => neighbours_exchange_rp, &
          &                             neighbours_exchange_ip, &
          &                             neighbours_exchange_igp, &
          &                             neighbours_exchange_single_ip, &
          &                             neighbours_exchange_wo_pack_unpack_ieep

     procedure (execution_context_root_send_master_rcv_ip         ), deferred, private    :: root_send_master_rcv_ip
     procedure (execution_context_root_send_master_rcv_ip_1D_array), deferred, private    :: root_send_master_rcv_ip_1D_array
     generic :: root_send_master_rcv => root_send_master_rcv_ip, &
          &                             root_send_master_rcv_ip_1D_array

     procedure (execution_context_gather_to_master_ip           ) , deferred, private :: gather_to_master_ip            
     procedure (execution_context_gather_to_master_igp          ) , deferred, private :: gather_to_master_igp           
     procedure (execution_context_gather_to_master_ip_1D_array  ) , deferred, private :: gather_to_master_ip_1D_array   
     procedure (execution_context_gather_to_masterv_ip_1D_array ) , deferred, private :: gather_to_masterv_ip_1D_array  
     procedure (execution_context_gather_to_masterv_igp_1D_array) , deferred, private :: gather_to_masterv_igp_1D_array 
     procedure (execution_context_gather_to_masterv_rp_1D_array ) , deferred, private :: gather_to_masterv_rp_1D_array  
     procedure (execution_context_gather_to_masterv_rp_2D_array ) , deferred, private :: gather_to_masterv_rp_2D_array  
     generic  :: gather_to_master => gather_to_master_ip, &
          &                          gather_to_master_igp, &
          &                          gather_to_master_ip_1D_array, &
          &                          gather_to_masterv_ip_1D_array, &
          &                          gather_to_masterv_igp_1D_array, &
          &                          gather_to_masterv_rp_1D_array, &
          &                          gather_to_masterv_rp_2D_array

     procedure (execution_context_scatter_from_masterv_rp_1D_array), deferred, private :: scatter_from_masterv_rp_1D_array                                  
     generic   :: scatter_from_master => scatter_from_masterv_rp_1D_array

  end type execution_context_t

  ! Types
  public :: execution_context_t

  abstract interface 

     !=============================================================================
     subroutine execution_context_assign(this, that)
       import :: execution_context_t
       implicit none 
       class(execution_context_t), intent(inout) :: this
       class(execution_context_t), intent(in)    :: that
     end subroutine execution_context_assign

     !=============================================================================
     subroutine execution_context_create ( this )
       import :: execution_context_t
       implicit none 
       class(execution_context_t), intent(inout) :: this
     end subroutine execution_context_create

     !=============================================================================
     subroutine execution_context_split_by_color ( this, color, new_subcontext )
       import :: execution_context_t
       implicit none 
       class(execution_context_t), intent(in)    :: this
       integer             , intent(in)    :: color
       class(execution_context_t), allocatable, intent(inout) :: new_subcontext
     end subroutine execution_context_split_by_color

     !=============================================================================
     subroutine execution_context_split_by_condition ( this, in_subcontext1, subcontext1, subcontext2 )
       import :: execution_context_t
       implicit none 
       class(execution_context_t)             , intent(in)    :: this
       logical                          , intent(in)    :: in_subcontext1
       class(execution_context_t), allocatable, intent(inout) :: subcontext1
       class(execution_context_t), allocatable, intent(inout) :: subcontext2
     end subroutine execution_context_split_by_condition

     !=============================================================================
     ! Frees the memory related to the communication object underlying "this"
     ! and finalizes the underlying message-passing library (i.e., MPI) if 
     ! finalize == .true. 
     subroutine execution_context_free ( p_context, finalize  )
       import :: execution_context_t
       implicit none 
       ! Parameters
       class(execution_context_t)            , intent(inout) :: p_context
       logical                         , intent(in)    :: finalize
     end subroutine execution_context_free

     !=============================================================================
     subroutine execution_context_nullify ( this )
       import :: execution_context_t
       implicit none 
       class(execution_context_t), intent(inout) :: this
     end subroutine execution_context_nullify

     !=============================================================================
     pure function execution_context_am_i_member(this)
       import :: execution_context_t
       implicit none
       class(execution_context_t), intent(in) :: this
       logical                          :: execution_context_am_i_member
     end function execution_context_am_i_member

     !=============================================================================
     subroutine execution_context_barrier(this)
       import :: execution_context_t
       implicit none 
       class(execution_context_t), intent(in) :: this
     end subroutine execution_context_barrier

     !=============================================================================
     subroutine execution_context_sum_scalar_rp (this,alpha)
       import :: execution_context_t, rp
       implicit none
       class(execution_context_t) , intent(in)    :: this
       real(rp)             , intent(inout) :: alpha
     end subroutine execution_context_sum_scalar_rp

     !=============================================================================
     subroutine execution_context_sum_vector_rp(this,alpha)
       import :: execution_context_t, rp
       implicit none
       class(execution_context_t) , intent(in)    :: this
       real(rp)             , intent(inout) :: alpha(:) 
     end subroutine execution_context_sum_vector_rp

     !=============================================================================
     subroutine execution_context_max_scalar_rp (this,alpha)
       import :: execution_context_t, rp
       implicit none
       class(execution_context_t) , intent(in)    :: this
       real(rp)             , intent(inout) :: alpha
     end subroutine execution_context_max_scalar_rp

     !=============================================================================
     subroutine execution_context_max_vector_rp(this,alpha)
       import :: execution_context_t, rp
       implicit none
       class(execution_context_t) , intent(in)    :: this
       real(rp)             , intent(inout) :: alpha(:) 
     end subroutine execution_context_max_vector_rp

     !=============================================================================
     subroutine execution_context_bcast_subcontext(this,subcontxt1,subcontxt2,condition)
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t) , intent(in)    :: this
       class(execution_context_t) , intent(in)    :: subcontxt1
       class(execution_context_t) , intent(in)    :: subcontxt2
       logical              , intent(inout) :: condition
     end subroutine execution_context_bcast_subcontext

     !=============================================================================
     ! When packing   (gathering) ,    buffer <- alpha * x
     ! When unpacking (scattering),    x <- beta*x + buffer
     subroutine execution_context_neighbours_exchange_rp ( this, & 
          &                                          num_rcv, list_rcv, rcv_ptrs, unpack_idx, & 
          &                                          num_snd, list_snd, snd_ptrs, pack_idx,   &
          &                                          alpha, beta, x)
       import :: execution_context_t, ip, rp
       implicit none
       class(execution_context_t), intent(in) :: this
       integer(ip)             , intent(in) :: num_rcv, list_rcv(num_rcv), rcv_ptrs(num_rcv+1)
       integer(ip)             , intent(in) :: unpack_idx (rcv_ptrs(num_rcv+1)-1)
       integer(ip)             , intent(in) :: num_snd, list_snd(num_snd), snd_ptrs(num_snd+1)
       integer(ip)             , intent(in) :: pack_idx (snd_ptrs(num_snd+1)-1)
       real(rp), intent(in)    :: alpha, beta
       real(rp), intent(inout) :: x(:)

     end subroutine execution_context_neighbours_exchange_rp

     !=============================================================================
     ! When packing   (gathering) ,    buffer <- alpha * x
     ! When unpacking (scattering),    x <- beta*x + buffer
     subroutine execution_context_neighbours_exchange_ip ( this, & 
          &                                          num_rcv, list_rcv, rcv_ptrs, unpack_idx, & 
          &                                          num_snd, list_snd, snd_ptrs, pack_idx,   &
          &                                          x,chunk_size)
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)    :: this
       ! Control info to receive
       integer(ip)             , intent(in)    :: num_rcv, list_rcv(num_rcv), rcv_ptrs(num_rcv+1)
       integer(ip)             , intent(in)    :: unpack_idx (rcv_ptrs(num_rcv+1)-1)
       ! Control info to send
       integer(ip)             , intent(in)    :: num_snd, list_snd(num_snd), snd_ptrs(num_snd+1)
       integer(ip)             , intent(in)    :: pack_idx (snd_ptrs(num_snd+1)-1)
       ! Raw data to be exchanged
       integer(ip)             , intent(inout) :: x(:)
       integer(ip)   , optional, intent(in)    :: chunk_size
     end subroutine execution_context_neighbours_exchange_ip

     !=============================================================================
     subroutine execution_context_neighbours_exchange_igp ( this, & 
          &                                              num_rcv, list_rcv, rcv_ptrs, unpack_idx, & 
          &                                              num_snd, list_snd, snd_ptrs, pack_idx,   &
          &                                              x, chunk_size)
       import :: execution_context_t, ip, igp
       implicit none
       class(execution_context_t), intent(in)    :: this
       ! Control info to receive
       integer(ip)             , intent(in)    :: num_rcv, list_rcv(num_rcv), rcv_ptrs(num_rcv+1)
       integer(ip)             , intent(in)    :: unpack_idx (rcv_ptrs(num_rcv+1)-1)
       ! Control info to send
       integer(ip)             , intent(in)    :: num_snd, list_snd(num_snd), snd_ptrs(num_snd+1)
       integer(ip)             , intent(in)    :: pack_idx (snd_ptrs(num_snd+1)-1)
       ! Raw data to be exchanged
       integer(igp)            , intent(inout) :: x(:)
       integer(ip)   , optional, intent(in)    :: chunk_size

     end subroutine execution_context_neighbours_exchange_igp

     !=============================================================================
     subroutine execution_context_neighbours_exchange_single_ip ( this, & 
          &                                                    num_neighbours, &
          &                                                    list_neighbours, &
          &                                                    input_data,&
          &                                                    output_data)
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in) :: this
       integer                 , intent(in)    :: num_neighbours
       integer(ip)             , intent(in)    :: list_neighbours (num_neighbours)
       integer(ip)             , intent(in)    :: input_data
       integer(ip)             , intent(inout) :: output_data(num_neighbours)
     end subroutine execution_context_neighbours_exchange_single_ip

     !=============================================================================
     subroutine execution_context_neighbours_exchange_wo_pack_unpack_ieep ( this, &
          &                                                              number_neighbours, &
          &                                                              neighbour_ids, &
          &                                                              snd_ptrs, &
          &                                                              snd_buf, & 
          &                                                              rcv_ptrs, &
          &                                                              rcv_buf )
       import :: execution_context_t, ip, ieep
       implicit none
       class(execution_context_t)  , intent(in)    :: this 
       integer(ip)           , intent(in)    :: number_neighbours
       integer(ip)           , intent(in)    :: neighbour_ids(number_neighbours)
       integer(ip)           , intent(in)    :: snd_ptrs(number_neighbours+1)
       integer(ieep)         , intent(in)    :: snd_buf(snd_ptrs(number_neighbours+1)-1)   
       integer(ip)           , intent(in)    :: rcv_ptrs(number_neighbours+1)
       integer(ieep)         , intent(out)   :: rcv_buf(rcv_ptrs(number_neighbours+1)-1)
     end subroutine execution_context_neighbours_exchange_wo_pack_unpack_ieep

     !=============================================================================
     subroutine execution_context_gather_scalar_ip ( this, input_data, output_data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(ip)         , intent(in)   :: input_data
       integer(ip)         , intent(out)  :: output_data(:) ! (this%num_tasks)
     end subroutine execution_context_gather_scalar_ip

     !=============================================================================
     subroutine execution_context_scatter_scalar_ip ( this, input_data, output_data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(ip)             , intent(in)   :: input_data(:) ! (this%num_tasks)
       integer(ip)             , intent(out)  :: output_data
     end subroutine execution_context_scatter_scalar_ip

     !=============================================================================
     subroutine execution_context_bcast_scalar_ip ( this, data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)    :: this
       integer(ip)             , intent(inout) :: data
     end subroutine execution_context_bcast_scalar_ip

     !=============================================================================
     subroutine execution_context_root_send_master_rcv_ip ( this, input_data, output_data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)      :: this
       integer(ip)         , intent(in)      :: input_data
       integer(ip)         , intent(inout)   :: output_data
     end subroutine execution_context_root_send_master_rcv_ip

     !=============================================================================
     subroutine execution_context_root_send_master_rcv_ip_1D_array ( this, input_data, output_data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)      :: this
       integer(ip)         , intent(in)      :: input_data(:)
       integer(ip)         , intent(inout)   :: output_data(:)
     end subroutine execution_context_root_send_master_rcv_ip_1D_array

     !=============================================================================
     subroutine execution_context_gather_to_master_ip ( this, input_data, output_data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(ip)             , intent(in)   :: input_data
       integer(ip)             , intent(out)  :: output_data(:) ! (this%num_tasks)
     end subroutine execution_context_gather_to_master_ip

     !=============================================================================
     subroutine execution_context_gather_to_master_igp ( this, input_data, output_data )
       import :: execution_context_t, igp
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(igp)            , intent(in)   :: input_data
       integer(igp)            , intent(out)  :: output_data(:) ! (this%num_tasks)
     end subroutine execution_context_gather_to_master_igp

     !=============================================================================
     subroutine execution_context_gather_to_master_ip_1D_array ( this, input_data_size, input_data, output_data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(ip)             , intent(in)   :: input_data_size
       integer(ip)             , intent(in)   :: input_data(input_data_size)
       integer(ip)             , intent(out)  :: output_data(:)
     end subroutine execution_context_gather_to_master_ip_1D_array

     !=============================================================================
     subroutine execution_context_gather_to_masterv_ip_1D_array ( this, input_data_size, input_data, recv_counts, displs, output_data )
       import :: execution_context_t, ip
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(ip)             , intent(in)   :: input_data_size
       integer(ip)             , intent(in)   :: input_data(input_data_size)
       integer(ip)             , intent(in)   :: recv_counts(:) ! (this%num_tasks)
       integer(ip)             , intent(in)   :: displs(:) ! (this%num_tasks)
       integer(ip)             , intent(out)  :: output_data(:)
     end subroutine execution_context_gather_to_masterv_ip_1D_array

     !=============================================================================
     subroutine execution_context_gather_to_masterv_igp_1D_array ( this, input_data_size, input_data, recv_counts, displs, output_data )
       import :: execution_context_t, ip, igp
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(ip)             , intent(in)   :: input_data_size
       integer(igp)            , intent(in)   :: input_data(input_data_size)
       integer(ip)             , intent(in)   :: recv_counts(:) ! (this%num_tasks)
       integer(ip)             , intent(in)   :: displs(:) ! (this%num_tasks)
       integer(igp)            , intent(out)  :: output_data(:)
     end subroutine execution_context_gather_to_masterv_igp_1D_array

     !=============================================================================
     subroutine execution_context_gather_to_masterv_rp_1D_array ( this, input_data_size, input_data, recv_counts, displs, output_data )
       import :: execution_context_t, ip, rp
       implicit none
       class(execution_context_t), intent(in)   :: this
       integer(ip)             , intent(in)   :: input_data_size
       real(rp)                , intent(in)   :: input_data(input_data_size)
       integer(ip)             , intent(in)   :: recv_counts(:) ! (this%num_tasks)
       integer(ip)             , intent(in)   :: displs(:) ! (this%num_tasks)
       real(rp)                , intent(out)  :: output_data(:)
     end subroutine execution_context_gather_to_masterv_rp_1D_array

     !=============================================================================
     subroutine execution_context_gather_to_masterv_rp_2D_array ( this, input_data, recv_counts, displs, output_data )
       import :: execution_context_t, ip, rp
       implicit none
       class(execution_context_t), intent(in)   :: this
       real(rp)                , intent(in)   :: input_data(:,:)
       integer(ip)             , intent(in)   :: recv_counts(:) ! (this%num_tasks)
       integer(ip)             , intent(in)   :: displs(:) ! (this%num_tasks)
       real(rp)                , intent(out)  :: output_data(:)
     end subroutine execution_context_gather_to_masterv_rp_2D_array

     !=============================================================================
     subroutine execution_context_scatter_from_masterv_rp_1D_array ( this, input_data, send_counts, displs, output_data_size, output_data )
       import :: execution_context_t, ip, rp
       implicit none
       class(execution_context_t), intent(in)   :: this
       real(rp)                , intent(in)   :: input_data(:)
       integer(ip)             , intent(in)   :: send_counts(:) ! (this%num_tasks)
       integer(ip)             , intent(in)   :: displs(:) ! (this%num_tasks)
       integer(ip)             , intent(in)   :: output_data_size
       real(rp)                , intent(out)  :: output_data(output_data_size)
       integer                :: the_mpi_comm, iret, root
     end subroutine execution_context_scatter_from_masterv_rp_1D_array

  end interface

contains

  pure function execution_context_get_num_tasks (this)
    implicit none
    class(execution_context_t), intent(in) :: this
    integer :: execution_context_get_num_tasks
    execution_context_get_num_tasks = this%num_tasks
  end function execution_context_get_num_tasks

  subroutine execution_context_set_num_tasks (this, num_tasks)
    implicit none
    class(execution_context_t), intent(inout) :: this
    integer             , intent(in)    :: num_tasks
    assert(num_tasks>=-1)
    this%num_tasks = num_tasks
  end subroutine execution_context_set_num_tasks

  pure function execution_context_get_current_task (this)
    implicit none
    class(execution_context_t), intent(in) :: this
    integer :: execution_context_get_current_task
    execution_context_get_current_task = this%current_task
  end function execution_context_get_current_task

  subroutine execution_context_set_current_task (this, current_task)
    implicit none
    class(execution_context_t), intent(inout) :: this
    integer             , intent(in)    :: current_task
    assert(current_task>=-1)
    this%current_task = current_task
  end subroutine execution_context_set_current_task

end module execution_context_names