#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Ensure the target test files are in their original state before applying any patch
git checkout d6eede9e085f0b36edcf0a2f6dff5f7875181019 "test/format-test.cc"

# Required: apply test patch to update target tests (if any)
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate into the pre-existing build directory created by the Dockerfile
cd build

# Execute target tests using ctest, filtering by the specified test name.
# The context indicates "format-test.cc" compiles into "format-test" executable/test.
ctest --output-on-failure -R "format-test"
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test files
# Navigate back to the repository root first
cd /testbed
git checkout d6eede9e085f0b36edcf0a2f6dff5f7875181019 "test/format-test.cc"