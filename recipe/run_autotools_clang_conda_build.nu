#!/usr/bin/env nu

# Set default build script or use provided argument
let buildscript = if ($env.argv | length) > 0 {
    $env.argv.0
} else {
    "build.sh"
}

# Copy necessary files to current directory
try {
    cp $"($env.RECIPE_DIR)/($buildscript)" .
} catch {
    print $"Error: Could not find build script ($buildscript) in ($env.RECIPE_DIR)"
    exit 1
}

try {
    cp $"($env.BUILD_PREFIX)/Library/bin/create_def.nu" .
    cp $"($env.BUILD_PREFIX)/Library/bin/conda_build_wrapper.nu" .
} catch {
    print "Error: Could not copy required Nushell scripts"
    exit 1
}

# Set MSYS2 environment variables
$env.MSYSTEM = $"MINGW($env.ARCH)"
$env.MSYS2_PATH_TYPE = "inherit"
$env.CHERE_INVOKING = "1"

# Convert Windows paths to Unix paths using cygpath
let prefix_unix = try { (cygpath -u $env.LIBRARY_PREFIX | str trim) } catch { $env.LIBRARY_PREFIX }
let build_prefix_unix = try { (cygpath -u $env.BUILD_PREFIX | str trim) } catch { $env.BUILD_PREFIX }
let src_dir_unix = try { (cygpath -u $env.SRC_DIR | str trim) } catch { $env.SRC_DIR }
let recipe_dir_unix = try { (cygpath -u $env.RECIPE_DIR | str trim) } catch { $env.RECIPE_DIR }

# Set environment variables for the bash session
$env.PREFIX = $prefix_unix
$env.BUILD_PREFIX = $build_prefix_unix
$env.SRC_DIR = $src_dir_unix
$env.RECIPE_DIR = $recipe_dir_unix

# Run the conda build wrapper through bash
try {
    bash -lce $"./conda_build_wrapper.sh ($buildscript)"
} catch {
    print $"Error: Build failed for script ($buildscript)"
    exit 1
}
