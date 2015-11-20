module quad_lagrangian_reference_fe_names
  use reference_fe_names
  use SB_quadrature_names
  use SB_interpolation_names
  use allocatable_array_ip1_names
  use types_names
  use memor_names
  implicit none
# include "debug.i90"

  private

  type, extends(reference_fe_t) :: quad_lagrangian_reference_fe_t
  private
contains 
  procedure :: create
  procedure :: create_interpolation
!  procedure :: set_integration_rule
  procedure :: create_quadrature
  procedure :: fill
  !procedure :: local_to_ijk_node     
  !procedure :: ijk_to_local_node     
  procedure :: permute_order_vef
end type quad_lagrangian_reference_fe_t

public :: quad_lagrangian_reference_fe_t

contains 

subroutine create ( this, number_dimensions, order, continuity )
 implicit none 
 class(quad_lagrangian_reference_fe_t), intent(out) :: this 
 integer(ip), intent(in)  :: number_dimensions, order
 logical, optional, intent(in) :: continuity

 call this%set_common_data ( number_dimensions, order, continuity )
 call this%set_topology( "tet" )
 call this%set_fe_type( "Lagrangian" )
 call this%fill( )

end subroutine create

! subroutine set_integration_rule ( this , quadrature, interpolation )
!  implicit none 
!  class(quad_lagrangian_reference_fe_t), intent(in) :: this
!  class(SB_quadrature_t), intent(in) :: quadrature
!  class(SB_interpolation_t), intent(out) :: interpolation

!  ! Here we should put all the things in interpolation.f90
! end subroutine set_integration_rule

subroutine create_interpolation ( this, quadrature, interpolation, compute_hessian )
  implicit none 
  class(quad_lagrangian_reference_fe_t), intent(in) :: this 
  class(SB_quadrature_t), intent(in) :: quadrature
  type(SB_interpolation_t), intent(out) :: interpolation
  logical, optional, intent(in) :: compute_hessian

  integer(ip) :: nlocs, ntens, i

  ntens = 0
  do i = 1, this%get_number_dimensions()
     ntens = ntens + i
  end do

  call interpolation%create( this%get_number_dimensions(), this%get_number_nodes(), &
       quadrature%get_number_integration_points(), ntens, compute_hessian )

  nlocs = int(real(quadrature%get_number_integration_points())**(1.0_rp/real(this%get_number_dimensions())))
  call fill_interpolation( interpolation, this%get_order(), this%get_number_dimensions(), &
       nlocs, ntens, quadrature%get_pointer_coordinates() )

end subroutine create_interpolation

subroutine create_quadrature ( this, quadrature, max_order )
 implicit none 
 class(quad_lagrangian_reference_fe_t), intent(in) :: this        
 integer(ip), optional, intent(in) :: max_order
 class(SB_quadrature_t), intent(out) :: quadrature
 integer(ip) :: ngaus, order


 order = this%get_order()
 if ( present(max_order) ) then
    order = max_order
 else
    order = this%get_order()
 end if

 ngaus = (order + 1)**this%get_number_dimensions()

 call quadrature%create( this%get_number_dimensions(), ngaus )
 call fill_quadrature( quadrature )

end subroutine create_quadrature

subroutine fill (this)
 implicit none
 ! Parameters
 class(quad_lagrangian_reference_fe_t), intent(inout) :: this

 ! Local variables
 integer(ip)               :: nd,p
 integer(ip)               :: i,j,k,l,m
 integer(ip)               :: aux1,aux2,aux3,aux4
 integer(ip)               :: od,cd,kk,c
 integer(ip)               :: c2,c3,c4,c5,c6,co
 integer(ip)               :: no  ! #vefs in nd-quad
 integer(ip)               :: nn  ! #nodes in the nd-quad of order p
 integer(ip)               :: nt  ! sum of the #nodes (all, not only interior) of the vefs
 integer(ip)               :: nt2 ! sum of the #vefs (all, not only interior) of the vefs
 integer(ip)               :: nc  ! #corners x #{vefs delimited by each corner}
 integer(ip)               :: nod ! #corners in the quad. nod = 2^(nd)
 integer(ip), allocatable  :: auxt1(:,:),auxt2(:,:),auxt3(:,:),auxt4(:,:),auxt5(:,:), auxt6(:,:)
 integer(ip), allocatable  :: obdla(:,:),node2ob(:),ob2node(:)

 integer(ip), allocatable  :: aux(:),idm(:),fdm(:),ijk(:),ijk_g(:)

 integer(ip), pointer :: number_vefs, number_nodes, number_vefs_dimension(:)
 type(allocatable_array_ip1_t), pointer ::  orientation
 type(list_t), pointer :: interior_nodes_vef, nodes_vef, corners_vef, vefs_vef

 number_vefs => this%get_pointer_number_vefs()
 number_nodes => this%get_pointer_number_nodes()
 number_vefs_dimension => this%get_pointer_number_vefs_dimension()
 orientation => this%get_pointer_orientation()
 interior_nodes_vef => this%get_pointer_interior_nodes_vef()
 interior_nodes_vef => this%get_pointer_interior_nodes_vef()
 nodes_vef => this%get_pointer_nodes_vef()
 corners_vef => this%get_pointer_corners_vef()
 vefs_vef => this%get_pointer_vefs_vef()

 !  ! Initilize values
 nd = this%get_number_dimensions()
 p  = this%get_order()

 call memalloc( nd, aux, __FILE__, __LINE__ )
 call memalloc( nd, idm, __FILE__, __LINE__ )
 call memalloc( nd, fdm, __FILE__, __LINE__ )
 call memalloc( nd, ijk, __FILE__, __LINE__ )
 call memalloc( nd, ijk_g, __FILE__, __LINE__ )

 no = 0
 nn = 0
 nt = 0
 nc = 0
 nt2 = 0
 nod = 0

 ! Initialize nvef_dim, nodes_vef
 !call memalloc(nd+2,nvef_dim,__FILE__,__LINE__)
 !call memalloc(nd+1,nodes_vef,__FILE__,__LINE__)
 number_vefs_dimension = 0
 number_vefs_dimension(1) = 1

 do k = 0,nd
    i = int(2**(nd-k)*bnm(nd,k)) ! #vefs of dimension k
    no = no + i                  ! compute #vefs
    nn = nn + int(i*((p-1)**k))  ! #nodes inside vefs of dimension k
    nt = nt + int(i*((p+1)**k))  ! nodes in the clousure of the vef
    nt2 = nt2 + int(i*((3)**k))! vefs in the clousure of the vef
    nc = nc + int(i*2**k)        ! corners delimiting vefs of dimension k
    nod = nod + bnm(nd,k)        ! #nodes/{displacement} (2^n = sum(bnm(n,k)), k=0,..,n)
    ! Pointer to obj id by dim. Local obj of dim k are nvef_dim(k):nvef_dim(k+1)
    number_vefs_dimension(k+2) = number_vefs_dimension(k+1) + i 
    ! #nodes in vefs of dimension k 
 end do

 ! Set constant values of reference_element
 number_vefs = no-1
 number_nodes = int((p+1)**nd) 

 ! Allocate arrays
 call orientation%create(no)
 call memalloc(no+1,interior_nodes_vef%p,__FILE__,__LINE__)  !Pointer to interior_nodes_vef%l for each vef
 call memalloc(nn,  interior_nodes_vef%l,__FILE__,__LINE__)  !Array of interior nodes of each vef
 call memalloc(no+1,nodes_vef%p,__FILE__,__LINE__)  !Pointer to nodes_vef%l for each vef
 call memalloc(nt,  nodes_vef%l,__FILE__,__LINE__)  !Array of all nodes of each vef
 call memalloc(no+1,vefs_vef%p,__FILE__,__LINE__)  !Pointer to vefs_vef%l for each vef
 call memalloc(nt2,  vefs_vef%l,__FILE__,__LINE__)  !Array of all vefs of each vef
 call memalloc(no+1,corners_vef%p,__FILE__,__LINE__)  !Pointer to corners_vef%l for each vef
 call memalloc(nc,  corners_vef%l,__FILE__,__LINE__)  !Array of corners for each vef
 call memalloc(nod,nd+1,obdla,__FILE__,__LINE__)
 call memalloc(no, node2ob,__FILE__,__LINE__)        ! Auxiliar array
 call memalloc(no, ob2node,__FILE__,__LINE__)        ! Auxiliar array

 interior_nodes_vef%p=0   !Pointer to ndxob%l for each vef
 interior_nodes_vef%l=0   !Array of interior nodes of each vef
 nodes_vef%p=0   !Pointer to ntxob%l for each vef
 vefs_vef%l=0   !Array of all nodes of each vef
 vefs_vef%p=0   !Pointer to obxob%l for each vef
 nodes_vef%l=0   !Array of all nodes of each vef
 corners_vef%p=0   !Pointer to crxob%l for each vef
 corners_vef%l=0   !Array of corners for each vef


 !Initialize pointers
 interior_nodes_vef%p(1) = 1
 nodes_vef%p(1) = 1
 vefs_vef%p(1) = 1
 corners_vef%p(1) = 1

 !Loop over dimensions
 do k = 0,nd
    aux1 = int(((p-1)**k)) ! interior nodes for an vef of dim k
    aux3 = int(((p+1)**k)) ! Total nodes for an vef of dim k
    aux2 = int(2**k)       ! Corners for an vef of dim k
    aux4 = int((3**k)) ! Corners for an vef of dim k (idem p=2)

    ! Loop over vefs of dimension k
    do i = number_vefs_dimension(k+1),number_vefs_dimension(k+2)-1 
       interior_nodes_vef%p(i+1) = interior_nodes_vef%p(i) + aux1 ! assign pointers
       nodes_vef%p(i+1) = nodes_vef%p(i) + aux3 ! assign pointers
       corners_vef%p(i+1) = corners_vef%p(i) + aux2 ! assign pointers
       vefs_vef%p(i+1) = vefs_vef%p(i) + aux4 ! assign pointers 
    end do
 end do

 ! Initialize auxiliar values
 k = 0
 i = 0
 idm = 0
 j = 2

 ! Construction of obdla matrix
 ! For each vef, up to a displacement, we have an identifier id={1..nod}
 ! obdla(id,1) = dimension of the vef
 ! obdla(id,2:obdla(id,1)+1) = gives the directions that define the vef
 obdla = -1
 obdla(1,1) = 0
 do od = 0,nd
    if (od > 0) then
       call r_dim(j,idm(1:od),k,i,nd,od,obdla,nod)
    end if
 end do

 ! Initialize auxiliar values
 idm = 0
 fdm = 0
 cd  = 0
 c2  = 0 ! ndxob%p counter
 c3  = 0 ! crxob%p counter
 c4  = 0 ! ntxob%p counter
 c5  = 0 ! obxob%p counter
 c6  = 0 ! ob2node   counter
 co  = 0 ! counter of vefs

 ! Loop over vefs dimensions
 do od = 0,nd
    ! Create ijk tables (od)
    ! Compute auxt1 the local numbering of the corners of an vef of dimension nd-od
    ! It allows to know how many translations for each paralel set of vefs
    if (od < nd) then
       call memalloc(nd-od,2**(nd-od),auxt1,__FILE__,__LINE__)
       auxt1 = 0
       kk    = 0
       aux1  = 1
       ijk   = 0
       call Q_r_ijk(kk,aux1,ijk,nd-od,auxt1,0,1)
    end if
    ! Compute auxt2 the local numbering of the corners in an vef of dim od
    if (od >0) then
       call memalloc(od,2**(od),auxt2,__FILE__,__LINE__)
       auxt2 = 0
       kk    = 0
       aux1  = 1
       ijk   = 0
       call Q_r_ijk(kk,aux1,ijk,od,auxt2,0,1)

       if (p > 1) then
          ! Compute auxt3 the local numbering of the interior nodes in an vef of dim od
          call memalloc(od,(p-1)**(od),auxt3,__FILE__,__LINE__)
          auxt3 = 0
          kk    = 0
          aux1  = 1
          ijk   = 0
          call Q_r_ijk(kk,aux1,ijk,od,auxt3,1,p-1)
       end if

       ! Compute auxt4 the local numbering of all nodes in an vef of dim od
       call memalloc(od,(p+1)**(od),auxt4,__FILE__,__LINE__)
       auxt4 = 0
       kk    = 0
       aux1  = 1
       ijk   = 0
       call Q_r_ijk(kk,aux1,ijk,od,auxt4,0,p)

       ! Compute auxt5 the local numbering of all nodes in an vef of dim od
       call memalloc(od,(2+1)**(od),auxt5,__FILE__,__LINE__)
       auxt5 = 0
       kk    = 0
       aux1  = 1
       ijk   = 0
       call Q_r_ijk(kk,aux1,ijk,od,auxt5,0,2)

       ! Compute auxt6 the local numbering of the interior vefs in an vef of dim od
       call memalloc(od,(2-1)**(od),auxt6,__FILE__,__LINE__)
       auxt6 = 0
       kk    = 0
       aux1  = 1
       ijk   = 0
       call Q_r_ijk(kk,aux1,ijk,od,auxt6,1,2-1)

    end if


    ! For each dimension, there are bnm(nd,od) vefs up to translation
    do j = 1,bnm(nd,od)
       idm = -1 ! positions in which the nodes variates
       fdm = -1 ! Positions corresponding to the translation between paralel vefs
       aux = -1 ! auxiliar vector to construct fdm from idm
       cd = cd+1

       ! Take the position that will vary inside the vef
       do k = 1,od
          idm(k) = obdla(cd,k+1) 
       end do

       !Mark the positions already taken by idm

       aux = 0
       do k=1,od
          aux(idm(k)+1) = 1
       end do

       !Construct the array of orthogonal space wrt idm. 
       !It gives the translations for each paralel vef
       c = 1
       do k=1,nd
          if (aux(k) == 0) then
             fdm(c) = k-1
             c = c+1
          end if
       end do

       ! Corner numbering
       ! Loop over the translations
       do l = 1,2**(nd-od) 

          ! Set orientation of the vef
          co = co +1
          call Q_orientation_vef(orientation%a(co),fdm(1:nd-od),od,nd,l)

          !ijk_g(jdm) will contain the translations from one vef to another
          !ijk_g(idm) will contain the variations inside the vef
          do k = 1,nd-od
             ijk_g(fdm(k)+1) = auxt1(k,l)
          end do

          ! Loop over the corners inside the vef
          do m = 1,2**od
             do k = 1,od
                ijk_g(idm(k)+1) = auxt2(k,m)
             end do
             c2 = c2+1
             corners_vef%l(c2) = Q_gijk(ijk_g,nd,1) !store the vef numbering of the corner 
          end do
       end do

       ! Interior node numbering
       ! Loop over the translations
       do l = 1,2**(nd-od)
          !ijk_g(jdm) will contain the translations from 1 vef to another; must be scaled by p
          !ijk_g(idm) will contain the variations inside the vef
          do k = 1,nd-od
             ijk_g(fdm(k)+1) = auxt1(k,l)*p
          end do

          ! Loop over the interior nodes of the vef
          do m = 1,(p-1)**(od)
             do k = 1,od
                ijk_g(idm(k)+1) = auxt3(k,m)
             end do
             c3 = c3+1
             interior_nodes_vef%l(c3) = Q_gijk(ijk_g,nd,p) ! Store the local numbering in ndxob%l
          end do
       end do

       ! All node numbering
       !Loop over the translations
       do l = 1,2**(nd-od)
          !ijk_g(jdm) will contain the translations from 1 vef to another; must be scaled by p
          !ijk_g(idm) will contain the variations inside the vef
          do k = 1,nd-od
             ijk_g(fdm(k)+1) = auxt1(k,l)*p
          end do

          ! Loop over the interior nodes of the vef
          do m = 1,(p+1)**(od)
             do k = 1,od
                ijk_g(idm(k)+1) = auxt4(k,m)
             end do
             c4 = c4+1
             nodes_vef%l(c4) = Q_gijk(ijk_g,nd,p) ! Store the local numbering in ntxob%l
          end do
       end do

       ! obxob array and auxiliar ob2node array 

       ! Interior node numbering
       ! Loop over the translations
       do l = 1,2**(nd-od)
          !ijk_g(jdm) will contain the translations from 1 vef to another; must be scaled by p
          !ijk_g(idm) will contain the variations inside the vef
          do k = 1,nd-od
             ijk_g(fdm(k)+1) = auxt1(k,l)*2
          end do

          ! Loop over the interior nodes of the vef
          do m = 1,(2-1)**(od)
             do k = 1,od
                ijk_g(idm(k)+1) = auxt6(k,m)
             end do
             c6 = c6+1
             ob2node(c6) = Q_gijk(ijk_g,nd,2) ! Store the local numbering in ndxob%l
          end do
       end do


       do l = 1,2**(nd-od)

          ! Fixed values for the vef
          do k = 1,nd-od
             ijk_g(fdm(k)+1) = auxt1(k,l)*2
          end do

          ! Fill obxob (equivalent to ntxob for p=2)
          do m = 1,3**od
             do k = 1,od
                ijk_g(idm(k)+1) = auxt5(k,m)
             end do
             c5 = c5 +1
             vefs_vef%l(c5) = Q_gijk(ijk_g,nd,2)
          end do

          ! Define ijk_g for the node in the center of the vef
          do k = 1,od
             ijk_g(idm(k)+1) = 1
          end do

          ! Find the generic node numbering
          m = Q_gijk(ijk_g,nd,2)

          ! Fill ob2node array
          !ob2node(m) = co
       end do

    end do

    !Deallocate auxiliar arrays
    if (od < nd) call memfree(auxt1,__FILE__,__LINE__)
    if (od >0) then
       call memfree(auxt2,__FILE__,__LINE__)
       if (p > 1) call memfree(auxt3,__FILE__,__LINE__)
       call memfree(auxt4,__FILE__,__LINE__)
       call memfree(auxt5,__FILE__,__LINE__)
       call memfree(auxt6,__FILE__,__LINE__)
    end if
 end do

 do i=1,no
    node2ob(ob2node(i)) = i
 end do

 ! Modify the identifiers of the nodes by the ids of the vef in obxob
 do c5 = 1, nt2
    vefs_vef%l(c5) = node2ob(vefs_vef%l(c5))
 end do

 ! Sort the array 
 !do co = 1, no
 !   call sort(obxob%p(co+1)-obxob%p(co),obxob%l(obxob%p(co):obxob%p(co+1)))
 !end do

 ! Deallocate OBDLA
 call memfree(obdla,__FILE__,__LINE__)
 call memfree(ob2node,__FILE__,__LINE__)
 call memfree(node2ob,__FILE__,__LINE__)


 call memfree( aux, __FILE__, __LINE__ )
 call memfree( idm, __FILE__, __LINE__ )
 call memfree( fdm, __FILE__, __LINE__ )
 call memfree( ijk, __FILE__, __LINE__ )
 call memfree( ijk_g, __FILE__, __LINE__ )


 ! ! Create the face permutation of nodes
 ! if (nd>2) then call memalloc(2*2**2,nodes_vef(3),o2n,__FILE__,__LINE__)

 ! write(*,*) 'orientation vefs'
 ! do od = 1,nd
 !    write(*,*) 'dime', od, '--------------------------'
 !    write(*,*) orientation(nvef_dim(od):nvef_dim(od+1)-1)
 ! end do
 ! write(*,*) 'no+1', no+1, 'ndxob%p'
 ! do od = 1,no+1
 !    write(*,*) ndxob%p(od), ', &'
 ! end do
 ! write(*,*) 'nn', nn, 'ndxob%l'
 ! do od = 1,nn
 !    write(*,*) ndxob%l(od), ', &'
 ! end do

 ! write(*,*) 'no+1', no+1, 'ntxob%p'
 ! do od = 1,no+1
 !    write(*,*) ntxob%p(od), ', &'
 ! end do
 ! write(*,*) 'nt', nt, 'ntxob%l'
 ! do od = 1,nt
 !    write(*,*) ntxob%l(od), ', &'
 ! end do

 ! write(*,*) 'no+1', no+1, 'crxob%p'
 ! do od = 1,no+1
 !    write(*,*) crxob%p(od), ', &'
 ! end do
 ! write(*,*) 'nc', nc, 'crxob%l'
 ! do od = 1,nc
 !    write(*,*) crxob%l(od), ', &'
 ! end do
end subroutine fill





!=================================================================================================
! BNM(A,B)=A!/((A-B)!B!) computes the binomial coefficient of (A,B), A>B
integer (ip) function bnm(a,b)
 implicit none
 integer(ip) :: a,b
 if (a >= b) then
    bnm = int(fc(a)/(fc(b)*fc(a-b)))
 else
    write(*,*) 'ERROR: no binomial coef for b > a'
    check(.false.)
 end if
end function bnm
!==================================================================================================
! Given the dimension nd of the quad and the positions p0,...,p1 we want to consider is going
! to take values. The routine Q_R_IJK returns the number of nodes (co) and a matrix auxt1 that 
! for the nth node of the quad it gives the ijk position that it corresponds to
!         | p0 p0   ... p0 p0   ... p1 |
! auxt1 = | p0 p0   ... p0 p0+1 ... p1 |
!         | p0 p0+1 ... p1 p0   ... p1 |
recursive subroutine Q_r_ijk(co,d,ijk,nd,auxt1,p0,p1)
 implicit none
 ! Parameters
 integer(ip), intent(in)    :: d,nd,p0,p1
 integer(ip), intent(inout) :: ijk(nd),co              !#nodes
 integer(ip), intent(inout) :: auxt1(nd,(p1+1-p0)**nd) ! ode ijk position matrix

 ! Local variables
 integer(ip)                :: dp,i,ipp

 do ipp = p0,p1
    if (d>nd) exit
    ijk(nd-d+1) = ipp 
    if (d < nd) call Q_r_ijk(co,d+1,ijk,nd,auxt1,p0,p1)
    if (d == nd) then
       co = co + 1
       do i = 1,nd
          auxt1(i,co) = ijk(i)
       end do
    end if
 end do
end subroutine Q_r_ijk


!==================================================================================================
! Q_GIJK(i,nd,p) returns the generic identifier of a node with coordinates i in an elem(nd,p)
!Given the coordinates ijk (in i) and the dimension nd and the order p of the 
!quad, it returns the local numbering of the node: Q_gijk=i+j*(p+1)+k*(p+1)^2
integer(ip) function Q_gijk(i,nd,p)
 implicit none
 integer(ip) :: nd,i(nd),p,k
 Q_gijk = 1
 do k = 1,nd
    Q_gijk = Q_gijk + i(k)*((p+1)**(k-1))
 end do
end function  Q_gijk


!==================================================================================================
subroutine Q_orientation_vef(o,fdm,od,nd,l)
 implicit none
 ! Parameters
 integer(ip), intent(out) :: o
 integer(ip), intent(in)  :: fdm(:)  ! fdm gives the orthogonal directions to the vef
 integer(ip), intent(in)  :: od,nd,l ! l=translation ordering

 if (nd == 2 .and. od == 1) then
    o = modulo(l+fdm(1),2)
 elseif (nd == 3 .and. od == 2) then
    o = modulo(l+fdm(1),2)
 elseif (nd>3) then
    write(*,*) __FILE__,__LINE__,'WARNING!! the orientation is not defined for dimension >3'
 else
    o = 0
 end if
end subroutine Q_orientation_vef

!==================================================================================================
! R_DIM construct OBDLA matrix
! For each vef, up to a displacement, we have an identifier id={1..nod}
! obdla(id,1) = dimension of the vef
! obdla(id,2:obdla(id,1)+1) = gives the directions that define the vef
recursive subroutine r_dim(co,idm,ko,i,nd,od,obdla,nod)
 implicit none
 integer(ip), intent(in)    :: ko !space position we begin to count from (ij=>i<j)
 integer(ip), intent(in)    :: i  !i=local space position we are currently modifying (i=0..od)
 integer(ip), intent(in)    :: nd,od,nod
 integer(ip), intent(inout) :: obdla(nod,nd+1)
 integer(ip), intent(inout) :: idm(od) 
 integer(ip), intent(inout) :: co      ! Pointer to the position of the vef
 integer(ip)                :: aux,ijk_c(nd),j,cd,kn,s

 !Given dimension od of the vef
 do kn = ko,nd-od+i
    idm(i+1) = kn 
    if (i+1 < od) then
       call r_dim(co,idm,kn+1,i+1,nd,od,obdla,nod)
    else
       obdla(co,1) = od
       do j = 1,od
          obdla(co,j+1) = idm(j)
       end do
       co = co + 1
    end if
 end do
end subroutine r_dim

!==================================================================================================
! FC(k)=k! computes the factorial of k 
integer(ip) function fc(i)
 implicit none
 integer(ip) :: i, k
 fc = 1
 do k=2,i
    fc = fc*k
 end do
end function fc


!-----------------------------------------------------------------------
subroutine fill_quadrature ( quadrature ) !ndime,ngaus,posgp,weigp)
  !-----------------------------------------------------------------------
  !
  !     This routine sets up the integration constants of open
  !     integration rules for brick elements:
  ! 
  !          NDIME = 1             NDIME = 2             NDIME = 3
  ! 
  !      NGAUS  EXACT POL.     NGAUS  EXACT POL.     NGAUS  EXACT POL. 
  !      -----  ----------     -----  ----------     -----  ----------
  !        1      q1           1 x 1     q1          1x1x1     q1	
  !        2      q3           2 x 2     q3          2x2x2     q3   
  !        3      q5           3 x 3     q5          3x3x3     q5
  !        4      q7           4 x 4     q7          4x4x4     q7
  !        5      q9           5 x 5     q9          5x5x5     q9
  !        6      q11          6 x 6     q11         6x6x6     q11
  !        7      q13          7 x 7     q13         7x7x7     q13
  !        8      q15          8 x 8     q15         8x8x8     q15
  !       16      q31         16 x 16    q31        16x16x16   q31
  ! 
  !-----------------------------------------------------------------------
 implicit none
 type(SB_quadrature_t), intent(inout)  :: quadrature
 real(rp)                 :: posgl(20),weigl(20)
 integer(ip)              :: nlocs,igaus,ilocs,jlocs,klocs,ndime,ngaus

 type(list_t), pointer :: interior_nodes_vef, nodes_vef, corners_vef, vefs_vef

 real(rp), pointer :: coordinates(:,:), weight(:)

 coordinates => quadrature%get_pointer_coordinates()
 weight => quadrature%get_pointer_weight()
 ndime = quadrature%get_number_dimensions()
 ngaus = quadrature%get_number_integration_points()

 if(ndime==1) then
    nlocs=ngaus
 else if(ndime==2) then
    nlocs=nint(sqrt(real(ngaus,rp)))
 else
    nlocs=nint(real(ngaus,rp)**(1.0_rp/3.0_rp))
 end if

 if(nlocs==1) then
    posgl(1)=0.0_rp
    weigl(1)=2.0_rp
 else if(nlocs==2) then
    posgl(1)=-0.577350269189626_rp
    posgl(2)= 0.577350269189626_rp
    weigl(1)= 1.0_rp
    weigl(2)= 1.0_rp
 else if(nlocs==3) then
    posgl(1)=-0.774596669241483_rp
    posgl(2)= 0.0_rp
    posgl(3)= 0.774596669241483_rp
    weigl(1)= 0.555555555555556_rp
    weigl(2)= 0.888888888888889_rp
    weigl(3)= 0.555555555555556_rp
 else if(nlocs==4)  then
    posgl(1)=-0.861136311594053_rp
    posgl(2)=-0.339981043584856_rp
    posgl(3)= 0.339981043584856_rp
    posgl(4)= 0.861136311594053_rp
    weigl(1)= 0.347854845137454_rp
    weigl(2)= 0.652145154862546_rp
    weigl(3)= 0.652145154862546_rp
    weigl(4)= 0.347854845137454_rp
 else if(nlocs==5)  then
    posgl(1) = -0.906179845938664_rp
    posgl(2) = -0.538469310105683_rp
    posgl(3) =  0.0_rp
    posgl(4) =  0.538469310105683_rp
    posgl(5) =  0.906179845938664_rp
    weigl(1) =  0.236926885056189_rp
    weigl(2) =  0.478628670499366_rp
    weigl(3) =  0.568888888888889_rp
    weigl(4) =  0.478628670499366_rp
    weigl(5) =  0.236926885056189_rp
 else if(nlocs==6)  then
    posgl(1) = -0.932469514203152_rp
    posgl(2) = -0.661209386466265_rp
    posgl(3) = -0.238619186083197_rp
    posgl(4) =  0.238619186083197_rp
    posgl(5) =  0.661209386466265_rp
    posgl(6) =  0.932469514203152_rp
    weigl(1) =  0.171324492379170_rp
    weigl(2) =  0.360761573048139_rp
    weigl(3) =  0.467913934572691_rp
    weigl(4) =  0.467913934572691_rp
    weigl(5) =  0.360761573048139_rp
    weigl(6) =  0.171324492379170_rp
 else if(nlocs==7)  then
    posgl(1) = -0.949107912342759_rp
    posgl(2) = -0.741531185599394_rp
    posgl(3) = -0.405845151377397_rp
    posgl(4) =  0.0_rp
    posgl(5) =  0.405845151377397_rp
    posgl(6) =  0.741531185599394_rp
    posgl(7) =  0.949107912342759_rp
    weigl(1) =  0.129484966168870_rp
    weigl(2) =  0.279705391489277_rp
    weigl(3) =  0.381830050505119_rp
    weigl(4) =  0.417959183673469_rp
    weigl(5) =  0.381830050505119_rp
    weigl(6) =  0.279705391489277_rp
    weigl(7) =  0.129484966168870_rp
 else if(nlocs==8)  then
    posgl(1) = -0.960289856497536_rp
    posgl(2) = -0.796666477413627_rp
    posgl(3) = -0.525532409916329_rp
    posgl(4) = -0.183434642495650_rp
    posgl(5) =  0.183434642495650_rp
    posgl(6) =  0.525532409916329_rp
    posgl(7) =  0.796666477413627_rp
    posgl(8) =  0.960289856497536_rp

    weigl(1) =  0.101228536290376_rp
    weigl(2) =  0.222381034453374_rp
    weigl(3) =  0.313706645877887_rp
    weigl(4) =  0.362683783378362_rp
    weigl(5) =  0.362683783378362_rp
    weigl(6) =  0.313706645877887_rp
    weigl(7) =  0.222381034453374_rp
    weigl(8) =  0.101228536290376_rp
 else if(nlocs== 9 )  then 
    posgl( 1 ) = 0.968160239507626_rp 
    posgl( 2 ) = 0.836031107326636_rp 
    posgl( 3 ) = 0.613371432700590_rp 
    posgl( 4 ) = 0.324253423403809_rp 
    posgl( 5 ) = 0.000000000000000_rp 
    posgl( 6 ) = -0.324253423403809_rp 
    posgl( 7 ) = -0.613371432700590_rp 
    posgl( 8 ) = -0.836031107326636_rp 
    posgl( 9 ) = -0.968160239507626_rp 

    weigl( 1 ) = 0.081274388361575_rp 
    weigl( 2 ) = 0.180648160694857_rp 
    weigl( 3 ) = 0.260610696402936_rp 
    weigl( 4 ) = 0.312347077040003_rp 
    weigl( 5 ) = 0.330239355001260_rp 
    weigl( 6 ) = 0.312347077040003_rp 
    weigl( 7 ) = 0.260610696402936_rp 
    weigl( 8 ) = 0.180648160694857_rp 
    weigl( 9 ) = 0.081274388361575_rp 
 else if(nlocs== 10 )  then 
    posgl( 1 ) = 0.973906528517172_rp 
    posgl( 2 ) = 0.865063366688985_rp 
    posgl( 3 ) = 0.679409568299024_rp 
    posgl( 4 ) = 0.433395394129247_rp 
    posgl( 5 ) = 0.148874338981631_rp 
    posgl( 6 ) = -0.148874338981631_rp 
    posgl( 7 ) = -0.433395394129247_rp 
    posgl( 8 ) = -0.679409568299024_rp 
    posgl( 9 ) = -0.865063366688985_rp 
    posgl( 10 ) = -0.973906528517172_rp 

    weigl( 1 ) = 0.066671344308688_rp 
    weigl( 2 ) = 0.149451349150581_rp 
    weigl( 3 ) = 0.219086362515982_rp 
    weigl( 4 ) = 0.269266719309996_rp 
    weigl( 5 ) = 0.295524224714753_rp 
    weigl( 6 ) = 0.295524224714753_rp 
    weigl( 7 ) = 0.269266719309996_rp 
    weigl( 8 ) = 0.219086362515982_rp 
    weigl( 9 ) = 0.149451349150581_rp 
    weigl( 10 ) = 0.066671344308688_rp 
 else if(nlocs== 11 )  then 
    posgl( 1 ) = 0.978228658146057_rp 
    posgl( 2 ) = 0.887062599768095_rp 
    posgl( 3 ) = 0.730152005574049_rp 
    posgl( 4 ) = 0.519096129206812_rp 
    posgl( 5 ) = 0.269543155952345_rp 
    posgl( 6 ) = 0.000000000000000_rp 
    posgl( 7 ) = -0.269543155952345_rp 
    posgl( 8 ) = -0.519096129206812_rp 
    posgl( 9 ) = -0.730152005574049_rp 
    posgl( 10 ) = -0.887062599768095_rp 
    posgl( 11 ) = -0.978228658146057_rp 

    weigl( 1 ) = 0.055668567116174_rp 
    weigl( 2 ) = 0.125580369464904_rp 
    weigl( 3 ) = 0.186290210927734_rp 
    weigl( 4 ) = 0.233193764591990_rp 
    weigl( 5 ) = 0.262804544510247_rp 
    weigl( 6 ) = 0.272925086777901_rp 
    weigl( 7 ) = 0.262804544510247_rp 
    weigl( 8 ) = 0.233193764591990_rp 
    weigl( 9 ) = 0.186290210927734_rp 
    weigl( 10 ) = 0.125580369464904_rp 
    weigl( 11 ) = 0.055668567116174_rp 
 else if(nlocs== 12 )  then 
    posgl( 1 ) = 0.981560634246719_rp 
    posgl( 2 ) = 0.904117256370475_rp 
    posgl( 3 ) = 0.769902674194305_rp 
    posgl( 4 ) = 0.587317954286617_rp 
    posgl( 5 ) = 0.367831498998180_rp 
    posgl( 6 ) = 0.125233408511469_rp 
    posgl( 7 ) = -0.125233408511469_rp 
    posgl( 8 ) = -0.367831498998180_rp 
    posgl( 9 ) = -0.587317954286617_rp 
    posgl( 10 ) = -0.769902674194305_rp 
    posgl( 11 ) = -0.904117256370475_rp 
    posgl( 12 ) = -0.981560634246719_rp 

    weigl( 1 ) = 0.047175336386512_rp 
    weigl( 2 ) = 0.106939325995318_rp 
    weigl( 3 ) = 0.160078328543346_rp 
    weigl( 4 ) = 0.203167426723066_rp 
    weigl( 5 ) = 0.233492536538355_rp 
    weigl( 6 ) = 0.249147045813403_rp 
    weigl( 7 ) = 0.249147045813403_rp 
    weigl( 8 ) = 0.233492536538355_rp 
    weigl( 9 ) = 0.203167426723066_rp 
    weigl( 10 ) = 0.160078328543346_rp 
    weigl( 11 ) = 0.106939325995318_rp 
    weigl( 12 ) = 0.047175336386512_rp 
 else if(nlocs== 13 )  then 
    posgl( 1 ) = 0.984183054718588_rp 
    posgl( 2 ) = 0.917598399222978_rp 
    posgl( 3 ) = 0.801578090733310_rp 
    posgl( 4 ) = 0.642349339440340_rp 
    posgl( 5 ) = 0.448492751036447_rp 
    posgl( 6 ) = 0.230458315955135_rp 
    posgl( 7 ) = 0.000000000000000_rp 
    posgl( 8 ) = -0.230458315955135_rp 
    posgl( 9 ) = -0.448492751036447_rp 
    posgl( 10 ) = -0.642349339440340_rp 
    posgl( 11 ) = -0.801578090733310_rp 
    posgl( 12 ) = -0.917598399222978_rp 
    posgl( 13 ) = -0.984183054718588_rp 

    weigl( 1 ) = 0.040484004765316_rp 
    weigl( 2 ) = 0.092121499837728_rp 
    weigl( 3 ) = 0.138873510219787_rp 
    weigl( 4 ) = 0.178145980761946_rp 
    weigl( 5 ) = 0.207816047536888_rp 
    weigl( 6 ) = 0.226283180262897_rp 
    weigl( 7 ) = 0.232551553230874_rp 
    weigl( 8 ) = 0.226283180262897_rp 
    weigl( 9 ) = 0.207816047536888_rp 
    weigl( 10 ) = 0.178145980761946_rp 
    weigl( 11 ) = 0.138873510219787_rp 
    weigl( 12 ) = 0.092121499837728_rp 
    weigl( 13 ) = 0.040484004765316_rp 
 else if(nlocs== 14 )  then 
    posgl( 1 ) = 0.986283808696812_rp 
    posgl( 2 ) = 0.928434883663574_rp 
    posgl( 3 ) = 0.827201315069765_rp 
    posgl( 4 ) = 0.687292904811685_rp 
    posgl( 5 ) = 0.515248636358154_rp 
    posgl( 6 ) = 0.319112368927890_rp 
    posgl( 7 ) = 0.108054948707344_rp 
    posgl( 8 ) = -0.108054948707344_rp 
    posgl( 9 ) = -0.319112368927890_rp 
    posgl( 10 ) = -0.515248636358154_rp 
    posgl( 11 ) = -0.687292904811685_rp 
    posgl( 12 ) = -0.827201315069765_rp 
    posgl( 13 ) = -0.928434883663574_rp 
    posgl( 14 ) = -0.986283808696812_rp 

    weigl( 1 ) = 0.035119460331752_rp 
    weigl( 2 ) = 0.080158087159760_rp 
    weigl( 3 ) = 0.121518570687903_rp 
    weigl( 4 ) = 0.157203167158194_rp 
    weigl( 5 ) = 0.185538397477938_rp 
    weigl( 6 ) = 0.205198463721296_rp 
    weigl( 7 ) = 0.215263853463158_rp 
    weigl( 8 ) = 0.215263853463158_rp 
    weigl( 9 ) = 0.205198463721296_rp 
    weigl( 10 ) = 0.185538397477938_rp 
    weigl( 11 ) = 0.157203167158194_rp 
    weigl( 12 ) = 0.121518570687903_rp 
    weigl( 13 ) = 0.080158087159760_rp 
    weigl( 14 ) = 0.035119460331752_rp 
 else if(nlocs== 15 )  then 
    posgl( 1 ) = 0.987992518020485_rp 
    posgl( 2 ) = 0.937273392400706_rp 
    posgl( 3 ) = 0.848206583410427_rp 
    posgl( 4 ) = 0.724417731360170_rp 
    posgl( 5 ) = 0.570972172608539_rp 
    posgl( 6 ) = 0.394151347077563_rp 
    posgl( 7 ) = 0.201194093997435_rp 
    posgl( 8 ) = 0.000000000000000_rp 
    posgl( 9 ) = -0.201194093997435_rp 
    posgl( 10 ) = -0.394151347077563_rp 
    posgl( 11 ) = -0.570972172608539_rp 
    posgl( 12 ) = -0.724417731360170_rp 
    posgl( 13 ) = -0.848206583410427_rp 
    posgl( 14 ) = -0.937273392400706_rp 
    posgl( 15 ) = -0.987992518020485_rp 

    weigl( 1 ) = 0.030753241996117_rp 
    weigl( 2 ) = 0.070366047488108_rp 
    weigl( 3 ) = 0.107159220467172_rp 
    weigl( 4 ) = 0.139570677926154_rp 
    weigl( 5 ) = 0.166269205816994_rp 
    weigl( 6 ) = 0.186161000015562_rp 
    weigl( 7 ) = 0.198431485327112_rp 
    weigl( 8 ) = 0.202578241925561_rp 
    weigl( 9 ) = 0.198431485327112_rp 
    weigl( 10 ) = 0.186161000015562_rp 
    weigl( 11 ) = 0.166269205816994_rp 
    weigl( 12 ) = 0.139570677926154_rp 
    weigl( 13 ) = 0.107159220467172_rp 
    weigl( 14 ) = 0.070366047488108_rp 
    weigl( 15 ) = 0.030753241996117_rp 
 else if(nlocs==16)  then
    posgl( 1) =-0.98940093499165_rp
    posgl( 2) =-0.94457502307323_rp
    posgl( 3) =-0.86563120238783_rp
    posgl( 4) =-0.75540440835500_rp
    posgl( 5) =-0.61787624440264_rp
    posgl( 6) =-0.45801677765723_rp
    posgl( 7) =-0.28160355077926_rp
    posgl( 8) =-0.09501250983764_rp
    posgl( 9) = 0.09501250983764_rp
    posgl(10) = 0.28160355077926_rp
    posgl(11) = 0.45801677765723_rp
    posgl(12) = 0.61787624440264_rp
    posgl(13) = 0.75540440835500_rp
    posgl(14) = 0.86563120238783_rp
    posgl(15) = 0.94457502307323_rp
    posgl(16) = 0.98940093499165_rp

    weigl( 1) =  0.02715245941175_rp
    weigl( 2) =  0.06225352393865_rp
    weigl( 3) =  0.09515851168249_rp
    weigl( 4) =  0.12462897125553_rp
    weigl( 5) =  0.14959598881658_rp
    weigl( 6) =  0.16915651939500_rp
    weigl( 7) =  0.18260341504492_rp
    weigl( 8) =  0.18945061045507_rp
    weigl( 9) =  0.18945061045507_rp
    weigl(10) =  0.18260341504492_rp
    weigl(11) =  0.16915651939500_rp
    weigl(12) =  0.14959598881658_rp
    weigl(13) =  0.12462897125553_rp
    weigl(14) =  0.09515851168249_rp
    weigl(15) =  0.06225352393865_rp
    weigl(16) =  0.02715245941175_rp
 else if(nlocs== 17 )  then 
    posgl( 1 ) = 0.990575475314417_rp 
    posgl( 2 ) = 0.950675521768768_rp 
    posgl( 3 ) = 0.880239153726986_rp 
    posgl( 4 ) = 0.781514003896801_rp 
    posgl( 5 ) = 0.657671159216691_rp 
    posgl( 6 ) = 0.512690537086477_rp 
    posgl( 7 ) = 0.351231763453876_rp 
    posgl( 8 ) = 0.178484181495848_rp 
    posgl( 9 ) = 0.000000000000000_rp 
    posgl( 10 ) = -0.178484181495848_rp 
    posgl( 11 ) = -0.351231763453876_rp 
    posgl( 12 ) = -0.512690537086477_rp 
    posgl( 13 ) = -0.657671159216691_rp 
    posgl( 14 ) = -0.781514003896801_rp 
    posgl( 15 ) = -0.880239153726986_rp 
    posgl( 16 ) = -0.950675521768768_rp 
    posgl( 17 ) = -0.990575475314417_rp 

    weigl( 1 ) = 0.024148302868548_rp 
    weigl( 2 ) = 0.055459529373987_rp 
    weigl( 3 ) = 0.085036148317179_rp 
    weigl( 4 ) = 0.111883847193404_rp 
    weigl( 5 ) = 0.135136368468525_rp 
    weigl( 6 ) = 0.154045761076810_rp 
    weigl( 7 ) = 0.168004102156450_rp 
    weigl( 8 ) = 0.176562705366993_rp 
    weigl( 9 ) = 0.179446470356207_rp 
    weigl( 10 ) = 0.176562705366993_rp 
    weigl( 11 ) = 0.168004102156450_rp 
    weigl( 12 ) = 0.154045761076810_rp 
    weigl( 13 ) = 0.135136368468525_rp 
    weigl( 14 ) = 0.111883847193404_rp 
    weigl( 15 ) = 0.085036148317179_rp 
    weigl( 16 ) = 0.055459529373987_rp 
    weigl( 17 ) = 0.024148302868548_rp 
 else if(nlocs== 18 )  then 
    posgl( 1 ) = 0.991565168420931_rp 
    posgl( 2 ) = 0.955823949571398_rp 
    posgl( 3 ) = 0.892602466497556_rp 
    posgl( 4 ) = 0.803704958972523_rp 
    posgl( 5 ) = 0.691687043060353_rp 
    posgl( 6 ) = 0.559770831073948_rp 
    posgl( 7 ) = 0.411751161462843_rp 
    posgl( 8 ) = 0.251886225691506_rp 
    posgl( 9 ) = 0.084775013041735_rp 
    posgl( 10 ) = -0.084775013041735_rp 
    posgl( 11 ) = -0.251886225691506_rp 
    posgl( 12 ) = -0.411751161462843_rp 
    posgl( 13 ) = -0.559770831073948_rp 
    posgl( 14 ) = -0.691687043060353_rp 
    posgl( 15 ) = -0.803704958972523_rp 
    posgl( 16 ) = -0.892602466497556_rp 
    posgl( 17 ) = -0.955823949571398_rp 
    posgl( 18 ) = -0.991565168420931_rp 

    weigl( 1 ) = 0.021616013526483_rp 
    weigl( 2 ) = 0.049714548894969_rp 
    weigl( 3 ) = 0.076425730254889_rp 
    weigl( 4 ) = 0.100942044106287_rp 
    weigl( 5 ) = 0.122555206711478_rp 
    weigl( 6 ) = 0.140642914670651_rp 
    weigl( 7 ) = 0.154684675126265_rp 
    weigl( 8 ) = 0.164276483745833_rp 
    weigl( 9 ) = 0.169142382963144_rp 
    weigl( 10 ) = 0.169142382963144_rp 
    weigl( 11 ) = 0.164276483745833_rp 
    weigl( 12 ) = 0.154684675126265_rp 
    weigl( 13 ) = 0.140642914670651_rp 
    weigl( 14 ) = 0.122555206711478_rp 
    weigl( 15 ) = 0.100942044106287_rp 
    weigl( 16 ) = 0.076425730254889_rp 
    weigl( 17 ) = 0.049714548894969_rp 
    weigl( 18 ) = 0.021616013526483_rp 
 else if(nlocs== 19 )  then 
    posgl( 1 ) = 0.992406843843584_rp 
    posgl( 2 ) = 0.960208152134830_rp 
    posgl( 3 ) = 0.903155903614818_rp 
    posgl( 4 ) = 0.822714656537143_rp 
    posgl( 5 ) = 0.720966177335229_rp 
    posgl( 6 ) = 0.600545304661681_rp 
    posgl( 7 ) = 0.464570741375961_rp 
    posgl( 8 ) = 0.316564099963630_rp 
    posgl( 9 ) = 0.160358645640225_rp 
    posgl( 10 ) = 0.000000000000000_rp 
    posgl( 11 ) = -0.160358645640225_rp 
    posgl( 12 ) = -0.316564099963630_rp 
    posgl( 13 ) = -0.464570741375961_rp 
    posgl( 14 ) = -0.600545304661681_rp 
    posgl( 15 ) = -0.720966177335229_rp 
    posgl( 16 ) = -0.822714656537143_rp 
    posgl( 17 ) = -0.903155903614818_rp 
    posgl( 18 ) = -0.960208152134830_rp 
    posgl( 19 ) = -0.992406843843584_rp 

    weigl( 1 ) = 0.019461788229726_rp 
    weigl( 2 ) = 0.044814226765699_rp 
    weigl( 3 ) = 0.069044542737641_rp 
    weigl( 4 ) = 0.091490021622450_rp 
    weigl( 5 ) = 0.111566645547334_rp 
    weigl( 6 ) = 0.128753962539336_rp 
    weigl( 7 ) = 0.142606702173607_rp 
    weigl( 8 ) = 0.152766042065860_rp 
    weigl( 9 ) = 0.158968843393954_rp 
    weigl( 10 ) = 0.161054449848784_rp 
    weigl( 11 ) = 0.158968843393954_rp 
    weigl( 12 ) = 0.152766042065860_rp 
    weigl( 13 ) = 0.142606702173607_rp 
    weigl( 14 ) = 0.128753962539336_rp 
    weigl( 15 ) = 0.111566645547334_rp 
    weigl( 16 ) = 0.091490021622450_rp 
    weigl( 17 ) = 0.069044542737641_rp 
    weigl( 18 ) = 0.044814226765699_rp 
    weigl( 19 ) = 0.019461788229726_rp 
 else if(nlocs== 20 )  then 
    posgl( 1 ) = 0.993128599185095_rp 
    posgl( 2 ) = 0.963971927277914_rp 
    posgl( 3 ) = 0.912234428251326_rp 
    posgl( 4 ) = 0.839116971822219_rp 
    posgl( 5 ) = 0.746331906460151_rp 
    posgl( 6 ) = 0.636053680726515_rp 
    posgl( 7 ) = 0.510867001950827_rp 
    posgl( 8 ) = 0.373706088715420_rp 
    posgl( 9 ) = 0.227785851141645_rp 
    posgl( 10 ) = 0.076526521133497_rp 
    posgl( 11 ) = -0.076526521133497_rp 
    posgl( 12 ) = -0.227785851141645_rp 
    posgl( 13 ) = -0.373706088715420_rp 
    posgl( 14 ) = -0.510867001950827_rp 
    posgl( 15 ) = -0.636053680726515_rp 
    posgl( 16 ) = -0.746331906460151_rp 
    posgl( 17 ) = -0.839116971822219_rp 
    posgl( 18 ) = -0.912234428251326_rp 
    posgl( 19 ) = -0.963971927277914_rp 
    posgl( 20 ) = -0.993128599185095_rp 

    weigl( 1 ) = 0.017614007139152_rp 
    weigl( 2 ) = 0.040601429800387_rp 
    weigl( 3 ) = 0.062672048334109_rp 
    weigl( 4 ) = 0.083276741576705_rp 
    weigl( 5 ) = 0.101930119817240_rp 
    weigl( 6 ) = 0.118194531961518_rp 
    weigl( 7 ) = 0.131688638449177_rp 
    weigl( 8 ) = 0.142096109318382_rp 
    weigl( 9 ) = 0.149172986472604_rp 
    weigl( 10 ) = 0.152753387130726_rp 
    weigl( 11 ) = 0.152753387130726_rp 
    weigl( 12 ) = 0.149172986472604_rp 
    weigl( 13 ) = 0.142096109318382_rp 
    weigl( 14 ) = 0.131688638449177_rp 
    weigl( 15 ) = 0.118194531961518_rp 
    weigl( 16 ) = 0.101930119817240_rp 
    weigl( 17 ) = 0.083276741576705_rp 
    weigl( 18 ) = 0.062672048334109_rp 
    weigl( 19 ) = 0.040601429800387_rp 
    weigl( 20 ) = 0.017614007139152_rp 
 else
    write(*,*) __FILE__,__LINE__,'ERROR:: Quadrature not defined',nlocs
    stop
 end if

 if(ndime==1) then
    igaus=0
    do ilocs=1,nlocs
       igaus=igaus+1
       weight(  igaus)=weigl(ilocs)
       coordinates(1,igaus)=posgl(ilocs)
    end do
 else if(ndime==2) then
    igaus=0
    do jlocs=1,nlocs
       do ilocs=1,nlocs
          igaus=igaus+1
          weight(  igaus)=weigl(ilocs)*weigl(jlocs)
          coordinates(1,igaus)=posgl(ilocs)
          coordinates(2,igaus)=posgl(jlocs)
       end do
    end do
 else if(ndime==3) then
    igaus=0
    do klocs=1,nlocs
       do jlocs=1,nlocs
          do ilocs=1,nlocs
             igaus=igaus+1
             weight(  igaus)=weigl(ilocs)*weigl(jlocs)*weigl(klocs)
             coordinates(1,igaus)=posgl(ilocs)
             coordinates(2,igaus)=posgl(jlocs)
             coordinates(3,igaus)=posgl(klocs)
          end do
       end do
    end do
 end if

end subroutine fill_quadrature

subroutine fill_interpolation ( interpolation, order, ndime, nlocs, ntens, coord_ip ) !ndime,ngaus,posgp,weigp)
  implicit none 
  type(SB_interpolation_t), intent(inout) :: interpolation
  integer(ip), intent(in) :: order, ndime, nlocs, ntens
  real(rp), target, intent(in) :: coord_ip(:,:)

  logical :: khes
  real(rp), pointer :: shape_functions(:,:), shape_derivatives(:,:,:), hessian(:,:,:)
  real(rp)    :: coord(order+1),shpe1(order+1,nlocs),shpd1(order+1,nlocs),shph1(order+1,nlocs)

  shape_functions => interpolation%get_pointer_shape_functions()
  shape_derivatives => interpolation%get_pointer_shape_derivatives()
  hessian => interpolation%get_pointer_hessian()
  
  khes = .false.
  if ( associated( hessian ) ) then 
     khes = .true.
  end if

  ! Set the coordenades of the nodal points
  call Q_coord_1d(coord,order+1)
  ! Compute the 1d shape function on the gauss points
  call shape1(coord_ip(1,:),order,nlocs,coord,shpe1,shpd1,shph1,khes)


  !if (int%khes == 1) then
  if ( associated(hessian) ) then 
     call shapen(shape_functions,shape_derivatives,shpe1,shpd1,shph1,ndime,order,nlocs,ntens,khes,hessian)
  else
     call shapen(shape_functions,shape_derivatives,shpe1,shpd1,shph1,ndime,order,nlocs,ntens,khes)
  end if
end subroutine fill_interpolation

subroutine Q_coord_1d (x,n)
 implicit none
 ! Parameters
 integer(ip), intent(in)  :: n
 real(rp)   , intent(out) :: x(n)

 ! Local variables
 integer(ip)              :: i

 do i = 0,n-1
    x(i+1) = 2*real(i)/(real(n)-1)-1
 end do
end subroutine Q_coord_1d

! ===================================================================================================
! Compute the shape function and its derivative
subroutine shape1(xg,p,ng,xn,shpe1,shpd1,shph1,khes)
 implicit none
 integer(ip), intent(in)  :: p,ng
 logical, intent(in)      :: khes
 real(rp),    intent(in)  :: xn(p+1),xg(ng)
 real(rp),    intent(out) :: shpe1(p+1,ng),shpd1(p+1,ng),shph1(p+1,ng)
 integer(ip)              :: i,j,k,m,ig
 real(rp)                 :: aux, aux2, aux3, auxv(ng),auxv2(ng),auxv3(ng)

 shpe1 = 1.0_rp
 shpd1 = 0.0_rp
 shph1 = 0.0_rp
 do i = 1,p+1
    do j = 1,p+1
       if (j /= i) then
          aux = 1/(xn(i)-xn(j)) 
          auxv = 1/(xn(i)-xn(j))
          if (khes ) auxv3 = 0
          do k = 1,p+1
             if (k /= j .and. k /= i) then
                aux2 = 1/(xn(i)-xn(k))
                if (khes ) auxv2 = 1/(xn(i)-xn(k))
                do ig = 1,ng
                   auxv(ig) = auxv(ig)*(xg(ig)-xn(k))*aux2
                end do
                if (khes ) then
                   do m = 1, p+1
                      if (m/=k .and. m/= j .and. m /= i) then
                         aux3 = 1/(xn(i)-xn(m))
                         do ig = 1,ng
                            auxv2(ig) = auxv2(ig)*(xg(ig)-xn(m))*aux3
                         end do
                      end if
                   end do
                end if
                auxv3 = auxv3+auxv2
             end if
          end do
          do ig = 1,ng
             shpe1(i,ig) = shpe1(i,ig)*(xg(ig)-xn(j))*aux
             shpd1(i,ig) = shpd1(i,ig) + auxv(ig)
             shph1(i,ig) = shph1(i,ig) + auxv3(ig)*aux
          end do
       end if
    end do
 end do
end subroutine shape1

  
  !==================================================================================================
subroutine shapen (shape,deriv,s1,sd1,sdd1,nd,p,ng,nt,khes,hessi)
  implicit none
  ! Parameters
  integer(ip)       , intent(in)  :: nd,p,ng,nt
  logical, intent(in)      :: khes
  real(rp)          , intent(in)  :: s1(p+1,ng),sd1(p+1,ng),sdd1(p+1,ng)
  real(rp)          , intent(out) :: shape((p+1)**nd,ng**nd)
  real(rp)          , intent(out) :: deriv(nd,(p+1)**nd,ng**nd)
  real(rp), optional, intent(out) :: hessi(nt,(p+1)**nd,ng**nd)


  ! Local variables
  integer(ip)              :: i,ig,d,d2,d3,it
  integer(ip)              :: ijk(nd),ijkg(nd),permu(nt)

  ! The presumed order of the varibles in the hessian is not the one obtained by generation
  
  if (nd == 2) then
     permu = (/ 1, 3, 2 /)
  elseif (nd == 3) then
     permu = (/ 1, 4, 5, 2, 6, 3/)
  end if

  ! Initialize values
  shape = 0.0_rp
  deriv = 0.0_rp
  if ( khes ) hessi = 0.0_rp

  ! Initialize nodal coordinates vector
  ijk = 0; ijk(1) = -1
  do i = 1,(p+1)**nd

     ! Set coordinates of node i 
     call Q_ijkg(ijk,i,nd,p)

     ! Initialize Gauss point coordinates vector
     ijkg = 0; ijkg(1) = -1
     do ig = 1,ng**nd

        ! Set coordinates of Gauss point ig 
        call Q_ijkg(ijkg,ig,nd,ng-1)

        ! Initialize shape
        shape(i,ig) = 1.0_rp
        it = 0
        do d = 1,nd
           ! Shape is the tensor product 1d shape: s_ijk(x,y,z) = s_i(x)*s_j(y)*s_k(z)
           shape(i,ig) = shape(i,ig)*s1(ijk(d)+1,ijkg(d)+1)

           ! Initialize deriv and hessi
           deriv(d,i,ig) = 1.0_rp
           it = it+1
           if (khes ) hessi(permu(it),i,ig)= 1.0_rp

           ! Deriv: d(s_ijk)/dx (x,y,z) = s'_i(x)*s_j(y)*s_k(z)
           ! Hessi: d2(s_ijk)/dx2 (x,y,z) = s''_i(x)*s_j(y)*s_k(z)
           do d2 = 1,nd
              if (d2 /= d) then
                 deriv( d,i,ig) = deriv( d,i,ig)*s1(ijk(d2)+1,ijkg(d2)+1)
                 if ( khes ) hessi(permu(it),i,ig)=hessi(permu(it),i,ig)*s1(ijk(d2)+1,ijkg(d2)+1)
              else
                 deriv( d,i,ig) = deriv( d,i,ig)* sd1(ijk(d)+1,ijkg(d)+1)  
                 if (khes ) hessi(permu(it),i,ig)=hessi(permu(it),i,ig)*sdd1(ijk(d)+1,ijkg(d)+1)             
              end if
           end do

           if ( khes ) then
              ! Hessi: d2(s_ijk)/dxdy (x,y,z) = s'_i(x)*s'_j(y)*s_k(z)
              do d2 = d+1,nd
                 it = it+1
                 hessi(permu(it),i,ig) = 1.0_rp
                 do d3 = 1,nd
                    if (d3 /= d .and. d3 /= d2) then
                       hessi(permu(it),i,ig) = hessi(permu(it),i,ig)*s1(ijk(d3)+1,ijkg(d3)+1)
                    else
                       hessi(permu(it),i,ig) = hessi(permu(it),i,ig)*sd1(ijk(d3)+1,ijkg(d3)+1)             
                    end if
                 end do
              end do
           end if

        end do
     end do
  end do
end subroutine shapen

  !==================================================================================================
  ! Q_IJKG(i,g,nd,p) returns coordinates of the g-th node in an elem(nd,p)
  subroutine Q_ijkg(i,g,nd,p)
    implicit none
    integer(ip), intent(in)  :: nd,g,p
    integer(ip), intent(out) :: i(nd)

    integer(ip)              :: k,g2

    g2 = g-1
    do k=1,nd
       i(k) = int(mod(g2,(p+1)**k)/(p+1)**(k-1))
       g2 = g2 - i(k)*(p+1)**(k-1)
    end do
  end subroutine Q_ijkg

  !   ! ==================================================================================================
  !   subroutine interpolation_local_tp(clocs,int,nd,order,ngaus)
  !     implicit none
  !     ! Parameters
  !     type(interpolation_t), intent(inout) :: int
  !     integer(ip)        , intent(in)    :: nd, order, ngaus
  !     real(rp)           , intent(in)    :: clocs(ngaus)

  !     real(rp)    :: coord(order+1),shpe1(order+1,ngaus),shpd1(order+1,ngaus),shph1(order+1,ngaus)
  !     integer(ip) :: iloc,aux(ngaus)

  !     ! Set the coordenades of the nodal points
  !     call Q_coord_1d(coord,order+1)

  !     ! Compute the 1d shape function on the gauss points
  !     call shape1(clocs,order,ngaus,coord,shpe1,shpd1,shph1,int%khes)

  !     ! Compute the tensorial product
  !     if (int%khes == 1) then
  !        call shapen(int%shape,int%deriv,shpe1,shpd1,shph1,nd,order,ngaus,int%ntens,int%khes,int%hessi)
  !     else
  !        call shapen(int%shape,int%deriv,shpe1,shpd1,shph1,nd,order,ngaus,int%ntens,int%khes)
  !     end if
  !   end subroutine interpolation_local_tp

  ! end subroutine fill_interpolation

  !=================================================================================================
  ! This subroutine gives the reodering (o2n) of the nodes of an vef given an orientation 'o'
  ! and a delay 'r' wrt to a refence element sharing the same vef.
  subroutine  permute_order_vef( this,o2n,p,o,r,nd )
    implicit none
    class(quad_lagrangian_reference_fe_t), intent(in) :: this 
    integer(ip), intent(in)    :: p,o,r,nd
    integer(ip), intent(inout) :: o2n(:)

    if     (nd == 0) then
       o2n(1) = 1
    elseif (nd == 1) then
       call permute_or_1d(o2n(1:p+1),p,r)
    elseif (nd == 2) then
       call permute_or_2d(o2n(1:int((p+1)**2)),p,o,r)
    else
       write(*,*) __FILE__,__LINE__,'WARNING! Permutations not given for nd>3'
    end if
  end subroutine permute_order_vef


  !=================================================================================================
  subroutine  permute_or_1d( o2n,p,r )
    implicit none
    integer(ip), intent(in)    :: p,r
    integer(ip), intent(inout) :: o2n(p+1)

    ! Local variables
    integer(ip) :: i

    ! Generic loop+rotation identifier  
    if (r==1) then
       o2n = (/(i,i=1,p+1)/)
    elseif (r==2) then
       o2n = (/(p+1-i,i=0,p)/)
    else
       write(*,*) __FILE__,__LINE__,'Q_permute_or_1d:: ERROR! Delay cannot be >1 for edges'
    end if
  end subroutine permute_or_1d

  !==================================================================================================
  subroutine permute_or_2d( o2n,p,o,r )
    implicit none
    integer(ip), intent(in)    :: p,o,r
    integer(ip), intent(inout) :: o2n((p+1)**2)

    ! Local variables
    integer(ip) :: o_r,i,j,ij_q(4) ! ij_q = (i,j,p-i,p-j)
    integer(ip) :: ij_n(2),go
    integer(ip) :: ij_perm_quad(2,8) = reshape((/ 1, 2, 2, 3, 4, 1, 3, 4, 2, 1, 3, 2, 1, 4, 4, 3/), &
         &                                     (/2,8/))

    ! Generic loop+rotation identifier
    o_r = 4*o+r
    do j = 0,p
       ij_q(2) = j
       ij_q(4) = p-j
       do i = 0,p
          ij_q(1) = i
          ij_q(3) = p-i
          ! Get the global numbering of node (i,j)
          go = Q_gijk(ij_q(1:2),2,p)
          ! i,j coordinates for the o_r permutation
          ij_n(1:2) = ij_q(ij_perm_quad(1:2,o_r)) 
          ! Get the global numbering of node ij_n
          o2n(go) = Q_gijk(ij_n,2,p)
       end do
    end do
  end subroutine permute_or_2d

end module quad_lagrangian_reference_fe_names

