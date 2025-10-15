#!/usr/bin/env nu

# Create library bin directory
mkdir $env.LIBRARY_BIN

# Copy Nushell scripts to library bin
cp ($env.RECIPE_DIR + "/conda_build_wrapper.nu") ($env.LIBRARY_BIN + "/")
cp ($env.RECIPE_DIR + "/create_def.nu") ($env.LIBRARY_BIN + "/")
cp ($env.RECIPE_DIR + "/run_autotools_clang_conda_build.nu") ($env.LIBRARY_BIN + "/")
