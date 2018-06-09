!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! -*- Mode: F90 -*- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! module_hydro_common.f90 ---
!!!!
!! module hydro_precision
!! module hydro_commons
!! module hydro_parameters 
!! module hydro_const
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module hydro_precision
    integer, parameter :: prec_real = kind(1.d0)
    integer, parameter :: prec_int = 4
    integer, parameter :: prec_output = 4
end module hydro_precision

module hydro_commons
    use hydro_precision
    integer(kind = prec_int) :: imin, imax, jmin, jmax  ! Global grid indices
    integer :: imin_local, imax_local, jmin_local, jmax_local  ! Grid indices local to process
    integer :: nx_local, ny_local  ! Local gridsize without ghost cells
    real(kind = prec_real), allocatable, dimension(:, :, :) :: uold  ! Grid
    real(kind = prec_real) :: t = 0.
    integer(kind = prec_int) :: nstep = 0
    integer(kind = prec_int) :: nout = 0
    character(LEN = 1000) :: output_directory, timestamp
end module hydro_commons

module hydro_mpi_vars
    use hydro_precision
    integer(kind = prec_int) :: world_rank, world_size, ierror  ! common mpi variables
    integer(kind = prec_int), parameter :: master = 0
    enum, bind(c)
        enumerator :: boundary_tag
    end enum
end module hydro_mpi_vars

module hydro_command_arguments
    enum, bind(c)
        enumerator :: arg_in = 1
        enumerator :: arg_out = 2
    end enum
end module hydro_command_arguments

module hydro_parameters
    use hydro_precision
    integer(kind = prec_int) :: nx = 2
    integer(kind = prec_int) :: ny = 2
    integer(kind = prec_int) :: nvar = 4
    real(kind = prec_real) :: dx = 1.0
    real(kind = prec_real) :: tend = 0.0
    real(kind = prec_real) :: gamma = 1.4d0
    real(kind = prec_real) :: courant_factor = 0.5d0
    real(kind = prec_real) :: smallc = 1.d-10
    real(kind = prec_real) :: smallr = 1.d-10
    integer(kind = prec_int) :: niter_riemann = 10
    integer(kind = prec_int) :: iorder = 2
    real(kind = prec_real) :: slope_type = 1.
    real(kind = prec_real) :: t_rate = 1./10
    character(LEN = 20) :: scheme = 'muscl'
    integer(kind = prec_int) :: boundary_right = 1
    integer(kind = prec_int) :: boundary_left = 1
    integer(kind = prec_int) :: boundary_down = 1
    integer(kind = prec_int) :: boundary_up = 1
    integer(kind = prec_int) :: noutput = 100
    integer(kind = prec_int) :: nstepmax = 1000000
end module hydro_parameters

module hydro_mpi_datatypes
    use hydro_precision
    use hydro_mpi_vars
    use mpi
    integer :: prec_real_mpi_datatype
    integer :: lower_send_row, lower_recv_row
    integer :: upper_send_row, upper_recv_row

    contains
        subroutine init_mpi_datatypes
            use hydro_commons
            use hydro_parameters
            integer :: ndims = rank(uold)
            integer, dimension(:), allocatable :: sizes, subsizes, starts

!            allocate(sizes(ndims))
!            allocate(subsizes(ndims))
!            allocate(starts(ndims))
!
!            ! Create mpi_datatypes for sending and receiving ghost cells
!            sizes = [nx, ny, nvar]
!            subsizes = [nx, 2, nvar]
!
!            ! Lower send/recv rows
!            starts = [0, jmin_local + 2 - 1, 0]  ! Array indexing starting at 0 for mpi
!            call mpi_type_create_subarray(ndims, sizes, subsizes, starts, mpi_order_fortran, mpi_integer, &
!                    lower_send_row, ierror)
!            starts = [0, jmin_local - 1, 0]  ! Array indexing starting at 0 for mpi
!            call mpi_type_create_subarray(ndims, sizes, subsizes, starts, mpi_order_fortran, mpi_integer, &
!                    lower_recv_row, ierror)
!
!            ! Upper send/recv rows
!            starts = [0, jmax_local - 3 - 1, 0]  ! Array indexing starting at 0 for mpi
!            call mpi_type_create_subarray(ndims, sizes, subsizes, starts, mpi_order_fortran, mpi_integer, &
!                    upper_send_row, ierror)
!            starts = [0, jmax_local - 1 - 1, 0]  ! Array indexing starting at 0 for mpi
!            call mpi_type_create_subarray(ndims, sizes, subsizes, starts, mpi_order_fortran, mpi_integer, &
!                    upper_recv_row, ierror)
!
!            call mpi_type_commit(lower_send_row, ierror)
!            call mpi_type_commit(lower_recv_row, ierror)
!            call mpi_type_commit(upper_send_row, ierror)
!            call mpi_type_commit(upper_recv_row, ierror)

            ! prec_real as mpi_datatype
            call mpi_type_match_size(mpi_typeclass_real, prec_real, prec_real_mpi_datatype, ierror)
        end subroutine init_mpi_datatypes

        subroutine free_mpi_datatypes
            call mpi_type_free(lower_recv_row, ierror)
            call mpi_type_free(lower_send_row, ierror)
            call mpi_type_free(upper_send_row, ierror)
            call mpi_type_free(upper_recv_row, ierror)
        end subroutine free_mpi_datatypes
end module hydro_mpi_datatypes

module hydro_const
    ! This is used so that "zero" always has the precision 'prec_real'.
    ! Otherwise one would write 0, 0.0 or 0.0d0 which are all different
    ! precisions.
    use hydro_precision
    real(kind = prec_real) :: zero = 0.0
    real(kind = prec_real) :: one = 1.0
    real(kind = prec_real) :: two = 2.0
    real(kind = prec_real) :: three = 3.0
    real(kind = prec_real) :: four = 4.0
    real(kind = prec_real) :: two3rd = 0.6666666666666667d0
    real(kind = prec_real) :: half = 0.5
    real(kind = prec_real) :: third = 0.33333333333333333d0
    real(kind = prec_real) :: forth = 0.25
    real(kind = prec_real) :: sixth = 0.16666666666666667d0
    integer(kind = prec_int) :: ID = 1
    integer(kind = prec_int) :: IU = 2
    integer(kind = prec_int) :: IV = 3
    integer(kind = prec_int) :: IP = 4
end module hydro_const

module hydro_work_space
    use hydro_precision
    use hydro_parameters

    ! Work arrays
    real(kind = prec_real), dimension(:, :), pointer :: u, q, qxm, qxp, dq, qleft, qright, qgdnv, flux
    real(kind = prec_real), dimension(:), pointer :: c
    real(kind = prec_real), dimension(:), pointer :: rl, ul, pl, cl, wl
    real(kind = prec_real), dimension(:), pointer :: rr, ur, pr, cr, wr
    real(kind = prec_real), dimension(:), pointer :: ro, uo, po, co, wo
    real(kind = prec_real), dimension(:), pointer :: rstar, ustar, pstar, cstar
    real(kind = prec_real), dimension(:), pointer :: sgnm, spin, spout, ushock
    real(kind = prec_real), dimension(:), pointer :: frac, scr, delp, pold
    integer(kind = prec_int), dimension(:), pointer :: ind, ind2
    !$OMP THREADPRIVATE(u,q,qxm,qxp,dq,qleft,qright,qgdnv,flux, &
    !$OMP c,rl,ul,pl,cl,wl,rr,ur,pr,cr,wr,ro,uo,po,co,wo,ind,ind2, &
    !$OMP rstar,ustar,pstar,cstar,sgnm,spin,spout,ushock,frac,scr,delp,pold)

contains

    subroutine allocate_work_space(ii1, ii2, ngrid)
        implicit none

        ! Dummy arguments
        integer(kind = prec_int), intent(in) :: ii1, ii2, ngrid

        allocate(u  (ii1:ii2, 1:nvar))
        allocate(q  (ii1:ii2, 1:nvar))
        allocate(dq (ii1:ii2, 1:nvar))
        allocate(qxm(ii1:ii2, 1:nvar))
        allocate(qxp(ii1:ii2, 1:nvar))
        allocate(c  (ii1:ii2))
        allocate(qleft (ii1:ngrid, 1:nvar))
        allocate(qright(ii1:ngrid, 1:nvar))
        allocate(qgdnv (ii1:ngrid, 1:nvar))
        allocate(flux  (ii1:ngrid, 1:nvar))
        allocate(rl    (ii1:ngrid), ul   (ii1:ngrid), pl   (ii1:ngrid), cl    (ii1:ngrid))
        allocate(rr    (ii1:ngrid), ur   (ii1:ngrid), pr   (ii1:ngrid), cr    (ii1:ngrid))
        allocate(ro    (ii1:ngrid), uo   (ii1:ngrid), po   (ii1:ngrid), co    (ii1:ngrid))
        allocate(rstar (ii1:ngrid), ustar(ii1:ngrid), pstar(ii1:ngrid), cstar (ii1:ngrid))
        allocate(wl    (ii1:ngrid), wr   (ii1:ngrid), wo   (ii1:ngrid))
        allocate(sgnm  (ii1:ngrid), spin (ii1:ngrid), spout(ii1:ngrid), ushock(ii1:ngrid))
        allocate(frac  (ii1:ngrid), scr  (ii1:ngrid), delp (ii1:ngrid), pold  (ii1:ngrid))
        allocate(ind   (ii1:ngrid), ind2 (ii1:ngrid))
    end subroutine allocate_work_space

    subroutine deallocate_work_space()
        deallocate(u, q, dq, qxm, qxp, c, qleft, qright, qgdnv, flux)
        deallocate(rl, ul, pl, cl)
        deallocate(rr, ur, pr, cr)
        deallocate(ro, uo, po, co)
        deallocate(rstar, ustar, pstar, cstar)
        deallocate(wl, wr, wo)
        deallocate(sgnm, spin, spout, ushock)
        deallocate(frac, scr, delp, pold)
        deallocate(ind, ind2)
    end subroutine deallocate_work_space
end module hydro_work_space
