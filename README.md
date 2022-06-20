# FITSexplore

Simple command line script to explore FITS files content.

## Usage

```FITSexplore [-d] [-k KEYWORD] [-f KEYWORD VALUE] [-r] [--version] [-h] [TARGET...]```

#### Without optional argument

it will display the name and the type of all HDU
contained in the files `TARGET`. The `TARGET` can contain any files with extension : .fits, .fits.gz, fits.Z, .oifits

```console
me@host:~$ FITSexplore GRAVI.fits.Z
FITS(filename) = File: GRAVI.fits.Z
Mode: "r" (read-only)
HDUs: Num  Name                  Type
      1                          Image
      2    ARRAY_DESCRIPTION     Table
      3    ARRAY_GEOMETRY        Table
      4    OPTICAL_TRAIN         Table
      5    IMAGING_DATA_ACQ      Image
      6    IMAGING_DATA_SC       Image
      7    IMAGING_DETECTOR_SC   Table
      8    OPDC                  Table
      9    FDDL                  Table
```

#### -r,--recursive

Recursively explores entire directories given by TARGET. If no TARGET is given it will explore the working directory.

#### -d, --header

Display the FITS header of the `TARGET`

```console
me@host:~$ FITSexplore -d file.fits
read(FitsHeader, filename) = SIMPLE  =                    T / file does conform to FITS standard
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
HDUNAME = 'IMAGE-OI FINAL IMAGE' / Unique name for the image within the FITS file
```

#### -k, --keyword `KEYWORD`

Print the value of the FITS header `KEYWORD`.
This argument can be set multiple times to display several FITS keywords.

```console
me@host:~$ FITSexplore -k "ESO DPR TYPE" -k "ESO DET2 SEQ1 DIT" -k  "ESO DET2 NDIT" -r /path/to/folder
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
me@host:~$ FITSexplore -f "ESO DPR TYPE"  "DARK" -r /path/to/folder
/path/to/folder/file6.fits.Z
/path/to/folder/file7.fits.Z
/path/to/folder/file8.fits.Z
```

### Other examples

* Adding a keyword value in the filename:

```console
me@host:~$ FITSexplore -k "ESO DPR TYPE" | awk  '{system("mv "$1" "$2"_"$1)}'
````

* Displaying the size of files of a given type:

```console
me@host:~$ ls -lh $(FITSexplore -f "ESO DPR TYPE" "DARK" -r /path/to/folder)
````

## Installation
* As FITSexplore use  [EasyFITS.jl](https://github.com/emmt/EasyFITS.jl), the `EmmtRegistry` must be added to your Julia package manager:
* 
```julia
using Pkg
pkg"registry add https://github.com/emmt/EmmtRegistry"
```

* Install the unregistered Julia package FITSexplore.jl.

```julia
pkg> add https://github.com/FerreolS/FITSexplore.jl
```

* Copy the script `FITSexplore` located in the bin folder to your favorite `bin` folder included in your `PATH` (e.g `$HOME/bin`, `/usr/local/bin`, `~/Applications`). This script can be found in the folder `.julia/packages/FITSexplore`.
* Make the script executable.

```julia
chmod +x FITSexplore
```
