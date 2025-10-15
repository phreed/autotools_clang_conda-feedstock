#!/usr/bin/env nu

# Get the def file name from the first argument
let def_file = if ($env.argv | length) > 0 { $env.argv.0 } else { error "Missing def file argument" }
let remaining_args = if ($env.argv | length) > 1 { ($env.argv | skip 1) } else { [] }

# Create temporary directory
let tmp_dir = (mktemp -d | str trim)
mut rm_dirs = [$tmp_dir]
touch ($tmp_dir + "/symbol_list.txt")

# Process each argument
for arg in $remaining_args {
    if ($arg | str ends-with ".lib") {
        # Handle .lib files
        let extract_dir = (mktemp -d | str trim)
        $rm_dirs = ($rm_dirs | append $extract_dir)

        cp $arg ($extract_dir + "/static_lib.lib")
        cd $extract_dir

        # Get file list from archive
        let file_list = (do { ^$env.AR t "static_lib.lib" } | lines | where $it != "")

        for file in $file_list {
            # Extract file
            ^$env.AR x ($extract_dir + "/static_lib.lib") $file

            # Create unique name with SHA256 hash
            let sha256 = (sha256sum $file | split row " " | get 0)
            let new_name = $"($sha256)_($file)"
            mv $file $new_name

            # Move file to back of archive
            ^$env.AR m "static_lib.lib" $file

            # Add Windows path to symbol list
            let win_path = (cygpath -w ($extract_dir + "/" + $new_name) | str trim)
            $"($win_path)\n" | save -a ($tmp_dir + "/symbol_list.txt")
        }

        cd -
    } else {
        # Handle regular object files
        let win_path = (cygpath -w $arg | str trim)
        $"($win_path)\n" | save -a ($tmp_dir + "/symbol_list.txt")
    }
}

# Create the .def file using cmake
try {
    cmake -E __create_def $def_file ($tmp_dir + "/symbol_list.txt")
} catch {
    print $"Error: Failed to create def file ($def_file)"
    exit 1
}

# Cleanup temporary directories
for dir in $rm_dirs {
    rm -rf $dir
}
