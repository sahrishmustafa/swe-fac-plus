#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory
cd /testbed

# Checkout the specific test files to their original state at the commit SHA.
# This ensures a clean state before applying any potential patches.
# The listed files include documentation and header files, which are included
# for a complete reset, even though only .cpp files are actual tests.
git checkout 4902cd721586822ded795afe0c418c553137306a "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# --- Pre-build Step ---
# Execute the single header generation script required by Catch2's build process.
python3 scripts/generateSingleHeader.py

# --- Build Steps ---
# Create a dedicated build directory to perform an out-of-source build.
mkdir Build-Debug
# Change into the build directory. All subsequent build commands will be executed here.
cd Build-Debug

# Configure CMake for a Debug build with C++14 standard and test options.
# Updated based on test log analysis: explicitly setting CMAKE_CXX_STANDARD=14
# and CMAKE_CXX_EXTENSIONS=OFF to resolve compilation issues.
cmake .. \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_STANDARD=14 \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCATCH_BUILD_EXTRA_TESTS=ON \
    -DCATCH_ENABLE_WERROR=ON \
    -DCATCH_BUILD_TESTING=ON

# Compile the project using all available CPU cores for speed.
make -j "$(nproc)"

# --- Test Execution ---
# Current directory is 'Build-Debug'.
# Run the CTest suite.
# As per the collected information, CTest automatically discovers and runs the compiled
# test executables (including those from Class.tests.cpp and Misc.tests.cpp).
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed output in case of test failures.
CTEST_OUTPUT_ON_FAILURE=1 ctest -j "$(nproc)"
rc=$? # Capture the exit code of the test command immediately after execution.

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific files again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout 4902cd721586822ded795afe0c418c553137306a "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"