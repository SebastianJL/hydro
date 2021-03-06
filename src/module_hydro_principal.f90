!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! -*- Mode: F90 -*- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! module_hydro_principal.f90 --- 
!!!!
!! subroutine init_hydro_grid
!! subroutine cmpdt(dt)
!! subroutine godunov(idim,dt)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module hydro_principal

contains

    subroutine init_hydro_grid
        use hydro_commons
        use hydro_const
        use hydro_parameters
        use hydro_mpi_vars
        implicit none

        ! Local variables
        integer(kind = prec_int) :: i, j
        integer(kind = prec_int) :: imin_block, imax_block
        integer(kind = prec_int) :: jmin_block, jmax_block
        integer(kind = prec_int) :: nx_block, ny_block
        integer(kind = prec_int) :: block_density

        ! Indices for entire grid
        imin = 1
        imax = nx + 4
        jmin = 1
        jmax = ny + 4

        ! Indices for process local part of grid
        imin_local = imin
        imax_local = imax
        jmin_local = world_rank*(ny)/world_size + 1
        if (world_rank == world_size - 1) then  ! If last process
            jmax_local = jmax
        else
            jmax_local = world_rank*(ny)/world_size + 4 + (ny)/world_size
        end if

        nx_local = nx
        ny_local = jmax_local - jmin_local - 3

        allocate(uold(imin:imax, jmin_local:jmax_local, 1:nvar))

        ! Initial conditions in grid interior
        ! Warning: conservative variables U = (rho, rhou, rhov, E)

        ! Set grid to plain initial conditions
        do j = jmin_local + 2, jmax_local - 2
            do i = imin + 2, imax - 2
                uold(i, j, ID) = 1.0
                uold(i, j, IU) = 0.0
                uold(i, j, IV) = 0.0
                uold(i, j, IP) = 1.d-5
            end do
        end do

        ! Point explosion
        if (world_rank == 0) then
            uold(imin + 2, jmin_local + 2, IP) = 1./dx/dx
        end if

!        ! Explosion line
!        if (world_rank == world_size - 1) then
!            do i=imin + 2, imax - 2
!                uold(i, jmax_local - 2, IP) = 1./dx/dx
!            end do
!        end if

        ! Put high density block into grid
        nx_block = nx/2
        ny_block = 2*nx_block
        block_density = 100
        imin_block = int(nx/2. - nx_block/2. + 2, kind = prec_int)
        jmin_block = int(ny/2. - ny_block/2. + 2, kind = prec_int)
        imax_block = imin_block + nx_block
        jmax_block = jmin_block + ny_block
        if (jmin_local <= jmin_block .and. jmax_local >= jmax_block) then
            do j = jmin_block, jmax_block
                do i = imin_block, imax_block
                    uold(i, j, ID) = block_density
                end do
            end do
        else if (jmin_local > jmin_block .and. jmax_local >= jmax_block) then
            do j = jmin_local, jmax_block
                do i = imin_block, imax_block
                    uold(i, j, ID) = block_density
                end do
            end do
        else if (jmin_local <= jmin_block .and. jmax_local < jmax_block) then
            do j = jmin_block, jmax_local
                do i = imin_block, imax_block
                    uold(i, j, ID) = block_density
                end do
            end do
        else if (jmin_local > jmin_block .and. jmax_local < jmax_block) then
            do j = jmin_local, jmax_local
                do i = imin_block, imax_block
                    uold(i, j, ID) = block_density
                end do
            end do
        end if
    end subroutine init_hydro_grid


    subroutine cmpdt(dt)
        use hydro_commons
        use hydro_const
        use hydro_parameters
        use hydro_utils
        use hydro_mpi_vars
        use hydro_mpi_datatypes
        use mpi
        implicit none

        ! Dummy arguments
        real(kind = prec_real), intent(out) :: dt
        ! Local variables
        integer(kind = prec_int) :: i, j
        real(kind = prec_real) :: cournox, cournoy, eken, dt_send
        real(kind = prec_real), dimension(:, :), allocatable :: q
        real(kind = prec_real), dimension(:), allocatable :: e, c

        ! compute time step on grid interior
        cournox = zero
        cournoy = zero

        allocate(q(1:nx, 1:IP))
        allocate(e(1:nx), c(1:nx))

        do j = jmin_local + 2, jmax_local - 2

            do i = 1, nx
                q(i, ID) = max(uold(i + 2, j, ID), smallr)
                q(i, IU) = uold(i + 2, j, IU)/q(i, ID)
                q(i, IV) = uold(i + 2, j, IV)/q(i, ID)
                eken = half*(q(i, IU)**2 + q(i, IV)**2)
                q(i, IP) = uold(i + 2, j, IP)/q(i, ID) - eken
                e(i) = q(i, IP)
            end do

            call eos(q(1:nx, ID), e, q(1:nx, IP), c)

            cournox = max(cournox, maxval(c(1:nx) + abs(q(1:nx, IU))))
            cournoy = max(cournoy, maxval(c(1:nx) + abs(q(1:nx, IV))))

        end do

        deallocate(q, e, c)

        dt_send = courant_factor*dx/max(cournox, cournoy, smallc)
        call mpi_allreduce(dt_send, dt, 1, prec_real_mpi_datatype, mpi_min, mpi_comm_world, ierror)
    end subroutine cmpdt


    subroutine godunov(idim, dt)
        use hydro_commons
        use hydro_const
        use hydro_parameters
        use hydro_utils
        use hydro_work_space
        implicit none

        ! Dummy arguments
        integer(kind = prec_int), intent(in) :: idim
        real(kind = prec_real), intent(in) :: dt
        ! Local variables
        integer(kind = prec_int) :: i, j, in
        real(kind = prec_real) :: dtdx


        ! constant
        dtdx = dt/dx

        ! Update boundary conditions
        call make_boundary(idim)

        call exchange_ghost_cells(idim)

        if (idim==1)then

            ! Allocate work space for 1D sweeps
            call allocate_work_space(imin, imax, nx + 1)

            do j = jmin_local + 2, jmax_local - 2

                ! Gather conservative variables
                do i = imin, imax
                    u(i, ID) = uold(i, j, ID)
                    u(i, IU) = uold(i, j, IU)
                    u(i, IV) = uold(i, j, IV)
                    u(i, IP) = uold(i, j, IP)
                end do
                if(nvar>4)then
                    do in = 5, nvar
                        do i = imin, imax
                            u(i, in) = uold(i, j, in)
                        end do
                    end do
                end if

                ! Convert to primitive variables
                call constoprim(u, q, c)

                ! Characteristic tracing
                call trace(q, dq, c, qxm, qxp, dtdx)

                do in = 1, nvar
                    do i = 1, nx + 1
                        qleft (i, in) = qxm(i + 1, in)
                        qright(i, in) = qxp(i + 2, in)
                    end do
                end do

                ! Solve Riemann problem at interfaces
                call riemann(qleft, qright, qgdnv, &
                        & rl, ul, pl, cl, wl, rr, ur, pr, cr, wr, ro, uo, po, co, wo, &
                        & rstar, ustar, pstar, cstar, sgnm, spin, spout, &
                        & ushock, frac, scr, delp, pold, ind, ind2)

                ! Compute fluxes
                call cmpflx(qgdnv, flux)

                ! Update conservative variables
                do i = imin + 2, imax - 2
                    uold(i, j, ID) = u(i, ID) + (flux(i - 2, ID) - flux(i - 1, ID))*dtdx
                    uold(i, j, IU) = u(i, IU) + (flux(i - 2, IU) - flux(i - 1, IU))*dtdx
                    uold(i, j, IV) = u(i, IV) + (flux(i - 2, IV) - flux(i - 1, IV))*dtdx
                    uold(i, j, IP) = u(i, IP) + (flux(i - 2, IP) - flux(i - 1, IP))*dtdx
                end do
                if(nvar>4)then
                    do in = 5, nvar
                        do i = imin + 2, imax - 2
                            uold(i, j, in) = u(i, in) + (flux(i - 2, in) - flux(i - 1, in))*dtdx
                        end do
                    end do
                end if

            end do

            ! Deallocate work space
            call deallocate_work_space()

        else

            ! Allocate work space for 1D sweeps
            call allocate_work_space(jmin_local, jmax_local, ny_local + jmin_local)

            do i = imin + 2, imax - 2

                ! Gather conservative variables
                do j = jmin_local, jmax_local
                    u(j, ID) = uold(i, j, ID)
                    u(j, IU) = uold(i, j, IV)
                    u(j, IV) = uold(i, j, IU)
                    u(j, IP) = uold(i, j, IP)
                end do
                if(nvar>4)then
                    do in = 5, nvar
                        do j = jmin_local, jmax_local
                            u(j, in) = uold(i, j, in)
                        end do
                    end do
                end if

                ! Convert to primitive variables
                call constoprim(u, q, c)

                ! Characteristic tracing
                call trace(q, dq, c, qxm, qxp, dtdx)

                do in = 1, nvar
                    do j = jmin_local, jmin_local + ny_local
                        qleft (j, in) = qxm(j + 1, in)
                        qright(j, in) = qxp(j + 2, in)
                    end do
                end do

                ! Solve Riemann problem at interfaces
                call riemann(qleft, qright, qgdnv, &
                        & rl, ul, pl, cl, wl, rr, ur, pr, cr, wr, ro, uo, po, co, wo, &
                        & rstar, ustar, pstar, cstar, sgnm, spin, spout, &
                        & ushock, frac, scr, delp, pold, ind, ind2)

                ! Compute fluxes
                call cmpflx(qgdnv, flux)

                ! Update conservative variables
                do j = jmin_local + 2, jmax_local - 2
                    uold(i, j, ID) = u(j, ID) + (flux(j - 2, ID) - flux(j - 1, ID))*dtdx
                    uold(i, j, IU) = u(j, IV) + (flux(j - 2, IV) - flux(j - 1, IV))*dtdx
                    uold(i, j, IV) = u(j, IU) + (flux(j - 2, IU) - flux(j - 1, IU))*dtdx
                    uold(i, j, IP) = u(j, IP) + (flux(j - 2, IP) - flux(j - 1, IP))*dtdx
                end do
                if(nvar>4)then
                    do in = 5, nvar
                        do j = jmin_local + 2, jmax_local - 2
                            uold(i, j, in) = u(j, in) + (flux(j - 2, in) - flux(j - 1, in))*dtdx
                        end do
                    end do
                end if

            end do

            ! Deallocate work space
            call deallocate_work_space()

        end if
    end subroutine godunov

end module hydro_principal


