program test_expand_matrix

USE types_names
USE memor_names
USE serial_names
USE sparse_matrix_names


implicit none

# include "debug.i90"

    type(sparse_matrix_t)       :: sparse_matrix
    integer(ip)                 :: num_rows_and_cols_to_expand = 5
    integer(ip)                 :: nz_to_expand = 5
    integer(ip), allocatable    :: C_T_ia(:)
    integer(ip), allocatable    :: C_T_ja(:)
    real(rp),    allocatable    :: C_T_val(:)
    integer(ip), allocatable    :: I_ia(:)
    integer(ip), allocatable    :: I_ja(:)
    real(rp),    allocatable    :: i_val(:)


    call meminit()

    call memalloc(nz_to_expand, C_T_ia, __FILE__, __LINE__)
    call memalloc(nz_to_expand, C_T_ja, __FILE__, __LINE__)
    call memalloc(nz_to_expand, C_T_val, __FILE__, __LINE__)
    call memalloc(nz_to_expand, I_ia, __FILE__, __LINE__)
    call memalloc(nz_to_expand, I_ja, __FILE__, __LINE__)
    call memalloc(nz_to_expand, i_val, __FILE__, __LINE__)

    C_T_ia = (/1,1,3,5,5/)
    C_T_ja = (/3,4,1,2,5/)
    C_T_val = (/3.0,4.0,1.0,2.0,5.0/)
    I_ia = (/1,1,2,3,3/)
    I_ja = (/2,3,1,1,3/)
    I_val = (/2.0,3.0,1.0,1.0,3.0/)

print*, '!------------------------------------------------------------------'
print*, '! SYMMETRIC STORAGE - NUMERIC'
print*, '!------------------------------------------------------------------'

    call sparse_matrix%create(5, .true., .true., SPARSE_MATRIX_SIGN_UNKNOWN )

    call sparse_matrix%insert(nz=3,          &
                              ia=1,          &
                              ja=(/1,2,3/),  &
                              val=(/1.,2.,3./))
    call sparse_matrix%insert(nz=3,          &
                              ia=2,          &
                              ja=(/2,3,4/),  &
                              val=(/2.,3.,4./))
    call sparse_matrix%insert(nz=3,          &
                              ia=3,          &
                              ja=(/3,4,5/),  &
                              val=(/3.,4.,5./))
    call sparse_matrix%insert(nz=3,          &
                              ia=4,          &
                              ja=(/1,2,3/),  &
                              val=(/1.,2.,3./))
    call sparse_matrix%insert(nz=3,          &
                              ia=5,          &
                              ja=(/3,4,5/),  &
                              val=(/3.,4.,5./))

    call sparse_matrix%convert('CSR')

    call sparse_matrix%print_matrix_market(6)

    call sparse_matrix%expand_matrix_numeric(C_T_nz = nz_to_expand,                      &
                                             C_T_num_cols = num_rows_and_cols_to_expand, &
                                             C_T_ia = C_T_ia,                            &
                                             C_T_ja = C_T_ja,                            &
                                             C_T_val= C_T_val,                           &
                                             I_nz   = nz_to_expand,                      &
                                             I_ia   = I_ia,                              &
                                             I_ja   = I_ja,                              &
                                             I_val  = I_val) 

    call sparse_matrix%print_matrix_market(6)
    call sparse_matrix%free()

print*, '!------------------------------------------------------------------'
print*, '! NON SYMMETRIC STORAGE - NUMERIC'
print*, '!------------------------------------------------------------------'

    call sparse_matrix%create(5, .false., .true., SPARSE_MATRIX_SIGN_UNKNOWN )

    call sparse_matrix%insert(nz=3,          &
                              ia=1,          &
                              ja=(/1,2,3/),  &
                              val=(/1.,2.,3./))
    call sparse_matrix%insert(nz=3,          &
                              ia=2,          &
                              ja=(/2,3,4/),  &
                              val=(/2.,3.,4./))
    call sparse_matrix%insert(nz=3,          &
                              ia=3,          &
                              ja=(/3,4,5/),  &
                              val=(/3.,4.,5./))
    call sparse_matrix%insert(nz=3,          &
                              ia=4,          &
                              ja=(/1,2,3/),  &
                              val=(/1.,2.,3./))
    call sparse_matrix%insert(nz=3,          &
                              ia=5,          &
                              ja=(/3,4,5/),  &
                              val=(/3.,4.,5./))

    call sparse_matrix%convert('CSR')


    call sparse_matrix%expand_matrix_numeric(C_T_nz = nz_to_expand,                      &
                                             C_T_num_cols = num_rows_and_cols_to_expand, &
                                             C_T_ia = C_T_ia,                            &
                                             C_T_ja = C_T_ja,                            &
                                             C_T_val= C_T_val,                           &
                                             I_nz   = nz_to_expand,                      &
                                             I_ia   = I_ia,                              &
                                             I_ja   = I_ja,                              &
                                             I_val  = I_val) 

    call sparse_matrix%print_matrix_market(6)
    call sparse_matrix%free()


print*, '!------------------------------------------------------------------'
print*, '! SYMMETRIC STORAGE - SYMBOLIC'
print*, '!------------------------------------------------------------------'

    call sparse_matrix%create(5, .true., .true., SPARSE_MATRIX_SIGN_UNKNOWN )

    call sparse_matrix%insert(nz=3,          &
                              ia=1,          &
                              ja=(/1,2,3/))
    call sparse_matrix%insert(nz=3,          &
                              ia=2,          &
                              ja=(/2,3,4/))
    call sparse_matrix%insert(nz=3,          &
                              ia=3,          &
                              ja=(/3,4,5/))
    call sparse_matrix%insert(nz=3,          &
                              ia=4,          &
                              ja=(/1,2,3/))
    call sparse_matrix%insert(nz=3,          &
                              ia=5,          &
                              ja=(/3,4,5/))

    call sparse_matrix%convert('CSR')

    call sparse_matrix%expand_matrix_symbolic(C_T_nz = nz_to_expand,                      &
                                              C_T_num_cols = num_rows_and_cols_to_expand, &
                                              C_T_ia = C_T_ia,                            &
                                              C_T_ja = C_T_ja,                            &
                                              I_nz   = nz_to_expand,                      &
                                              I_ia   = I_ia,                              &
                                              I_ja   = I_ja)

    call sparse_matrix%print(6)
    call sparse_matrix%free()


print*, '!------------------------------------------------------------------'
print*, '! NON SYMMETRIC STORAGE - SYMBOLIC'
print*, '!------------------------------------------------------------------'

    call sparse_matrix%create(5, .false., .true., SPARSE_MATRIX_SIGN_UNKNOWN )

    call sparse_matrix%insert(nz=3,          &
                              ia=1,          &
                              ja=(/1,2,3/))
    call sparse_matrix%insert(nz=3,          &
                              ia=2,          &
                              ja=(/2,3,4/))
    call sparse_matrix%insert(nz=3,          &
                              ia=3,          &
                              ja=(/3,4,5/))
    call sparse_matrix%insert(nz=3,          &
                              ia=4,          &
                              ja=(/1,2,3/))
    call sparse_matrix%insert(nz=3,          &
                              ia=5,          &
                              ja=(/3,4,5/))

    call sparse_matrix%convert('CSR')

    call sparse_matrix%expand_matrix_symbolic(C_T_nz = nz_to_expand,                      &
                                              C_T_num_cols = num_rows_and_cols_to_expand, &
                                              C_T_ia = C_T_ia,                            &
                                              C_T_ja = C_T_ja,                            &
                                              I_nz   = nz_to_expand,                      &
                                              I_ia   = I_ia,                              &
                                              I_ja   = I_ja)

    call sparse_matrix%print(6)

    call memfree(C_T_ia, __FILE__, __LINE__)
    call memfree(C_T_ja, __FILE__, __LINE__)
    call memfree(C_T_val, __FILE__, __LINE__)
    call memfree(I_ia, __FILE__, __LINE__)
    call memfree(I_ja, __FILE__, __LINE__)
    call memfree(I_val, __FILE__, __LINE__)
    call sparse_matrix%free()

    call memstatus()

end program
