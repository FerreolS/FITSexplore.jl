# FITSexplore

[![License][license-img]][license-url] [![Build Status][github-ci-img]][github-ci-url] [![Coverage][codecov-img]][codecov-url] [![Aqua QA][aqua-img]][aqua-url]

Simple command-line tool and Julia package to explore FITS file content.

## Package API

`FITSexplore` exports 2 functions:

- `fitsexplore(dir::String) -> Dict{String, FitsHeader}` builds a dictionary mapping each supported FITS filename to its primary header.
- `filter_keyword!(filelist, filters)` filters in place  a file list produced by `fitsexplore`  according to `filters`, a dictionary mapping each keyword to a value or a list of allowed values.

Small example:

```julia
using FITSexplore

files = fitsexplore(".")
filter_keyword!(files, Dict("NAXIS" => 2, "EXTNAME" => ["SCI", "PRIMARY"]))

# `files` now contains only entries matching all filters.
```

## Command line tool

### Usage

```text
fitsexplore [-l] [-d] [-s] [-k KEYWORD] [-f KEYWORD VALUE] [--set KEYWORD VALUE [COMMENT]] [-u HDU] [-r] [--version] [-h] [TARGET...]
```

Alternative module invocation:

```bash
julia -m FITSexplore -- [options] [TARGET...]
```

#### Without optional argument

By default, `fitsexplore` lists all HDU for each FITS file in `TARGET`.
Each output line includes file name, HDU index, and type (plus `EXTNAME` when present).

`TARGET` can contain files with extensions `.fits`, `.fits.gz`, `fits.Z`, `.oifits`, `.oifits.gz`, `.oifits.Z`.

```console
me@host:~$ fitsexplore GRAVI.fits.Z
.
  GRAVI.fits.Z
    EXTNUM  EXTNAME TYPE
    1       ""      PRIMARY
    2       "ARRAY_DESCRIPTION" BINTABLE
    3       "ARRAY_GEOMETRY" BINTABLE
    4       "OPTICAL_TRAIN" BINTABLE
```

#### -l, --list

Explicitly list HDU (same behavior as default mode).
Malformed FITS files are reported as warnings only in this explicit list mode.

```console
me@host:~$ fitsexplore -l file.fits
.
  file.fits
  EXTNUM  EXTNAME TYPE
  1       ""      PRIMARY
  2       "SCI"   IMAGE
```

#### -r,--recursive

Recursively explores entire directories given by TARGET. If no TARGET is given it will explore the working directory.

#### -d, --header

Display the FITS header of the `TARGET`

```console
me@host:~$ fitsexplore -d file.fits
SIMPLE  =                    T / file does conform to FITS standard
BITPIX  =                  -32 / number of bits per data pixel
NAXIS   =                    2 / Dimensionality
NAXIS1  =                  242 / width of row in bytes
NAXIS2  =                  242 / number of rows in table
EXTEND  =                    T / File contains extensions
CRPIX1  =                122.0 / Reference pixel
CRPIX2  =                122.0 / Reference pixel
CRVAL1  =                  0.0 / Coordinate at reference pixel
CRVAL2  =                  0.0 / Coordinate at reference pixel
CDELT1  = 6.944444444444445e-8 / Coord. incr. per pixel
CDELT2  = 6.944444444444445e-8 / Coord. incr. per pixel
CUNIT1  = 'deg     '           / Physical units for CDELT1 and CRVAL1
CUNIT2  = 'deg     '           / Physical units for CDELT2 and CRVAL2
HDUNAME = 'IMAGE-OI FINAL IMAGE' / unique name for the image within the FITS file
```

#### -s, --stats

Display statistical information for image HDU.
By default all image HDU are shown; use `-u/--hdu` to select specific HDU.

```console
me@host:~$ fitsexplore -s file.fits
file.fits  hdu :SCI
size (640, 640)  eltype Float32  mean 16170.782  std 10711.193  median 17808.355  mad 10895.537 min 0.0 max 65535.0
```

#### -k, --keyword `KEYWORD`

Print the value of the FITS header `KEYWORD`.
This argument can be set multiple times to display several FITS keywords.

```console
me@host:~$ fitsexplore -k "ESO DPR TYPE" -k "ESO DET2 SEQ1 DIT" -k  "ESO DET2 NDIT" -r /path/to/folder
/path/to/folder/file1.fits.Z             STD,SINGLE      3.0     120
/path/to/folder/file2.fits.Z             STD,SINGLE      3.0     120
/path/to/folder/file3.fits.Z             SKY,SINGLE      3.0     120
/path/to/folder/file4.fits.Z             SKY,SINGLE      30.0    12
/path/to/folder/file5.fits.Z             STD,SINGLE      30.0    8
/path/to/folder/file6.fits.Z             DARK    0.3     100
/path/to/folder/file7.fits.Z             DARK    3.0     100
/path/to/folder/file8.fits.Z             DARK    30.0    30
```

#### -f, --filter `KEYWORD` `VALUE`

Print all files where the FITS header `KEYWORD` = `VALUE`.

```console
me@host:~$ fitsexplore -f "ESO DPR TYPE"  "DARK" -r /path/to/folder
/path/to/folder/file6.fits.Z
/path/to/folder/file7.fits.Z
/path/to/folder/file8.fits.Z
```

#### --set `KEYWORD` `VALUE` `[COMMENT]`

Set or replace FITS header `KEYWORD` with `VALUE` on selected files/HDU.

- `VALUE` is parsed as `Bool` (`true`/`false`), `Int`, `Float64`, or `String`.
- If `-u/--hdu` is omitted, only HDU `1` is modified.
- If `COMMENT` is provided, the keyword comment is also updated.

```console
me@host:~$ fitsexplore --set OBJECT M42 file.fits
file.fits
```

```console
me@host:~$ fitsexplore --set EXPTIME 30.0 "Exposure time (s)" -u 2 file.fits
file.fits#2
```

Note: because `COMMENT` is optional and positional, pass it only when a target path follows it.
For example, `fitsexplore --set OBJECT M42 file.fits` sets no comment, while
`fitsexplore --set OBJECT M42 "Object name" file.fits` sets comment `Object name`.

### Other Command-line usage examples

- Adding a keyword value in the filename:

```console
me@host:~$ fitsexplore -k "ESO DPR TYPE" | awk  '{system("mv "$1" "$2"_"$1)}'
```

- Displaying the size of files of a given type:

```console
me@host:~$ ls -lh $(fitsexplore -f "ESO DPR TYPE" "DARK" /path/to/folder)
```

## Installation

### Standard (Julia app)

Install the package as a Julia app:

```julia-pkg
pkg> app add https://github.com/FerreolS/FITSexplore.jl
```

Make sure `~/.julia/bin` is in your `PATH`, then run:

```bash
fitsexplore --help
```

### Downloading a self-contained relocatable binary

A `.tar.gz` archive of relocatable binaries of last release are available in  the [`exe` orphan branch](https://github.com/FerreolS/FITSexplore.jl/tree/exe). The bundle requires no Julia installation and can be copied to any path.

### Building a self-contained relocatable binary

The fully self-contained, relocatable binary bundle can be built with [JuliaC](https://github.com/JuliaLang/JuliaC.jl).

**Prerequisites:** Julia ≥ 1.12.

**Build**
The repository includes a `Makefile` to build the relocatable. Once built the binary can be installed under `~/.julia/bundles`, with an executable launcher in `~/.julia/bin`.

From the repository root:

```bash
make build
make install
```

Equivalent direct Julia commands are:

```bash
julia make.jl build
julia make.jl install
```

After `make install`, you get:

- bundle directory: `~/.julia/bundles/fitsexplore-bundle/`
- executable symlink: `~/.julia/bin/fitsexplore`

Make sure `~/.julia/bin` is in your `PATH`:

```bash
echo 'export PATH="$HOME/.julia/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
fitsexplore --help
```

Optional targets:

```bash
make uninstall   # remove ~/.julia/bin/fitsexplore and ~/.julia/bundles/fitsexplore-bundle
make clean       # remove local build directory (default: ./build-juliac)
```

You can override build/install locations and options:

```bash
make install BUNDLE_DIR=build-juliac TRIM_MODE=safe INSTALL_ROOT="$HOME/.julia/bundles/fitsexplore-bundle"
```

## Performance

macOS, Apple Intel, 20 warm runs via `hyperfine`:

|     | --help | more complex call |
|---|---|---|
| Julia app  | 1.03 s |  1.04 s |
| Relocatable bundle | 53 ms | 106 ms | 

[license-url]: ./LICENSE.md
[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat
[github-ci-img]: https://github.com/FerreolS/FITSexplore.jl/actions/workflows/CI.yml/badge.svg?branch=master
[github-ci-url]: https://github.com/FerreolS/FITSexplore.jl/actions/workflows/CI.yml?query=branch%3Amaster
[codecov-img]: http://codecov.io/github/FerreolS/FITSexplore.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/FerreolS/FITSexplore.jl?branch=master
[aqua-img]: https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg
[aqua-url]: https://github.com/JuliaTesting/Aqua.jl
