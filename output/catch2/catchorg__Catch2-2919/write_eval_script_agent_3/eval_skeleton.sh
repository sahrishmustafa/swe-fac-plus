#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as defined in the Dockerfile
cd /testbed

# Reset target test file to ensure a clean state before applying patch
# This ensures that git apply operates on the original file content for the specified file.
git checkout fa43b77429ba76c462b1898d6cd2f2d7a9416b14 "tests/SelfTest/UsageTests/MatchersRanges.tests.cpp"

# Apply the test patch to the specified files
# The actual content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Configure CMake project with the specified flags in a 'build' directory
# -Bbuild: Specifies 'build' as the binary directory
# -H.: Specifies the current directory as the source directory
# -DCATCH_DEVELOPMENT_BUILD=ON: Enables building tests and development features
# -DCATCH_BUILD_EXTRA_TESTS=ON: Crucial for including tests from tests/ExtraTests
# -G Ninja: Specifies Ninja as the build system generator
cmake -Bbuild -H. \
      -DCATCH_DEVELOPMENT_BUILD=ON \
      -DCATCH_BUILD_EXTRA_TESTS=ON \
      -G Ninja

# Build the project using Ninja, specifying the 'build' directory
# This command is run from the /testbed (repository root) directory.
ninja -C build

# Navigate into the build directory to run tests
cd build

# Execute the specific target test using the Catch2 test runner executable (SelfTest)
# and its internal tag filter mechanism. The SelfTest executable is located at tests/SelfTest
# within the build directory. The tag filter '[ranges]' is used as recommended by the analysis.
./tests/SelfTest "[ranges]"
rc=$?

# Navigate back to the repository root for cleanup
cd /testbed

# Echo the final exit code for the judge to process
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: Reset the target test file to its original state
# This command is run from the /testbed (repository root) directory.
git checkout fa43b77429ba76c462b1898d6cd2f2d7a9416b14 "tests/SelfTest/UsageTests/MatchersRanges.tests.cpp"