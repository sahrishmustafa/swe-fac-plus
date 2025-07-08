#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout target files to their original state before applying any potential patch,
# as per the skeleton's initial checkout step.
git checkout c96ff018fedc7fe087b6f898442458a31a240a28 "tests/ondemand/CMakeLists.txt" "tests/ondemand/ondemand_error_tests.cpp" "tests/ondemand/ondemand_dom_api_tests.cpp" "tests/test_macros.h"

# Required: apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Required: rebuild the project after applying the test patch.
# This ensures that any new or modified tests/code are included in the executables
# before running the tests.
echo "Rebuilding project after applying patch..."
cmake --build build
if [ $? -ne 0 ]; then
    echo "Build failed after patching. Exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    # Ensure cleanup even on build failure
    git checkout c96ff018fedc7fe087b6f898442458a31a240a28 "tests/ondemand/CMakeLists.txt" "tests/ondemand/ondemand_error_tests.cpp" "tests/ondemand/ondemand_dom_api_tests.cpp" "tests/test_macros.h"
    exit 1
fi
echo "Project rebuild complete."

# Required: run target tests
# Navigate into the build directory as specified by the context retrieval agent
# for executing CTest.
cd build
ctest . --output-on-failure -R "(ondemand_error_tests|ondemand_dom_api_tests)"
rc=$? # Capture the exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Echo the captured exit code

# Navigate back to the testbed root for cleanup
cd /testbed 

# Cleanup: Revert changes to the target files to their original state
git checkout c96ff018fedc7fe087b6f898442458a31a240a28 "tests/ondemand/CMakeLists.txt" "tests/ondemand/ondemand_error_tests.cpp" "tests/ondemand/ondemand_dom_api_tests.cpp" "tests/test_macros.h"