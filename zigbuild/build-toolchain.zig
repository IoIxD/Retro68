const std = @import("std");

const allocator = std.heap.page_allocator;

const utils = @import("utils.zig");

fn c_required() void {
    utils.echo("**** Apple's version of GCC on Power Macs is too old.");
    utils.echo("**** Please explicitly specify the C and C++ compilers");
    utils.echo("**** using the --host-c-compiler and --host-cxx-compiler options.");
    utils.echo("**** You can utils.install a usable compiler using tigerbrew.");
    std.process.exit(1);
}

fn interface_note() void {
    utils.echo("##// WARNING:");
    utils.echo("##// Different from previous versions, Retro68 now expects to find");
    utils.echo("##// header files and libraries inside the InterfacesAndLibraries diretory.");
}

pub fn build(buil: *std.Build) !void {
    utils.echo("Starting");
    const src = try std.fs.cwd().realpathAlloc(allocator, ".");

    const prefix = buil.option([]const u8, "prefix", "the path to utils.install the toolchain to") orelse try utils.concat(.{ src, "/toolchain" });
    var skip_thirdparty = buil.option(bool, "skip-thirdparty", "do not rebuild gcc & third party libraries") orelse false;
    const no_68k = buil.option(bool, "no-68k", "disable support for 68K Macs") orelse false;
    const no_ppc = buil.option(bool, "no-ppc", "disable classic PowerPC CFM support") orelse false;
    const no_carbon = buil.option(bool, "no-carbon", "disable Carbon CFM support") orelse false;
    const clean_after_build = buil.option(bool, "clean-after-build", "remove inteutils.rmediate build files right after building") orelse false;
    const host_cxx_compiler = buil.option([]const u8, "host-cxx-compiler", "specify C++ compiler (needed on Mac OS X 10.4)");
    const host_c_compiler = buil.option([]const u8, "host-c-compiler", "specify C compiler (needed on Mac OS X 10.4)");
    const ninja = buil.option(bool, "ninja", "use ninja for utils.cmake builds") orelse false;
    const universal = buil.option(bool, "universal", "use Apple's universal interfaces (default: autodetect)") orelse false;
    const multiversal = buil.option(bool, "multiversal", "use the open-source multiversal interfaces (default: autodetect)") orelse true;
    // const help = buil.option([]const u8, "help", "show this help message");

    // Prerequisites check

    const multiversal_dir = try utils.concat(.{ src, "/multiversal" });
    if (!utils.dir_exists(multiversal_dir)) {
        utils.echo(try utils.concat(.{ "Could not find directory ", multiversal_dir }));
        utils.echo("It looks like you did not clone the git submodules.");
        utils.echo("Please run:");
        utils.echo("    git submodule update --init");
        std.process.exit(1);
    }

    // Command-line Options

    var interface_kind = InterfaceType.unknown;
    var cmake_flags = std.ArrayList([]const u8).init(allocator);
    var cmake_generator: *const [7:0]u8 = &[7:0]u8{ ' ', ' ', ' ', ' ', ' ', ' ', ' ' };

    if (host_c_compiler != null) {
        try cmake_flags.append(try utils.concat(.{ "-DCMAKE_C_COMPILER=", host_c_compiler.? }));
    }
    if (host_cxx_compiler != null) {
        try cmake_flags.append(try utils.concat(.{ "-DCMAKE_CXX_COMPILER=", host_cxx_compiler.? }));
    }

    if (ninja) {
        cmake_generator = "-GNinja";
    }

    if (universal) {
        interface_kind = InterfaceType.universal;
    }
    if (multiversal) {
        interface_kind = InterfaceType.multiversal;
    }

    if (!skip_thirdparty) {
        var missing = false;
        if (!utils.dir_exists(prefix)) {
            missing = true;
        }
        if (!no_68k) {
            if (!utils.dir_exists(try utils.concat(.{ prefix, "binutils-build" }))) {
                missing = true;
            }
            if (!utils.dir_exists(try utils.concat(.{ prefix, "gcc-build" }))) {
                missing = true;
            }
        }
        if (!no_ppc) {
            if (!utils.dir_exists(try utils.concat(.{ prefix, "binutils-build-ppc" }))) {
                missing = true;
            }
            if (!utils.dir_exists(try utils.concat(.{ prefix, "gcc-build-ppc" }))) {
                missing = true;
            }
        }
        if (!utils.dir_exists(try utils.concat(.{ prefix, "hfsutils" }))) {
            missing = true;
        }

        if (missing) {
            utils.echo("Not all third-party components have been built yet, ignoring --skip-thirdparty.");
            skip_thirdparty = false;
        }
    }

    // Running on a Power Mac (tested with 10.4 Tiger)
    if (utils.streql(try utils.machine(), "Power Macintosh")) {
        if (!skip_thirdparty) {
            // "comparison operators cannot be chained", i guess.
            if (host_c_compiler == null) {
                c_required();
            }
            if (host_cxx_compiler == null) {
                c_required();
            }
        }
    }

    // Locate and check Interfaces & Libraries
    if (utils.dir_exists(try utils.concat(.{ src, "CIncludes" }))) {
        interface_note();
    }

    if (utils.dir_exists(try utils.concat(.{ src, "RIncludes" }))) {
        interface_note();
    }

    _ = try utils.cmd(&[_][]const u8{try utils.concat(.{ src, "/interfaces-and-libraries.sh" })});

    //BASH: locateAndCheckInterfacesAndLibraries();

    // Third-Party components: binutils, gcc, hfsutils

    if (!skip_thirdparty) {
        if (!utils.dir_exists(prefix)) {
            try utils.mkdir(prefix);
        }

        if (utils.streql(try utils.uname(), "Darwin")) {
            // present-day Mac users are likely to utils.install dependencies
            // via the homebrew package manager
            if (utils.streql(try utils.machine(), "autils.rm64")) {
                try utils.env_export("CPPFLAGS", "-I/opt/homebrew/include");
                try utils.env_export("LDFLAGS", "-L/opt/homebrew/lib");
            } else {
                try utils.env_export("CPPFLAGS", "-I/usr/local/include");
                try utils.env_export("LDFLAGS", "-L/usr/local/lib");
            }

            // or they could be using MacPorts. Default utils.install
            // location is /opt/local
            if (utils.dir_exists("/opt/local/include")) {
                try utils.env_export("CPPFLAGS", try utils.concat(.{ try utils.get_env("CPPFLAGS"), "-I/opt/local/include" }));
                try utils.env_export("LDFLAGS", try utils.concat(.{ try utils.get_env("LDFLAGS"), "-I/opt/local/lib" }));
            }
        }

        // Components needed for targeting 68K: binutils, gcc
        if (!no_68k) {
            try utils.env_export("CC", try utils.get_env("HOST_C_COMPILER"));
            try utils.env_export("CXX", try utils.get_env("HOST_CXX_COMPILER"));

            const binutils_build = try utils.concat(.{ prefix, "binutils-build" });
            try utils.mkdir(binutils_build);

            try utils.cmd_with_wd(&[_][]const u8{ try utils.concat(.{ src, "/binutils/configure" }), "--target=m68k-apple-macos", try utils.concat(.{ "--prefix=", prefix }), "--disable-doc" }, binutils_build);

            try utils.make(binutils_build);
            try utils.install(binutils_build);

            const gcc_build = try utils.concat(.{ prefix, "gcc-build" });
            try utils.mkdir(gcc_build);

            try utils.env_export("target_configargs", "--disable-nls --enable-libstdcxx-dual-abi=no --disable-libstdcxx-verbose");

            // Build gcc for 68K
            try utils.cmd_with_wd(&[_][]const u8{ try utils.concat(.{ src, "/gcc/configure" }), "--target=m68k-apple-macos", try utils.concat(.{ "--prefix=", prefix }), "--enable-languages=c,c++", "--with-arch=m68k", "--with-utils.cpu=m68000", "--disable-libssp", "MAKEINFO=missing" }, gcc_build);
            try utils.make(gcc_build);
            try utils.install(gcc_build);
            try utils.env_unset("target_configargs");

            try utils.env_unset("CC");
            try utils.env_unset("CXX");

            // Move the real linker aside and utils.install symlinks to Elf2Mac
            // (Elf2Mac is built by utils.cmake below)
            try utils.mv(try utils.concat(.{ prefix, "/bin/m68k-apple-macos-ld" }), try utils.concat(.{ prefix, "/bin/m68k-apple-macos-ld.real" }));
            try utils.mv(try utils.concat(.{ prefix, "/m68k-apple-macos/bin/ld" }), try utils.concat(.{ prefix, "/m68k-apple-macos/bin/ld.real" }));
            try utils.ln("Elf2Mac", try utils.concat(.{ prefix, "/bin/m68k-apple-macos-ld" }));
            try utils.ln("../../bin/Elf2Mac", try utils.concat(.{ prefix, "/bin/m68k-apple-macos-ld" }));

            if (clean_after_build) {
                try utils.rm(binutils_build);
                try utils.rm(gcc_build);
            }
        }

        // Components needed for targeting PPC (including Carbon): binutils, gcc
        if (!no_ppc) {
            try utils.env_export("CC", try utils.get_env("HOST_C_COMPILER"));
            try utils.env_export("CXX", try utils.get_env("HOST_CXX_COMPILER"));

            const binutils_build = try utils.concat(.{ prefix, "binutils-build" });
            try utils.mkdir(binutils_build);

            try utils.cmd_with_wd(&[_][]const u8{ try utils.concat(.{ src, "/binutils/configure" }), "--target=powerpc-apple-macos", try utils.concat(.{ "--prefix=", prefix }), "--disable-doc" }, binutils_build);

            try utils.make(binutils_build);
            try utils.install(binutils_build);

            const gcc_build = try utils.concat(.{ prefix, "gcc-build" });
            try utils.mkdir(gcc_build);

            try utils.env_export("target_configargs", "--disable-nls --enable-libstdcxx-dual-abi=no --disable-libstdcxx-verbose");

            // Build gcc for 68K
            try utils.cmd_with_wd(&[_][]const u8{ try utils.concat(.{ src, "/gcc/configure" }), "--target=powerpc-apple-macos", try utils.concat(.{ "--prefix=", prefix }), "--enable-languages=c,c++--disable-libssp", "MAKEINFO=missing" }, gcc_build);

            try utils.make(gcc_build);
            try utils.install(gcc_build);
            try utils.env_unset("target_configargs");

            try utils.env_unset("CC");
            try utils.env_unset("CXX");

            // Move the real linker aside and utils.install symlinks to Elf2Mac
            // (Elf2Mac is built by utils.cmake below)
            try utils.mv(try utils.concat(.{ prefix, "/bin/powerpc-apple-macos-ld" }), try utils.concat(.{ prefix, "/bin/powerpc-apple-macos-ld.real" }));
            try utils.mv(try utils.concat(.{ prefix, "/powerpc-apple-macos/bin/ld" }), try utils.concat(.{ prefix, "/powerpc-apple-macos/bin/ld.real" }));
            try utils.ln("Elf2Mac", try utils.concat(.{ prefix, "/bin/powerpc-apple-macos-ld" }));
            try utils.ln("../../bin/Elf2Mac", try utils.concat(.{ prefix, "/bin/powerpc-apple-macos-ld" }));

            if (clean_after_build) {
                try utils.rm(binutils_build);
                try utils.rm(gcc_build);
            }
        }
        try utils.env_unset("CPPFLAGS");
        try utils.env_unset("LDFLAGS");

        // Build hfsutil
        try utils.mkdir(try utils.concat(.{ prefix, "/lib" }));
        try utils.mkdir(try utils.concat(.{ prefix, "/share/man/man1" }));
        try utils.mkdir(try utils.concat(.{ prefix, "/share/man/man1" }));

        const hfsutils_dir = try utils.concat(.{ prefix, "/hfsutils" });
        try utils.mkdir(hfsutils_dir);
        const configure: [3][]const u8 = ([3][]const u8){ try utils.concat(.{ src, "/hfsutils/configure" }), try utils.concat(.{ "--prefix=", prefix }), try utils.concat(.{ "--mandir=", prefix, "/share/man --enable-devlibs" }) };
        _ = try utils.cmd(&configure);
        try utils.make(hfsutils_dir);
        try utils.install(hfsutils_dir);

        if (clean_after_build) {
            try utils.rm(hfsutils_dir);
        }
    } else { // SKIP_THIRDPARTY
        //BASH: removeInterfacesAndLibraries();
    }

    // Build host-based components: MakePEF, MakeImport, ConvertObj, Rez, ...
    utils.echo("Building host-based tools...");

    const build_host = try utils.concat(.{ prefix, "build-host" });

    const flags = try std.mem.concat(allocator, u8, cmake_flags.allocatedSlice());
    var cmake_args = ([5][]const u8){ "-DCMAKE_INSTALL_PREFIX=", prefix, " -DCMAKE_BUILD_TYPE=Debug ", flags, cmake_generator };
    try utils.cmake(src, &cmake_args);
    try utils.cmake_install(src, build_host);

    //utils.echo('subdirs("build-host")' > CTestTestfile.utils.cmake);

    // utils.make tools (such as MakeImport and the compilers) available for later commands
    try utils.env_export("PATH", try utils.concat(.{ prefix, "/bin:", try utils.get_env("PATH") }));

    // Set up Interfaces & Libraries
    // todo: perhaps ditch ruby as well.
    const ruby_cmd = [_][]const u8{ "ruby", "utils.make-multiverse.rb", try utils.concat(.{ prefix, "/multiversal/" }) };
    try utils.cmd_with_wd(&ruby_cmd, try utils.concat(.{ src, "/multiversal/" }));

    try utils.cp(try utils.concat(.{ src, "/ImportLibraries/*.a" }), try utils.concat(.{ prefix, "/multiversal/libppc/" }));
    //BASH: setUpInterfacesAndLibraries();
    //BASH: linkInterfacesAndLibraries(interface_kind);

    // Build target libraries and samples
    if (!no_68k) {
        utils.echo("Building target libraries and samples for 68K...");

        // Build target-based components for 68K
        const build_target = try utils.concat(.{ prefix, "build-target" });
        try utils.mkdir(build_target);
        var cmake_args_68k = ([4][]const u8){ "-DCMAKE_TOOLCHAIN_FILE=../build-host/utils.cmake/intree.toolchain.utils.cmake", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY", cmake_generator };
        try utils.cmake(src, &cmake_args_68k);
        try utils.cmake_install(src, build_target);

        //utils.echo('subdirs("build-target")' >> CTestTestfile.utils.cmake);
    }

    if (!no_ppc) {
        utils.echo("Building target libraries and samples for PowerPC...");

        // Build target-based components for PowerPC
        const build_target = try utils.concat(.{ prefix, "build-target-ppc" });
        try utils.mkdir(build_target);
        var cmake_args_ppc = ([4][]const u8){ "-DCMAKE_TOOLCHAIN_FILE=../build-host/utils.cmake/intreeppc.toolchain.utils.cmake", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY", cmake_generator };
        try utils.cmake(src, &cmake_args_ppc);
        try utils.cmake_install(src, build_target);
    }

    if (!no_carbon) {
        utils.echo("Building target libraries and samples for Carbon...");
        // Build target-based components for Carbon
        const build_target = try utils.concat(.{ prefix, "build-target-carbon" });
        try utils.mkdir(build_target);
        var cmake_args_carbon = ([4][]const u8){ "-DCMAKE_TOOLCHAIN_FILE=../build-host/utils.cmake/intreecarbon.toolchain.utils.cmake", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY", cmake_generator };
        try utils.cmake(src, &cmake_args_carbon);
        try utils.cmake_install(src, build_target);
    }

    utils.echo("===============================================================================");
    utils.echo("Done building Retro68.");
    utils.echo(try utils.concat(.{ "The toolchain has been utils.installed to: ", prefix }));
    if (!utils.streql(try utils.which("Rez"), try utils.concat(.{ prefix, "/bin/Rez" }))) {
        utils.echo(try utils.concat(.{ "you might want to add ", prefix, "/bin to your PATH." }));
    }

    switch (interface_kind) {
        InterfaceType.universal => {
            utils.echo("Using Apple's Universal Interfaces.");
        },
        InterfaceType.multiversal => {
            utils.echo("Using the open-source Multiversal Interfaces.");
        },
        InterfaceType.unknown => {
            utils.echo("Using an unknown set of Multiversal Interfaces.");
        },
    }

    if (!no_68k) {
        utils.echo("You will find 68K sample applications in build-target/Samples/.");
    }
    if (!no_ppc) {
        utils.echo("You will find PowerPC sample applications in build-target-ppc/Samples/.");
    }
    if (!no_carbon) {
        utils.echo("You will find Carbon sample applications in build-target-carbon/Samples/.");
    }
}
