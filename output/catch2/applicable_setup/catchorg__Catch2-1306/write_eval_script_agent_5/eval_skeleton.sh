#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned.
cd /testbed

# Checkout the specific target test file to ensure it's in a clean state before patching.
# This prepares the file for the patch application.
git checkout 021fcee63667e346c619e04bbae932bcea562334 "projects/SelfTest/UsageTests/ToStringWhich.tests.cpp"

# Apply the test patch to the specified file.
# The actual patch content will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Explicitly set CXXFLAGS to disable treating warnings as errors.
# This ensures the compiler receives '-Wno-error' during the build phase,
# providing an additional layer of protection against build failures due to warnings.
export CXXFLAGS="-Wno-error"

# Build the project. The Dockerfile only configures CMake; the build step must be executed here.
# Pass -j $(nproc) to the underlying build tool using '--' to enable parallel compilation.
# This ensures that the SelfTest executable containing the target tests is compiled.
# If the build fails, the script will exit immediately with status 1,
# preventing subsequent commands from executing and incorrectly reporting success.
cmake --build Build -- -j $(nproc) || exit 1

# Navigate into the CMake build directory to run tests.
# The SelfTest executable is located in this directory after a successful build.
pushd Build

# Execute tests by directly running the SelfTest executable with Catch2's internal filtering.
# --rng-seed 0 ensures reproducible test runs by setting a fixed seed for random number generators.
# --test-spec "*ToStringWhich*" filters tests to only run those whose names or tags
# contain "ToStringWhich", effectively targeting tests from projects/SelfTest/UsageTests/ToStringWhich.tests.cpp.
./SelfTest --rng-seed 0 --test-spec "*ToStringWhich*"

# Capture the exit code of the test command.
rc=$?

# Return to the original /testbed directory.
popd

# Echo the exit code for the test analysis agent.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: Discard any changes made to the target test file by the patch.
git checkout 021fcee63667e346c619e04bbae932bcea562334 "projects/SelfTest/UsageTests/ToStringWhich.tests.cpp"