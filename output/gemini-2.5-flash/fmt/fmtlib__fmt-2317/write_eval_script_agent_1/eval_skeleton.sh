#!/bin/bash
set -uxo pipefail

# Navigate to the repository root for git operations and build commands.
cd /testbed

# Define target commit SHA and the specific test file(s) to be managed.
TARGET_COMMIT_SHA="7612f18dc8e0112e64e0845a1ebe9da6cfb8a123"
TEST_FILES="test/format-test.cc"
TEST_NAME="format-test" # The specific CTest target name for the test file "test/format-test.cc"

# Cleanup any previous build directory to ensure a clean slate.
echo "Cleaning up any existing build directory..."
rm -rf build

# --- Project Configuration (before patching) ---
# Create the build directory and configure CMake.
# This step prepares the build environment.
echo "Performing CMake configuration..."
mkdir build
cmake -S . -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=17 \
      -DFMT_TEST=ON
configure_rc=$? # Capture exit code for CMake configure

if [ $configure_rc -ne 0 ]; then
    echo "CMake configure failed with exit code $configure_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
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
patch_rc=$?

if [ $patch_rc -ne 0 ]; then
    echo "Applying test patch failed with exit code $patch_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# --- Rebuild Project After Patch ---
# CRITICAL: Rebuild the project after applying the patch. This ensures that
# any new or modified tests from the patch are included in the test executables.
# Using -j2 to limit parallel jobs and prevent potential OOM errors, as seen in similar contexts.
echo "Rebuilding project after patch to include test changes with -j2..."
cmake --build build --config Release -j2
rebuild_rc=$? # Capture exit code for the rebuild

if [ $rebuild_rc -ne 0 ]; then
    echo "Project rebuild after patch failed with exit code $rebuild_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# --- Execute Tests ---
# Navigate into the build directory where CTest is usually run.
echo "Navigating to build directory and running tests..."
cd build

# Execute only the target test using CTest's regex feature.
# CTEST_OUTPUT_ON_FAILURE=True ensures detailed test output on failure.
CTEST_OUTPUT_ON_FAILURE=True ctest -C Release -R "${TEST_NAME}"
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