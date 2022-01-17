"""

Package `FITSexplore`

"""

module FITSexplore

export endswith


using FITSIO, EasyFITS,ArgParse

const suffixes = [".fits", ".fits.gz","fits.Z"]



"""
	endswith(chain::Union{String,Vector{String}}, pattern::Vector{String})

Overloading of Base.endswith for vectors of string. Return `true` if `chain`
ends with one of the patterns given in `pattern`
"""
function Base.endswith(chain::Union{String,Vector{String}}, pattern::Vector{String})
	for str in pattern
		if endswith(chain,str)
			return true
		end
	end
	return false
end

"""
	endswith(chain::Vector{String}, pattern::String)

Overloading of Base.endswith for vectors of string. Return `true` if `chain`
ends with `pattern`
"""
function Base.endswith(chains::Vector{String},pattern::AbstractString)
	for chain in chains
		if endswith(chain,pattern)
			return true
		end
	end
	return false
end

"""
	newlist = filtercat(filelist,keyword,value)

Build a `newlist` dictionnary of all files where `fitsheader[keyword] == value`.
"""
function filtercat(filelist::Dict{String, FitsHeader},
					keyword::String,
					values::Union{Vector{String}, Vector{Bool}, Vector{Integer}, Vector{AbstractFloat}})
	newlist = Dict{String, FitsHeader}()
	for value in values
		merge!(newlist, filtercat(filelist,keyword,value))
	end
	return newlist
end

function filtercat(filelist::Dict{String, FitsHeader},
					keyword::String,
					value::Union{String, Bool, Integer, AbstractFloat, Nothing})
	try tmp = filter(p->p.second[keyword] == value,filelist)
		return  tmp
	catch
		return Dict{String, FitsHeader}()
	end
end


function explore(dir::String)
	filedict = Dict{String, FitsHeader}()

	for filename in readdir(dir)
		if isfile(filename)
			if endswith(filename,suffixes)
				get!(filedict, filename) do
					read(FitsHeader, filename)
				end
			end
		end
	end
	return filedict
end

function parse_keywords(args::Vector{String}, keywords::Vector{Vector{String}} )
	parse_keywords(args,[k[1] for k in keywords])
end

function parse_keywords(args::Vector{String}, keywords::Vector{String} )
	for filename in args
		if isfile(filename)
			if endswith(filename,suffixes)
				header  = read(FitsHeader, filename)
				str = ""
				for key in keywords
					if haskey(header,key)
						str = str * " \t " * string(header[key])
					end
				end
				println(filename ," \t ", str)
			end
		end
	end
end

function parse_filter(args::Vector{String}, filter::Vector{String} )
	for filename in args
		if isfile(filename)
			if endswith(filename,suffixes)
				header  = read(FitsHeader, filename)
				if haskey(header,filter[1])
					if header[filter[1]] ==  filter[2]
						println(filename ,"\t \t",header[filter[1]])
					end
				end
			end
		end
	end
end

function main(args)

    s = ArgParseSettings("Example 2 for argparse.jl: " *  # description
                         "flags, options help, " *
                         "required arguments.")

    @add_arg_table! s begin
        "--keyword", "-k"
			nargs = 1
			action = :append_arg
			arg_type = String
            help = "keyword"
        "--filter", "-f"
            help = "filter"
			arg_type = String
			nargs = 2
		"--header", "-d"
			help = "header"
			action = :store_true
		"filename"
			nargs = '*'
			arg_type = String
            help = "filenames of "
    end

    parsed_args = parse_args(args, s)
    #  println("Parsed args:")
    #  for (key,val) in parsed_args
    #      println("  $key  =>  $(repr(val))")
    #  end

	args::Vector{String} = isempty(parsed_args["filename"]) ?   readdir() : parsed_args["filename"]
	# println(args)

	head::Bool =  parsed_args["header"];

	if !isempty(parsed_args["keyword"])
		parse_keywords(args,parsed_args["keyword"])


	elseif !isempty(parsed_args["filter"])
		parse_filter(args,parsed_args["filter"])
	else
		for filename in args
			if isfile(filename)
				if endswith(filename,suffixes)
					if head
						@show read(FitsHeader,filename)
					else
						@show FITS(filename)
					end
				end
			end
		end
	end

end


function main2(args::Vector{String})

    s = ArgParseSettings("Example 2 for argparse.jl: " *  # description
                         "flags, options help, " *
                         "required arguments.")

    @add_arg_table! s begin
        "--keyword", "-k"
			nargs = 1
			action = :append_arg
			arg_type = String
            help = "keyword"
        "--filter", "-f"
            help = "filter"
			arg_type = String
			nargs = 2
		"arg1"
			nargs = '*'
			arg_type = String
            help = "an argument"
    end

    parsed_arg:: Dict{String, Union{String, Vector{String}}} = parse_args(args, s)
    println("Parsed args:")
	@show parsed_arg
end


end