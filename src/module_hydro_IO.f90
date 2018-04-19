!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! -*- Mode: F90 -*- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! module_hydro_IO.f90 ---
!!!!
!! subroutine read_params
!! subroutine prepare_output_directory
!! subroutine output
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module hydro_IO

contains

    subroutine read_params
        use hydro_parameters
        implicit none

        ! Local variables
        integer(kind = prec_int) :: narg, iargc
        character(LEN = 80) :: infile

        ! Namelists
        namelist/run/nstepmax, tend, noutput
        namelist/mesh/nx, ny, dx, boundary_left, boundary_right, boundary_down, boundary_up
        namelist/hydro/gamma, courant_factor, smallr, smallc, niter_riemann, &
                &         iorder, scheme, slope_type

        !   narg = iargc()
        !   IF(narg .NE. 1)THEN
        !      write(*,*)'You should type: a.out input.nml'
        !      write(*,*)'File input.nml should contain a parameter namelist'
        !      STOP
        !   END IF
        !   CALL getarg(1,infile)
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

        call DATE_AND_TIME(date = date, time = time, zone = zone)
        call title(nx, char_nx)
        call title(ny, char_ny)
        output_directory = '../output/output' &
                // '-' // date &
                // '-' // time &
                // '-' // zone &
                // '-nx' // TRIM(char_nx) &
                // '-ny' // TRIM(char_ny) &
                // '/'
        call SYSTEM('mkdir' // ' ' // TRIM(output_directory))
        call SYSTEM('cp ../input/input.nml ' // TRIM(output_directory))
    end subroutine prepare_output_directory

    subroutine output
        use hydro_commons
        use hydro_parameters
        use hydro_mpi_vars
        implicit none

        ! Local variables
        character(LEN = 80) :: filename
        character(LEN = 5) :: char, charpe
        integer(kind = prec_int) :: nout, y_width

        y_width = jmax_local - jmin_local - 3

        nout = nstep/noutput
        call title(nout, char)
        call title(world_rank, charpe)
        filename = TRIM(output_directory) // 'output_' // TRIM(char) // '.' // TRIM(charpe)
        open(10, file = filename, form = 'unformatted')
        rewind(10)
        print*, 'Process ', world_rank, 'outputting array of size=', nx, y_width, nvar
        write(10)real(t, kind = prec_output), real(gamma, kind = prec_output)
        write(10)nx, y_width, nvar, nstep
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
