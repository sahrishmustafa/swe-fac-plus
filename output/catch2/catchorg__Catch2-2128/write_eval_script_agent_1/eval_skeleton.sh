#!/bin/bash
set -uxo pipefail

# Ensure we are in the /testbed directory
cd /testbed

# Define the target commit SHA and the specific test file to be managed.
# This ensures that even if the file was modified locally or by a previous run,
# it is reset to its state at the target commit before applying any patch.
COMMIT_SHA="65c9a1d31a338f28ef93cd61c475efc40f6cc42e"
TARGET_TEST_FILE="tests/SelfTest/UsageTests/Compilation.tests.cpp"

echo "Resetting $TARGET_TEST_FILE to its state at commit $COMMIT_SHA..."
git checkout "$COMMIT_SHA" "$TARGET_TEST_FILE" || { echo "Failed to checkout $TARGET_TEST_FILE. Aborting."; exit 1; }

# Apply the test patch if provided. The content of the patch is inserted here
# programmatically by the evaluation system.
echo "Attempting to apply test patch..."
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912
# The git apply command will exit with an error code if the patch fails to apply,
# which will be caught by 'set -e' due to 'pipefail' or explicit '|| exit 1' if added.
# However, for patches that might contextually fail but are expected, this script will continue.

# Navigate to the 'Build' directory, where the CMake-generated executables and tests reside.
# The Dockerfile has already performed the build steps, including creating and populating 'Build'.
echo "Navigating to /testbed/Build directory for test execution..."
cd /testbed/Build || { echo "Error: 'Build' directory not found at /testbed/Build. Ensure build steps completed in Dockerfile."; exit 1; }

# Execute only the specified target test file using CTest.
# The `CTEST_OUTPUT_ON_FAILURE=1` ensures detailed output upon test failures.
# We use `ctest -j $(nproc)` to parallelize test execution.
# To run ONLY the specific test `tests/SelfTest/UsageTests/Compilation.tests.cpp`,
# we use the `-R` flag with a regular expression that matches the likely CTest name
# for this test, which is typically derived from its path (e.g., "SelfTest.UsageTests.Compilation").
echo "Running tests matching regex SelfTest.UsageTests.Compilation..."
CTEST_OUTPUT_ON_FAILURE=1 ctest -j $(nproc) -R "SelfTest\.UsageTests\.Compilation"
rc=$? # Capture the exit code of the ctest command immediately

# Output the captured exit code. This is crucial for the judging system.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the /testbed directory for cleanup.
echo "Navigating back to /testbed for cleanup operations..."
cd /testbed || { echo "Failed to navigate back to /testbed. Cleanup skipped."; exit $rc; }

# Clean up: Reset the target test file to its original state from the repository.
# This ensures a clean state for any subsequent operations or for future runs.
echo "Resetting $TARGET_TEST_FILE after test run..."
git checkout "$COMMIT_SHA" "$TARGET_TEST_FILE" || { echo "Failed to reset $TARGET_TEST_FILE. Manual intervention might be required."; }

# Exit with the captured test result code.
exit $rc