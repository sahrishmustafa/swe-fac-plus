#!/bin/bash
set -euxo pipefail

# Navigate to the repository root as all operations are relative to it.
cd /testbed

# Ensure the target test file is in its original state before applying any patch.
# This resets it to the state at the target commit SHA, undoing any previous changes.
git checkout 8d9d528bf52c60864802844e8acf16db09dae19a "test/core-test.cc"

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate into the build directory to rebuild the project.
# The project has already been configured by the Dockerfile's RUN commands.
echo "Navigating to build directory for recompilation..."
cd /testbed/build

# Required: rebuild the project to include any changes from the patch in the test executables.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
echo "Building the project..."
make -j$(nproc)
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute target tests using ctest.
# Set CTEST_OUTPUT_ON_FAILURE=1 for detailed test output on failure.
# Use ctest -R to run only the specified test file by matching its CTest name.
echo "Running target test: core-test"
export CTEST_OUTPUT_ON_FAILURE=1
ctest -R "core-test"
rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test file.
# Navigate back to the repository root first to ensure `git checkout` operates correctly on paths relative to the root.
cd /testbed
git checkout 8d9d528bf52c60864802844e8acf16db09dae19a "test/core-test.cc"