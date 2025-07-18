#!/bin/bash
set -uxo pipefail
# Navigate to the testbed directory, which is the root of the cloned repository.
cd /testbed

# Ensure the target test file is in its original state before applying any patch.
# This prevents issues if a previous run's patch was not fully reverted.
git checkout 87fbc6f7566e4d3266bd3a2cd69f6c90e1aefa5d "test/prepare-test.cc"

# Required: apply the test patch to update the target tests.
# The actual patch content will be injected here programmatically.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Required: After applying the test patch, rebuild the test binary or recompile the project
# This ensures that any new or modified tests from the patch are included in the executable.
# Navigate to the build directory where the project was initially configured.
cd /testbed/build

# Rebuild the project. This will recompile `test/prepare-test.cc` if it was modified by the patch,
# and link it into the `prepare-test` executable.
echo "Attempting to rebuild the project after applying the patch..."
make -j$(nproc)
build_rc=$? # Capture the exit code of the build command

# Critical: If the build fails, set the OMNIGRIL_EXIT_CODE to 1 and exit immediately.
if [ $build_rc -ne 0 ]; then
  echo "Project rebuild failed with exit code $build_rc. Test execution aborted."
  echo "OMNIGRIL_EXIT_CODE=1" # Indicate failure due to build error
  exit 0 # Exit the script successfully from a shell perspective, but report failure via OMNIGRIL_EXIT_CODE
fi

echo "Project rebuilt successfully. Proceeding with test execution."

# Test execution: Run only the specified target test using CTest.
# The collected information indicates that `prepare-test.cc` compiles to a CTest target named `prepare-test`.
ctest -R prepare-test --output-on-failure
rc=$? # Capture the exit code immediately after running the tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the test status for the test log analysis agent

# Cleanup: Revert changes made by the patch to the target test file.
# Navigate back to the repository root directory before performing git checkout.
cd /testbed
git checkout 87fbc6f7566e4d3266bd3a2cd69f6c90e1aefa5d "test/prepare-test.cc"