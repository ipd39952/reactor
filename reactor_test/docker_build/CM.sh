#!/bin/sh

binDir=`dirname "$0"`
NPS_INSTANCEDIR=`cd "$binDir/.." && /bin/pwd`
export NPS_INSTANCEDIR
NPS_BASEDIR=`cd "$NPS_INSTANCEDIR/../.." && /bin/pwd`
export NPS_BASEDIR

# just deactivate the following line to not override (a compatible and configured) system's ImageMagick
imageMagickBase="$NPS_BASEDIR"/3rdparty/ImageMagick

test -n "$imageMagickBase" && test -d "$imageMagickBase" && {
    LD_LIBRARY_PATH="$imageMagickBase"/lib:$LD_LIBRARY_PATH
    PATH="$imageMagickBase"/bin:"$PATH"

    for path in "$imageMagickBase"/lib/ImageMagick-*; do
        imageMagickLibPath="$path"
    done
    MAGICK_CONFIGURE_PATH="$imageMagickLibPath"/config
    export MAGICK_CONFIGURE_PATH
    MAGICK_FILTER_MODULE_PATH="$imageMagickLibPath"/modules-Q16/filters
    export MAGICK_FILTER_MODULE_PATH
    MAGICK_CODER_MODULE_PATH="$imageMagickLibPath"/modules-Q16/coders
    export MAGICK_CODER_MODULE_PATH
}

LIB_FOUNDATION_RESOURCES_PATH="$NPS_BASEDIR"/3rdparty/libFoundation
export LIB_FOUNDATION_RESOURCES_PATH

PATH="$NPS_BASEDIR"/3rdparty/bin:"$PATH"
export PATH

test -x "$NPS_BASEDIR"/3rdparty/bin/tclsh && {
    for path in "$NPS_BASEDIR"/3rdparty/lib/tcl?.?; do
        TCL_LIBRARY="$path"
        export TCL_LIBRARY
    done
    TCLLIBPATH="$NPS_BASEDIR"/3rdparty/lib
    export TCLLIBPATH
}

LD_LIBRARY_PATH="$NPS_BASEDIR"/lib:"$NPS_BASEDIR"/3rdparty/lib:"$LD_LIBRARY_PATH"

LD_LIBRARY_PATH="$NPS_BASEDIR"/lib/sles:"$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

PATH="$NPS_BASEDIR/3rdparty/wdiff/bin":"$PATH"
export PATH

exec "$NPS_BASEDIR/lib/CM.bin" "$@"
