#!/usr/bin/env nu

# Autotools Conda Build Module for Windows
# Provides comprehensive autotools build support using Clang/LLVM toolchain
# with MSVC compatibility for conda packages on Windows

# Set up the build environment with Clang/LLVM toolchain
export def setup-environment [] {
    # Set up PATH
    $env.PATH = ($env.PREFIX + "/bin:" + $env.BUILD_PREFIX + "/Library/bin:" + $env.SRC_DIR + ":" + $env.PATH)

    # Set compiler and tool environment variables
    $env.CC = "clang.exe"
    $env.CXX = "clang++.exe"
    $env.RANLIB = "llvm-ranlib"
    $env.AS = "llvm-as"
    $env.AR = "llvm-ar"
    $env.NM = "llvm-nm"
    $env.LD = "lld-link"

    # Convert backslashes to forward slashes in library paths
    let library_inc = ($env.LIBRARY_INC | str replace -a "\\" "/")
    let library_lib = ($env.LIBRARY_LIB | str replace -a "\\" "/")

    # Set compiler flags for MSVC compatibility
    let cflags = $"-I($library_inc) -O2 -D_CRT_SECURE_NO_WARNINGS -D_MT -D_DLL -nostdlib -Xclang --dependent-lib=msvcrt -fuse-ld=lld"
    $env.CFLAGS = $cflags
    $env.CXXFLAGS = $cflags
    $env.CPPFLAGS = $cflags
    $env.LDFLAGS = $"-L($library_lib) -fuse-ld=lld -nostdlib -Xclang --dependent-lib=msvcrt"
    $env.lt_cv_deplibs_check_method = "pass_all"

    # Unset INCLUDE to avoid search path conflicts
    if "INCLUDE" in ($env | columns) {
        $env.INCLUDE = null
    }

    # Set MSYS2 environment variables
    $env.MSYSTEM = $"MINGW($env.ARCH)"
    $env.MSYS2_PATH_TYPE = "inherit"
    $env.CHERE_INVOKING = "1"

    print "Environment configured for Clang/LLVM autotools build"
    print "Remember to call 'autotools patch-libtool' after configure"
    print "Add llvm-openmp to requirements if using OpenMP"
}

# Convert Windows paths to Unix paths for MSYS2/Cygwin compatibility
export def convert-paths [] {
    try {
        $env.PREFIX = (cygpath -u $env.LIBRARY_PREFIX | str trim)
        $env.BUILD_PREFIX = (cygpath -u $env.BUILD_PREFIX | str trim)
        $env.SRC_DIR = (cygpath -u $env.SRC_DIR | str trim)
        $env.RECIPE_DIR = (cygpath -u $env.RECIPE_DIR | str trim)
        print "Paths converted for MSYS2 compatibility"
    } catch {
        print "Warning: Could not convert paths - cygpath may not be available"
    }
}

# Create Windows .def files from object files and libraries
export def create-def-file [
    def_file: string     # Output .def file path
    ...inputs: string    # Input .lib files and object files
] {
    print $"Creating definition file: ($def_file)"

    # Create temporary directory for processing
    let tmp_dir = (mktemp -d | str trim)
    mut rm_dirs = [$tmp_dir]
    touch ($tmp_dir + "/symbol_list.txt")

    # Process each input file
    for input in $inputs {
        if ($input | str ends-with ".lib") {
            print $"Processing library: ($input)"

            # Create extraction directory
            let extract_dir = (mktemp -d | str trim)
            $rm_dirs = ($rm_dirs | append $extract_dir)

            # Copy and extract library
            cp $input ($extract_dir + "/static_lib.lib")
            cd $extract_dir

            try {
                # Get file list from archive
                let file_list = (do { ^$env.AR t "static_lib.lib" } | lines | where $it != "")

                for file in $file_list {
                    # Extract file with unique name
                    ^$env.AR x "static_lib.lib" $file
                    let sha256 = (sha256sum $file | split row " " | get 0)
                    let unique_name = $"($sha256)_($file)"
                    mv $file $unique_name

                    # Add to archive processing queue
                    ^$env.AR m "static_lib.lib" $file

                    # Convert to Windows path and add to symbol list
                    let win_path = (cygpath -w ($extract_dir + "/" + $unique_name) | str trim)
                    $"($win_path)\n" | save -a ($tmp_dir + "/symbol_list.txt")
                }
            } catch {
                print $"Error processing library: ($input)"
            }
            cd -
        } else {
            print $"Processing object file: ($input)"
            # Handle regular object files
            try {
                let win_path = (cygpath -w $input | str trim)
                $"($win_path)\n" | save -a ($tmp_dir + "/symbol_list.txt")
            } catch {
                print $"Warning: Could not convert path for ($input)"
                $"($input)\n" | save -a ($tmp_dir + "/symbol_list.txt")
            }
        }
    }

    # Create the .def file using cmake
    let cmake_result = (do { run_external "cmake" "-E" "__create_def" $def_file ($tmp_dir | path join "symbol_list.txt")} | complete)
    if ($cmake_result.exit_code == 0) {
        print $"Successfully created: ($def_file)"
    } else {
        print $"Error: Failed to create definition file ($def_file)"

        # Cleanup and exit with error
        for dir in $rm_dirs {
            rm -rf $dir
        }
        return 1
    }

    # Cleanup temporary directories
    for dir in $rm_dirs {
        rm -rf $dir
    }

    return 0
}

# Patch libtool script for proper Windows DLL creation
export def patch-libtool [] {
    if not ("libtool" | path exists) {
        print "Error: libtool script not found"
        return 1
    }

    print "Patching libtool for Windows DLL support..."

    try {
        # Create backup
        cp libtool libtool.bak

        # Replace problematic command patterns
        open libtool
        | str replace -a "export_symbols_cmds=" "export_symbols_cmds2="
        | save libtool.tmp

        open libtool.tmp
        | str replace -a "archive_expsym_cmds=" "archive_expsym_cmds2="
        | save libtool2

        # Create new libtool header
        [
            "#!/bin/bash"
            $'export_symbols_cmds="($env.SRC_DIR)/create_def.sh \\$export_symbols \\$libobjs \\$convenience "'
            $'archive_expsym_cmds="\\$CC -o \\$tool_output_objdir\\$soname \\$libobjs \\$compiler_flags \\$deplibs -Wl,-DEF:\\\"\\$export_symbols\\\" -Wl,-DLL,-IMPLIB:\\\"\\$tool_output_objdir\\$libname.dll.lib\\\"; echo "'
        ] | str join "\n" | save libtool

        # Append the rest of the original libtool
        open libtool2 | save -a libtool

        # Fix linker flag patterns
        open libtool
        | str replace -a "|-fuse" "|-fuse-ld=*|-nostdlib|-Xclang|-fuse"
        | save libtool.fixed

        mv libtool.fixed libtool

        # Cleanup temporary files
        rm libtool.tmp libtool2

        print "Libtool successfully patched for Windows DLL creation"
        return 0
    } catch {
        print "Error: Failed to patch libtool"
        return 1
    }
}

# Handle library prefix removal (lib*.lib -> *.lib)
export def remove-lib-prefix [] {
    if ($env.REMOVE_LIB_PREFIX? | default "yes") == "no" {
        return 0
    }

    let lib_dir = ($env.PREFIX + "/lib")
    if not ($lib_dir | path exists) {
        print "Warning: Library directory not found"
        return 0
    }

    print "Removing lib prefix from library files..."

    try {
        let lib_files = (ls $lib_dir | where name =~ "lib.*\\.lib$" | get name)
        mut renamed_files = []

        for file in $lib_files {
            let basename = ($file | path basename)
            let new_name = ($basename | str substring 3..)
            let new_path = ($env.PREFIX + "/lib/" + $new_name)

            if not ($new_path | path exists) {
                cp $file $new_path
                $renamed_files = ($renamed_files | append $file)
                print $"Renamed: ($basename) -> ($new_name)"
            }
        }

        # Store for cleanup
        $env.LIB_RENAME_FILES = ($renamed_files | str join " ")
        return 0
    } catch {
        print "Error during library prefix removal"
        return 1
    }
}

# Restore library prefix (cleanup renamed files)
export def restore-lib-prefix [] {
    if ($env.REMOVE_LIB_PREFIX? | default "yes") == "no" {
        return 0
    }

    if ($env.LIB_RENAME_FILES? | default "") == "" {
        return 0
    }

    print "Cleaning up renamed library files..."

    let lib_files = ($env.LIB_RENAME_FILES | split row " " | where $it != "")
    for file in $lib_files {
        let basename = ($file | path basename)
        let new_name = ($basename | str substring 3..)
        let cleanup_path = ($env.PREFIX + "/lib/" + $new_name)

        if ($cleanup_path | path exists) {
            rm $cleanup_path
            print $"Cleaned up: ($new_name)"
        }
    }

    return 0
}

# Handle DLL library renaming (*.dll.lib -> *.lib)
export def rename-dll-libraries [] {
    if not ($env.PKG_NAME?) {
        return 0
    }

    let dll_lib = ($env.PREFIX + "/lib/" + $env.PKG_NAME + ".dll.lib")
    if not ($dll_lib | path exists) {
        return 0
    }

    print $"Renaming DLL library for package: ($env.PKG_NAME)"

    let static_lib = ($env.PREFIX + "/lib/" + $env.PKG_NAME + ".lib")
    let static_lib_backup = ($env.PREFIX + "/lib/" + $env.PKG_NAME + "_static.lib")

    try {
        # Backup existing static library if it exists
        if ($static_lib | path exists) {
            mv $static_lib $static_lib_backup
            print $"Backed up static library to: ($env.PKG_NAME)_static.lib"
        }

        # Rename DLL library
        mv $dll_lib $static_lib
        print $"Renamed DLL library: ($env.PKG_NAME).dll.lib -> ($env.PKG_NAME).lib"

        return 0
    } catch {
        print "Error during DLL library renaming"
        return 1
    }
}

# Run autotools build with full environment setup
export def build [
] {
    const script_name = "build.nu"
    # Setup environment
    setup-environment
    convert-paths

    # Handle library prefix removal
    remove-lib-prefix

    print "Running build script..."

    try {
        # Execute the build script
        source $script_name

        # Post-build cleanup
        rename-dll-libraries

        print "Build completed successfully!"
        return 0
    } catch {
        print $"Build failed for script: ($script_name)"
        return 1
    }
    # Always cleanup
    restore-lib-prefix
}

# Display help and usage information
export def help [] {
    print "Autotools Conda Build Module for Windows"
    print "========================================"
    print ""
    print "This module provides comprehensive autotools build support using"
    print "Clang/LLVM toolchain with MSVC compatibility for conda packages."
    print ""
    print "Available Commands:"
    print "  setup-environment     - Configure build environment"
    print "  convert-paths         - Convert Windows paths for MSYS2"
    print "  create-def-file       - Create Windows .def files"
    print "  patch-libtool         - Patch libtool for Windows DLL support"
    print "  remove-lib-prefix     - Remove lib prefix from library files"
    print "  restore-lib-prefix    - Restore original library names"
    print "  rename-dll-libraries  - Handle DLL library renaming"
    print "  build                 - Run complete autotools build process"
    print "  help                  - Show this help message"
    print ""
    print "Usage Examples:"
    print "  use autotools.nu"
    print "  autotools build build.sh"
    print "  autotools build-with-bash"
    print "  autotools patch-libtool"
    print ""
    print "Environment Variables:"
    print "  REMOVE_LIB_PREFIX     - Set to 'no' to skip lib prefix removal"
    print "  PKG_NAME              - Package name for DLL library renaming"
}

# Export the module name for import
export-env {
    $env.AUTOTOOLS_MODULE_LOADED = "true"
}

print "Autotools module loaded successfully"
print "Run 'autotools help' for usage information"
