"""

`FITSexplore` provides FITS exploration utilities as both:
- a Julia package (`using FITSexplore`), and
- a Julia app entrypoint (`julia -m FITSexplore -- ...` or installed `fitsexplore`).

"""
module FITSexplore

export fitsexplore

using AstroFITS, FITSHeaders, PrecompileTools, Printf #, UnicodePlots

const suffixes = [".fits", ".fits.gz", "fits.Z", ".oifits", ".oifits.gz", ".oifits.Z"]
const HeaderScalar = Union{String, Bool, Int, Float64}

@inline function emit_stdout(msg::String)
    GC.@preserve msg begin
        ccall(
            :write, Cssize_t, (Cint, Ptr{UInt8}, Csize_t),
            1, pointer(msg), ncodeunits(msg)
        )
    end
    return nothing
end

@inline function emit_stderr(msg::String)
    GC.@preserve msg begin
        ccall(
            :write, Cssize_t, (Cint, Ptr{UInt8}, Csize_t),
            2, pointer(msg), ncodeunits(msg)
        )
    end
    return nothing
end

@inline emit_stdout_line(msg::String) = emit_stdout(string(msg, "\n"))
@inline emit_stderr_line(msg::String) = emit_stderr(string(msg, "\n"))

function tab_join(values::Vector{String})::String
    isempty(values) && return ""
    out = values[1]
    for i in 2:length(values)
        out = string(out, "\t", values[i])
    end
    return out
end

function julia_main()::Cint
    try
        main(ARGS)
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

# Compatibility helpers for AstroFITS card/value API.
header_value(hdr, key::AbstractString) = hdr[key].value()

header_value_string(value::AbstractString)::String = String(value)
header_value_string(value::Bool)::String = string(value)
header_value_string(value::Integer)::String = string(value)
header_value_string(value::AbstractFloat)::String = string(value)
header_value_string(value)::String = sprint(show, value)

normalize_header_value(value::AbstractString)::String = String(value)
normalize_header_value(value::Bool)::Bool = value
normalize_header_value(value::Integer)::Int = Int(value)
normalize_header_value(value::AbstractFloat)::Float64 = Float64(value)
normalize_header_value(value)::String = sprint(show, value)

matches_filter_value(value::AbstractString, expected::AbstractString)::Bool = comparekeys(value, expected)
matches_filter_value(value::Bool, expected::AbstractString)::Bool = comparekeys(value, expected)
matches_filter_value(value::T, expected::AbstractString) where {T <: Number} = comparekeys(value, expected)
matches_filter_value(value, expected::AbstractString)::Bool = header_value_string(value) == expected

function push_required_header_value!(values::Vector{String}, header, key::AbstractString)::Bool
    haskey(header, key) || return false
    push!(values, header_value_string(header_value(header, key)))
    return true
end

function push_optional_header_value!(values::Vector{String}, header, key::AbstractString)
    if haskey(header, key)
        push!(values, header_value_string(header_value(header, key)))
    else
        push!(values, " ")
    end
    return nothing
end

function read_header(filename::AbstractString)
    # Header-only read path using FITSHeaders.FitsHeader.
    return readfits(FitsHeader, filename)
end

function read_header(filename::AbstractString, ext::Integer)
    # Header-only read path for a specific HDU extension.
    return readfits(FitsHeader, filename; ext = Int(ext))
end

function try_read_header(filename::AbstractString)
    try
        return read_header(filename)
    catch
        emit_stderr_line(string("Warning: cannot read FITS header, skipping file: ", filename))
        return nothing
    end
end

function try_read_header(filename::AbstractString, ext::Integer)
    ext_i = Int(ext)
    try
        return read_header(filename, ext_i)
    catch
        emit_stderr_line(
            string(
                "Warning: cannot read FITS header for HDU ", ext_i,
                ", skipping file: ", filename
            )
        )
        return nothing
    end
end

function selected_hdus(hdu_indices::Vector{Int})::Vector{Int}
    isempty(hdu_indices) && return [1]
    return hdu_indices
end

function format_filename_hdu(filename::String, hdu::Int, include_hdu::Bool)::String
    include_hdu || return filename
    return string(filename, "#", hdu)
end

"""
A thin header-like wrapper around a `Dict{String,Any}` built by reading
individual keywords directly via CFITSIO (bypassing `FITSHeaders.Parser`).
Supports the same `haskey` / `header_value` interface as `FitsHeader`.
"""
struct LightHeader
    data::Dict{String, HeaderScalar}
end
Base.haskey(h::LightHeader, key::AbstractString) = haskey(h.data, key)
header_value(h::LightHeader, key::AbstractString) = h.data[key]

"""
try_read_keywords_direct(filename, keywords)

Fallback for files whose full header cannot be parsed by `FITSHeaders`.
Opens the file via CFITSIO (`openfits`) and reads only the requested
`keywords` one at a time using `get(hdu, key, nothing)`, which never
touches invalid/non-standard cards.
Returns a `LightHeader` on success, `nothing` on failure.
"""
function try_read_keywords_direct(filename::AbstractString, keywords)
    # Disabled for trim-safe builds: this fallback relies on dynamic HDU dispatch.
    return nothing
end

"""
has_suffix(chain, patterns)

Return `true` if `chain` ends with at least one suffix in `patterns`.
"""
function has_suffix(chain::AbstractString, patterns::AbstractVector{<:AbstractString})
    for suffix in patterns
        if endswith(chain, suffix)
            return true
        end
    end
    return false
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

function filtercat2(
        filelist::Dict{String, FitsHeader},
        keyword::String,
        values::Union{Vector{String}, Vector{Bool}, Vector{Int}, Vector{AbstractFloat}}
    )
    newlist = Dict{String, FitsHeader}()
    for (filename, header) in filelist
        for value in values
            if haskey(header, keyword) && header_value(header, keyword) == value
                newlist[filename] = header
                break
            end
        end
    end
    return newlist
end

function filtercat3(filelist::Dict{String, FitsHeader}, keyword::String, values::AbstractVector)
    filtered = filter(file -> haskey(file[2], keyword) && header_value(file[2], keyword) in values, filelist)
    return Dict(filtered)
end


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


function parse_keywords(
        args::Vector{String},
        keywords::Vector{String},
        keywordsoptional::Vector{String},
        hdu_indices::Vector{Int}
    )
    use_selected_hdu = !isempty(hdu_indices)
    for filename in args
        if isfile(filename)
            if has_suffix(filename, suffixes)
                for hdu in selected_hdus(hdu_indices)
                    header = try_read_header(filename, hdu)
                    if isnothing(header) && hdu == 1
                        header = try_read_keywords_direct(filename, vcat(keywords, keywordsoptional))
                    end
                    isnothing(header) && continue

                    values = String[]
                    isrequired = true
                    for key in keywords
                        if !push_required_header_value!(values, header, key)
                            isrequired = false
                        end
                    end

                    if isrequired
                        for key in keywordsoptional
                            push_optional_header_value!(values, header, key)
                        end
                        emit_stdout_line(
                            string(
                                format_filename_hdu(filename, hdu, use_selected_hdu),
                                "\t",
                                tab_join(values)
                            )
                        )
                    end
                end
            end
        end
    end
    return
end

function parse_keywords(args::Vector{String}, keywords::Vector{String}, keywordsoptional::Vector{String})
    return parse_keywords(args, keywords, keywordsoptional, Int[])
end

function parse_keywords(args::Vector{String}, keywords::Vector{String})
    return parse_keywords(args, keywords, String[], Int[])
end

function parse_keywords(args::Vector{String}, keywords::Vector{Vector{String}}, keywordsoptional::Vector{Vector{String}})
    return parse_keywords(args, first.(keywords), first.(keywordsoptional), Int[])
end

function parse_keywords(args::Vector{String}, keywords::Vector{String}, keywordsoptional::Vector{Vector{String}})
    return parse_keywords(args, keywords, first.(keywordsoptional), Int[])
end

function parse_keywords(args::Vector{String}, keywords::Vector{Vector{String}}, keywordsoptional::Vector{String})
    return parse_keywords(args, first.(keywords), keywordsoptional, Int[])
end

function parse_keywords(args::Vector{String}, keywords::Vector{Vector{String}})
    return parse_keywords(args, first.(keywords), String[], Int[])
end

function parse_keywords(args::Vector{String}, keywords::Set{String})
    return parse_keywords(args, collect(keywords), String[], Int[])
end

function parse_keywords(args::Vector{String}, keywords::Set{String}, hdu_indices::Vector{Int})
    return parse_keywords(args, collect(keywords), String[], hdu_indices)
end

function parse_filter(args::Vector{String}, filter::Vector{String}, hdu_indices::Vector{Int})
    use_selected_hdu = !isempty(hdu_indices)
    for filename in args
        if isfile(filename)
            if has_suffix(filename, suffixes)
                for hdu in selected_hdus(hdu_indices)
                    header = try_read_header(filename, hdu)
                    if isnothing(header) && hdu == 1
                        header = try_read_keywords_direct(filename, [filter[1]])
                    end
                    isnothing(header) && continue
                    if haskey(header, filter[1])
                        if matches_filter_value(header_value(header, filter[1]), filter[2])
                            emit_stdout_line(format_filename_hdu(filename, hdu, use_selected_hdu))
                        end
                    end
                end
            end
        end
    end
    return
end

function parse_filter(args::Vector{String}, filter::Vector{String})
    return parse_filter(args, filter, Int[])
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

function comparekeys(key1::AbstractString, key2::AbstractString)
    return key1 == key2
end

function comparekeys(key1::Bool, key2::AbstractString)
    return if (lowercase(key2) == "true") | (lowercase(key2) == "t") | (key2 == "1")
        key1
    elseif (lowercase(key2) == "false") | (lowercase(key2) == "f") | (key2 == "0")
        !key1
    else
        false
    end
end


function comparekeys(key1::T, key2::AbstractString) where {T <: Number}
    parsed = tryparse(T, key2)
    return !isnothing(parsed) && key1 == parsed
end

name(hdu::FitsHDU) = haskey(hdu, "EXTNAME") ? hdu["EXTNAME"].string : ""

function show_plain(x)
    if x isa FitsHeader
        emit_stdout_line(string(length(x), "-element FitsHeader"))
    else
        emit_stdout_line(string(typeof(x)))
    end
    return nothing
end

function collect_hdu_indices(raw_hdu)::Vector{Int}
    isempty(raw_hdu) && return Int[]
    return Int[i for i in reduce(vcat, raw_hdu)]
end

function show_header_mode(filename::String, hdu_indices::Vector{Int})
    for hdu in selected_hdus(hdu_indices)
        hdr = try_read_header(filename, hdu)
        !isnothing(hdr) && show_plain(hdr)
    end
    return
end


function hdu_label(filename::String, hdu_index::Int)::String
    hdr = try_read_header(filename, hdu_index)
    if !isnothing(hdr) && haskey(hdr, "EXTNAME")
        return header_value_string(header_value(hdr, "EXTNAME"))
    end
    return string(hdu_index)
end

function header_int_value(hdr, key::AbstractString)::Union{Int,Nothing}
    haskey(hdr, key) || return nothing
    value = header_value(hdr, key)
    if value isa Integer
        return Int(value)
    end
    parsed = tryparse(Int, header_value_string(value))
    return parsed
end

function bitpix_eltype_name(bitpix::Int)::String
    bitpix == 8 && return "UInt8"
    bitpix == 10 && return "Int8"
    bitpix == 20 && return "UInt16"
    bitpix == 16 && return "Int16"
    bitpix == 40 && return "UInt32"
    bitpix == 32 && return "Int32"
    bitpix == 81 && return "UInt64"
    bitpix == 64 && return "Int64"
    bitpix == -32 && return "Float32"
    bitpix == -64 && return "Float64"
    return "Float64"
end

function stats_line(arr::Array{Float64,N}, dims_text::String, eltype_name::String)::String where {N}
    n = length(arr)
    n == 0 && return "size " * dims_text * "  eltype " * eltype_name

    vals = Vector{Float64}(undef, n)
    k = 1
    @inbounds for x in arr
        vals[k] = x
        k += 1
    end

    sumx = 0.0
    @inbounds for x in vals
        sumx += x
    end
    meanx = sumx / n

    varsum = 0.0
    @inbounds for x in vals
        dx = x - meanx
        varsum += dx * dx
    end
    stdx = sqrt(varsum / max(n - 1, 1))

    sorted_vals = sort(vals)
    half = n ÷ 2
    med = isodd(n) ? sorted_vals[half + 1] : (sorted_vals[half] + sorted_vals[half + 1]) / 2

    absdev = Vector{Float64}(undef, n)
    @inbounds for j in 1:n
        absdev[j] = abs(vals[j] - med)
    end
    sorted_absdev = sort(absdev)
    madd = isodd(n) ? sorted_absdev[half + 1] : (sorted_absdev[half] + sorted_absdev[half + 1]) / 2
    madd *= 1.4826

    return "size " * dims_text *
           "  eltype " * eltype_name *
           "  mean " * string(round(meanx; digits = 4)) *
           "  std " * string(round(stdx; digits = 4)) *
           "  median " * string(round(med; digits = 4)) *
           "  mad " * string(round(madd; digits = 4))
end

# Generated function: builds the format string and size() calls for each concrete N at
# compile time, then reads the array and delegates to stats_line.
@generated function _stats_line_for_naxis(
    filename::String, i::Int, eltype_name::String, ::Val{N}
) where {N}
    fmt        = N == 1 ? "(%d,)" : "(" * join(fill("%d", N), ", ") * ")"
    size_exprs = [:(size(arr, $k)) for k in 1:N]
    quote
        arr = readfits(Array{Float64,$N}, filename; ext = i)
        dims_text = Printf.@sprintf($fmt, $(size_exprs...))
        return stats_line(arr, dims_text, eltype_name)
    end
end

# Explicit Val(k) calls are required so JuliaC trim=safe can trace every specialisation.
function _dispatch_naxis(filename::String, i::Int, eltype_name::String, naxis::Int)::Union{String,Nothing}
    naxis == 1 && return _stats_line_for_naxis(filename, i, eltype_name, Val(1))
    naxis == 2 && return _stats_line_for_naxis(filename, i, eltype_name, Val(2))
    naxis == 3 && return _stats_line_for_naxis(filename, i, eltype_name, Val(3))
    naxis == 4 && return _stats_line_for_naxis(filename, i, eltype_name, Val(4))
    naxis == 5 && return _stats_line_for_naxis(filename, i, eltype_name, Val(5))
    naxis == 6 && return _stats_line_for_naxis(filename, i, eltype_name, Val(6))
    naxis == 7 && return _stats_line_for_naxis(filename, i, eltype_name, Val(7))
    return nothing
end

function show_stats_mode(filename::String, hdu_indices::Vector{Int})
    try
        hdus = isempty(hdu_indices) ? FitsFile(filename) do f; collect(1:length(f)); end : hdu_indices
        for i in hdus
            hdr = try_read_header(filename, i)
            isnothing(hdr) && continue
            naxis = something(header_int_value(hdr, "NAXIS"), -1)
            naxis <= 0 && continue
            eltype_name = bitpix_eltype_name(something(header_int_value(hdr, "BITPIX"), -64))

            emit_stdout_line(string(filename, "  hdu :", hdu_label(filename, i)))
            line = try
                _dispatch_naxis(filename, i, eltype_name, naxis)
            catch
                continue
            end
            isnothing(line) && continue
            emit_stdout_line(line)
            emit_stdout("\n")
        end
    catch
        emit_stderr_line(string("Warning: cannot read FITS data, skipping file: ", filename))
    end
    return nothing
end

function show_file_mode(filename::String)
    hdr = try_read_header(filename)
    !isnothing(hdr) && show_plain(hdr)
    return nothing
end

function process_file_mode(filename::String, head::Bool, stats::Bool, hdu_indices::Vector{Int})
    return if head
        show_header_mode(filename, hdu_indices)
    elseif stats
        show_stats_mode(filename, hdu_indices)
    elseif !isempty(hdu_indices)
        show_header_mode(filename, hdu_indices)
    else
        show_file_mode(filename)
    end
end

struct CLIOptions
    targets::Vector{String}
    recursive::Bool
    header::Bool
    stats::Bool
    hdu::Vector{Int}
    keyword::Vector{String}
    keyword_optional::Vector{String}
    filter::Vector{String}
end

const HELP_TEXT = """
Usage: fitsexplore [options] [TARGET...]

Simple tool to explore the content of FITS files.
Without any argument, displays name and type of all HDU.

Options:
  -d, --header            Print the whole FITS header.
  -s, --stats             Print statistics of all image HDU.
  -u, --hdu N             Select HDU by number (can repeat).
  -k, --keyword KW        Print value of FITS header KW (can repeat).
                          Files missing a required KW are not displayed.
  -K, --keyword-optional KW
                          Like -k but prints a space if KW is missing.
  -f, --filter KW VALUE   Print files where header KW = VALUE.
  -r, --recursive         Recursively explore directories.
  --version               Print version and exit.
  -h, --help              Print this message.

TARGET can be files or (with -r) directories. Defaults to '.'.
"""

function parse_cli_options(args::Vector{String})::CLIOptions
    targets = String[]
    keywords = String[]
    kw_opt = String[]
    filter_kv = String[]
    hdu_list = Int[]
    recursive = false
    header = false
    stats = false

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--help" || a == "-h"
            emit_stdout(HELP_TEXT)
            return CLIOptions(String[], false, false, false, Int[], String[], String[], String[])
        elseif a == "--version"
            emit_stdout_line("FITSexplore 0.2")
            return CLIOptions(String[], false, false, false, Int[], String[], String[], String[])
        elseif a == "--header" || a == "-d"
            header = true
        elseif a == "--stats" || a == "-s"
            stats = true
        elseif a == "--recursive" || a == "-r"
            recursive = true
        elseif a == "--keyword" || a == "-k"
            i += 1
            i <= length(args) || error("$a requires an argument")
            push!(keywords, args[i])
        elseif a == "--keyword-optional" || a == "-K"
            i += 1
            i <= length(args) || error("$a requires an argument")
            push!(kw_opt, args[i])
        elseif a == "--hdu" || a == "-u"
            i += 1
            i <= length(args) || error("$a requires an argument")
            push!(hdu_list, parse(Int, args[i]))
        elseif a == "--filter" || a == "-f"
            i += 1
            i + 1 <= length(args) + 1 || error("$a requires two arguments")
            i <= length(args) || error("$a requires two arguments")
            push!(filter_kv, args[i])
            i += 1
            i <= length(args) || error("$a requires two arguments (VALUE missing)")
            push!(filter_kv, args[i])
        elseif a == "--"
            # end-of-options separator: remaining args are all positional
            for j in (i + 1):length(args)
                push!(targets, args[j])
            end
            break
        elseif startswith(a, "-")
            error("Unknown option: $a")
        else
            push!(targets, a)
        end
        i += 1
    end

    isempty(targets) && push!(targets, ".")
    return CLIOptions(targets, recursive, header, stats, hdu_list, keywords, kw_opt, filter_kv)
end


function main(args = ARGS)
    opts::CLIOptions = parse_cli_options(Vector{String}(args))

    files = Vector{String}()
    for arg in opts.targets
        if isdir(arg) && opts.recursive
            files = vcat(files, [root * "/" * filename for (root, dirs, TARGET) in walkdir(arg) for filename in TARGET  ])
        else
            files = vcat(files, arg)
        end
    end


    head::Bool = opts.header
    stats::Bool = opts.stats
    hdu_indices::Vector{Int} = opts.hdu

    if !isempty(opts.keyword) || !isempty(opts.keyword_optional)
        parse_keywords(files, opts.keyword, opts.keyword_optional, hdu_indices)
    elseif !isempty(opts.filter)
        parse_filter(files, opts.filter, hdu_indices)
    else
        for filename in files
            (isfile(filename) && has_suffix(filename, suffixes)) || continue
            process_file_mode(filename, head, stats, hdu_indices)
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
