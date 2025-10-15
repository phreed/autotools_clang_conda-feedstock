#!/usr/bin/env nu

# Create library bin directory
mkdir $env.LIBRARY_BIN

# Install the autotools module and wrapper to the library bin
cp ($env.RECIPE_DIR + "/autotools.nu") ($env.LIBRARY_BIN + "/")
cp ($env.RECIPE_DIR + "/run_autotools_build.nu") ($env.LIBRARY_BIN + "/")

print "Autotools module and wrapper installed successfully"
