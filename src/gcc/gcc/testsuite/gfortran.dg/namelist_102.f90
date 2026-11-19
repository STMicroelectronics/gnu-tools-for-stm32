! { dg-do run }
! { dg-additional-options "-O2" }
!
! PR fortran/125095 - test namelist read with comments
!
! Based on testcases by Andy Nelson and Steven G. Kargl

program nmlbug
  implicit none
  call test_int
  call test_real
  call test_complex
  call test_logical
  call test_char

contains

  subroutine test_int

    integer :: array(4), barray(4), carray(4), darray(4)

    namelist/nml1/  array
    namelist/nml2/ barray
    namelist/nml3/ carray
    namelist/nml4/ darray

    open(10,status='scratch')
    write(10,'(A)') '&nml1'
    write(10,'(A)') '  array = 1, 2, 3, 4,'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml2'
    write(10,'(A)') '  barray = 5,    ! comment'
    write(10,'(A)') '           6,'
    write(10,'(A)') '           7     ! another comment'
    write(10,'(A)') '           8,'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml3'
    write(10,'(A)') '  carray =  9     ! New comment'
    write(10,'(A)') '           10'
    write(10,'(A)') '           11     ! another new comment'
    write(10,'(A)') '           12'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml4'
    write(10,'(A)') '  darray = 13, 14, 15, 16,'
    write(10,'(A)') '/'
    flush(10)
    rewind(10)

    read(10,nml1)
    if (any( array /= [ 1,  2,  3,  4])) stop 1
    read(10,nml2)
    if (any(barray /= [ 5,  6,  7,  8])) stop 2
    read(10,nml3)
    if (any(carray /= [ 9, 10, 11, 12])) stop 3
    read(10,nml4)
    if (any(darray /= [13, 14, 15, 16])) stop 4
    close(10)

  end subroutine test_int

  subroutine test_real

    real :: array(4), barray(4), carray(4), darray(4)

    namelist/nml1/  array
    namelist/nml2/ barray
    namelist/nml3/ carray
    namelist/nml4/ darray

    open(10,status='scratch')
    write(10,'(A)') '&nml1'
    write(10,'(A)') '  array = 1, 2, 3, 4,'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml2'
    write(10,'(A)') '  barray = 5,    ! comment'
    write(10,'(A)') '           6,'
    write(10,'(A)') '           7     ! another comment'
    write(10,'(A)') '           8,'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml3'
    write(10,'(A)') '  carray =  9     ! New comment'
    write(10,'(A)') '           10'
    write(10,'(A)') '           11     ! another new comment'
    write(10,'(A)') '           12'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml4'
    write(10,'(A)') '  darray = 13, 14, 15, 16,'
    write(10,'(A)') '/'
    flush(10)
    rewind(10)

    read(10,nml1)
    if (any( array /= [ 1,  2,  3,  4])) stop 1
    read(10,nml2)
    if (any(barray /= [ 5,  6,  7,  8])) stop 2
    read(10,nml3)
    if (any(carray /= [ 9, 10, 11, 12])) stop 3
    read(10,nml4)
    if (any(darray /= [13, 14, 15, 16])) stop 4
    close(10)

  end subroutine test_real

  subroutine test_complex

    complex :: array(4), barray(4), carray(4), darray(4)

    namelist/nml1/  array
    namelist/nml2/ barray
    namelist/nml3/ carray
    namelist/nml4/ darray

    open(10,status='scratch')
    write(10,'(A)') '&nml1'
    write(10,'(A)') '  array = (1,0), (2,0), (3,0), (4,0),'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml2'
    write(10,'(A)') '  barray = (5,0),    ! comment'
    write(10,'(A)') '           (6,0),'
    write(10,'(A)') '           (7,0)     ! another comment'
    write(10,'(A)') '           (8,0),'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml3'
    write(10,'(A)') '  carray =  (9,0)     ! New comment'
    write(10,'(A)') '           (10,0)'
    write(10,'(A)') '           (11,0)     ! another new comment'
    write(10,'(A)') '           (12,0)'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml4'
    write(10,'(A)') '  darray = (13,0), (14,0), (15,0), (16,0),'
    write(10,'(A)') '/'
    flush(10)
    rewind(10)

    read(10,nml1)
    if (any( array /= [ 1,  2,  3,  4])) stop 1
    read(10,nml2)
    if (any(barray /= [ 5,  6,  7,  8])) stop 2
    read(10,nml3)
    if (any(carray /= [ 9, 10, 11, 12])) stop 3
    read(10,nml4)
    if (any(darray /= [13, 14, 15, 16])) stop 4
    close(10)

  end subroutine test_complex

  subroutine test_logical

    logical :: array(4), barray(4), carray(4), darray(4)

    namelist/nml1/  array
    namelist/nml2/ barray
    namelist/nml3/ carray
    namelist/nml4/ darray

    open(10,status='scratch')
    write(10,'(A)') '&nml1'
    write(10,'(A)') '  array = T,F,F,T'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml2'
    write(10,'(A)') '  barray = T,    ! comment'
    write(10,'(A)') '           F,'
    write(10,'(A)') '           F     ! another comment'
    write(10,'(A)') '           T,'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml3'
    write(10,'(A)') '  carray =  T     ! New comment'
    write(10,'(A)') '            F'
    write(10,'(A)') '            F     ! another new comment'
    write(10,'(A)') '            T'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml4'
    write(10,'(A)') '  darray =  T,F,F,T'
    write(10,'(A)') '/'
    flush(10)
    rewind(10)

    read(10,nml1)
    if (any( array .neqv. [ .true.,.false.,.false.,.true. ])) stop 1
    read(10,nml2)
    if (any(barray .neqv. [ .true.,.false.,.false.,.true. ])) stop 2
    read(10,nml3)
    if (any(carray .neqv. [ .true.,.false.,.false.,.true. ])) stop 3
    read(10,nml4)
    if (any(darray .neqv. [ .true.,.false.,.false.,.true. ])) stop 4
    close(10)

  end subroutine test_logical

  subroutine test_char

    character(8) :: array(4), barray(4), carray(4), darray(4)

    namelist/nml1/  array
    namelist/nml2/ barray
    namelist/nml3/ carray
    namelist/nml4/ darray

    open(10,status='scratch')
    write(10,'(A)') '&nml1'
    write(10,'(A)') '  array = "a", "b", "c", "d",'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml2'
    write(10,'(A)') '  barray = "a",    ! comment'
    write(10,'(A)') '           "b",'
    write(10,'(A)') '           "c"     ! another comment'
    write(10,'(A)') '           "d",'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml3'
    write(10,'(A)') '  carray = "a"     ! New comment'
    write(10,'(A)') '           "b"'
    write(10,'(A)') '           "c"     ! another new comment'
    write(10,'(A)') '           "d"'
    write(10,'(A)') '/'
    write(10,*)
    write(10,'(A)') '&nml4'
    write(10,'(A)') '  darray = "a", "b", "c", "d",'
    write(10,'(A)') '/'
    flush(10)
    rewind(10)

    read(10,nml1)
    if (any( array /= [ "a", "b", "c", "d" ])) stop 1
    read(10,nml2)
    if (any(barray /= [ "a", "b", "c", "d" ])) stop 2
    read(10,nml3)
    if (any(carray /= [ "a", "b", "c", "d" ])) stop 3
    read(10,nml4)
    if (any(darray /= [ "a", "b", "c", "d" ])) stop 4
    close(10)

  end subroutine test_char

end program nmlbug
