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
module element_tools_names
  use types
  use fem_space_names
  use memory_guard_names
  implicit none
  private

  type, extends(memory_guard) :: field
  end type field
  type, extends(field) :: scalar
     real(rp), allocatable :: a(:)     ! a(ngaus)
  end type scalar
  type , extends(field) :: vector
     real(rp), allocatable :: a(:,:)   ! a(:,ngaus)
  end type vector
  type , extends(field) :: tensor
     real(rp), allocatable :: a(:,:,:) ! a(:,:,ngaus)
  end type tensor

  ! We assume that all dofs in this functions are interpolated using the same basis. 
  ! It can be exteneded to the general case, complicating the machinery.
  type, extends(memory_guard) :: fem_function
     integer(ip)                :: ivar=1
     integer(ip)                :: ndof=1
     type(fem_element), pointer :: elem => NULL()
  end type fem_function

  ! Shape and deriv...
  type, extends(fem_function) :: basis_function
     !real(rp), allocatable :: a(:,:)     ! shape(nnode,ngaus)
     class(field), allocatable :: left_factor
     class(field), allocatable :: right_factor
   contains
     procedure, pass(ul) :: scal_left         => scal_left_basis_function
     procedure, pass(ur) :: scal_right        => scal_right_basis_function
     procedure, pass(u)  :: product_by_scalar => product_scalar_x_basis_function
     generic    :: operator(*) => scal_right, scal_left, product_by_scalar
  end type basis_function
  type, extends(fem_function) :: basis_function_gradient
     !real(rp), allocatable :: a(:,:,:)   ! deriv(ndime,nnode,ngaus)
     class(field), allocatable :: left_factor
     class(field), allocatable :: right_factor
   contains
     procedure, pass(ul) :: scal_left => scal_left_basis_function_gradient
     procedure, pass(ur) :: scal_right => scal_right_basis_function_gradient
     procedure, pass(u)  :: product_by_scalar => product_scalar_x_basis_function
     procedure, pass(u)  :: product_by_vector => product_vector_x_basis_function
     procedure, pass(u)  :: product_by_tensor => product_tensor_x_basis_function
     generic    :: operator(*) => scal_right, scal_left, product_by_scalar, product_by_vector, product_by_tensor
  end type basis_function_gradient

  type, extends(fem_function) :: basis_function_divergence
     !real(rp), allocatable :: a(:,:,:)   ! deriv(ndime,nnode,ngaus)
     class(field), allocatable :: left_factor
     class(field), allocatable :: right_factor
   contains
     procedure, pass(ul) :: scal_left => scal_left_basis_function_divergence
     procedure, pass(ur) :: scal_right => scal_right_basis_function_divergence
     procedure, pass(u)  :: product_by_scalar => product_scalar_x_basis_function
     procedure, pass(u)  :: product_by_vector => product_vector_x_basis_function
     procedure, pass(u)  :: product_by_tensor => product_tensor_x_basis_function
     generic    :: operator(*) => scal_right, scal_left, product_by_scalar, product_by_vector, product_by_tensor
  end type basis_function_divergence

  ! Interpolations
  type, extends(fem_function) :: given_function
     integer(ip)                :: icomp=1
  end type given_function
  type, extends(fem_function) :: given_function_gradient
     integer(ip)                :: icomp=1
  end type given_function_gradient
  type, extends(fem_function) :: given_function_divergence
     integer(ip)                :: icomp=1
  end type given_function_gradient

  ! Cosmetics...easy to implement if we can return a polymorphic 
  ! allocatable and the compiler works, so we can use the same functions
  ! for both. Currently it is a mess and we don't want to duplicate 
  ! everything.
  !
  ! type, extends(basis_function_value)    :: trial_function
  ! end type trial_function
  ! type, extends(basis_function_gradient) :: trial_function_gradient
  ! end type trial_unction_gradient
  ! type, extends(basis_function_value)    :: test_function
  ! end type test_function
  ! type, extends(basis_function_gradient) :: test_function_gradient
  ! end type test_unction_gradient

  interface grad
     module procedure basis_function_gradient_constructor, given_function_gradient_constructor
  end interface grad
  interface div
     module procedure basis_function_divergence_constructor, given_function_divergence_constructor
  end interface div

  interface interpolation
     module procedure scalar_interpolation
     module procedure vector_interpolation
     module procedure scalar_gradient_interpolation
     module procedure vector_gradient_interpolation
     module procedure vector_divergence_interpolation
  end interface interpolation

  public :: grad, div

contains
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine copy_fem_function(from,to)
    implicit none
    type(basis_function), intent(in), target  :: from
    type(basis_function), intent(inout)       :: to
    to%ivar=from%ivar
    to%ndof=from%ndof
    to%elem=>from%elem
  end subroutine copy_fem_function

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! basis_function (some code replication to avoid functions returning polymorphic allocatables)
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  function basis_function(prob,ivar,ielem) result(var)
    implicit none
    type(physical_problem), intent(in) :: prob
    integer(ip)           , intent(in) :: ivar
    type(fem_element)     , intent(in) :: elem
    type(basis_function) :: var
    integer(ip)          :: nnode,ngaus
    call var%SetTemp()
    var%ivar = ivar
    var%elem => elem
    var%ndof = prob%vars_of_unk(ivar)
  end function basis_function

 function basis_function_gradient_constructor(u) result(g)
    type(basis_function), intent(in) :: u
    type(basis_function_gradient)    :: g
    integer(ip) :: ndime, nnode, ngaus
    call g%SetTemp()
    call copy_fem_function(u,g)
  end function basis_function_gradient_constructor

 function basis_function_divergence_constructor(u) result(g)
    type(basis_function), intent(in) :: u
    type(basis_function_divergence)    :: g
    integer(ip) :: ndime, nnode, ngaus
    call g%SetTemp()
    call copy_fem_function(u,g)
  end function basis_function_divergence_constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! given_function
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function given_function(prob,ivar,icomp,ielem) result(var)
    implicit none
    type(physical_problem), intent(in) :: prob
    integer(ip)           , intent(in) :: ivar
    integer(ip)           , intent(in) :: icomp
    type(fem_element)     , intent(in) :: elem
    type(given_function) :: var
    integer(ip)          :: nnode,ngaus
    call var%SetTemp()
    var%ivar  = ivar
    var%icomp = icomp
    var%elem => elem
    var%ndof = prob%vars_of_unk(ivar)
  end function given_function

 function given_function_gradient_constructor(u) result(g)
    type(given_function), intent(in) :: u
    type(given_function_gradient)    :: g
    integer(ip) :: ndime, nnode, ngaus
    call g%SetTemp()
    call copy_fem_function(u,g)
  end function given_function_gradient_constructor

 function given_function_divergence_constructor(u) result(g)
    type(given_function), intent(in) :: u
    type(given_function_divergence)  :: g
    integer(ip) :: ndime, nnode, ngaus
    call g%SetTemp()
    call copy_fem_function(u,g)
  end function given_function_divergence_constructor

  subroutine scalar_interpolation (u,res)
    type(given_function)  , intent(in)    :: u
    type(vector)          , intent(inout) :: res
    integer(ip)  :: ndof,nnode,ngaus
    integer(ip)  :: idof,inode,igaus
    assert( u%ndof == 1)
    call res%SetTemp()
    nnode = u%elem%integ(ivar)%uint_phy%nnode
    ngaus = u%elem%integ(ivar)%uint_phy%ngaus
    call memalloc(ngaus,res%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus,inode =1:nnode)
       res%a(igaus) = u%elem%integ(ivar)%uint_phy%shape(inode,igaus) * u%elem%unkno(inode,ivar,icomp)
    end forall
  end subroutine scalar_interpolation
  subroutine vector_interpolation (u,vec)
    type(given_function)  , intent(in)    :: u
    type(vector)          , intent(inout) :: vec
    integer(ip)  :: ndof,nnode,ngaus
    integer(ip)  :: idof,inode,igaus
    call vec%SetTemp()
    nnode = u%elem%integ(ivar)%uint_phy%nnode
    ngaus = u%elem%integ(ivar)%uint_phy%ngaus
    call memalloc(u%ndof,ngaus,vec%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus,idof=1:u%ndof,inode =1:nnode)
       vec%a(idof,igaus) = u%elem%integ(ivar)%uint_phy%shape(inode,igaus) * u%elem%unkno(inode, ivar-1+idof, icomp)
    end forall
  end subroutine vector_interpolation

  subroutine scalar_gradient_interpolation(g,vec)
    type(given_function_gradient), intent(in)  :: g
    type(vector)                 , intent(out) :: vec
    integer(ip) :: ndime, nnode, ngaus
    integer(ip) :: idime, inode, igaus
    assert(g%ndof==1)
    call vec%SetTemp()
    assert( associated(g%elem))
    ndime = g%elem%integ(ivar)%uint_phy%ndime
    ngaus = g%elem%integ(ivar)%uint_phy%ngaus
    call memalloc(ndime,ngaus,vec%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus,inode =1:nnode,idime=1:ndime)
       vec%a(idime,igaus) = g%elem%integ(g%ivar)%uint_phy%deriv(idime,inode,igaus) * g%elem%unkno(inode,g%ivar, icomp)
    end forall
  end subroutine scalar_gradient_interpolation
  subroutine vector_gradient_interpolation(g,tens)
    type(given_function_gradient), intent(in)  :: g
    type(tensor)                 , intent(out) :: tens
    integer(ip) :: ndof, ndime, nnode, ngaus
    integer(ip) :: idof, idime, inode, igaus
    call tens%SetTemp()
    assert(associated(g%elem))
    ndime = g%elem%integ(ivar)%uint_phy%ndime
    ndof  = g%ndof
    ngaus = g%elem%integ(ivar)%uint_phy%ngaus
    call memalloc(ndime,ndof,ngaus,g%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus,idof=1:ndof,inode =1:nnode,idime=1:ndime)
       tens%a(idime,idof,igaus) = g%elem%integ(g%ivar)%uint_phy%deriv(idime,inode,igaus) * g%elem%unkno(inode, ivar-1+idof, icomp)
    end forall
  end subroutine vector_gradient_interpolation
  subroutine vector_divergence_interpolation(u) result(res)
    type(given_function_divergence), intent(in)  :: g
    type(scalar)                   , intent(out) :: res
    integer(ip) :: ndof, ndime, nnode, ngaus
    integer(ip) :: idof, idime, inode, igaus
    ndime = g%elem%integ(ivar)%uint_phy%ndime
    assert( g%ndof == ndime)
    assert(associated(g%elem))
    call res%SetTemp()
    ndof  = g%ndof
    ngaus = g%elem%integ(ivar)%uint_phy%ngaus
    call memalloc(ngaus,res%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus,idof=1:ndof,inode =1:nnode,idime=1:ndime)
       res%a(igaus) = g%elem%integ(g%ivar)%uint_phy%deriv(idime,inode,igaus) * elem%unkno(inode, ivar-1+idof, icomp)
    end forall
  end subroutine vector_divergence_interpolation



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function scale_left_basis_function(alpha,ul) result(x)
    implicit none
    real(rp)            , intent(in) :: alpha
    type(basis_function), intent(in) :: ul
    type(basis_function)             :: x
    call copy_fem_function(u_1,x)
    call memalloc(size(ul%a,1),size(ul%a,2),x%a,__FILE__,__LINE__)    ! Should we rely on automatic allocation/deallocation?
    x%a = alpha * ul%a
  end function scale_left_basis_function
  function scale_left_basis_function_gradient(alpha,ul) result(x)
    implicit none
    real(rp)                     , intent(in) :: alpha
    type(basis_function_gradient), intent(in) :: ul
    type(basis_function_gradient)             :: x
    call copy_fem_function(ul,x)
    call memalloc(size(ul%a,1),size(ul%a,2),size(ul%a,3),x%a,__FILE__,__LINE__)    ! Should we rely on automatic allocation/deallocation?
    x%a = alpha * ul%a
  end function scale_left_basis_function_gradient
  function scale_right_basis_function(ur,alpha) result(x)
    implicit none
    real(rp)            , intent(in) :: alpha
    type(basis_function), intent(in) :: u
    type(basis_function)             :: x
    call copy_fem_function(u,x)
    call memalloc(size(ur%a,1),size(ur%a,2),x%a,__FILE__,__LINE__)    ! Should we rely on automatic allocation/deallocation?
    x%a = alpha * ur%a
  end function scale_right_basis_function
  function scale_right_basis_function_gradient(ur,alpha) result(x)
    implicit none
    real(rp)                     , intent(in) :: alpha
    type(basis_function_gradient), intent(in) :: ur
    type(basis_function_gradient)             :: x
    call copy_fem_function(ur,x)
    call memalloc(size(ur%a,1),size(ur%a,2),size(ur%a,3),x%a,__FILE__,__LINE__)    ! Should we rely on automatic allocation/deallocation?
    x%a = alpha * ur%a
  end function scale_right_basis_function_gradient

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function product_scalar_x_basis_function(scal,u) result(x)
    implicit none
    type(scalar)        , intent(in) :: scal
    type(basis_function), intent(in) :: u
    type(basis_function)             :: x
    integer(ip) :: nnode, ngaus
    integer(ip) :: igaus
    call copy_fem_function(u,x)
    nnode = size(u%a,1) ! also given by u%elem%integ(ivar)%uint_phy%nnode
    ngaus = size(u%a,2) ! also given by uelem%integ(ivar)%uint_phy%ngaus
    call memalloc(nnode,ngaus,x%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus)
       x%a(:,igaus) = scal%a(igaus) * u%a(:,igaus)
    end forall
  end function product_scalar_x_basis_function
  function product_scalar_x_basis_function_gradient(scal,u) result(x)
    implicit none
    type(scalar)                 , intent(in) :: scal
    type(basis_function_gradient), intent(in) :: u
    type(basis_function_gradient)             :: x
    integer(ip) :: ndime, nnode, ngaus
    integer(ip) :: igaus
    call copy_fem_function(u,x)
    ndime = size(u%a,1)
    nnode = size(u%a,2) ! also given by u%elem%integ(ivar)%uint_phy%nnode
    ngaus = size(u%a,3) ! also given by uelem%integ(ivar)%uint_phy%ngaus
    call memalloc(ndime,nnode,ngaus,x%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus)
       x%a(:,:,igaus) = scal%a(igaus) * u%a(:,:,igaus)
    end forall
  end function product_scalar_x_basis_function_gradient

  function product_vector_x_basis_function_gradient(vec,u) result(x)
    implicit none
    type(vector)                 , intent(in) :: vec
    type(basis_function_gradient), intent(in) :: u
    type(basis_function)                      :: x
    integer(ip) :: ndime, nnode, ngaus
    integer(ip) :: idime, inode, igaus

    ndime = u%elem%integ(ivar)%uint_phy%ndime
    assert(u%ndof == ndime ) ! Otherwise it cannot be contracted with a gradient
    call copy_fem_function(u,x)

    nnode = size(u%a,2) ! also given by u%elem%integ(ivar)%uint_phy%nnode
    ngaus = size(u%a,3) ! also given by uelem%integ(ivar)%uint_phy%ngaus
    call memalloc(nnode,ngaus,x%a,__FILE__,__LINE__)
    forall(igaus=1:ngaus,inode =1:nnode,idime=1:ndime )
       x%a(inode,igaus) = vec%a(idime,igaus) * u%a(idime,inode,igaus)
    end forall
  end function product_vector_x_basis_function_gradient

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Field functions
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function product_vector_tensor(xvector,ytensor) result(z)
    implicit none
    type(vector) :: x    ! xvector%a(:,ngaus)
    type(tensor) :: y    ! ytensor%a(:,:,ngaus)
    type(vector) :: z    ! z%a(:,ngaus)
    integer(ip) :: i,j,k
    assert(size(xvector,1)==size(ytensor,1))
    assert(size(xvector,2)==size(ytensor,3))
    ! Allocate, memory guard temp, etc.
    ! Change by forall
    do k=1,size(xvector,2)
       do j=1,size(xvector,2)
          z%a(j,k) = 0.0_rp
          do i=1,size(xvector,2)
             z%a(j,k) = z%a(j,k) + xvector%a(i,k)*ytensor%a(i,j,k)
          end do
       end do
    end do
  end function product_vector_tensor

  function product_tensor_vector(xtensor,yvector) result(z)
    implicit none
    type(vector) :: xtensor    ! xtensor%a(:,ngaus)
    type(tensor) :: yvector    ! yvector%a(:,:,ngaus)
    type(vector) :: z    ! z%a(:,ngaus)
    integer(ip) :: i,j,k
    assert(size(xtensor,1)==size(yvector,1))
    assert(size(xtensor,2)==size(yvector,3))
    ! Allocate, memory guard temp, etc.
    ! Change by forall
    do k=1,size(xtensor,2)
       do j=1,size(xtensor,2)
          z%a(j,k) = 0.0_rp
          do i=1,size(xtensor,2)
             z%a(j,k) = z%a(j,k) + xtensor%a(i,k)*yvector%a(i,j,k)
          end do
       end do
    end do
  end function product_vector_tensor

  function product_scalar_scalar(x,y) result(z)
    implicit none
    type(scalar) :: x    ! x(:,ngaus)
    type(scalar) :: y    ! y(:,ngaus)
    type(scalar) :: z    ! z(:,ngaus)
    integer(ip)  :: k
    assert(size(x,1)==size(y,1))
    ! The intrinsic product is element by element
    do k=1,size(x,2)
       z%a(:,k) = x%a(:,k)*y%a(:,k)
    end do
  end function product_scalar_scalar

! left scaling by real
  function scale_1(x,y) result(z)
    implicit none
    real(rp)     :: x
    type(scalar) :: y    ! y(ngaus)
    type(scalar) :: z    ! z(ngaus)
    z%a(:,k) = x*y%a(:,k)
  end function scale_1

! term by term inverse
  function inv(x) result(z)
    implicit none
    type(scalar) :: x    ! x(ngaus)
    type(scalar) :: z    ! z(ngaus)
    integer(ip)  :: i,j,k
    forall(i=1:size(x))
       z%a(i,k) = 1.0_rp/x%a(i,k)
    end forall
  end function inv
!----------------------------------------------------------------------------------------------------------------
!
! The following functions perform integration (sum over gauss points), including a dot product when necessary.
!
  function integral_function_function(v,u) result(mat)
    implicit none
    type(basis_function), intent(in) :: v
    type(basis_function), intent(in) :: u
    real(rp) :: mat(:,:)

    


    do i=1,size(x,2)
       do j=1,size(y,2)
          z%a(i,j) = 0.0_rp
          do k=1,size(x,3)
             do l=1,size(x,1)
                z%a(i,j) = z%a(i,j) + K%detjm(k)*K%weight(k)*x%a(l,i,k)*y%a(l,j,k)
             end do
          end do
       end do
    end do

  end function integral_function_function

  function integral_function_gradient



  end function integral_function_gradient

  function integral_gradient_function



  end function integral_gradient_function


!
!   function integral_scalar(K,v,u) result(z)
!     implicit none
!     type(array_rp2) :: x    ! x(ndof,ngaus)
!     type(array_rp2) :: y    ! y(ndof,ngaus)
!     type(array_rp2) :: z    ! z(ndof,ndof)
!     type(element)   :: K    ! element jacobian, etc.
!     integer(ip) :: i,j,k

!     assert(size(x,2)==size(y,2))
!     do i=1,size(x,1)
!        do j=1,size(y,1)
!           z%a(i,j) = 0.0_rp
!           do k=1,size(x,2)
!              z%a(i,j) = z%a(i,j) + K%detjm(k)*K%weight(k)*x%a(i,k)*y%a(j,k)
!           end do
!        end do
!     end do
!   end function integral_scalar
! !
!   function integral_vector(K,v,u) result(z)
!     implicit none
!     type(array_rp2) :: x    ! x(ndime,ndof,ngaus)
!     type(array_rp2) :: y    ! y(ndime,ndof,ngaus)
!     type(array_rp2) :: z    ! z(ndof,ndof)
!     type(element)   :: K    ! element jacobian, etc.
!     integer(ip) :: i,j,k,l

!     assert(size(x,2)==size(y,2))
!     do i=1,size(x,2)
!        do j=1,size(y,2)
!           z%a(i,j) = 0.0_rp
!           do k=1,size(x,3)
!              do l=1,size(x,1)
!                 z%a(i,j) = z%a(i,j) + K%detjm(k)*K%weight(k)*x%a(l,i,k)*y%a(l,j,k)
!              end do
!           end do
!        end do
!     end do
!   end function integral_vector

end program test_element_integration
