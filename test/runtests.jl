using Test
using FITSIO
using FITSexplore

@testset "FITSexplore CLI regressions" begin
    tmpdir = mktempdir()
    fits_path = joinpath(tmpdir, "sample.fits")

    # Build a minimal FITS file with one image HDU.
    f = FITS(fits_path, "w")
    write(f, reshape(collect(1:4), 2, 2))
    close(f)

    @testset "--hdu prints selected headers" begin
        @test_nowarn FITSexplore.main(["--hdu", "1", fits_path])
    end

    @testset "numeric filter rejects invalid values safely" begin
        @test_nowarn FITSexplore.main(["--filter", "NAXIS", "abc", fits_path])
    end

    @testset "App entrypoint" begin
        project_root = dirname(@__DIR__)
        cmd = `$(Base.julia_cmd()) --project=$project_root -m FITSexplore -- --help`
        @test success(pipeline(cmd, stdout=devnull, stderr=devnull))
    end
end
