"""

Package `FITSexplore`

"""

module FITSexplore

using FITSIO, EasyFITS, ArgParse

const suffixes = [".fits", ".fits.gz","fits.Z",".oifits",".oifits.gz",".oifits.Z"]



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
				iskeyword = true
				for key in keywords
					if haskey(header,key)
						str = str * " \t " * string(header[key])
					else
						iskeyword = false
					end
				end
				if iskeyword
					println(filename ," \t ", str)
				end
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
						println(filename)
					end
				end
			end
		end
	end
end

function main(args)

    settings = ArgParseSettings(prog = "FITSexplore",
						 #version = @project_version,
						 version = "0.1",
						 add_version = true)

	settings.description =  "Simple tool to explore the content of FITS files.\n\n"*
							"Without any argument, it will display the name and the type of all HDU contained in the files TARGET."
    @add_arg_table! settings begin
		"--header", "-d"
			help = "header"
			action = :store_true
			help = "Print the whole FITS header."
        "--keyword", "-k"
			nargs = 1
			action = :append_arg
			arg_type = String
            help = "Print the value of the FITS header KEYWORD. This argument can be set multiple times to display several FITS keyword"
        "--filter", "-f"
            help = "filter"
			arg_type = String
			nargs = 2
			metavar = ["KEYWORD", "VALUE"]
			help = "Print all files where the FITS header KEYWORD = VALUE."
		"--recursive", "-r"
			help = "Recursively explore entire directories."
			action = :store_true
		"TARGET"
			nargs = '*'
			arg_type = String
            help = "List of all TARGET to explore. In conjunction with -r TARGET can contain directories."
			default = ["."]
    end

    parsed_args = parse_args(args, settings)

	args =parsed_args["TARGET"];

	files = Vector{String}()
	for arg in args
		if isdir(arg) && parsed_args["recursive"]
			files =  vcat(files,[root*"/"*filename for (root, dirs, TARGET) in walkdir(arg) for filename in TARGET  ])
		else
			files =  vcat(files,arg)
		end
	end


	head::Bool =  parsed_args["header"];

	if !isempty(parsed_args["keyword"])
		parse_keywords(files,parsed_args["keyword"])


	elseif !isempty(parsed_args["filter"])
		parse_filter(files,parsed_args["filter"])
	else
		for filename in files
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

end