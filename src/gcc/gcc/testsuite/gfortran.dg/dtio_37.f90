! { dg-do run }
! { dg-additional-options "-O2" }
!
! PR fortran/125059 - derived type IO and automatic deallocation
! PR fortran/111952

module m
  type t
     integer :: i = 42
   contains
     procedure :: w
     generic :: write(formatted) => w
  end type t
contains
  subroutine w(dtv,unit,iotype,v_list,iostat,iomsg)
    class(t),        intent(in)    :: dtv
    integer,         intent(in)    :: unit
    character(len=*),intent(in)    :: iotype
    integer,         intent(in)    :: v_list(:)
    integer,         intent(out)   :: iostat
    character(len=*),intent(inout) :: iomsg
    write(unit,*,iostat=iostat,iomsg=iomsg) dtv%i
  end subroutine w
end

program p
  use m
  call f()
  call f()
contains
  subroutine f()
    type(t), allocatable :: a(:)
    allocate (a(1))
    print *, a(1)
  end subroutine f
end
