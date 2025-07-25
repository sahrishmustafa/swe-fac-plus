#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as all operations are relative to it.
cd /testbed

# Define the target commit SHA and test files to be cleaned/reverted.
TARGET_COMMIT_SHA="69396347af67b0307866a24283fcaaad02f98a59"
TARGET_TEST_FILES=(
    "test/compile-error-test/CMakeLists.txt"
    "test/format-test.cc"
)

# Ensure the target test files are in their original state before applying any patch.
# This resets them to the state at the target commit SHA, undoing any previous changes.
echo "Checking out target files to a clean state..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$TARGET_COMMIT_SHA" "$FILE"
done

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
echo "Applying test patch..."
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate into the build directory for recompilation and testing.
# The Dockerfile already creates and enters 'build' during initial setup.
cd build

# Configure CMake for the project. This ensures CMake is aware of any changes from the patch.
echo "Reconfiguring CMake..."
cmake .. -DCMAKE_BUILD_TYPE=Release -DFMT_TEST=ON
cmake_config_rc=$?

if [ $cmake_config_rc -ne 0 ]; then
    echo "CMake configuration failed with exit code $cmake_config_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Required: rebuild the project to include any changes from the patch in the test executables.
# Using -j2 to reduce memory pressure during compilation, addressing potential Out-Of-Memory issues.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
echo "Building the project..."
cmake --build . -j2
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute target tests using ctest.
# The context retrieval agent indicates that `test/compile-error-test/CMakeLists.txt`
# and `test/format-test.cc` are part of the larger test suite built and executed by CTest.
# As CTest typically runs tests based on internal discovery, the most reliable way to ensure
# these specific tests are run is to execute the main CTest suite.
echo "Running tests using ctest..."
export CTEST_OUTPUT_ON_FAILURE=True # This ensures full output for failed tests
ctest -C Release # Run tests configured for the Release build type from within the build directory

rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test files.
# Navigate back to the repository root first to ensure `git checkout` operates correctly.
cd /testbed
echo "Cleaning up: Reverting test file changes..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$TARGET_COMMIT_SHA" "$FILE"
done