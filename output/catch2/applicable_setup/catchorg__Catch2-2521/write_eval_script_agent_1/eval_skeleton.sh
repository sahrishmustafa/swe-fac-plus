#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific target files to their original state before applying the patch.
# This ensures that only the intended files are affected by the patch.
git checkout 359542d53ec142514da8a606ada8d9efd13b9678 "src/catch2/internal/catch_test_macro_impl.hpp"

# Apply the test patch to the specified files.
# The content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Rebuild the project after applying the patch.
# This is crucial for C++ projects, especially when header files (`.hpp`) are modified,
# to ensure that compiled tests pick up the changes.
cmake --build build -j$(nproc)

# Navigate to the build directory where the tests are located and executable by ctest.
cd build

# Execute the tests using ctest with verbose output.
# As the target file `src/catch2/internal/catch_test_macro_impl.hpp` is a header,
# its functionality is tested by the compiled Catch2 self-test executables.
# Running `ctest -VV` will execute all discovered tests that would implicitly
# exercise the code paths dependent on this header.
ctest -VV
rc=$? # Capture the exit code of the test command

# Return to the /testbed directory for proper cleanup operations.
cd ..

# Output the captured exit code for external systems to evaluate test success or failure.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified files by checking them out to their original state.
git checkout 359542d53ec142514da8a606ada8d9efd13b9678 "src/catch2/internal/catch_test_macro_impl.hpp"