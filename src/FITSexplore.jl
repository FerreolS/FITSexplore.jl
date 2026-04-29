"""

`FITSexplore` provides FITS exploration utilities as both:
- a Julia package (`using FITSexplore`), and
- a Julia app entrypoint (`julia -m FITSexplore -- ...` or installed `fitsexplore`).

"""
module FITSexplore

export filter_keyword!,
    fitsexplore

using AstroFITS, FITSHeaders, PrecompileTools, Printf


const suffixes = [".fits", ".fits.gz", "fits.Z", ".oifits", ".oifits.gz", ".oifits.Z"]


"""
    fitsexplore(dir::String; recursive::Bool = false) -> Dict{String, FitsHeader}

Scan `dir` and return a dictionary mapping each supported FITS filename to its
primary header.

Only regular files with known FITS suffixes are considered, and unreadable
headers are silently skipped. If `recursive` is `true`, subdirectories are
visited depth-first.
"""
function fitsexplore(dir::String; recursive::Bool = false)
    filedict = Dict{String, FitsHeader}()
    for (root, _, files) in walkdir(dir; topdown = true)
        for filename in files
            path = joinpath(root, filename)
            if has_suffix(path, suffixes)
                header = try_read_header(path)
                if !isnothing(header)
                    filedict[path] = header
                end
            end
        end
        recursive || break
    end
    return filedict
end


const ScalarFilterValue = Union{String, Bool, Integer, AbstractFloat, Nothing}
const VectorFilterValue = Union{Vector{String}, Vector{Bool}, Vector{Int}, Vector{AbstractFloat}}
const FilterValue = Union{ScalarFilterValue, VectorFilterValue}

function _matches_filter_value(actual, expected::ScalarFilterValue)::Bool
    return actual == expected
end

function _matches_filter_value(actual, expected::VectorFilterValue)::Bool
    for candidate in expected
        actual == candidate && return true
    end
    return false
end

"""
    filter_keyword!(filelist::Dict{String, FitsHeader}, filters::Dict{String})

Filter `filelist` in place according to `filters`.

Each entry in `filters` maps `keyword::String` to either:
- a scalar value: `Union{String, Bool, Integer, AbstractFloat, Nothing}`
- or a vector of allowed values: `Union{Vector{String}, Vector{Bool}, Vector{Int}, Vector{AbstractFloat}}`

Files not matching all keyword constraints are removed from `filelist`.
"""
function filter_keyword!(filelist::Dict{String, FitsHeader}, filters::Dict{String})
    for (filename, header) in collect(filelist)
        keep = true
        for (keyword, expected) in filters
            if !haskey(header, keyword) || !_matches_filter_value(header_value(header, keyword), expected)
                keep = false
            end
        end
        keep || delete!(filelist, filename)
    end
    return filelist
end

include("print.jl")
include("parse.jl")
include("fitsfiles.jl")
include("cli.jl")


"""
    main(args = ARGS) -> Int

Run FITSexplore CLI logic on `args`.

Depending on selected options, this dispatches to list/header/stats/plot,
keyword extraction, or filtering modes over matching input FITS files.
Returns `0` on normal completion.
"""
main(args = ARGS) = CLI.main(args)

julia_main()::Cint = CLI.julia_main()


@setup_workload begin
    sample_file = joinpath(@__DIR__, "samples", "sample.fits")
    keyword_args = ["-k", "NAXIS", "dummy.fits"]
    keyword_optional_args = ["-k", "NAXIS", "-K", "OBJECT", "dummy.fits"]
    filter_args = ["-f", "NAXIS", "2", "dummy.fits"]
    set_args = ["--set", "NAXIS", "2", "dummy.fits"]
    @compile_workload begin
        redirect_stdout(devnull) do
            redirect_stderr(devnull) do
                try
                    main(keyword_args)
                    main(keyword_optional_args)
                    main(filter_args)
                    main(set_args)
                    if isfile(sample_file)
                        sample_dir = dirname(sample_file)
                        main([sample_file])
                        main(["-r", sample_dir])
                        main(["-l", sample_file])
                        main(["-d", sample_file])
                        main(["-u", "1", sample_file])
                        main(["-d", "-u", "1", sample_file])
                        main(["-k", "NAXIS", sample_file])
                        main(["-k", "NAXIS", "-r", sample_dir])
                        main(["-k", "NAXIS", "-u", "1", sample_file])
                        main(["-k", "NAXIS", "-K", "OBJECT", sample_file])
                        main(["-f", "NAXIS", "2", sample_file])
                        main(["-f", "NAXIS", "2", "-r", sample_dir])
                        main(["-k", "NAXIS", "-K", "OBJECT", "-u", "1", sample_file])
                        main(["-f", "NAXIS", "2", "-u", "1", sample_file])
                        main(["--set", "OBJECT", "M42", sample_file])
                        main(["--set", "OBJECT", "M42", "Object name", sample_file])
                        main(["-s", sample_file])
                        main(["-s", "-u", "1", sample_file])
                        main(["-p", "-u", "1", sample_file])
                    end
                    #display(heatmap(rand(10, 10)))
                    parse_keywords(String[], ["NAXIS"], String[])
                    parse_filter(String[], ["NAXIS", "2"], Int[])
                    comparekeys(2, "2")
                    comparekeys("A", "A")
                    comparekeys(true, "true")
                catch
                    # Ignore runtime errors here; the goal is to record compilation edges.
                end
            end
        end
    end
end

# Register main as the app entry point for `julia -m FITSexplore` on Julia >= 1.11.
# `@main` (no-arg form) marks the module's `main` as the entry point.
# `include_string` is used so this file parses correctly on Julia < 1.11,
# where the `@main` macro does not exist.
if isdefined(Base, Symbol("@main"))
    include_string(@__MODULE__, "@main")
end

end
