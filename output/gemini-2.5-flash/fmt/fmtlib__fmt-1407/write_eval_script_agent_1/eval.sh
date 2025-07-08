#!/bin/bash
set -uxo pipefail

# Navigate to the repository root for git operations.
cd /testbed

# Define target commit SHA and test files for clarity and reusability.
TARGET_COMMIT_SHA="1f918159edded99c9c0cf005c96ecc12e4cc92b1"
TEST_FILES="test/core-test.cc test/format-test.cc"

# Ensure the target test files are in their original state before applying any patch.
# This resets them to the state at the target commit SHA, undoing any previous changes.
git checkout "${TARGET_COMMIT_SHA}" ${TEST_FILES}

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
diff --git a/test/core-test.cc b/test/core-test.cc
--- a/test/core-test.cc
+++ b/test/core-test.cc
@@ -453,11 +453,11 @@ template <> struct formatter<enabled_formatter> {
 FMT_END_NAMESPACE
 
 TEST(CoreTest, HasFormatter) {
-  using fmt::internal::has_formatter;
+  using fmt::has_formatter;
   using context = fmt::format_context;
-  EXPECT_TRUE((has_formatter<enabled_formatter, context>::value));
-  EXPECT_FALSE((has_formatter<disabled_formatter, context>::value));
-  EXPECT_FALSE((has_formatter<disabled_formatter_convertible, context>::value));
+  static_assert(has_formatter<enabled_formatter, context>::value, "");
+  static_assert(!has_formatter<disabled_formatter, context>::value, "");
+  static_assert(!has_formatter<disabled_formatter_convertible, context>::value, "");
 }
 
 struct convertible_to_int {
diff --git a/test/format-test.cc b/test/format-test.cc
--- a/test/format-test.cc
+++ b/test/format-test.cc
@@ -1974,8 +1974,8 @@ enum TestEnum { A };
 TEST(FormatTest, Enum) { EXPECT_EQ("0", fmt::format("{}", A)); }
 
 TEST(FormatTest, FormatterNotSpecialized) {
-  EXPECT_FALSE((fmt::internal::has_formatter<fmt::formatter<TestEnum>,
-                                             fmt::format_context>::value));
+  static_assert(!fmt::has_formatter<fmt::formatter<TestEnum>,
+                                    fmt::format_context>::value, "");
 }
 
 #if FMT_HAS_FEATURE(cxx_strong_enums)
EOF_114329324912

# Navigate into the pre-existing build directory.
# The Dockerfile has already created and configured the 'build' directory.
cd build

# Required: Rebuild the project to include any changes from the patch in the test executables.
# Using -j2 as suggested in the provided skeleton to prevent potential Out-Of-Memory errors during compilation.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
cmake --build . -j2
build_rc=$? # Capture exit code for CMake build

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute only the target tests (core-test.cc and format-test.cc) using CTest's regex feature.
# The CTest executable names are typically derived from their source file names (core-test, format-test).
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed test output on failure.
echo "Running specific ctest for core-test and format-test."
CTEST_OUTPUT_ON_FAILURE=1 ctest --output-on-failure -R "(core-test|format-test)"
rc=$? # Capture the exit code of the test command immediately.

# Navigate back to the repository root for cleanup.
cd /testbed

# Cleanup: Revert changes made by the patch to the target test files.
git checkout "${TARGET_COMMIT_SHA}" ${TEST_FILES}

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.