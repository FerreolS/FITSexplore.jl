
# Compatibility helpers for AstroFITS card/value API.
header_value(hdr, key::AbstractString) = hdr[key].value()

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
        return nothing
    end
end

function try_read_header(filename::AbstractString, ext::Integer)
    ext_i = Int(ext)
    try
        return read_header(filename, ext_i)
    catch
        return nothing
    end
end

function selected_hdus(hdu_indices::Vector{Int})::Vector{Int}
    isempty(hdu_indices) && return [1]
    return hdu_indices
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
