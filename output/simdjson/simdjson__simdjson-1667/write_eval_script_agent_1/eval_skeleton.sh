#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific target test file to its original state before applying any patch.
# This ensures a clean base for the patch application.
git checkout 47a62db55936e29e1966a26a9aadb5f28237ae37 "tests/ondemand/CMakeLists.txt"

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
# Changed from -j$(nproc) to -j4 to prevent Out-Of-Memory errors during compilation,
# as suggested by the reference environment script.
cmake --build . -j4

# Check the exit code of the build command. If the build fails, exit early.
if [ $? -ne 0 ]; then
    echo "Build failed after patch application. Exiting with OMNIGRIL_EXIT_CODE=1."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute only the specified target tests.
# The target file tests/ondemand/CMakeLists.txt registers tests with the label 'ondemand'.
# The test execution command provided by the context retrieval agent explicitly uses this label.
ctest -L ondemand -j$(nproc) --output-on-failure
rc=$?

# Capture the exit code immediately after running the tests.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed root directory for cleanup.
cd /testbed

# Clean up: Undo any changes made to the target test file.
# This ensures that the repository remains in its original state after the test run.
git checkout 47a62db55936e29e1966a26a9aadb5f28237ae37 "tests/ondemand/CMakeLists.txt"