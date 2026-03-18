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
                        shown = display_path(filename)
                        println_stdout(
                            string(
                                format_filename_hdu(shown, hdu, use_selected_hdu),
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
                    isnothing(header) && continue
                    if haskey(header, filter[1])
                        if matches_filter_value(header_value(header, filter[1]), filter[2])
                            println_stdout(format_filename_hdu(display_path(filename), hdu, use_selected_hdu))
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

function parse_set_value(value::AbstractString)
    value_lower = lowercase(value)
    if value_lower == "true" || value_lower == "t"
        return true
    elseif value_lower == "false" || value_lower == "f"
        return false
    end

    parsed_int = tryparse(Int, value)
    !isnothing(parsed_int) && return parsed_int

    parsed_float = tryparse(Float64, value)
    !isnothing(parsed_float) && return parsed_float

    return String(value)
end

set_hdu_keyword!(hdu, key::String, value::Bool, _comment::Nothing) = (AstroFITS.update_key(hdu, key, value); nothing)
set_hdu_keyword!(hdu, key::String, value::Integer, _comment::Nothing) = (AstroFITS.update_key(hdu, key, Int(value)); nothing)
set_hdu_keyword!(hdu, key::String, value::AbstractFloat, _comment::Nothing) = (AstroFITS.update_key(hdu, key, Float64(value)); nothing)
set_hdu_keyword!(hdu, key::String, value::String, _comment::Nothing) = (AstroFITS.update_key(hdu, key, value); nothing)

set_hdu_keyword!(hdu, key::String, value::Bool, comment::String) = (AstroFITS.update_key(hdu, key, value, comment); nothing)
set_hdu_keyword!(hdu, key::String, value::Integer, comment::String) = (AstroFITS.update_key(hdu, key, Int(value), comment); nothing)
set_hdu_keyword!(hdu, key::String, value::AbstractFloat, comment::String) = (AstroFITS.update_key(hdu, key, Float64(value), comment); nothing)
set_hdu_keyword!(hdu, key::String, value::String, comment::String) = (AstroFITS.update_key(hdu, key, value, comment); nothing)

function parse_set(args::Vector{String}, set_spec::Vector{String}, hdu_indices::Vector{Int})
    length(set_spec) in (2, 3) || error("internal error: set specification must have 2 or 3 arguments")

    key = set_spec[1]
    value = parse_set_value(set_spec[2])
    comment = length(set_spec) == 3 ? set_spec[3] : nothing
    use_selected_hdu = !isempty(hdu_indices)

    for filename in args
        if isfile(filename)
            if has_suffix(filename, suffixes)
                shown = display_path(filename)
                try
                    file = openfits(filename, "rw")
                    try
                        for hdu in selected_hdus(hdu_indices)
                            checkbounds(Bool, file, hdu) || continue
                            hdu_obj = AstroFITS._FitsAnyHDU(file, hdu)
                            set_hdu_keyword!(hdu_obj, key, value, comment)
                            println_stdout(format_filename_hdu(shown, hdu, use_selected_hdu))
                        end
                    finally
                        close(file)
                    end
                catch
                    println_stderr(
                        string(
                            "warning: failed to set keyword ",
                            key,
                            " in ",
                            shown
                        )
                    )
                end
            end
        end
    end
    return
end

function parse_set(args::Vector{String}, set_spec::Vector{String})
    return parse_set(args, set_spec, Int[])
end

function comparekeys(key1::AbstractString, key2::AbstractString)
    return key1 == key2
end

function comparekeys(key1::Bool, key2::AbstractString)
    key2_lower = lowercase(key2)
    return if (key2_lower == "true") || (key2_lower == "t") || (key2 == "1")
        key1
    elseif (key2_lower == "false") || (key2_lower == "f") || (key2 == "0")
        !key1
    else
        false
    end
end

function comparekeys(key1::T, key2::AbstractString) where {T <: Number}
    parsed = tryparse(T, key2)
    return !isnothing(parsed) && key1 == parsed
end
matches_filter_value(value::AbstractString, expected::AbstractString)::Bool = comparekeys(value, expected)
matches_filter_value(value::Bool, expected::AbstractString)::Bool = comparekeys(value, expected)
matches_filter_value(value::T, expected::AbstractString) where {T <: Number} = comparekeys(value, expected)
matches_filter_value(value, expected::AbstractString)::Bool = header_value_string(value) == expected

header_value_string(value::AbstractString)::String = String(value)
header_value_string(value::Bool)::String = string(value)
header_value_string(value::Integer)::String = string(value)
header_value_string(value::AbstractFloat)::String = string(value)
header_value_string(value)::String = sprint(show, value)

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

struct CLIOptions
    targets::Vector{String}
    recursive::Bool
    list::Bool
    header::Bool
    stats::Bool
    plot::Bool
    hdu::Vector{Int}
    keyword::Vector{String}
    keyword_optional::Vector{String}
    filter::Vector{String}
    set::Vector{String}
end

const HELP_TEXT = """
Usage: fitsexplore [options] [TARGET...]

Simple tool to explore the content of FITS files.
Without any argument, displays name and type of all HDU.

Options:
    -l, --list              List all HDU with their name/type.
    -d, --header            Print the whole FITS header.
    -s, --stats             Print statistics of all image HDU.
    -p, --plot              Plot image HDU (NAXIS=2 or 3).
    -u, --hdu N             Select HDU by number (can repeat).
    -k, --keyword KW        Print value of FITS header KW (can repeat).
                            Files missing a required KW are not displayed.
    -K, --keyword-optional KW
                            Like -k but prints a space if KW is missing.
    -f, --filter KW VALUE   Print files where header KW = VALUE.
    --set KW VALUE [COMMENT]
                            Set or replace FITS keyword KW with VALUE
    -r, --recursive         Recursively explore directories.
    --version               Print version and exit.
    -h, --help              Print this message.

TARGET can be files or (with -r) directories. Defaults to '.'.
"""

"""
    parse_cli_options(args::Vector{String}) -> CLIOptions

Parse command-line arguments into a `CLIOptions` struct.

Recognized options include listing, header display, stats, plotting, HDU
selection, keyword extraction, filtering, recursion, help and version.
Throws an error for unknown options or missing required option arguments.
"""
function parse_cli_options(args::Vector{String})::CLIOptions
    targets = String[]
    keywords = String[]
    kw_opt = String[]
    filter_kv = String[]
    set_kvc = String[]
    hdu_list = Int[]
    recursive = false
    list = false
    header = false
    stats = false
    plot = false

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--help" || a == "-h"
            print_stdout(HELP_TEXT)
            return CLIOptions(String[], false, false, false, false, false, Int[], String[], String[], String[], String[])
        elseif a == "--version"
            println_stdout("FITSexplore 0.1.0")
            return CLIOptions(String[], false, false, false, false, false, Int[], String[], String[], String[], String[])
        elseif a == "--list" || a == "-l"
            list = true
        elseif a == "--header" || a == "-d"
            header = true
        elseif a == "--stats" || a == "-s"
            stats = true
        elseif a == "--plot" || a == "-p"
            plot = true
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
            i <= length(args) || error("$a requires two arguments")
            push!(filter_kv, args[i])
            i += 1
            i <= length(args) || error("$a requires two arguments (VALUE missing)")
            push!(filter_kv, args[i])
        elseif a == "--set"
            isempty(set_kvc) || error("--set may only be specified once")

            i += 1
            i <= length(args) || error("$a requires at least two arguments (KW and VALUE)")
            push!(set_kvc, args[i])

            i += 1
            i <= length(args) || error("$a requires at least two arguments (VALUE missing)")
            push!(set_kvc, args[i])

            # Optional COMMENT: only consumed if at least one argument remains after it
            # so `--set KW VALUE file.fits` is parsed as no-comment with target `file.fits`.
            if i < length(args)
                next_arg = args[i + 1]
                if !startswith(next_arg, "-") && (i + 1 < length(args))
                    i += 1
                    push!(set_kvc, args[i])
                end
            end
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

    if !isempty(set_kvc) && isempty(targets)
        error("--set requires at least one TARGET")
    end

    isempty(targets) && push!(targets, ".")
    return CLIOptions(targets, recursive, list, header, stats, plot, hdu_list, keywords, kw_opt, filter_kv, set_kvc)
end
