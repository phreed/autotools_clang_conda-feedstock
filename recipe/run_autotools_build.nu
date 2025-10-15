#!/usr/bin/env nu

# Simple wrapper script for backward compatibility with existing build processes
# This provides an easy entry point to the autotools module

# Get build script name from command line arguments or use default
let build_script = if ($env.argv | length) > 0 { $env.argv.0 } else { "build.sh" }

print $"Starting autotools build with: ($build_script)"

# Import and use the autotools module
try {
    use autotools.nu

    # Copy build script from recipe directory if it exists
    if ($env.RECIPE_DIR? | default "") != "" {
        let recipe_script = ($env.RECIPE_DIR | path join $build_script)
        if ($recipe_script | path exists) {
            cp $recipe_script .
            print $"Copied ($build_script) from recipe directory"
        }
    }

    # Run the autotools build process
    let result = autotools build-with-bash $build_script

    if $result == 0 {
        print "Autotools build completed successfully!"
        exit 0
    } else {
        print "Autotools build failed!"
        exit 1
    }

} catch {
    print "Error: Failed to load autotools module or run build"
    print "Make sure the autotools module is properly installed"
    exit 1
}
