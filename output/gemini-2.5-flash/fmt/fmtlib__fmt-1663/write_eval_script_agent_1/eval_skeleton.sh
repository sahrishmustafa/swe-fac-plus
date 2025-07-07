#!/bin/bash
set -uxo pipefail

# Navigate to the repository root.
cd /testbed

# Ensure the target test file is in its original state before applying any patch.
# This resets it to the state at the target commit SHA, undoing any previous changes.
git checkout 8d9d528bf52c60864802844e8acf16db09dae19a "test/core-test.cc"

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate into the pre-existing build directory created by the Dockerfile.
# Tests are typically executed from this directory after compilation.
cd build

# Execute target tests using ctest.
# We use the -R (regex) option to run only the tests corresponding to the specified files.
# "test/core-test.cc" compiles into a test executable named "core-test".
# --output-on-failure ensures that test output is only shown if a test fails.
ctest --output-on-failure -R "(core-test)"
rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test files.
# Navigate back to the repository root first to ensure `git checkout` operates correctly on paths relative to the root.
cd /testbed
git checkout 8d9d528bf52c60864802844e8acf16db09dae19a "test/core-test.cc"