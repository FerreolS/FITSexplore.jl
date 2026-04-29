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

    @testset "set keyword option" begin
        project_root = dirname(@__DIR__)

        set_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--set\", \"OBJECT\", \"M42\", \"$fits_path\"])"`
        set_out = read(pipeline(set_cmd, stderr = devnull), String)
        @test occursin(fits_path_rel, set_out)

        hdr1 = readfits(FitsHeader, fits_path)
        @test hdr1["OBJECT"].value(String) == "M42"

        set_with_comment_cmd = `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--set\", \"OBJECT\", \"M43\", \"Target name\", \"$fits_path\"])"`
        set_with_comment_out = read(pipeline(set_with_comment_cmd, stderr = devnull), String)
        @test occursin(fits_path_rel, set_with_comment_out)

        hdr2 = readfits(FitsHeader, fits_path)
        @test hdr2["OBJECT"].value(String) == "M43"
        @test hdr2["OBJECT"].comment == "Target name"

        FITSexplore.main(["--set", "EXPTIME", "42", fits_path])
        hdr3 = readfits(FitsHeader, fits_path)
        @test hdr3["EXPTIME"].value(Integer) == 42

        FITSexplore.main(["--set", "DITHER", "true", fits_path])
        hdr4 = readfits(FitsHeader, fits_path)
        @test hdr4["DITHER"].value(Bool)
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

        @testset "print helper functions" begin
            a = reshape(Float64.(1:6), 2, 3)
            m1 = FITSexplore.mean_along_dims(a, 1)
            m2 = FITSexplore.mean_along_dims(a, 2)
            @test size(m1) == (1, 3)
            @test size(m2) == (2, 1)
            @test m1 ≈ reshape([1.5, 3.5, 5.5], 1, 3)
            @test m2 ≈ reshape([3.0, 4.0], 2, 1)

            empty_a = Array{Float64}(undef, 0, 3)
            @test isempty(FITSexplore.mean_along_dims(empty_a, 1))

            cwd = pwd()
            @test FITSexplore.display_path(cwd) == "."
            @test occursin("..", FITSexplore.display_path(dirname(cwd)))
            @test occursin("fitsexplore", lowercase(FITSexplore.display_path(joinpath(cwd, "sub", "fitsexplore-child"))))

            stat = FITSexplore.stats_line(reshape(Float64.(1:4), 2, 2), "(2, 2)", "Float64")
            @test occursin("size (2, 2)", stat)
            @test occursin("eltype Float64", stat)
            @test occursin("mean", stat)
            @test occursin("std", stat)
        end

        @testset "header_int_value helper" begin
            struct DummyCard
                value
            end

            hdr = Dict{String, DummyCard}(
                "INT" => DummyCard(() -> 12),
                "STRINT" => DummyCard(() -> "34"),
                "BAD" => DummyCard(() -> "x3")
            )

            @test FITSexplore.header_int_value(hdr, "INT") == 12
            @test FITSexplore.header_int_value(hdr, "STRINT") == 34
            @test isnothing(FITSexplore.header_int_value(hdr, "MISSING"))
            @test isnothing(FITSexplore.header_int_value(hdr, "BAD"))
        end
    end

    @testset "parse_cli_options coverage" begin
        @test FITSexplore.parse_cli_options(String[]).targets == ["."]
        @test FITSexplore.parse_cli_options(["--", "a.fits"]).targets == ["a.fits"]
        @test FITSexplore.parse_cli_options(["-l", "-r", "x"]).recursive
        @test FITSexplore.parse_cli_options(["-l", "-r", "x"]).list
        @test FITSexplore.parse_cli_options(["--set", "OBJECT", "M42", "x.fits"]).set == ["OBJECT", "M42"]
        @test FITSexplore.parse_cli_options(["--set", "OBJECT", "M42", "object name", "x.fits"]).set == ["OBJECT", "M42", "object name"]

        @test_throws ErrorException FITSexplore.parse_cli_options(["--unknown"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-k"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-K"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-u"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["-f", "NAXIS"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["--set", "OBJECT"])
        @test_throws ErrorException FITSexplore.parse_cli_options(["--set", "OBJECT", "M42"])
        @test_throws ArgumentError FITSexplore.parse_cli_options(["-f", "NAXIS", "2", "-u", "not_an_int"])

        # Check user-visible messages for malformed specs.
        err_f = try
            FITSexplore.parse_cli_options(["-f", "NAXIS"])
            nothing
        catch err
            err
        end
        @test err_f isa ErrorException
        @test occursin("requires two arguments (VALUE missing)", sprint(showerror, err_f))

        err_set = try
            FITSexplore.parse_cli_options(["--set", "OBJECT", "M42"])
            nothing
        catch err
            err
        end
        @test err_set isa ErrorException
        @test occursin("--set requires at least one TARGET", sprint(showerror, err_set))

        # Type inference checks for helpers used in parser/filters hot paths.
        @test (@inferred FITSexplore.comparekeys(2, "2")) === true
        @test (@inferred FITSexplore.comparekeys(false, "false")) === true
        @test (@inferred FITSexplore.header_value_string(2.5)) == "2.5"

        # Help/version must return early with empty targets.
        @test isempty(FITSexplore.parse_cli_options(["--help"]).targets)
        @test isempty(FITSexplore.parse_cli_options(["--version"]).targets)
    end

    @testset "recursive traversal resilience" begin
        root = mktempdir()
        unreadable = joinpath(root, "unreadable")
        mkpath(unreadable)

        # Trigger readdir catch/continue branch in recursive walk.
        chmod(unreadable, 0o000)
        try
            @test_nowarn FITSexplore.main(["--recursive", root])
        finally
            chmod(unreadable, 0o700)
            rm(root; recursive = true, force = true)
        end
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
