"""

Package `FITSexplore`

"""
module FITSexplore

export fitsexplore

using FITSIO, ArgParse, StatsBase, UnicodePlots

const suffixes = [".fits", ".fits.gz","fits.Z",".oifits",".oifits.gz",".oifits.Z"]



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
function filtercat(filelist::Dict{String, FITSHeader},
	keyword::String,
	values::Union{Vector{String}, Vector{Bool}, Vector{Integer}, Vector{AbstractFloat}})
	newlist = Dict{String, FITSHeader}()
	for value in values
		merge!(newlist, filtercat(filelist,keyword,value))
	end
	return newlist
end

function filtercat(filelist::Dict{String, FITSHeader},
	keyword::String,
	value::Union{String, Bool, Integer, AbstractFloat, Nothing})
	try tmp = filter(p->p.second[keyword] == value,filelist)
		return  tmp
	catch
		return Dict{String, FITSHeader}()
	end
end


function fitsexplore(dir::String)
	filedict = Dict{String, FITSHeader}()
	
	for filename in readdir(dir,join=true)
		if isfile(filename)
			if endswith(filename,suffixes)
				get!(filedict, filename) do
					read_header(filename)
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
				header  = read_header(filename)
				str = ""
				iskeyword = true
				for key in keywords
					if haskey(header,key)
						str = str * "\t" * string(header[key])
					else
						iskeyword = false
					end
				end
				if iskeyword
					println(filename ,"\t", str)
				end
			end
		end
	end
end

function parse_filter(args::Vector{String}, filter::Vector{String} )
	for filename in args
		if isfile(filename)
			if endswith(filename,suffixes)
				header  = read_header(filename)
				if haskey(header,filter[1])
					if comparekeys(header[filter[1]],filter[2])
						println(filename)
					end
				end
			end
		end
	end
end

function comparekeys(key1::AbstractString,key2::AbstractString)
	return key1==key2
end

function comparekeys(key1::Bool,key2::AbstractString)
	p = false
	if (lowercase(key2)=="true") | (lowercase(key2)=="t")| (key2=="1")
		p = true
	elseif (lowercase(key2)=="false") | (lowercase(key2)=="f")| (key2=="0")
		p = false
	else
		return false
	end
	return key1==p
end
function comparekeys(key1::Number,key2::AbstractString)
	return key1==Meta.parse(key2)
end


function print_stats(a)
	# println("size \t \t type \t\tminimum\tmaximum\tmean\tstd\tmedian\tmad")
	# println(size(a), "\t", eltype(a),"\t",round.(minimum(a); digits=4),"\t",
	#           round.(maximum(a); digits=4),"\t",round.(mean(a); digits=4),"\t",
	#           round.(std(a); digits=4),"\t",round.(median(a); digits=4),"\t",
	#           round.(mad(a); digits=4))
	
	
	med= median(a)
	madd= mad(a,center=med)
	minn =round.(minimum(a); digits=4) 
	maxx =round.(maximum(a); digits=4) 
	println(
		"size ", size(a), "  eltype ", eltype(a),
		"  mean ", round.(mean(a); digits=4), "  std ", round.(std(a); digits=4),
		"  median ", round.(med; digits=4), "  mad ", round.(madd; digits=4)
	)
	try 
		h = fit(Histogram,a[:], range(max(minn,med-3*madd),min(maxx,med+3*madd),50)) 
		W = h.weights
		barsyms = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']
		symidxs = eachindex(barsyms)
		norm_factor = length(symidxs) / maximum(W)
		get_sym_idx(x) = isnan(x) ? 1 : clamp(first(symidxs) + floor(Int, norm_factor * x), first(symidxs), last(symidxs))
		print(minn)
		print(String(barsyms[get_sym_idx.(W)]))
		print(maxx)
	catch e
		@warn "cannot compute histogram" e
		return (minn, maxx)
	end
	return  (max(minn,med-3*madd),min(maxx,med+3*madd))
end

name(hdu::HDU) = FITSIO.fits_try_read_extname(hdu.fitsfile)



function main(args)
	
	settings = ArgParseSettings(prog = "FITSexplore",
	#version = @project_version,
	version = "0.2",
	add_version = true)
	
	settings.description =  "Simple tool to explore the content of FITS files.\n\n"*
	"Without any argument, it will display the name and the type of all HDU contained in the files TARGET."
	@add_arg_table! settings begin
		"--header", "-d"
		help = "header"
		action = :store_true
		help = "Print the whole FITS header."
		"--stats", "-s"
		action = :store_true
		help = "Print the statistics of all image HDU"
		"--plot", "-p"
		action = :store_true
		help = "show the statistic and plot all  HDU"
		"--hdu", "-u"
		nargs = 1
		action = :append_arg
		arg_type = Int
		help = "Select the hdu by number in conjunction with -p, -s, -d"
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
	stats::Bool =  parsed_args["stats"];
	plott::Bool =  parsed_args["plot"];

	if !isempty(parsed_args["keyword"])
		parse_keywords(files,parsed_args["keyword"])
	elseif !isempty(parsed_args["filter"])
		parse_filter(files,parsed_args["filter"])
	else
		for filename in files
			if isfile(filename)
				if endswith(filename,suffixes)
					if head
						if !isempty(parsed_args["hdu"])
							for index ∈ reduce(vcat,parsed_args["hdu"])
								@show read_header(filename, hduindex =index)
							end
						else
							@show read_header(filename)
						end
					elseif (stats || plott)
						f= FITS(filename)

						if !isempty(parsed_args["hdu"])
							
							for index ∈ reduce(vcat,parsed_args["hdu"])
								hdu = f[index]
								if isa(hdu, ImageHDU) 
									if (size(hdu) == ())
										continue
									else
										println(filename, "  hdu :", name(hdu))
										data =read(hdu) 
										(minn, maxx) = print_stats(read(hdu))
										println()
										if plott
											if ndims(data) ==3
												display(heatmap(clamp.(mean(data,dims=3)[:,:,1],minn,maxx)'))
											else
												display(heatmap(clamp.(data,minn,maxx)'))
											end
											
										end
									end
								end
							end
						else
							for hdu ∈ f
								if isa(hdu, ImageHDU) 
									if (size(hdu) == ())
										continue
									else
										println(filename, "  hdu :", name(hdu))
										data =read(hdu) 
										(minn, maxx) = print_stats(read(hdu))
										println()
										if plott
											if ndims(data) ==3
												display(heatmap(clamp.(mean(data,dims=3)[:,:,1],minn,maxx)'))
											else
												display(heatmap(clamp.(data,minn,maxx)'))
											end
											
										end
									end
								end
							end
						end
					elseif !isempty(parsed_args["hdu"])
						@show read_header(filename[parsed_args["hdu"]])
					else
						@show FITS(filename)
					end

				end
			end
		end
	end

end

end