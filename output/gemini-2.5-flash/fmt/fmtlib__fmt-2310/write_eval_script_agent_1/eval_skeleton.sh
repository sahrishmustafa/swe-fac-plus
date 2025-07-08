#!/bin/bash
set -uxo pipefail

# Navigate to the repository root for git operations and build commands.
cd /testbed

# Define target commit SHA and the specific test file(s) to be managed.
TARGET_COMMIT_SHA="bc13c6de390751ecf8daa1b1ce8f775d104fdc65"
TEST_FILES="test/format-test.cc"
TEST_NAME="format-test" # The specific CTest target name for the test file.

# Cleanup any previous build directory to ensure a clean slate.
echo "Cleaning up any existing build directory..."
rm -rf build

# --- Initial Project Build ---
# Create the build directory and configure CMake.
# This step is essential so that test executables are built before any patching.
echo "Performing initial CMake configuration..."
mkdir build
# Ensure tests are enabled with -DFMT_TEST=ON and a Release build is configured.
cmake -S . -B build -DFMT_TEST=ON -DCMAKE_BUILD_TYPE=Release
configure_rc=$? # Capture exit code for CMake configure

if [ $configure_rc -ne 0 ]; then
    echo "Initial CMake configure failed with exit code $configure_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Build the project, including the test executables.
# Using -j$(nproc) for parallel builds as per the Dockerfile setup.
echo "Performing initial project build with -j$(nproc)..."
cmake --build build -j$(nproc)
build_rc=$? # Capture exit code for CMake build

if [ $build_rc -ne 0 ]; then
    echo "Initial project build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Ensure the target test files are in their pristine state from the target commit
# before applying any patch. This prevents issues if previous runs left changes.
echo "Resetting target test file(s) to original commit state..."
git checkout "${TARGET_COMMIT_SHA}" ${TEST_FILES}

# --- Apply Test Patch ---
# Required: Apply the test patch to update target tests.
# The actual content of the patch will be inserted here by the system.
echo "Applying test patch..."
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# --- Rebuild Project After Patch ---
# CRITICAL: Rebuild the project after applying the patch. This ensures that
# any new or modified tests from the patch are included in the test executables.
# Using -j$(nproc) for parallel builds as per the Dockerfile setup.
echo "Rebuilding project after patch to include test changes with -j$(nproc)..."
cmake --build build -j$(nproc)
rebuild_rc=$? # Capture exit code for the rebuild

if [ $rebuild_rc -ne 0 ]; then
    echo "Project rebuild after patch failed with exit code $rebuild_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# --- Execute Tests ---
# Navigate into the build directory where CTest must be run.
echo "Navigating to build directory and running tests..."
cd build

# Execute only the target test using CTest's regex feature.
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed test output on failure.
# The '-R "format-test"' flag correctly targets 'test/format-test.cc'.
CTEST_OUTPUT_ON_FAILURE=1 ctest --output-on-failure -R "${TEST_NAME}"
rc=$? # Capture the exit code of the test command immediately for result parsing.

# --- Cleanup ---
# Navigate back to the repository root for cleanup.
cd /testbed

# Revert changes made by the patch to the target test files.
# This leaves the repository in a clean state after the evaluation.
echo "Cleaning up: Reverting changes made to test files by the patch..."
git checkout "${TARGET_COMMIT_SHA}" ${TEST_FILES}

# Required: Echo the captured exit code. This value is used by the test harness
# to determine the success or failure of the evaluation.
echo "OMNIGRIL_EXIT_CODE=$rc"