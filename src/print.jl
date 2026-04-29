# Custom statistical functions (avoid Statistics dependency for trim-safe binaries)

"""
    mean_var(arr::AbstractVector{<:Real}) -> (Float64, Float64)

Compute mean and variance in a single pass. Returns (mean, std) with Bessel's correction.
"""
function mean_var(arr::AbstractVector{<:Real})
    n = length(arr)
    n == 0 && return NaN, NaN

    # First pass: compute mean
    sum_x = zero(Float64)
    @inbounds for x in arr
        sum_x += x
    end
    mean_val = sum_x / n

    # Second pass: compute variance (with Bessel's correction for unbiased estimate)
    sum_sq_dev = zero(Float64)
    @inbounds for x in arr
        dev = x - mean_val
        sum_sq_dev += dev * dev
    end
    variance = sum_sq_dev / (n - 1)  # Bessel's correction

    return mean_val, variance
end

"""
    mean_along_dims(arr::Array{<:Real}, dims::Int) -> Array{Float64}

Compute mean along a specified dimension.
"""
function mean_along_dims(arr::Array{<:Real}, dims::Int)
    size(arr, dims) == 0 && return similar(arr, Float64)

    # Compute the shape of the output
    in_shape = size(arr)
    out_shape = ntuple(i -> i == dims ? 1 : in_shape[i], ndims(arr))
    out = zeros(Float64, out_shape)
    counts = zeros(Int, out_shape)

    # Sum values and count
    @inbounds for idx in CartesianIndices(arr)
        out_idx = ntuple(i -> i == dims ? 1 : idx[i], ndims(arr))
        out[out_idx...] += arr[idx]
        counts[out_idx...] += 1
    end

    # Divide by counts to get mean
    @inbounds for i in eachindex(out)
        out[i] /= counts[i]
    end

    return out
end

function tab_join(values::Vector{String})::String
    isempty(values) && return ""
    out = values[1]
    for i in 2:length(values)
        out = string(out, "\t", values[i])
    end
    return out
end

print_stdout(msg::String) = print(Core.stdout, msg)
println_stdout(msg::String) = println(Core.stdout, msg)

print_stderr(msg::String) = print(Core.stderr, msg)
println_stderr(msg::String) = println(Core.stderr, msg)

function format_filename_hdu(filename::String, hdu::Int, include_hdu::Bool)::String
    include_hdu || return filename
    return string(filename, "#", hdu)
end

function display_path(path::AbstractString)::String
    p = try
        normpath(abspath(String(path)))
    catch
        return String(path)
    end
    cwd = normpath(abspath(pwd()))

    p == cwd && return "."

    p_parts = splitpath(p)
    cwd_parts = splitpath(cwd)

    # Different roots/volumes: fall back to absolute path.
    if isempty(p_parts) || isempty(cwd_parts) || p_parts[1] != cwd_parts[1]
        return p
    end

    common = 0
    n = min(length(p_parts), length(cwd_parts))
    while common < n && p_parts[common + 1] == cwd_parts[common + 1]
        common += 1
    end

    rel_parts = String[]
    for _ in (common + 1):length(cwd_parts)
        push!(rel_parts, "..")
    end
    for i in (common + 1):length(p_parts)
        push!(rel_parts, p_parts[i])
    end

    isempty(rel_parts) && return "."
    sep = Base.Filesystem.path_separator
    out = rel_parts[1]
    for i in 2:length(rel_parts)
        out = string(out, sep, rel_parts[i])
    end
    return out
end

function show_plain(hdr::FitsHeader)
    println_stdout(string(length(hdr), "-element ", nameof(typeof(hdr)), ":"))
    for card in hdr
        # Keep plain-card formatting while avoiding FitsHeader arrayshow paths in trim-safe builds.
        println_stdout(sprint(io -> show(io, MIME"text/plain"(), card)))
    end
    return nothing
end

function show_plain(x)
    println_stdout(sprint(show, x))
    return nothing
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

function header_int_value(hdr, key::AbstractString)::Union{Int, Nothing}
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

function stats_line(arr::Array{Float64, N}, dims_text::String, eltype_name::String)::String where {N}
    n = length(arr)
    n == 0 && return "size " * dims_text * "  eltype " * eltype_name

    vals = Vector{Float64}(undef, n)
    k = 1
    @inbounds for x in arr
        vals[k] = x
        k += 1
    end

    meanx, varx = mean_var(vals)
    med, madd = _median_and_mad(Float64.(vals))
    minx, maxx = extrema(vals)

    return "size " * dims_text *
        "  eltype " * eltype_name *
        "  mean " * string(round(meanx; digits = 4)) *
        "  std " * string(round(sqrt(varx); digits = 4)) *
        "  median " * string(round(med; digits = 4)) *
        "  mad " * string(round(madd; digits = 4)) *
        " min " * string(round(minx; digits = 4)) *
        " max " * string(round(maxx; digits = 4))

end

# Generated function: builds the format string and size() calls for each concrete N at
# compile time, then reads the array and delegates to stats_line.
@generated function _stats_line_for_naxis(
        filename::String, i::Int, eltype_name::String, ::Val{N}
    ) where {N}
    fmt = N == 1 ? "(%d,)" : "(" * join(fill("%d", N), ", ") * ")"
    size_exprs = [:(size(arr, $k)) for k in 1:N]
    return quote
        arr = readfits(Array{Float64, $N}, filename; ext = i)
        dims_text = Printf.@sprintf($fmt, $(size_exprs...))
        return stats_line(arr, dims_text, eltype_name)
    end
end

# Explicit Val(k) calls are required so JuliaC trim=safe can trace every specialisation.
function _dispatch_naxis(filename::String, i::Int, eltype_name::String, naxis::Int)::Union{String, Nothing}
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
    shown = display_path(filename)
    try
        hdus = isempty(hdu_indices) ? FitsFile(filename) do f
                collect(1:length(f))
        end : hdu_indices
        for i in hdus
            hdr = try_read_header(filename, i)
            isnothing(hdr) && continue
            naxis = something(header_int_value(hdr, "NAXIS"), -1)
            naxis <= 0 && continue
            eltype_name = bitpix_eltype_name(something(header_int_value(hdr, "BITPIX"), -64))

            println_stdout(string(shown, "  hdu :", hdu_label(filename, i)))
            line = try
                _dispatch_naxis(filename, i, eltype_name, naxis)
            catch err
                err isa InterruptException && rethrow()
                continue
            end
            isnothing(line) && continue
            println_stdout(line)
            print_stdout("\n")
        end
    catch err
        err isa InterruptException && rethrow()
        return nothing
    end
    return nothing
end

function _median_and_mad(vals::Vector{Float64})
    n = length(vals)
    n == 0 && return 0.0, 0.0
    sorted_vals = sort(vals)
    half = n ÷ 2
    med = isodd(n) ? sorted_vals[half + 1] : (sorted_vals[half] + sorted_vals[half + 1]) / 2

    absdev = Vector{Float64}(undef, n)
    @inbounds for i in 1:n
        absdev[i] = abs(vals[i] - med)
    end
    sorted_absdev = sort(absdev)
    madd = isodd(n) ? sorted_absdev[half + 1] : (sorted_absdev[half] + sorted_absdev[half + 1]) / 2
    return med, madd * 1.4826
end

function _plot_matrix(a::Array{Float64, N}) where {N}
    return if N == 2
        a
    elseif N == 3
        dropdims(mean_along_dims(a, 3); dims = 3)
    else
        nothing
    end
end

function _downsample_mean(mat::Matrix{Float64}; max_h::Int = 24, max_w::Int = 72)
    h, w = size(mat)
    sh = max(1, cld(h, max_h))
    sw = max(1, cld(w, max_w))
    oh = cld(h, sh)
    ow = cld(w, sw)
    out = Matrix{Float64}(undef, oh, ow)
    @inbounds for i in 1:oh
        r1 = (i - 1) * sh + 1
        r2 = min(i * sh, h)
        for j in 1:ow
            c1 = (j - 1) * sw + 1
            c2 = min(j * sw, w)
            s = 0.0
            n = 0
            for r in r1:r2, c in c1:c2
                s += mat[r, c]
                n += 1
            end
            out[i, j] = s / max(n, 1)
        end
    end
    return out
end

function _ascii_heatmap(mat::Matrix{Float64})::String
    vals = vec(mat)
    isempty(vals) && return ""

    med, madd = _median_and_mad(Float64.(vals))
    lo = med - 3 * madd
    hi = med + 3 * madd
    if !isfinite(lo) || !isfinite(hi) || lo == hi
        lo, hi = extrema(vals)
    end
    lo == hi && (hi = lo + 1)

    chars = collect(" .:-=+*#%@")
    nlev = length(chars)
    io = IOBuffer()
    h, w = size(mat)
    @inbounds for i in 1:h
        for j in 1:w
            x = clamp((mat[i, j] - lo) / (hi - lo), 0.0, 1.0)
            idx = Int(floor(x * (nlev - 1))) + 1
            print(io, chars[idx])
        end
        i < h && print(io, '\n')
    end
    return String(take!(io))
end

function plot_image(a::Array{Float64, N}) where {N}
    mat = _plot_matrix(a)
    if isnothing(mat)
        return nothing
    end
    println_stdout(_ascii_heatmap(_downsample_mean(mat)))
    return nothing
end

function show_plot_mode(filename::String, hdu_indices::Vector{Int})
    shown = display_path(filename)
    try
        hdus = isempty(hdu_indices) ? FitsFile(filename) do f
                collect(1:length(f))
        end : hdu_indices
        for i in hdus
            hdr = try_read_header(filename, i)
            isnothing(hdr) && continue
            naxis = something(header_int_value(hdr, "NAXIS"), -1)
            naxis <= 0 && continue

            println_stdout(string(shown, "  hdu :", hdu_label(filename, i)))

            if naxis == 2
                arr = try
                    readfits(Array{Float64, 2}, filename; ext = i)
                catch err
                    err isa InterruptException && rethrow()
                    continue
                end
                plot_image(arr)
            elseif naxis == 3
                arr = try
                    readfits(Array{Float64, 3}, filename; ext = i)
                catch err
                    err isa InterruptException && rethrow()
                    continue
                end
                plot_image(arr)
            else
                continue
            end

            print_stdout("\n")
        end
    catch err
        err isa InterruptException && rethrow()
        return nothing
    end
    return nothing
end

function show_file_mode(filename::String)
    show_list_mode(filename, Int[]; warn_malformed = false)
    return nothing
end

function hdu_type_name(hdr)::String
    if haskey(hdr, "XTENSION")
        return header_value_string(header_value(hdr, "XTENSION"))
    end
    if haskey(hdr, "SIMPLE")
        return "PRIMARY"
    end
    return "UNKNOWN"
end

function hdu_name(hdr)::String
    if haskey(hdr, "EXTNAME")
        return header_value_string(header_value(hdr, "EXTNAME"))
    end
    return ""
end

function show_list_mode(filename::String, hdu_indices::Vector{Int}; warn_malformed::Bool = false)
    shown = display_path(filename)
    selected = try
        isempty(hdu_indices) ? FitsFile(filename) do f
                collect(1:length(f))
        end : hdu_indices
    catch
        warn_malformed && println_stderr(string("warning: malformed FITS file: ", shown))
        return nothing
    end

    hdu_lines = String[]
    for hdu in selected
        hdr = try_read_header(filename, hdu)
        isnothing(hdr) && continue
        typ = hdu_type_name(hdr)
        name = hdu_name(hdr)
        quoted_name = string('"', name, '"')
        push!(hdu_lines, string("        ", hdu, "\t", quoted_name, "\t", typ))
    end

    isempty(hdu_lines) && return nothing

    println_stdout(dirname(shown))
    println_stdout(string("    ", basename(shown)))
    println_stdout("        EXTNUM\tEXTNAME\tTYPE")
    for line in hdu_lines
        println_stdout(line)
    end
    return nothing
end

function process_file_mode(filename::String, list::Bool, head::Bool, stats::Bool, plot::Bool, hdu_indices::Vector{Int})
    return if head
        show_header_mode(filename, hdu_indices)
    elseif stats
        show_stats_mode(filename, hdu_indices)
    elseif plot
        show_plot_mode(filename, hdu_indices)
    elseif list || !isempty(hdu_indices)
        show_list_mode(filename, hdu_indices; warn_malformed = list)
    else
        show_file_mode(filename)
    end
end
