!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! -*- Mode: F90 -*- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! module_hydro_IO.f90 ---
!!!!
!! subroutine read_params
!! subroutine prepare_output_directory
!! subroutine output
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module hydro_IO
    character(LEN = 80) :: infile

contains

    subroutine read_params
        use hydro_parameters
        implicit none

        ! Local variables
        integer(kind = prec_int) :: narg, iargc

        ! Namelists
        namelist/run/nstepmax, tend, noutput
        namelist/mesh/nx, ny, dx, boundary_left, boundary_right, boundary_down, boundary_up
        namelist/hydro/gamma, courant_factor, smallr, smallc, niter_riemann, &
                &         iorder, scheme, slope_type

        infile = "../input/input.nml"
        open(1, file = infile)
        read(1, NML = run)
        read(1, NML = mesh)
        read(1, NML = hydro)
        close(1)
    end subroutine read_params

    subroutine prepare_output_directory
        use hydro_commons
        use hydro_parameters
        use hydro_mpi_vars
        use mpi

        ! Local variables
        character(LEN = 5) :: char_nx, char_ny
        character(LEN = 8) :: date
        character(LEN = 10) :: time
        character(LEN = 5) :: zone
        character(LEN = 100) :: command
        integer :: status

        status = 1
        do while (.not. status == 0)
            call DATE_AND_TIME(date = date, time = time, zone = zone)
            call title(nx, char_nx)
            call title(ny, char_ny)
            output_directory = '../output/output' &
                    // '-nx' // TRIM(char_nx) &
                    // '-ny' // TRIM(char_ny) &
                    // '-' // date &
                    // '-' // time &
                    // '-' // zone &
                    // '/'
            command = 'mkdir ' // TRIM(output_directory)
            call execute_command_line(command, wait=.true., exitstat=status)
        end do
        command = 'cp ' // TRIM(infile) // ' ' // TRIM(output_directory)
        call execute_command_line(command)
    end subroutine prepare_output_directory

    subroutine output
        use hydro_commons
        use hydro_parameters
        use hydro_mpi_vars
        implicit none

        ! Local variables
        character(LEN = 80) :: filename
        character(LEN = 5) :: char, charpe
        integer(kind = prec_int) :: nout

        nout = nstep/noutput
        call title(nout, char)
        call title(world_rank, charpe)
        filename = TRIM(output_directory) // 'output_' // TRIM(char) // '.' // TRIM(charpe)
        open(10, file = filename, form = 'unformatted')
        rewind(10)
        print*, 'Process ', world_rank, 'outputting array of size=', nx_local, ny_local, nvar
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

end module hydro_IO
