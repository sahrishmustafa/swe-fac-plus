#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory
cd /testbed

# Checkout the specific test file to its original state at the commit SHA
# This ensures a clean state before applying any potential patches.
git checkout c9de7dd12d2971c63f9d32ce5459eb98f2fec13d "projects/SelfTest/UsageTests/BDD.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate to the build directory where the Catch2 'SelfTest' executable is located.
# The Dockerfile ensures this directory exists and the project is built.
cd build

# Execute the specific test cases from BDD.tests.cpp using the Catch2 SelfTest executable.
# Tests from BDD.tests.cpp are typically tagged with [BDD].
# --success flag ensures a non-zero exit code on test failure, critical for automation.
# --verbosity high provides detailed output.
./projects/SelfTest "[BDD]" --success --verbosity high
rc=$? # Capture the exit code of the test command

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific test file again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout c9de7dd12d2971c63f9d32ce5459eb98f2fec13d "projects/SelfTest/UsageTests/BDD.tests.cpp"