#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Reset target test files to ensure a clean state before applying patch
# This ensures that git apply operates on the original file content for the specified files.
git checkout 8ce92d2c7288b6b3261caf1c016f8a779b6a8efc "tests/CMakeLists.txt" "tests/ExtraTests/CMakeLists.txt"

# Apply the test patch to the specified files
# The actual content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Configure CMake project
# -Bbuild: Specifies the build directory
# -H.: Specifies the source directory (current directory)
# -DCMAKE_BUILD_TYPE=Release: Sets release build type
# -DCMAKE_CXX_STANDARD=17: Sets C++ standard to C++17
# -DCMAKE_CXX_EXTENSIONS=OFF: Disables compiler extensions
# -DCATCH_DEVELOPMENT_BUILD=ON: Enables building of tests and development features
# -G Ninja: Specifies Ninja as the build system generator
cmake -Bbuild -H. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_EXTENSIONS=OFF \
      -DCATCH_DEVELOPMENT_BUILD=ON \
      -G Ninja

# Build the project using Ninja
# Change directory to the build directory before running ninja
cd build
ninja

# Execute tests using CTest
# CTEST_OUTPUT_ON_FAILURE=1: Ensures full test output on failure
# ctest -C Release: Runs tests for the Release configuration
# -j 2: Runs up to 2 tests in parallel
# The 'tests/CMakeLists.txt' and 'tests/ExtraTests/CMakeLists.txt' define the tests.
# CTest automatically discovers and runs all tests enabled by these files within the build configuration.
CTEST_OUTPUT_ON_FAILURE=1 ctest -C Release -j 2

# Capture the exit code of the test command
rc=$?

# Echo the exit code for the judge to process
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed root for cleanup
cd /testbed

# Clean up: Reset the target test files to their original state
git checkout 8ce92d2c7288b6b3261caf1c016f8a779b6a8efc "tests/CMakeLists.txt" "tests/ExtraTests/CMakeLists.txt"