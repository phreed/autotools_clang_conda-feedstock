#!/usr/bin/env nu

# Example build script showing how to use the autotools module
# This demonstrates the typical usage pattern for autotools-based conda packages

# Import the autotools module
use autotools.nu

print "=== Autotools Conda Build Example ==="
print ""

# Method 1: Simple build (recommended for most cases)
print "Method 1: Simple autotools build"
print "================================"
print "autotools build build.nu"
print ""

# For this example, we'll show the manual process
print "Method 2: Manual step-by-step process"
print "====================================="

# Setup the build environment
print "1. Setting up build environment..."
autotools setup-environment

# Convert paths for MSYS2 compatibility
print "2. Converting paths for MSYS2..."
autotools convert-paths

# Run configure (example)
print "3. Running configure..."
print "   ./configure --prefix=$env.PREFIX --enable-shared --disable-static"
print "   (This would be in your actual build.sh script)"

# Patch libtool after configure
print "4. Patching libtool for Windows DLL support..."
print "   autotools patch-libtool"
print "   (Call this after ./configure in your build script)"

# Build and install (example)
print "5. Building and installing..."
print "   make -j$env.CPU_COUNT"
print "   make install"
print "   (This would be in your actual build.sh script)"

# Handle library naming
print "6. Post-build library handling..."
autotools rename-dll-libraries

print ""
print "=== Build Complete ==="
print ""
print "Available autotools commands:"
autotools help
