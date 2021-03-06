!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! -*- Mode: F90 -*- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! module_hydro_IO.f90 ---
!!!!
!! subroutine read_params
!! subroutine prepare_output_directory
!! subroutine output
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module hydro_IO
    character(LEN = 1000) :: infile

contains

    subroutine read_params
        use hydro_parameters
        use hydro_command_arguments
        implicit none

        ! Local variables
        integer(kind = prec_int) :: narg, iargc
        integer :: status

        ! Namelists
        namelist/run/nstepmax, tend, noutput, t_rate
        namelist/mesh/nx, ny, dx, boundary_left, boundary_right, boundary_down, boundary_up
        namelist/hydro/gamma, courant_factor, smallr, smallc, niter_riemann, &
                &         iorder, scheme, slope_type

        call get_command_argument(arg_in, infile, status=status)
        if (.not. status==0) then
            infile = "../input/input.nml"
        end if
        open(1, file = infile)
        read(1, NML = run)
        read(1, NML = mesh)
        read(1, NML = hydro)
        close(1)
    end subroutine read_params

    subroutine prepare_output_directory
        use hydro_commons
        use hydro_parameters
        use hydro_command_arguments
        use hydro_mpi_vars
        use mpi

        ! Local variables
        character(LEN = 5) :: char_nx, char_ny, char_ncpu
        character(LEN = 8) :: date
        character(LEN = 10) :: time
        character(LEN = 5) :: zone
        character(LEN = 100) :: command
        integer :: status

        call DATE_AND_TIME(date = date, time = time, zone = zone)
        timestamp = '-' // date &
                // '-' // time &
                // '-' // zone

        ! Retrieve output directory from command line if given else create.
        call get_command_argument(arg_out, output_directory, status=status)
        do while (.not. status == 0)
            call title(world_size, char_ncpu)
            call title(nx, char_nx)
            call title(ny, char_ny)
            output_directory = '../output/output' &
                    // trim(timestamp) &
                    // '-ncpu:' // TRIM(char_ncpu) &
                    // '-nx:' // TRIM(char_nx) &
                    // '-ny:' // TRIM(char_ny) &
                    // '/'
            command = 'mkdir ' // TRIM(output_directory)
            call execute_command_line(command, wait=.true., exitstat=status)
        end do
        call unix_directory(output_directory)
        command = 'cp ' // TRIM(infile) // ' ' // TRIM(output_directory)
        call execute_command_line(command)
    end subroutine prepare_output_directory

    subroutine output
        use hydro_commons
        use hydro_parameters
        use hydro_mpi_vars
        implicit none

        ! Local variables
        character(LEN = 1000) :: filename
        character(LEN = 5) :: char, charpe
!        integer(kind = prec_int) :: nout

!        nout = nstep/noutput
        call title(nout, char)
        call title(world_rank, charpe)
        filename = TRIM(output_directory) // 'output_' // TRIM(char) // '.' // TRIM(charpe)
        open(10, file = filename, form = 'unformatted')
        rewind(10)
!        print*, 'Process ', world_rank, 'outputting array of size=', nx_local, ny_local, nvar
        write(10)real(t, kind = prec_output), real(gamma, kind = prec_output)
        write(10)nx_local, ny_local, nvar, nstep
        write(10)real(uold(imin + 2:imax - 2, jmin_local + 2:jmax_local - 2, 1:nvar), kind = prec_output)
        close(10)
    end subroutine output

    subroutine title(n, nchar)
        use hydro_precision
        implicit none

        integer(kind = prec_int) :: n
        character(LEN = 5) :: nchar
        character(LEN = 1) :: nchar1
        character(LEN = 2) :: nchar2
        character(LEN = 3) :: nchar3
        character(LEN = 4) :: nchar4
        character(LEN = 5) :: nchar5

        if (n >= 10000) then
            write(nchar5, '(i5)') n
            nchar = nchar5
        elseif (n >= 1000) then
            write(nchar4, '(i4)') n
            nchar = '0' // nchar4
        elseif (n >= 100) then
            write(nchar3, '(i3)') n
            nchar = '00' // nchar3
        elseif (n >= 10) then
            write(nchar2, '(i2)') n
            nchar = '000' // nchar2
        else
            write(nchar1, '(i1)') n
            nchar = '0000' // nchar1
        endif
    end subroutine title

    subroutine unix_directory(dir)
        use hydro_precision
        implicit none

        ! Dummy variables
        character(len = *), intent(inout) :: dir
        ! Local variables
        integer(kind = prec_int) :: l

        l = len(trim(dir))
        if (.not. dir(l:l) == '/') then
            dir = trim(dir) // '/'
        end if
    end subroutine unix_directory

!    function convert_seconds_to_string(total) result(time)
!        use hydro_precision
!        implicit none
!
!        ! Dummy variables
!        real(kind=prec_real) :: total
!        character(len = *) :: time
!        ! Local variables
!        integer(kind = prec_int) :: hour, minute
!        real(kind = prec_real) :: second
!
!        hour = int(total / 3600)              ! 3600 secs/hour
!        minute = int((total - 3600*hour) / 60.)
!        second =  total - 3600*hour - 60*minute
!
!        write(time, '(I2, I2, F7.4)') hour, minute, second
!    end function convert_seconds_to_string

end module hydro_IO
