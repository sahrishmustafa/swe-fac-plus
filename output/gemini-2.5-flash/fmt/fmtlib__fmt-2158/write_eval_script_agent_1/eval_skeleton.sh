#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Ensure the target test files are in their original state before applying any patch
# Use the specific commit SHA and target files
git checkout 835b910e7d758efdfdce9f23df1b190deb3373db "test/format-test.cc"

# Required: apply test patch to update target tests (if any)
# The content of the patch will be inserted here programmatically
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate into the pre-existing build directory created by the Dockerfile
cd build

# Execute target tests using ctest, filtering by the specific test name.
# The context indicates the test name corresponds to the specified test file's executable.
ctest --output-on-failure -R "format-test"
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test files
# Navigate back to the repository root first
cd /testbed
git checkout 835b910e7d758efdfdce9f23df1b190deb3373db "test/format-test.cc"