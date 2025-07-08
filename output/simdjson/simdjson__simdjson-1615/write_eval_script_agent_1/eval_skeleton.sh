#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific target test file to its original state before applying any patch.
# This ensures a clean base for the patch application.
git checkout 40cba172ed66584cf670c98202ed474a316667e3 "tests/ondemand/CMakeLists.txt"

# Apply the test patch to modify/add tests.
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate to the build directory.
# The Dockerfile has already run `cmake ..` and `cmake --build .` from /testbed,
# so the `build` directory should already exist and contain the compiled project.
cd build

# Set the SIMDJSON_DEVELOPER_MODE environment variable.
# This is crucial for CMake to configure and build tests, examples, and benchmarks.
# While CMake might have already configured with this, ensuring it's set before
# a rebuild is a good practice.
export SIMDJSON_DEVELOPER_MODE=ON

# Rebuild the project after applying the patch.
# This step is critical to ensure that any new or modified tests from the patch
# are compiled and included in the test executable.
# Use -j$(nproc) to utilize all available CPU cores for faster build.
cmake --build . -j$(nproc)

# Check the exit code of the build command. If the build fails, exit early.
if [ $? -ne 0 ]; then
    echo "Build failed after patch application. Exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute only the specified target tests.
# The target file is tests/ondemand/CMakeLists.txt.
# CTest does not directly run a CMakeLists.txt file. Instead, it runs tests
# discovered by CMake within the build directory.
# To adhere to the "execute only the specified target test files" requirement,
# we use --tests-regex with a pattern that attempts to match tests
# originating from or logically belonging to the 'ondemand' module.
# The regex ".*ondemand.*" is a best effort to capture such tests, assuming
# their full CTest name includes 'ondemand' or a related identifier.
ctest --output-on-failure --tests-regex ".*ondemand.*"
rc=$?

# Capture the exit code immediately after running the tests.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed root directory for cleanup.
cd /testbed

# Clean up: Undo any changes made to the target test file.
# This ensures that the repository remains in its original state after the test run.
git checkout 40cba172ed66584cf670c98202ed474a316667e3 "tests/ondemand/CMakeLists.txt"