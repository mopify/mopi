[![Travis build](https://travis-ci.org/scottclowe/mopi.svg?branch=master)](https://travis-ci.org/scottclowe/mopi)
[![Shippable build](https://img.shields.io/shippable/56b101e71895ca44747335db/master.svg?label=shippable)](https://app.shippable.com/projects/56b101e71895ca44747335db)
[![Coveralls report](https://coveralls.io/repos/scottclowe/mopi/badge.svg?branch=master&service=github)](https://coveralls.io/github/scottclowe/mopi?branch=master)
[![Codecov report](https://codecov.io/github/scottclowe/mopi/coverage.svg?branch=master)](https://codecov.io/github/scottclowe/mopi?branch=master)

MOPI: MATLAB/Octave Package Installer
=====================================

MOPI provides a useful way to install dependencies for MATLAB and
Octave.

There are two methods available to install dependency packages, one is the
shell script `mopi.sh`, and the other is a MATLAB function `mopi.m`.

These lightweight utilities can be included in any MATLAB/Octave project which
has non-trivial dependencies either by using a [submodule] of
[this repository], or including them as a static copy along with the [LICENSE]
file, which can potentially be managed and updated using [git subtree].


Usage
-----

On *nix, one can download requirements specified in a file named
`requirements.txt` with the bash script:

```bash
mopi.sh requirements.txt
```

On all systems, at the MATLAB or Octave command prompt one can do:

```matlab
mopi('requirements.txt')
```

By default, the shell script will download packages into a folder called
`external` in the present directory, whereas the `.m` function will ask for an
installation destination using a command prompt.

To specify a download location at the terminal, one can need only provide it
as a second input with

```bash
mopi.sh requirements.txt DOWLOAD_FOLDER
```

or equivalently

```matlab
mopi('requirements.txt', DOWLOAD_FOLDER)
```

Each non-Forge package will be downloaded into a folder within DOWLOAD_FOLDER
corresponding to the inferred name of the package.

The `.m` function for MATLAB and Octave can alternatively be given the name of
a single package, or cell array of packages instead of a file listing packages.

```matlab
mopi(PACKAGE_NAME)
```

The `.m` function can optionally add the downloaded packages to the path
immediately (by default this is enabled).


Specification
-------------

This package offers three ways to install other MATLAB and Octave packages.
These are
  - from MATLAB FileExchange
  - from Octave Forge
  - from generic URL


### MATLAB FileExchange (FEX)

Packages on [MATLAB FileExchange][fex] should preferably be specified with the
protocol scheme `fex://`.
This should be followed by the FEX ID of the package.
The FEX ID can be determined from the URL of the package, e.g.
<https://www.mathworks.com/matlabcentral/fileexchange/55540-dummy-package>,
or the `File ID` field on this page.
In this case, the FEX ID is `55540`.

For example, the package can be specified by

    fex://55540

or alternatively, the name can be included, such as

    fex://55540-dummy-package

which will be stripped out during processing.

Each FEX package will be installed into a folder matching the FEX ID of the
package, such as `55540`, with the downloaded contents unzipped into this
folder.

If an entry does not have a protocol prefix, but is solely numeric (or numeric
and then a hyphen) it is assumed to be a FEX package.

For example,

    55540-dummy-package

is implicitly a FEX package and will be interpretted as such.


### Octave Forge

Packages on [Octave Forge][forge] should preferably be specified with the
protocol scheme `forge://`.
This should be followed by the name of the package.

For example

    forge://control

Forge requirements are ignored if the `.m` function is run on MATLAB instead
of Octave.
The shell script will install Forge dependencies only if a command `octave`
can be found on the system, otherwise Forge dependencies are quietly ignored.

Care should be taken to make sure the packages are installed in the correct
order, lest an error be thrown due to a missing dependency of a dependency.

For instance, the `statistics` package
[requires](http://octave.sourceforge.net/statistics/)
the `io` package, so in a `requirements.txt` file one should specify

    forge://io
    forge://statistics

and not

    forge://statistics
    forge://io

For example,

    control

is implicitly a Forge package and will be interpretted as such.


### Uniform Resource Locator (URL)

All other protocols are handled the same way, and will be downloaded with
`wget` or similar over HTTP, HTTPS, FTP, etc.

The name of the package is inferred from the (extensionless) filename which the
URL points to.
The package will then be installed into a subfolder matching this inferred
package name.
If the downloaded file is an archive it will be decompressed, otherwise it will
be copied as-is.

For example,

    http://www.mathworks.com/moler/ncm.zip

or

    http://www.mathworks.com/moler/ncm.tar.gz

would both be decompressed into a folder `ncm`.


### Comments

Comments can be inserted into requirements files by prepending them with a `#`.
Entire lines can be commented out, or inline comments can be used.
Inline comments must have a space separating them from actual content, lest
the `#` be confused with a URL anchor

    # This file contains a demo
    fex://55540  # This is a dummy package


Example
-------

Here is an example file listing package requirements.

**requirements.txt**

    # Requirements for package foo
    forge://control
    fex://55540-dummy-package
    http://www.mathworks.com/moler/ncm.zip

If one wishes to only install requirements when they are needed in the code,
the following method can be used:

```matlab
if ~exist('dummy.txt', 'file')
    mopi('fex://55540');
end
```


Differences between .sh and .m implementations
----------------------------------------------

There are a small number of differences between the shell and native matlab
implementations of MOPI.
  - The shell script can infer archives from their MIME type;
    the matlab function can only use file extensions.
  - The shell script can unpack a wider variety of archive file types (provied
    an appropriate utility bash command is available);
    on MATLAB, the `.m` function is restricted to only `.zip`, `.gz`, `.tar`,
    (and `.tar.gz` or `.tgz`);
    on Octave, the `.m` function is restricted to `.zip`, `.gz`, `.tar`, `.bz`
    and `.z`.
  - The shell script can save the downloaded files to a cache directory to use
    in future;
    the matlab function always discards downloaded files.
    This feature should be useful when repeatedly installing dependencies, for
    unit testing on a continous integration server such as Travis, say.
  - The matlab function can optionally add the downloaded packages to the
    MATLAB/Octave search path;
    the shell script cannot.


Notes
-----

MOPI was inspired by [requireFEXpackage] and [pip].


  [this repository]:    https://github.com/scottclowe/mopi
  [LICENSE]:            https://github.com/scottclowe/mopi/blob/master/LICENSE
  [forge]:              http://octave.sourceforge.net/
  [fex]:                https://www.mathworks.com/matlabcentral/fileexchange
  [submodule]:          https://git-scm.com/book/en/v2/Git-Tools-Submodules
  [git subtree]:        https://medium.com/@porteneuve/mastering-git-subtrees-943d29a798ec
  [requireFEXpackage]:  https://www.mathworks.com/matlabcentral/fileexchange/31069-require-fex-package
  [pip]:                https://pip.pypa.io/en/stable/reference/pip_install
