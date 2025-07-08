#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Define variables for clarity and maintainability
TARGET_COMMIT_SHA="6cd04aa858f2d92105c0fbd65cdafb96428db002"
TARGET_TEST_FILE="tests/ondemand/ondemand_json_pointer_tests.cpp"
TARGET_CTEST_NAME="ondemand_json_pointer_tests" # Based on the file path, this is the derived CTest test name

# Checkout the specific target test file to its original state before applying any patch.
# This ensures a clean base for the patch application.
git checkout "$TARGET_COMMIT_SHA" "$TARGET_TEST_FILE"

# Apply the test patch to modify/add tests.
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate to the build directory.
# The Dockerfile has already run `cmake ..` and `cmake --build .` from /testbed,
# so the `build` directory should already exist and contain the compiled project.
cd build

# Rebuild the project after applying the patch.
# This step is critical to ensure that any new or modified tests from the patch
# are compiled and included in the test executable.
# Use -j4 for parallel compilation jobs, as specified in the Dockerfile.
echo "Attempting to rebuild the project after patch application..."
cmake --build . -j4

# Check the exit code of the build command. If the build fails, exit early.
if [ $? -ne 0 ]; then
    echo "Build failed after patch application. Exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi
echo "Project rebuilt successfully."

# Execute only the specified target tests using CTest.
# CTest runs tests discovered by CMake within the build directory.
# We use -R (regular expression) to specifically target tests generated from the provided file.
echo "Running target tests: $TARGET_CTEST_NAME"
ctest --output-on-failure -R "$TARGET_CTEST_NAME"
rc=$?

# Capture the exit code immediately after running the tests.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed root directory for cleanup.
cd /testbed

# Clean up: Undo any changes made to the target test file.
# This ensures that the repository remains in its original state after the test run.
echo "Cleaning up: reverting changes to $TARGET_TEST_FILE"
git checkout "$TARGET_COMMIT_SHA" "$TARGET_TEST_FILE"