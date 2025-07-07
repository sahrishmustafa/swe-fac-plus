#!/bin/bash
set -euxo pipefail

# Define the target commit SHA and the specific test files to be managed.
COMMIT_SHA="52066dbc2a53f4c3ab2a418d03f93200a8245451"
TARGET_TEST_FILES=(
    "src/catch2/catch_test_macros.hpp"
    "src/catch2/internal/catch_test_failure_exception.hpp"
    "tests/CMakeLists.txt"
    "tests/ExtraTests/CMakeLists.txt"
)

# Ensure we are in the /testbed directory
cd /testbed || { echo "Error: /testbed directory not found. Aborting."; exit 1; }

echo "Resetting target test files to their state at commit $COMMIT_SHA..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$COMMIT_SHA" "$FILE" || { echo "Failed to checkout $FILE. Aborting."; exit 1; }
done

# Apply the test patch if provided. The content of the patch is inserted here.
echo "Attempting to apply test patch..."
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate to the 'build' directory where the project was initially configured and built.
cd /testbed/build || { echo "Error: 'build' directory not found at /testbed/build. Ensure Dockerfile build steps are complete."; exit 1; }

# Recompile the project after applying the patch.
# This step is critical because the target files (e.g., CMakeLists.txt, header files)
# are part of the build configuration and source, and any changes from the patch
# require a recompile for the test executables to incorporate them.
echo "Recompiling project after patch application to integrate changes..."
ninja || { echo "Error: Failed to recompile project. Aborting."; exit 1; }

# Set environment variable for CTest to show output on failure.
echo "Setting CTEST_OUTPUT_ON_FAILURE environment variable..."
export CTEST_OUTPUT_ON_FAILURE=1

# Execute tests using CTest.
# As per collected information, the "target test files" provided are
# build/source configuration files, not individual test executables.
# The `ctest` command discovers and executes all defined tests.
# Therefore, to ensure changes applied by the patch are tested, the entire
# test suite must be run after recompilation.
echo "Executing Catch2 tests using ctest..."
ctest -C Release -j $(nproc)
rc=$? # Capture the exit code of the ctest command immediately

# Output the captured exit code. This is crucial for the judging system.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the /testbed directory for cleanup.
echo "Navigating back to /testbed for cleanup operations..."
cd /testbed || { echo "Failed to navigate back to /testbed. Cleanup skipped."; exit $rc; }

# Clean up: Reset the target test files to their original state from the repository.
# This ensures a clean state for any subsequent operations or for future runs.
echo "Resetting target test files after test run..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$COMMIT_SHA" "$FILE" || { echo "Failed to reset $FILE. Manual intervention might be required."; }
done

# Exit with the captured test result code.
exit $rc