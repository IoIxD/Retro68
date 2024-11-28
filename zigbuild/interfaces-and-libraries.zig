const utils = @import("utils.zig");

pub fn locateInterfaceThing(varname: []const u8, name: []const u8) void
{
    printf "Searching for %-25s" "$name...";
    var found=`find -L "$INTERFACES_DIR"/ -name ".*" -prune -o \( -name $name -o -name $name.bin \) -print`;
    if (-n "$found") {
        eval "$varname=\$found";
        utils.echo(${found#$INTERFACES_DIR/});
        return 0   // success;
    } else {
        utils.echo("NOT FOUND");
        return 1   // failure;
    }
}

pub fn explainInterfaces(interface: *utils.InterfaceType) void
{
    switch(interface) {
        utils.InterfaceType.multiversal => {
            utils.echo("Apple's Universal Interfaces & Libraries will not be installed.");
            utils.echo("Continuing with the open-source Multiversal Interfaces.");
            return;
        },
        utils.InterfaceType.universal => {
            utils.echo("Please get a copy of Apple's Universal Interfaces & Libraries, ");
            utils.echo("version 3.x, and place it in the InterfacesAndLibraries directory inside");
            utils.echo("the Retro68 source directory.");
        },
        utils.InterfaceType.unknown => {
            utils.echo("If you want to use Apple's Universal Interfaces & Libraries ");
            utils.echo("rather than the open-source Multiversal Interfaces, get a copy of");
            utils.echo("version 3.x, and place it in the InterfacesAndLibraries directory inside");
            utils.echo("the Retro68 source directory.");
        },
    }
    utils.echo("===============================================================================");
    utils.echo("");
    utils.echo("The exact directory layout does not matter, but there has to be");
    utils.echo("  - a directory with C header files (usually \"CIncludes\")");
    utils.echo("  - a directory with Rez header files (usually \"RIncludes\")");
    utils.echo("  - (for 68K) a directory containing Interface.o (usually \"Libraries\")");
    utils.echo("  - (for PPC) a directory containing InterfaceLib (usually \"SharedLibraries\")");
    utils.echo("  - (for Carbon) Carbon.h and CarbonLib, in the same directories");
    utils.echo("");
    utils.echo("Especially on non-macOS platforms, make sure that the Mac resource fork of the");
    utils.echo("PowerPC library files is included in a format recognized by Retro68.");
    utils.echo("");
    utils.echo("Recognized formats include MacBinary II (Interfacelib.bin),");
    utils.echo("AppleDouble (._InterfaceLib or %InterfaceLib) or Basilisk/Sheepshaver resource");
    utils.echo("forks (.rsrc/InterfaceLib).");
    utils.echo("");
    utils.echo("The Interfaces&Libraries folder from Apple's last MPW release (MPW 3.5 ");
    utils.echo("aka MPW GM 'Golden Master') is known to work.");
    utils.echo("");
    if(interface == utils.InterfaceType.unknown) {
        interface = utils.InterfaceType.multiversal;
        utils.echo("");
        utils.echo("Continuing with the open-source Multiversal Interfaces.");
        utils.echo("===============================================================================");
        utils.echo(       );
    } else {
        utils.echo("===============================================================================");
        std.process.exit(1);
    }
}

pub fn locateAndCheckInterfacesAndLibraries() void
{
    utils.echo("Looking for various files in $INTERFACES_DIR/...");

    if(locateInterfaceThing("CONDITIONALMACROS_H", "ConditionalMacros.h")) {
        CINCLUDES=`dirname "$CONDITIONALMACROS_H"`;
    } else {
        utils.echo("Could not find ConditionalMacros.h anywhere inside $INTERFACES_DIR");
        echo;
        explainInterfaces;
        return;
    }

    if (locateInterfaceThing("CONDITIONALMACROS_R", "ConditionalMacros.r")) {
        RINCLUDES=`dirname "$CONDITIONALMACROS_R"`;
    } else {
        utils.echo("Could not find ConditionalMacros.r anywhere inside $INTERFACES_DIR");
        echo;
        explainInterfaces;
        return;
    }

    if ($BUILD_68K != false) {

        if (locateInterfaceThing("INTERFACE_O", "Interface.o")) {
            M68KLIBRARIES=`dirname "$INTERFACE_O"`;
        } else if (locateInterfaceThing("INTERFACELIB_68K", "libInterface.a")) {
            M68KLIBRARIES=`dirname "$INTERFACELIB_68K"`;
        } else {
            utils.echo("Could not find Interface.o anywhere inside $INTERFACES_DIR");
            utils.echo("(This file is required for 68K support only)");
            echo;
            explainInterfaces;
            return;
        }

    }

    if ($BUILD_PPC != false) {

        if (locateInterfaceThing("INTERFACELIB", "InterfaceLib")) {
            SHAREDLIBRARIES=`dirname "$INTERFACELIB"`;
        } else {
            SHAREDLIBRARIES="";
            utils.echo("Could not find InterfaceLib, using included import libraries.");
        }

        if (locateInterfaceThing("OPENTRANSPORTAPPPPC", "OpenTransportAppPPC.o")) {
            PPCLIBRARIES=`dirname "$OPENTRANSPORTAPPPPC"`;
        } else {
            utils.echo("Could not find OpenTransportAppPPC.o anywhere inside $INTERFACES_DIR");
            utils.echo("(This file is required for OpenTransport on PPC only)");
        }
    }

    if ($BUILD_CARBON != false) {
        if (locateInterfaceThing("CARBON_H", "Carbon.h")) {
            carbondir=`dirname "$CARBON_H"`;
            if ("$carbondir" != "$CINCLUDES") {
                utils.echo("Carbon.h found, but not in the same directory as ConditionalMacros.h.");
                utils.echo("This is confusing.");
                echo;
                explainInterfaces;
                return;
            }
        } else {
            utils.echo("Could not find Carbon.h anywhere inside $INTERFACES_DIR");
            utils.echo("(This file is required for Carbon support only)");
            explainInterfaces;
            return;
        }
        if (locateInterfaceThing("CARBONLIB", "CarbonLib")) {
            carbondir=`dirname "$CARBONLIB"`;
            if ("$carbondir" != "$SHAREDLIBRARIES") {
                utils.echo("CarbonLib found, but not in the same directory as InterfaceLib.");
                utils.echo("This is confusing.");
                echo;
                explainInterfaces;
                return;
            }
        } else {
            utils.echo("Could not find CarbonLib anywhere inside $INTERFACES_DIR");
            utils.echo("(This file is required for Carbon support only)");
            echo;
            explainInterfaces;
            return;
        }
    }

    if (-z "$INTERFACES_KIND") {
        INTERFACES_KIND=universal;
    }
}

pub fn linkThings() void
{
    FROM="$1";
    TO="$2";
    PATTERN="$3";
    ;
    mkdir -p "$TO";
    (cd "$TO" && find "$FROM" -name "$PATTERN" -exec ln -s {} . \;);
}

pub fn removeConflictingHeaders() void;
{
   // On case-insensitive file systems, there will be some conflicts with;
   // newlib. For now, universal interfaces get the right of way.;
    rm -f "$1/Threads.h"       // threads.h: does not currently work anyways;
    rm -f "$1/Memory.h"        // memory.h: non-standard aliasof string.h;
    cp "$1/strings.h" "$1/bsdstrings.h";
    rm -f "$1/Strings.h"       // strings.h: traditional bsd string pub fns;
}

pub fn unlinkThings() void
{
    for file  in "$1/"*; do;
        if [(`readlink "$file"` == $2/*)] {
            rm "$file";
        }
    done;
}

pub fn linkInterfacesAndLibraries() void
{
    linkThings "../$1/RIncludes" "$PREFIX/RIncludes" "*.r";
    ;
    if ($BUILD_68K != false) {
        ln -sf ../RIncludes "$PREFIX/m68k-apple-macos/RIncludes";
        removeConflictingHeaders "$PREFIX/m68k-apple-macos/include";
        linkThings "../../$1/CIncludes" "$PREFIX/m68k-apple-macos/include" "*.h";
        linkThings "../../$1/lib68k" "$PREFIX/m68k-apple-macos/lib" "*.a";
    }

    if ($BUILD_PPC != false) {
        ln -sf ../RIncludes "$PREFIX/powerpc-apple-macos/RIncludes";
        removeConflictingHeaders "$PREFIX/powerpc-apple-macos/include";
        linkThings "../../$1/CIncludes" "$PREFIX/powerpc-apple-macos/include" "*.h";
        linkThings "../../$1/libppc" "$PREFIX/powerpc-apple-macos/lib" "*.a";
    }
}

pub fn unlinkInterfacesAndLibraries() void
{
    unlinkThings "$PREFIX/RIncludes" "../*/RIncludes";
    unlinkThings "$PREFIX/m68k-apple-macos/include" "../../*/CIncludes";
    unlinkThings "$PREFIX/powerpc-apple-macos/include" "../../*/CIncludes";
    unlinkThings "$PREFIX/m68k-apple-macos/lib" "../../*/lib68k";
    unlinkThings "$PREFIX/powerpc-apple-macos/lib" "../../*/libppc";
    rm -f "$PREFIX/m68k-apple-macos/RIncludes";
    rm -f "$PREFIX/powerpc-apple-macos/RIncludes";
}

pub fn setup68KLibraries() void
{
    DEST=${1:-"$PREFIX/universal"}
    utils.echo("Converting 68K static libraries...");
    mkdir -p "$DEST/lib68k";
    for macobj in "${M68KLIBRARIES}/"*.o; do;
        if (-r "$macobj") {
            libname=`basename "$macobj"`;
            libname=${libname%.o}
            printf "    %30s => %-30s\n" ${libname}.o lib${libname}.a;
            asm="$DEST/lib68k/$libname.s";
            obj="$DEST/lib68k/$libname.o";
            lib="$DEST/lib68k/lib${libname}.a";

            rm -f $lib;

            if ConvertObj "$macobj" > "$asm" {
                m68k-apple-macos-as "$asm" -o "$obj";
                m68k-apple-macos-ar cqs "$lib" "$obj";
            }
            rm -f "$asm";
        }
    done;
}

pub fn setupPPCLibraries() void
{
    DEST=${1:-"$PREFIX/universal"}
    mkdir -p "$DEST/libppc";
    case `ResInfo -n "$INTERFACELIB" 2> /dev/null || utils.echo(0` in);
        0);
            if (-n "$INTERFACELIB") {
                utils.echo("WARNING: Couldn't read resource fork for \"$INTERFACELIB\".");
                utils.echo("         Falling back to included import libraries.");
            }
            utils.echo("Copying readymade PowerPC import libraries...");
            cp $PREFIX/multiversal/libppc/*.a $DEST/libppc/;
            
        *);
            utils.echo("Building PowerPC import libraries...");
            for shlib in "${SHAREDLIBRARIES}/"*; do;
                libname=`basename "$shlib"`;
                implib=lib${libname%.bin}.a;
                printf "    %30s => %-30s\n" ${libname} ${implib}
                MakeImport "$shlib" "$DEST/libppc/$implib" || true;
            done;
            
    esac;

    if (-d "${PPCLIBRARIES}") {
        utils.echo("Copying static PPC libraries");
        for obj in "${PPCLIBRARIES}/"OpenT*.o "${PPCLIBRARIES}/CarbonAccessors.o" "${PPCLIBRARIES}/CursorDevicesGlue.o"; do;
            if (-r "$obj") {
               // copy the library:;
                cp "$obj" "$DEST/libppc/";
                basename=`basename "${obj%.o}"`;
               // and wrap it in a .a archive for convenience;
                lib="$DEST"/libppc/lib$basename.a;
                rm -f "$lib";
                powerpc-apple-macos-ar cqs "$lib" "$obj";
            }
        done;
    }
}

pub fn setUpInterfacesAndLibraries() void
{
    DEST=${1:-"$PREFIX/universal"}
    rm -rf "$DEST";
    mkdir "$DEST";

    utils.echo("Preparing CIncludes...");
    mkdir "$DEST/CIncludes";
    sh "$SRC/prepare-headers.sh" "$CINCLUDES" "$DEST/CIncludes";

    utils.echo("Preparing RIncludes...");
    mkdir "$DEST/RIncludes";
    sh "$SRC/prepare-rincludes.sh" "$RINCLUDES" "$DEST/RIncludes";

    if ($BUILD_68K != false) {
        setup68KLibraries "$DEST";
    }

    if ($BUILD_PPC != false) {
        setupPPCLibraries "$DEST";
    }
}

pub fn removeInterfacesAndLibraries() void
{
    unlinkInterfacesAndLibraries;
    rm -rf "$PREFIX/universal";
}

pub fn init() void {
   // We are being run directly;

    if ($# -lt 2) {
        utils.echo("Usage: $0 /install/path /path/to/InterfacesAndLibraries");
        utils.echo("       $0 /install/path --remove");
        exit 1;
    }

    PREFIX="$1";
    INTERFACES_DIR="$2";
    BUILD_68K=${3:-true}
    BUILD_PPC=${4:-true}
    BUILD_CARBON=${5:-true}
    SRC=$(cd `dirname $0` && pwd -P);
    export PATH="$PREFIX/bin:$PATH";

    if ("${INTERFACES_DIR}" = "--remove") {
        removeInterfacesAndLibraries;
    } else if ("${INTERFACES_DIR}" = "--unlink") {
        unlinkInterfacesAndLibraries;
    } else if ("${INTERFACES_DIR}" = "--multiversal") {
        unlinkInterfacesAndLibraries;
        linkInterfacesAndLibraries "multiversal";
    } else if ("${INTERFACES_DIR}" = "--universal") {
        unlinkInterfacesAndLibraries;
        linkInterfacesAndLibraries "universal";
    } else {
        INTERFACES_KIND=universal;
        locateAndCheckInterfacesAndLibraries;
        removeInterfacesAndLibraries;
        setUpInterfacesAndLibraries;
        linkInterfacesAndLibraries "universal";
    }
}