!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! -*- Mode: F90 -*- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! main.f90 ---
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

program hydro_main
    use hydro_commons
    use hydro_parameters
    use hydro_IO
    use hydro_principal
    use hydro_mpi_vars
    use hydro_mpi_datatypes
    use mpi
    implicit none

    real(kind = prec_real) :: dt, wtime, tps_cpu, t_start, t_end
    integer(kind = prec_int) :: nbp_init, nbp_final, nbp_max, freq_p

    ! Inititialize
    call mpi_init(ierror)
    call mpi_comm_size(mpi_comm_world, world_size, ierror)
    call mpi_comm_rank(mpi_comm_world, world_rank, ierror)

    call system_clock(count_rate = freq_p, count_max = nbp_max)
    call system_clock(nbp_init)
    call cpu_time(t_start)

    call read_params

    if (world_rank == master) then
        call prepare_output_directory
    end if
    call mpi_bcast(output_directory, len(output_directory), mpi_character, master, mpi_comm_world, ierror)

!    call init_mpi_datatypes

    call init_hydro_grid


    ! Main time loop
    print*, 'Starting time integration, nx = ', nx, ' ny = ', ny
    do while (t < tend .and. nstep < nstepmax)

        ! Output results
        if(MOD(nstep, noutput)==0)then
            call output
        end if

        ! Compute new time-step
        if(MOD(nstep, 2)==0)then
            call cmpdt(dt)
            if(nstep==0)dt = dt/2.
        endif

        ! Directional splitting
        if(MOD(nstep, 2)==0)then
            call godunov(1, dt)
            call godunov(2, dt)
        else
            call godunov(2, dt)
            call godunov(1, dt)
        end if

        nstep = nstep + 1
        t = t + dt
        write(*, '("step=",I6," t=",1pe10.3," dt=",1pe10.3)')nstep, t, dt

    end do

    ! Final output
    call output

    ! Timing
    call cpu_time(t_end)
    tps_cpu = t_end - t_start
    call mpi_barrier(mpi_comm_world, ierror)
    call system_clock(nbp_final)
    if (nbp_final>nbp_init) then
        wtime = real(nbp_final - nbp_init)/real(freq_p)
    else
        wtime = real(nbp_final - nbp_init + nbp_max)/real(freq_p)
    endif

    write(*, "(A, I04, A, F7.4)") 'CPU ', world_rank, ' Time [s]     : ', tps_cpu
    call mpi_barrier(mpi_comm_world, ierror)
    if (world_rank == master) then
        write(*, "(A, F7.4)") 'Walltime [s]          : ', wtime
    end if

    call mpi_finalize(ierror)

end program hydro_main
