module CLI

using ..FITSexplore:
    CLIOptions,
    has_suffix,
    parse_cli_options,
    parse_filter,
    parse_keywords,
    parse_set,
    process_file_mode,
    suffixes

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
    # Explicit stack-based traversal - avoids walkdir which uses Channel/Task
    # and hangs in trim-safe compiled binaries.
    dirs = String[root]
    while !isempty(dirs)
        dir = pop!(dirs)
        entries = String[]
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

end
