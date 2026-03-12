using Pkg
using PackageCompiler

project_root = normpath(joinpath(@__DIR__, ".."))
sysimage_path = joinpath(@__DIR__, "FITSexplore_sysimage.dylib")
precompile_file = joinpath(@__DIR__, "precompile_workload.jl")

Pkg.activate(project_root)
Pkg.instantiate()

create_sysimage(
    ["FITSexplore"];
    project = project_root,
    sysimage_path = sysimage_path,
    precompile_execution_file = precompile_file,
    incremental = true,
)

println("Built sysimage: " * sysimage_path)
println("Run with: julia --startup-file=no --project=$project_root -J $sysimage_path -m FITSexplore -- <args>")
