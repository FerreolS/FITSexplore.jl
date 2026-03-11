using Test
using AstroFITS
using FITSexplore

@testset "FITSexplore CLI regressions" begin
    tmpdir = mktempdir()
    fits_path = joinpath(tmpdir, "sample.fits")

    # Build a minimal FITS file with one image HDU.
    writefits!(fits_path, FitsHeader(), reshape(collect(1:4), 2, 2); overwrite=true)

    @testset "--hdu prints selected headers" begin
        @test_nowarn FITSexplore.main(["--hdu", "1", fits_path])
    end

    @testset "numeric filter rejects invalid values safely" begin
        @test_nowarn FITSexplore.main(["--filter", "NAXIS", "abc", fits_path])
    end

    @testset "App entrypoint" begin
        project_root = dirname(@__DIR__)
        # `-m Module` entry-point support was added in Julia 1.11; use -e on older versions.
        cmd = if VERSION >= v"1.11"
            `$(Base.julia_cmd()) --project=$project_root -m FITSexplore -- --help`
        else
            `$(Base.julia_cmd()) --project=$project_root -e "using FITSexplore; FITSexplore.main([\"--help\"])"`
        end
        @test success(pipeline(cmd, stdout=devnull, stderr=devnull))
    end
end
