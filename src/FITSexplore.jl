"""

`FITSexplore` provides FITS exploration utilities as both:
- a Julia package (`using FITSexplore`), and
- a Julia app entrypoint (`julia -m FITSexplore -- ...` or installed `fitsexplore`).

"""
module FITSexplore

public fitsexplore,
    filtercat,
    filter_keywords

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


"""
newlist = filtercat(filelist,keyword,value)

Build a `newlist` dictionnary of all files where `fitsheader[keyword] == value`.
"""
function filtercat(
        filelist::Dict{String, FitsHeader},
        keyword::String,
        values::Union{Vector{String}, Vector{Bool}, Vector{Int}, Vector{AbstractFloat}}
    )
    newlist = Dict{String, FitsHeader}()
    for value in values
        merge!(newlist, filtercat(filelist, keyword, value))
    end
    return newlist
end

function filtercat(
        filelist::Dict{String, FitsHeader},
        keyword::String,
        value::Union{String, Bool, Integer, AbstractFloat, Nothing}
    )
    try
        tmp = filter(p -> header_value(p.second, keyword) == value, filelist)
        return tmp
    catch
        return Dict{String, FitsHeader}()
    end
end

"""
filter_keywords(filelist::Dict{String, FITSHeader}, filter::Dict{String,Any})

Filter the files in `filelist` based on the keyword-value pairs in `filter`.

The function modifies `filelist` in place and removes the files that do not meet the filter criteria.
"""
function filter_keywords(filelist::Dict{String, FitsHeader}, filter::Dict{String, Any})
    for (filename, header) in filelist
        keep = true
        for (key, value) in filter
            if !haskey(header, key) || header_value(header, key) != value
                keep = false
                break
            end
        end
        if !keep
            delete!(filelist, filename)
        end
    end
    return
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

    files = Vector{String}()
    for arg in opts.targets
        if isdir(arg) && opts.recursive
            append!(files, [root * "/" * filename for (root, _, target_files) in walkdir(arg) for filename in target_files])
        else
            push!(files, arg)
        end
    end

    list::Bool = opts.list
    head::Bool = opts.header
    stats::Bool = opts.stats
    plot::Bool = opts.plot
    hdu_indices::Vector{Int} = opts.hdu

    if !isempty(opts.keyword) || !isempty(opts.keyword_optional)
        parse_keywords(files, opts.keyword, opts.keyword_optional, hdu_indices)
    elseif !isempty(opts.filter)
        parse_filter(files, opts.filter, hdu_indices)
    else
        for filename in files
            (isfile(filename) && has_suffix(filename, suffixes)) || continue
            process_file_mode(filename, list, head, stats, plot, hdu_indices)
        end
    end
    return 0
end


@setup_workload begin
    sample_file = joinpath(@__DIR__, "samples", "sample.fits")
    keyword_args = ["-k", "NAXIS", "dummy.fits"]
    keyword_optional_args = ["-k", "NAXIS", "-K", "OBJECT", "dummy.fits"]
    filter_args = ["-f", "NAXIS", "2", "dummy.fits"]
    @compile_workload begin
        redirect_stdout(devnull) do
            redirect_stderr(devnull) do
                try
                    main(keyword_args)
                    main(keyword_optional_args)
                    main(filter_args)
                    if isfile(sample_file)
                        main([sample_file])
                        main(["-l", sample_file])
                        main(["-d", sample_file])
                        main(["-u", "1", sample_file])
                        main(["-d", "-u", "1", sample_file])
                        main(["-k", "NAXIS", sample_file])
                        main(["-k", "NAXIS", "-u", "1", sample_file])
                        main(["-k", "NAXIS", "-K", "OBJECT", sample_file])
                        main(["-f", "NAXIS", "2", sample_file])
                        main(["-k", "NAXIS", "-K", "OBJECT", "-u", "1", sample_file])
                        main(["-f", "NAXIS", "2", "-u", "1", sample_file])
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
