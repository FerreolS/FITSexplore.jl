using FITSexplore

sample_file = joinpath(@__DIR__, "..", "samples", "sample.fits")

function safe_main(args::Vector{String})
    try
        FITSexplore.main(args)
    catch
        # Keep sysimage precompile resilient to sample-specific FITS issues.
    end
    return nothing
end

redirect_stdout(devnull) do
    redirect_stderr(devnull) do
        if isfile(sample_file)
            safe_main([sample_file])
            safe_main(["--header", sample_file])
            safe_main(["--stats", sample_file])
            safe_main(["--hdu", "1", sample_file])
            safe_main(["--keyword", "NAXIS", sample_file])
            safe_main(["--keyword", "NAXIS", "--keyword-optional", "OBJECT", sample_file])
            safe_main(["--filter", "NAXIS", "2", sample_file])
        end
    end
end
