#!/usr/bin/env nu

# Example build script showing how to use the autotools module
# This demonstrates a typical usage pattern for autotools-based conda packages

# Import the autotools module
use autotools.nu

print "=== Autotools Conda Build Example ==="
print "The `autotools` steps could be selected for only windows."
print ""

# Setup the build environment
print "1. Setting up build environment..."
autotools setup-environment

# Convert paths for MSYS2 compatibility
print "2. Converting paths for MSYS2..."
autotools convert-paths

# Run configure
print "3. Running configure..."
run_external "./configure" $"--prefix=$env.PREFIX" "--enable-shared" "--disable-static"

# Patch libtool after configure
print "4. Patching libtool for Windows DLL support..."
autotools patch-libtool

# Build and install
print "5. Building and installing..."
run_external "make" $"-j($env.CPU_COUNT)"
run_external "make" "install"

# Handle library naming
print "6. Post-build library handling..."
autotools rename-dll-libraries

print ""
print "=== Build Complete ==="
print ""
print "Available autotools commands:"
autotools help
