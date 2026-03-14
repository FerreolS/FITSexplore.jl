#!/usr/bin/env julia

"""
Build and install a relocatable FITSexplore executable bundle with JuliaC.

Usage:
    julia make.jl [build|install|uninstall|clean]

Default action is `build` if no argument is provided.

Environment overrides:
    JULIAC_ENV    Julia environment for JuliaC (default: /tmp/juliac-env)
    BUNDLE_DIR    Output bundle directory (default: build-juliac)
    EXE_NAME      Executable name (default: fitsexplore)
    TRIM_MODE     JuliaC trim mode (default: safe)
    EXPERIMENTAL  Set to 0/false/no to disable --experimental (default: enabled)
    INSTALL_ROOT  Install location for the bundle (default: ~/.julia/bundles/<EXE_NAME>-bundle)
    BIN_DIR       Directory for launcher symlink (default: ~/.julia/bin)
"""

using Pkg

const ROOT = @__DIR__
const JULIAC_ENV = get(ENV, "JULIAC_ENV", "/tmp/juliac-env")
const BUNDLE_DIR = get(ENV, "BUNDLE_DIR", "build-juliac")
const EXE_NAME = get(ENV, "EXE_NAME", "fitsexplore")
const TRIM_MODE = get(ENV, "TRIM_MODE", "safe")
const INSTALL_ROOT = abspath(expanduser(get(ENV, "INSTALL_ROOT", joinpath("~", ".julia", "bundles", "$(EXE_NAME)-bundle"))))
const BIN_DIR = abspath(expanduser(get(ENV, "BIN_DIR", joinpath("~", ".julia", "bin"))))

function envflag(name::String, default::Bool)
    raw = lowercase(strip(get(ENV, name, default ? "1" : "0")))
    return !(raw in ("0", "false", "no", "off"))
end

const USE_EXPERIMENTAL = envflag("EXPERIMENTAL", true)

function ensure_juliac_env(path::String)
    mkpath(path)
    Pkg.activate(path; io = devnull)
    Pkg.add("JuliaC")
    return Pkg.instantiate()
end

function build_bundle()
    outdir = abspath(ROOT, BUNDLE_DIR)
    isdir(outdir) && rm(outdir; recursive = true, force = true)

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
        dir = ROOT,
    )
    run(cmd)

    exe = joinpath(outdir, "bin", EXE_NAME)
    isfile(exe) || error("Bundle build failed: missing executable $(exe)")
    println("Bundle ready: ", exe)
    return exe
end

function install_bundle()
    ensure_juliac_env(JULIAC_ENV)
    build_bundle()

    mkpath(dirname(INSTALL_ROOT))
    mkpath(BIN_DIR)

    ispath(INSTALL_ROOT) && rm(INSTALL_ROOT; recursive = true, force = true)
    cp(abspath(ROOT, BUNDLE_DIR), INSTALL_ROOT; force = true)

    link_path = joinpath(BIN_DIR, EXE_NAME)
    ispath(link_path) && rm(link_path; force = true)
    symlink(joinpath(INSTALL_ROOT, "bin", EXE_NAME), link_path)

    println("Installed ", EXE_NAME, " to ", INSTALL_ROOT)
    println("Symlink: ", link_path, " -> ", joinpath(INSTALL_ROOT, "bin", EXE_NAME))
    return nothing
end

function uninstall_bundle()
    link_path = joinpath(BIN_DIR, EXE_NAME)
    ispath(link_path) && rm(link_path; force = true)
    ispath(INSTALL_ROOT) && rm(INSTALL_ROOT; recursive = true, force = true)
    println("Removed ", EXE_NAME, " from ", BIN_DIR, " and ", INSTALL_ROOT)
    return nothing
end

function clean_bundle()
    outdir = abspath(ROOT, BUNDLE_DIR)
    ispath(outdir) && rm(outdir; recursive = true, force = true)
    println("Removed ", outdir)
    return nothing
end

function main(args::Vector{String})
    action = isempty(args) ? "build" : args[1]
    if action == "build"
        ensure_juliac_env(JULIAC_ENV)
        build_bundle()
    elseif action == "install"
        install_bundle()
    elseif action == "uninstall"
        uninstall_bundle()
    elseif action == "clean"
        clean_bundle()
    else
        error("unknown action: $(action). Expected one of: build, install, uninstall, clean")
    end
    return nothing
end

main(ARGS)
