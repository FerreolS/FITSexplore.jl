#!/usr/bin/env julia

using Printf

project_root = normpath(joinpath(@__DIR__, ".."))
sysimage_path = joinpath(@__DIR__, "FITSexplore_sysimage.dylib")

function default_args()
    sample_file = joinpath(project_root, "samples", "sample.fits")
    return isfile(sample_file) ? [sample_file] : String[]
end

function usage_and_exit()
    println("Usage: julia --project=. benchmark/compare_startup.jl [fitsexplore args...]")
    println("Example: julia --project=. benchmark/compare_startup.jl --header samples/sample.fits")
    return exit(1)
end

function build_command(args::Vector{String}; use_sysimage::Bool)
    julia_cmd = String[
        "julia",
        "--startup-file=no",
        "--project=$project_root",
    ]
    if use_sysimage
        isfile(sysimage_path) || error("Missing sysimage: $sysimage_path")
        push!(julia_cmd, "-J", sysimage_path)
    end
    append!(julia_cmd, ["-e", "using FITSexplore; FITSexplore.main(ARGS)", "--"])
    append!(julia_cmd, args)
    return Cmd(julia_cmd)
end

function run_once(cmd::Cmd)
    out = PipeBuffer()
    err = PipeBuffer()
    t0 = time_ns()
    ok = success(pipeline(cmd, stdout = out, stderr = err))
    elapsed = (time_ns() - t0) / 1.0e9
    return (
        ok = ok,
        elapsed = elapsed,
        stdout = String(take!(out)),
        stderr = String(take!(err)),
    )
end

function report(label::AbstractString, result)
    return @printf("%-20s %8.3f s | ok=%s\n", label, result.elapsed, string(result.ok))
end

args = isempty(ARGS) ? default_args() : copy(ARGS)
isempty(args) && usage_and_exit()

println("Comparing startup for arguments:")
println("  ", join(args, " "))
println()

baseline_cold = run_once(build_command(args; use_sysimage = false))
baseline_warm = run_once(build_command(args; use_sysimage = false))
sysimage_cold = run_once(build_command(args; use_sysimage = true))
sysimage_warm = run_once(build_command(args; use_sysimage = true))

report("baseline cold", baseline_cold)
report("baseline warm", baseline_warm)
report("sysimage cold", sysimage_cold)
report("sysimage warm", sysimage_warm)

if !baseline_cold.ok || !baseline_warm.ok || !sysimage_cold.ok || !sysimage_warm.ok
    println()
    println("Last stderr output:")
    println(sysimage_warm.stderr)
    exit(2)
end
