using Test
using AstroFITS
using FITSexplore

@testset "FITSexplore CLI regressions" begin
    tmpdir = mktempdir()
    fits_path = joinpath(tmpdir, "sample.fits")

    # Build a minimal FITS file with one image HDU.
    writefits!(fits_path, FitsHeader(), reshape(collect(1:4), 2, 2); overwrite = true)
    fits_path_rel = relpath(fits_path, pwd())

    bad_fits_path = joinpath(tmpdir, "broken.fits")
    write(bad_fits_path, "THIS IS NOT A VALID FITS HEADER")

    @testset "--hdu prints selected headers" begin
        @test_nowarn FITSexplore.main(["--hdu", "1", fits_path])
    end

    @testset "numeric filter rejects invalid values safely" begin
        @test_nowarn FITSexplore.main(["--filter", "NAXIS", "abc", fits_path])
    end

    @testset "default and header CLI branches" begin
        project_root = dirname(@__DIR__)

        default_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"$fits_path\"])"`
        default_out = read(pipeline(default_cmd, stderr = devnull), String)
        @test occursin(dirname(fits_path_rel), default_out)
        @test occursin(basename(fits_path_rel), default_out)
        @test occursin("EXTNUM\tEXTNAME\tTYPE", default_out)
        @test occursin("1\t\"\"\tPRIMARY", default_out)

        list_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--list\", \"$fits_path\"])"`
        list_out = read(pipeline(list_cmd, stderr = devnull), String)
        @test occursin(dirname(fits_path_rel), list_out)
        @test occursin(basename(fits_path_rel), list_out)
        @test occursin("EXTNUM\tEXTNAME\tTYPE", list_out)
        @test occursin("1\t\"\"\tPRIMARY", list_out)

        julia_cmd = join(Base.shell_escape_posixly.(Base.julia_cmd().exec), " ")
        bad_default_expr = "using FITSexplore; FITSexplore.main([$(repr(bad_fits_path))])"
        bad_default_cmd = string(
            julia_cmd,
            " --project=", Base.shell_escape_posixly(project_root),
            " -e ", Base.shell_escape_posixly(bad_default_expr),
            " >/dev/null 2>&1"
        )
        bad_default_stderr = read(`sh -c $bad_default_cmd`, String)
        @test isempty(strip(bad_default_stderr))

        bad_list_expr = "using FITSexplore; FITSexplore.main([\"--list\", $(repr(bad_fits_path))])"
        bad_list_cmd = string(
            julia_cmd,
            " --project=", Base.shell_escape_posixly(project_root),
            " -e ", Base.shell_escape_posixly(bad_list_expr),
            " 2>&1 >/dev/null"
        )
        bad_list_stderr = read(`sh -c $bad_list_cmd`, String)
        @test occursin("warning: malformed FITS file:", bad_list_stderr)
        @test occursin(basename(bad_fits_path), bad_list_stderr)

        @test_nowarn FITSexplore.main(["--header", fits_path])
    end

    @testset "recursive mode branches" begin
        project_root = dirname(@__DIR__)

        recursive_list_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--recursive\", \"$tmpdir\"])"`
        recursive_list_out = read(pipeline(recursive_list_cmd, stderr = devnull), String)
        @test occursin(basename(fits_path), recursive_list_out)
        @test occursin("EXTNUM\tEXTNAME\tTYPE", recursive_list_out)

        recursive_kw_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"NAXIS\", \"--recursive\", \"$tmpdir\"])"`
        recursive_kw_out = read(pipeline(recursive_kw_cmd, stderr = devnull), String)
        @test occursin(basename(fits_path), recursive_kw_out)
        @test occursin("2", recursive_kw_out)

        recursive_filter_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--filter\", \"NAXIS\", \"2\", \"--recursive\", \"$tmpdir\"])"`
        recursive_filter_out = read(pipeline(recursive_filter_cmd, stderr = devnull), String)
        @test occursin(basename(fits_path), recursive_filter_out)
    end

    @testset "stats CLI branches" begin
        project_root = dirname(@__DIR__)
        stats_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--stats\", \"$fits_path\"])"`
        @test success(pipeline(stats_cmd, stdout = devnull, stderr = devnull))

        stats_hdu_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--stats\", \"--hdu\", \"1\", \"$fits_path\"])"`
        @test success(pipeline(stats_hdu_cmd, stdout = devnull, stderr = devnull))
    end

    @testset "plot CLI branches" begin
        project_root = dirname(@__DIR__)
        plot_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--plot\", \"$fits_path\"])"`
        @test success(pipeline(plot_cmd, stdout = devnull, stderr = devnull))

        plot_hdu_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--plot\", \"--hdu\", \"1\", \"$fits_path\"])"`
        @test success(pipeline(plot_hdu_cmd, stdout = devnull, stderr = devnull))
    end

    @testset "keyword and filter outputs" begin
        project_root = dirname(@__DIR__)
        kw_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"NAXIS\", \"$fits_path\"])"`
        kw_out = read(pipeline(kw_cmd, stderr = devnull), String)
        @test occursin(fits_path_rel, kw_out)
        @test occursin("2", kw_out)

        kw_hdu_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"NAXIS\", \"--hdu\", \"1\", \"$fits_path\"])"`
        kw_hdu_out = read(pipeline(kw_hdu_cmd, stderr = devnull), String)
        @test occursin("$(fits_path_rel)#1", kw_hdu_out)

        # Default keyword behavior: missing required keyword suppresses output.
        kw_missing_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"DOES_NOT_EXIST\", \"$fits_path\"])"`
        kw_missing_out = read(pipeline(kw_missing_cmd, stderr = devnull), String)
        @test isempty(strip(kw_missing_out))

        # If a required keyword is missing, optional keywords should not force output.
        kw_missing_with_optional_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"DOES_NOT_EXIST\", \"--keyword-optional\", \"NAXIS\", \"$fits_path\"])"`
        kw_missing_with_optional_out = read(pipeline(kw_missing_with_optional_cmd, stderr = devnull), String)
        @test isempty(strip(kw_missing_with_optional_out))

        kw_optional_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"NAXIS\", \"--keyword-optional\", \"DOES_NOT_EXIST\", \"$fits_path\"])"`
        kw_optional_out = read(pipeline(kw_optional_cmd, stderr = devnull), String)
        @test occursin(fits_path_rel, kw_optional_out)
        @test occursin("\t2\t ", kw_optional_out)

        only_optional_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword-optional\", \"DOES_NOT_EXIST\", \"$fits_path\"])"`
        only_optional_out = read(pipeline(only_optional_cmd, stderr = devnull), String)
        @test occursin(fits_path_rel, only_optional_out)
        @test occursin("\t ", only_optional_out)

        filter_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--filter\", \"NAXIS\", \"2\", \"$fits_path\"])"`
        filter_out = read(pipeline(filter_cmd, stderr = devnull), String)
        @test occursin(fits_path_rel, filter_out)

        filter_hdu_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--filter\", \"NAXIS\", \"2\", \"--hdu\", \"1\", \"$fits_path\"])"`
        filter_hdu_out = read(pipeline(filter_hdu_cmd, stderr = devnull), String)
        @test occursin("$(fits_path_rel)#1", filter_hdu_out)

        # Malformed FITS files should be skipped instead of crashing.
        bad_kw_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"NAXIS\", \"$bad_fits_path\"])"`
        @test success(pipeline(bad_kw_cmd, stdout = devnull, stderr = devnull))

        bad_kw_warn_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--keyword\", \"NAXIS\", \"$bad_fits_path\"])"`
        bad_kw_stderr = read(pipeline(bad_kw_warn_cmd, stderr = stdout), String)
        @test isempty(strip(bad_kw_stderr))

        bad_filter_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--filter\", \"NAXIS\", \"2\", \"$bad_fits_path\"])"`
        @test success(pipeline(bad_filter_cmd, stdout = devnull, stderr = devnull))

        bad_filter_quiet_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--filter\", \"NAXIS\", \"2\", \"$bad_fits_path\"])"`
        bad_filter_stderr = read(pipeline(bad_filter_quiet_cmd, stderr = stdout), String)
        @test isempty(strip(bad_filter_stderr))
    end

    @testset "selected hdu stats output" begin
        project_root = dirname(@__DIR__)
        stats_hdu_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--stats\", \"--hdu\", \"1\", \"$fits_path\"])"`
        stats_hdu_out = read(pipeline(stats_hdu_cmd, stderr = devnull), String)
        @test occursin(fits_path_rel, stats_hdu_out)
        @test occursin("hdu :1", stats_hdu_out)
        @test occursin("size (2, 2)", stats_hdu_out)
    end

    @testset "helpers coverage" begin
        @test FITSexplore.comparekeys("A", "A")
        @test FITSexplore.comparekeys(true, "true")
        @test FITSexplore.comparekeys(true, "1")
        @test FITSexplore.comparekeys(false, "false")
        @test !FITSexplore.comparekeys(false, "notabool")
        @test FITSexplore.comparekeys(2, "2")
        @test !FITSexplore.comparekeys(2, "2.1")

        headers = FITSexplore.fitsexplore(tmpdir)
        @test haskey(headers, fits_path)

        dict_copy = copy(headers)
        FITSexplore.filter_keyword!(dict_copy, Dict{String, FITSexplore.FilterValue}("NAXIS" => 2))
        @test haskey(dict_copy, fits_path)

        dict_copy2 = copy(headers)
        FITSexplore.filter_keyword!(dict_copy2, Dict{String, FITSexplore.FilterValue}("NAXIS" => 3))
        @test !haskey(dict_copy2, fits_path)

        dict_copy3 = copy(headers)
        FITSexplore.filter_keyword!(dict_copy3, Dict{String, FITSexplore.FilterValue}("NAXIS" => [2, 3]))
        @test haskey(dict_copy3, fits_path)

        dict_copy4 = copy(headers)
        FITSexplore.filter_keyword!(dict_copy4, Dict{String, FITSexplore.FilterValue}("NAXIS" => [3, 4]))
        @test isempty(dict_copy4)
    end

    @testset "parse_cli_options coverage" begin
        @test FITSexplore.parse_cli_options(String[]).targets == ["."]
        @test FITSexplore.parse_cli_options(["--", "a.fits"]).targets == ["a.fits"]
        @test FITSexplore.parse_cli_options(["-l", "-r", "x"]).recursive
        @test FITSexplore.parse_cli_options(["-l", "-r", "x"]).list

        @test_throws ErrorException FITSexplore.parse_cli_options(["--unknown"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-k"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-K"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-u"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-f", "NAXIS"])
        @test_throws ArgumentError FITSexplore.parse_cli_options(["-f", "NAXIS", "2", "-u", "not_an_int"])

        # Help/version must return early with empty targets.
        @test isempty(FITSexplore.parse_cli_options(["--help"]).targets)
        @test isempty(FITSexplore.parse_cli_options(["--version"]).targets)
    end

    @testset "App entrypoint" begin
        project_root = dirname(@__DIR__)
        # `-m Module` entry-point support was added in Julia 1.11; use -e on older versions.
        cmd = if VERSION >= v"1.11"
            `$(Base.julia_cmd()) --project=$project_root -m FITSexplore -- --help`
        else
            `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--help\"])"`
        end
        @test success(pipeline(cmd, stdout = devnull, stderr = devnull))
    end
end
