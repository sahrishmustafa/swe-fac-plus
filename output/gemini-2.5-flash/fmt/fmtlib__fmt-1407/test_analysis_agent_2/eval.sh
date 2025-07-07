#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as operations like git checkout from a specific path require it.
cd /testbed

# Ensure the target test files are in their original state before applying any patch.
# This resets them to the state at the target commit SHA, undoing any previous changes (e.g., from prior patch applications).
git checkout 1f918159edded99c9c0cf005c96ecc12e4cc92b1 "test/core-test.cc" "test/format-test.cc"

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

# Navigate into the pre-existing build directory created by the Dockerfile.
# Tests are typically executed from this directory after compilation.
cd build

# Execute target tests using ctest.
# We use the -R (regex) option to run only the tests corresponding to the specified files.
# "test/core-test.cc" and "test/format-test.cc" usually compile into test executables named "core-test" and "format-test" respectively.
# --output-on-failure ensures that test output is only shown if a test fails, keeping the log clean for successful runs.
ctest --output-on-failure -R "(core-test|format-test)"
rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test files.
# Navigate back to the repository root first to ensure `git checkout` operates correctly on paths relative to the root.
cd /testbed
git checkout 1f918159edded99c9c0cf005c96ecc12e4cc92b1 "test/core-test.cc" "test/format-test.cc"