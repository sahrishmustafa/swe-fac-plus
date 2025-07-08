#!/bin/bash
set -uxo pipefail

# Navigate to the repository root for git operations.
cd /testbed

# Ensure the target test file is in its original state before applying any patch.
# This resets it to the state at the target commit SHA, undoing any previous changes.
git checkout d6eede9e085f0b36edcf0a2f6dff5f7875181019 "test/format-test.cc"

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
diff --git a/test/format-test.cc b/test/format-test.cc
--- a/test/format-test.cc
+++ b/test/format-test.cc
@@ -2621,3 +2621,13 @@ TEST(FormatTest, FormatCustomChar) {
   EXPECT_EQ(result.size(), 1);
   EXPECT_EQ(result[0], mychar('x'));
 }
+
+TEST(FormatTest, FormatUTF8Precision) {
+  using str_type = std::basic_string<char8_t>;
+  str_type format(reinterpret_cast<const char8_t*>(u8"{:.4}"));
+  str_type str(reinterpret_cast<const char8_t*>(u8"caf\u00e9s")); // cafés
+  auto result = fmt::format(format, str);
+  EXPECT_EQ(fmt::internal::count_code_points(result), 4);
+  EXPECT_EQ(result.size(), 5);
+  EXPECT_EQ(result, str.substr(0, 5));
+}
EOF_114329324912

# Create and navigate into the build directory.
# All build and test execution steps will happen from within this directory.
mkdir -p build
cd build

# Required: Configure and build the project to include any changes from the patch in the test executables.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
cmake -DCMAKE_BUILD_TYPE=Release -GNinja ..
build_config_rc=$? # Capture exit code for CMake configuration
if [ $build_config_rc -ne 0 ]; then
    echo "CMake configuration failed with exit code $build_config_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Apply the fix for Out-Of-Memory errors during compilation by limiting parallel jobs.
# -j2 limits the build to 2 parallel compilation processes.
cmake --build . -j2
build_rc=$? # Capture exit code for CMake build

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute only the target test (format-test.cc) using CTest's regex feature.
# The 'format-test' executable is built from 'test/format-test.cc'.
# CTEST_OUTPUT_ON_FAILURE=1 for detailed test output on failure.
echo "Running specific ctest for format-test."
ctest --output-on-failure -R "format-test"
rc=$? # Capture the exit code of the test command immediately.

# Navigate back to the repository root for cleanup.
cd /testbed

# Cleanup: Revert changes made by the patch to the target test file.
git checkout d6eede9e085f0b36edcf0a2f6dff5f7875181019 "test/format-test.cc"

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.