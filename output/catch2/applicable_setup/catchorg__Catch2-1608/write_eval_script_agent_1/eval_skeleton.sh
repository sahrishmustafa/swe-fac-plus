#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory
# The Dockerfile sets /testbed/build as WORKDIR, so we need to go up one level.
cd /testbed

# Checkout the specific test file to its original state at the commit SHA
# This ensures a clean state before applying any potential patches.
git checkout 979bbf03bb00bc55ca09783791b5091a2247df68 "projects/SelfTest/UsageTests/Message.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate to the build directory where the Catch2 'SelfTest' executable is located.
# The Dockerfile ensures this directory exists and the project is built.
cd build

# Execute the specific test cases from Message.tests.cpp using the Catch2 SelfTest executable.
# Tests from Message.tests.cpp are typically tagged with [messages].
# --success flag ensures a non-zero exit code on test failure, critical for automation.
./projects/SelfTest "[messages]" --success
rc=$? # Capture the exit code of the test command

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific test file again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout 979bbf03bb00bc55ca09783791b5091a2247df68 "projects/SelfTest/UsageTests/Message.tests.cpp"