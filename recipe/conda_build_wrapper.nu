#!/usr/bin/env nu


# Set up PATH
$env.PATH = ($env.PREFIX | path join "/bin") + ":" + ($env.BUILD_PREFIX | path join "Library" "bin") + ":" + $env.SRC_DIR + ":" + $env.PATH

# Set compiler and tool environment variables
$env.CC = "clang.exe"
$env.CXX = "clang++.exe"
$env.RANLIB = "llvm-ranlib"
$env.AS = "llvm-as"
$env.AR = "llvm-ar"
$env.NM = "llvm-nm"
$env.LD = "lld-link"

# Convert backslashes to forward slashes in LIBRARY_INC and LIBRARY_LIB
let library_inc = ($env.LIBRARY_INC | str replace -a "\\" "/")
let library_lib = ($env.LIBRARY_LIB | str replace -a "\\" "/")

# Set compiler flags
let cflags = $"-I($library_inc) -O2 -D_CRT_SECURE_NO_WARNINGS -D_MT -D_DLL -nostdlib -Xclang --dependent-lib=msvcrt -fuse-ld=lld"
$env.CFLAGS = $cflags
$env.CXXFLAGS = $cflags
$env.CPPFLAGS = $cflags
$env.LDFLAGS = $"-L($library_lib) -fuse-ld=lld -nostdlib -Xclang --dependent-lib=msvcrt"
$env.lt_cv_deplibs_check_method = "pass_all"

# Unset INCLUDE to avoid search path issues
if "INCLUDE" in ($env | columns) {
    $env.INCLUDE = null
}

print "You need to run patch_libtool bash function after configure to fix the libtool script."
print "If your package uses OpenMP, add llvm-openmp to your host and run requirements."

# Define patch_libtool function
def patch_libtool [] {
    # libtool has support for exporting symbols using either nm or dumpbin with some creative use of sed and awk,
    # but neither works correctly with C++ mangling schemes.
    # cmake's dll creation tool works, but need to hack libtool to get it working

    # Create backup and modify libtool
    cp libtool libtool.bak

    # Replace export_symbols_cmds and archive_expsym_cmds
    open libtool | str replace -a "export_symbols_cmds=" "export_symbols_cmds2=" | save libtool.tmp
    open libtool.tmp | str replace -a "archive_expsym_cmds=" "archive_expsym_cmds2=" | save libtool2

    # Create new libtool script
    "#!/bin/bash" | save libtool
    $'export_symbols_cmds="($env.SRC_DIR)/create_def.sh \\$export_symbols \\$libobjs \\$convenience "' | save -a libtool
    $'archive_expsym_cmds="\\$CC -o \\$tool_output_objdir\\$soname \\$libobjs \\$compiler_flags \\$deplibs -Wl,-DEF:\\\"\\$export_symbols\\\" -Wl,-DLL,-IMPLIB:\\\"\\$tool_output_objdir\\$libname.dll.lib\\\"; echo "' | save -a libtool

    # Append the rest of libtool2
    open libtool2 | save -a libtool

    # Fix the sed pattern for fuse flags
    cp libtool libtool.bak2
    open libtool | str replace -a "|-fuse" "|-fuse-ld=*|-nostdlib|-Xclang|-fuse" | save libtool

    rm libtool.tmp libtool2 libtool.bak2
}

# Handle library prefix removal if needed
if ($env.REMOVE_LIB_PREFIX? | default "yes") != "no" {
    # Find lib*.lib files and rename them
    let lib_dir = ($env.PREFIX + "/lib")
    if ($lib_dir | path exists) {
        let lib_files = (ls $lib_dir | where name =~ "lib.*\\.lib$" | get name)

        for file in $lib_files {
            let basename = ($file | path basename)
            let new_name = ($basename | str substring 3..)
            let new_path = ($env.PREFIX + "/lib/" + $new_name)

            if not ($new_path | path exists) {
                cp $file $new_path
            }
        }

        # Store the list for cleanup later
        $env.LIB_RENAME_FILES = ($lib_files | str join " ")
    }
}

# Run the build script
# If you want to set this script dynamically then overwrite the default script.
source "dynamic_build.nu"

# Handle DLL library renaming
if ($env.PREFIX | path join "lib" ($env.PKG_NAME + ".dll.lib") | path exists) {
    let static_lib = ($env.PREFIX | path join "lib"  ($env.PKG_NAME + ".lib"))
    let dll_lib = ($env.PREFIX | path join "lib" ($env.PKG_NAME + ".dll.lib"))
    let static_lib_new = ($env.PREFIX | path join "lib" ($env.PKG_NAME + "_static.lib"))

    if ($static_lib | path exists) {
        mv $static_lib $static_lib_new
    }
    mv $dll_lib $static_lib
}

# Cleanup renamed lib files if needed
if ($env.REMOVE_LIB_PREFIX? | default "yes") != "no" and ($env.LIB_RENAME_FILES? | default "") != "" {
    let lib_files = ($env.LIB_RENAME_FILES | split row " " | where $it != "")
    for file in $lib_files {
        let basename = ($file | path basename)
        let new_name = ($basename | str substring 3..)
        let cleanup_path = ($env.PREFIX + "/lib/" + $new_name)

        if ($cleanup_path | path exists) {
            rm $cleanup_path
        }
    }
}
