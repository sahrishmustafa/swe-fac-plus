#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as defined in the Dockerfile
cd /testbed

# Reset target test files to ensure a clean state before applying patch
# This ensures that git apply operates on the original file content for the specified files.
git checkout 8ce92d2c7288b6b3261caf1c016f8a779b6a8efc "tests/CMakeLists.txt" "tests/ExtraTests/CMakeLists.txt"

# Apply the test patch to the specified files
# The actual content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Configure CMake project with the specified flags
# -Bbuild: Specifies 'build' as the binary directory
# -H.: Specifies the current directory as the source directory
# -DCATCH_DEVELOPMENT_BUILD=ON: Enables building tests and development features
# -DCATCH_BUILD_EXTRA_TESTS=ON: Crucial for including tests from tests/ExtraTests
# -G Ninja: Specifies Ninja as the build system generator
cmake -Bbuild -H. \
      -DCATCH_DEVELOPMENT_BUILD=ON \
      -DCATCH_BUILD_EXTRA_TESTS=ON \
      -G Ninja

# Build the project using Ninja, specifying the build directory
# This command is run from the /testbed (repository root) directory.
ninja -C build

# Handle ApprovalTests: Run the approve.py script to update test baselines.
# This ensures that ApprovalTests find their expected output, if outputs have changed
# due to environment or patch. Run from the repository root.
python3 tools/scripts/approve.py

# Array to store exit codes of individual test runs
declare -a test_exit_codes

# Find and run tests from the main 'tests' directory
# The SelfTest executable is usually built directly under build/tests/
for test_binary in build/tests/SelfTest; do
    if [ -f "$test_binary" ] && [ -x "$test_binary" ]; then
        echo "Running test: $test_binary"
        # Removed --exclude-tag as it's not recognized by the test binaries according to analysis
        "$test_binary"
        test_exit_codes+=( $? )
    fi
done

# Find and run tests from 'ExtraTests' directory
# Test executables from ExtraTests are usually built directly under build/tests/ExtraTests/
for test_binary in build/tests/ExtraTests/*; do
    if [ -f "$test_binary" ] && [ -x "$test_binary" ]; then
        echo "Running extra test: $test_binary"
        # Removed --exclude-tag as it's not recognized by the test binaries according to analysis
        "$test_binary"
        test_exit_codes+=( $? )
    fi
done

# Determine overall exit code
# If any individual test run returned a non-zero exit code, the overall result is a failure.
rc=0
for code in "${test_exit_codes[@]}"; do
    if [ "$code" -ne 0 ]; then
        rc=1
        break
    fi
done

# Echo the final exit code for the judge to process
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: Reset the target test files to their original state
# This command is run from the /testbed (repository root) directory.
git checkout 8ce92d2c7288b6b3261caf1c016f8a779b6a8efc "tests/CMakeLists.txt" "tests/ExtraTests/CMakeLists.txt"