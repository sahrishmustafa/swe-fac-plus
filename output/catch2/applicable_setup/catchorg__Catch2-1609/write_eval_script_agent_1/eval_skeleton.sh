#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory.
# The Dockerfile sets /testbed/build as WORKDIR initially, so we need to go up one level.
cd /testbed

# Checkout the specific test files to their original state at the commit SHA.
# This ensures a clean state before applying any potential patches.
git checkout bd703dd74be7fd2413eb0c01662a491bcebea430 "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Navigate to the build directory where the Catch2 'SelfTest' executable is located.
# The Dockerfile ensures this directory exists and the project is built.
cd build

# Execute the specific test cases from Class.tests.cpp and Misc.tests.cpp using the Catch2 SelfTest executable.
# Tests from Class.tests.cpp are typically tagged with [class] or [classification].
# Tests from Misc.tests.cpp are typically tagged with [misc].
# We combine these tags to run only the relevant tests efficiently.
# The --success flag ensures a non-zero exit code upon test failure, which is critical for automation.
./projects/SelfTest "[class],[classification],[misc]" --success
rc=$? # Capture the exit code of the test command

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific test files again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout bd703dd74be7fd2413eb0c01662a491bcebea430 "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"