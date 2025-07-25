#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as defined in the Dockerfile
cd /testbed

# Reset target test files to ensure a clean state before applying patch.
# This ensures that git apply operates on the original file content for the specified files.
git checkout 4acc51828f7f93f3b2058a63f54d112af4034503 "tests/CMakeLists.txt" "tests/SelfTest/UsageTests/Misc.tests.cpp"

# Apply the test patch to the specified files.
# The actual content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Re-configure CMake project with the specified flags after applying the patch.
# This is crucial if tests/CMakeLists.txt was modified, to reflect changes in the build system.
# -Bbuild: Specifies 'build' as the binary directory
# -H.: Specifies the current directory as the source directory
# -DCMAKE_BUILD_TYPE=Release: For an optimized build
# -DCMAKE_CXX_STANDARD=17: Specifies the C++ standard
# -DCATCH_DEVELOPMENT_BUILD=ON: Crucial for building tests and development features
# -G Ninja: Specifies Ninja as the build system generator
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCATCH_DEVELOPMENT_BUILD=ON \
    -G Ninja

# Re-build the project using CMake's build command, specifying the build directory.
# This command compiles the source code and creates executables, including tests,
# picking up any changes from the patch and re-configuration.
cmake --build build

# Set CTEST_OUTPUT_ON_FAILURE if not already set by Dockerfile (for robustness)
# and run tests using ctest from the build directory.
# CTEST_OUTPUT_ON_FAILURE=1: Shows output for failed tests immediately
# ctest -C Release: Runs tests for the Release configuration
# -j 2: Uses 2 parallel jobs for testing, improving speed
CTEST_OUTPUT_ON_FAILURE=1 ctest --test-dir build -C Release -j 2
rc=$? # Capture the exit code of ctest

# Echo the final exit code for the judge to process
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: Reset the target test files to their original state,
# ensuring the repository is left in a clean state after the tests.
git checkout 4acc51828f7f93f3b2058a63f54d112af4034503 "tests/CMakeLists.txt" "tests/SelfTest/UsageTests/Misc.tests.cpp"