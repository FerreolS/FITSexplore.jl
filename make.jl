#!/usr/bin/env julia

"""
Build a relocatable FITSexplore executable bundle with JuliaC.

Environment overrides:
  JULIAC_ENV   Julia environment for JuliaC (default: /tmp/juliac-env)
  BUNDLE_DIR   Output bundle directory (default: build-juliac)
  EXE_NAME     Executable name (default: fitsexplore)
  TRIM_MODE    JuliaC trim mode (default: safe)
  EXPERIMENTAL Set to 0/false/no to disable --experimental (default: enabled)
"""

using Pkg

const ROOT = @__DIR__
const JULIAC_ENV = get(ENV, "JULIAC_ENV", "/tmp/juliac-env")
const BUNDLE_DIR = get(ENV, "BUNDLE_DIR", "build-juliac")
const EXE_NAME = get(ENV, "EXE_NAME", "fitsexplore")
const TRIM_MODE = get(ENV, "TRIM_MODE", "safe")

function envflag(name::String, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "1" : "0")))
    return !(raw in ("0", "false", "no", "off"))
end

const USE_EXPERIMENTAL = envflag("EXPERIMENTAL", true)

function ensure_juliac_env(path::String)
    mkpath(path)
    Pkg.activate(path; io=devnull)
    Pkg.add("JuliaC")
    Pkg.instantiate()
end

function build_bundle()
    outdir = abspath(ROOT, BUNDLE_DIR)
    isdir(outdir) && rm(outdir; recursive=true, force=true)

    args = String[
        "--output-exe", EXE_NAME,
        "--bundle", BUNDLE_DIR,
        "--trim=$(TRIM_MODE)",
    ]
    USE_EXPERIMENTAL && push!(args, "--experimental")
    push!(args, ".")

    base = Base.julia_cmd()
    cmd = Cmd(
        Cmd(
            vcat(
                base.exec,
                [
                    "--startup-file=no",
                    "--project=$(JULIAC_ENV)",
                    "-e",
                    "using JuliaC; JuliaC.main(ARGS)",
                    "--",
                ],
                args,
            ),
        );
        dir=ROOT,
    )
    run(cmd)

    exe = joinpath(outdir, "bin", EXE_NAME)
    isfile(exe) || error("Bundle build failed: missing executable $(exe)")
    println("Bundle ready: ", exe)
end

ensure_juliac_env(JULIAC_ENV)
build_bundle()
