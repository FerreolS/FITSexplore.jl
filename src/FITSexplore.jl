"""

`FITSexplore` provides FITS exploration utilities as both:
- a Julia package (`using FITSexplore`), and
- a Julia app entrypoint (`julia -m FITSexplore -- ...` or installed `fitsexplore`).

"""
module FITSexplore

export fitsexplore,
    filter_keyword!

using AstroFITS, FITSHeaders, PrecompileTools, Printf, Statistics


const suffixes = [".fits", ".fits.gz", "fits.Z", ".oifits", ".oifits.gz", ".oifits.Z"]


"""
    fitsexplore(dir::String) -> Dict{String, FitsHeader}

Scan `dir` (non-recursively) and return a dictionary mapping each supported
FITS filename to its primary header.

Only regular files with known FITS suffixes are considered, and unreadable
headers are silently skipped.
"""
function fitsexplore(dir::String)
    filedict = Dict{String, FitsHeader}()
    for filename in readdir(dir, join = true)
        if isfile(filename) && has_suffix(filename, suffixes)
            header = try_read_header(filename)
            if !isnothing(header)
                filedict[filename] = header
            end
        end
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
    filter_keyword!(filelist::Dict{String, FitsHeader}, filters::Dict{String, FilterValue})

Filter `filelist` in place according to `filters`.

Each entry in `filters` maps `keyword::String` to either:
- a scalar value: `Union{String, Bool, Integer, AbstractFloat, Nothing}`
- or a vector of allowed values: `Union{Vector{String}, Vector{Bool}, Vector{Int}, Vector{AbstractFloat}}`

Files not matching all keyword constraints are removed from `filelist`.
"""
function filter_keyword!(filelist::Dict{String, FitsHeader}, filters::Dict{String, FilterValue})
    for (filename, header) in collect(filelist)
        keep = true
        for (keyword, expected) in filters
            if !haskey(header, keyword) || !_matches_filter_value(header_value(header, keyword), expected)
                keep = false
                break
            end
        end
        keep || delete!(filelist, filename)
    end
    return nothing
end

include("print.jl")
include("parse.jl")
include("fitsfiles.jl")


function julia_main()::Cint
    try
        main(ARGS)
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

"""
    main(args = ARGS) -> Int

Run FITSexplore CLI logic on `args`.

Depending on selected options, this dispatches to list/header/stats/plot,
keyword extraction, or filtering modes over matching input FITS files.
Returns `0` on normal completion.
"""
function main(args = ARGS)
    opts::CLIOptions = parse_cli_options(Vector{String}(args))

    list::Bool = opts.list
    head::Bool = opts.header
    stats::Bool = opts.stats
    plot::Bool = opts.plot
    hdu_indices::Vector{Int} = opts.hdu
    keywords::Vector{String} = opts.keyword
    kw_opt::Vector{String} = opts.keyword_optional
    filter::Vector{String} = opts.filter
    set_spec::Vector{String} = opts.set

    for arg in opts.targets
        if isdir(arg) && opts.recursive
            _walk_and_process(arg, keywords, kw_opt, filter, set_spec, list, head, stats, plot, hdu_indices)
        else
            _process_one(arg, keywords, kw_opt, filter, set_spec, list, head, stats, plot, hdu_indices)
        end
    end
    return 0
end

function _walk_and_process(
        root::String,
        keywords::Vector{String}, kw_opt::Vector{String}, filter::Vector{String}, set_spec::Vector{String},
        list::Bool, head::Bool, stats::Bool, plot::Bool, hdu_indices::Vector{Int}
    )
    # Explicit stack-based traversal — avoids walkdir which uses Channel/Task
    # and hangs in trim-safe compiled binaries.
    dirs = String[root]
    while !isempty(dirs)
        dir = pop!(dirs)
        local entries
        try
            entries = readdir(dir; join = true)
        catch
            continue
        end
        for path in entries
            if isdir(path)
                push!(dirs, path)
            elseif has_suffix(path, suffixes)
                _process_one(path, keywords, kw_opt, filter, set_spec, list, head, stats, plot, hdu_indices)
            end
        end
    end
    return nothing
end

function _process_one(
        filename::String,
        keywords::Vector{String}, kw_opt::Vector{String}, filter::Vector{String}, set_spec::Vector{String},
        list::Bool, head::Bool, stats::Bool, plot::Bool, hdu_indices::Vector{Int}
    )
    (isfile(filename) && has_suffix(filename, suffixes)) || return
    if !isempty(set_spec)
        parse_set([filename], set_spec, hdu_indices)
    elseif !isempty(keywords) || !isempty(kw_opt)
        parse_keywords([filename], keywords, kw_opt, hdu_indices)
    elseif !isempty(filter)
        parse_filter([filename], filter, hdu_indices)
    else
        process_file_mode(filename, list, head, stats, plot, hdu_indices)
    end
    return nothing
end


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
