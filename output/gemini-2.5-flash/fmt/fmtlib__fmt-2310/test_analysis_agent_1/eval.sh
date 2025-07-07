#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Ensure the target test files are in their original state before applying any patch
# Use the specific commit SHA bc13c6de390751ecf8daa1b1ce8f775d104fdc65 for target files
git checkout bc13c6de390751ecf8daa1b1ce8f775d104fdc65 "test/format-test.cc"

# Required: apply test patch to update target tests (if any)
# The content of the patch will be inserted here programmatically
git apply -v - <<'EOF_114329324912'
diff --git a/test/format-test.cc b/test/format-test.cc
--- a/test/format-test.cc
+++ b/test/format-test.cc
@@ -1272,10 +1272,16 @@ TEST(format_test, format_nan) {
   double nan = std::numeric_limits<double>::quiet_NaN();
   EXPECT_EQ("nan", fmt::format("{}", nan));
   EXPECT_EQ("+nan", fmt::format("{:+}", nan));
-  if (std::signbit(-nan))
+  EXPECT_EQ("  +nan", fmt::format("{:+06}", nan));
+  EXPECT_EQ("+nan  ", fmt::format("{:<+06}", nan));
+  EXPECT_EQ(" +nan ", fmt::format("{:^+06}", nan));
+  EXPECT_EQ("  +nan", fmt::format("{:>+06}", nan));
+  if (std::signbit(-nan)) {
     EXPECT_EQ("-nan", fmt::format("{}", -nan));
-  else
+    EXPECT_EQ("  -nan", fmt::format("{:+06}", -nan));
+  } else {
     fmt::print("Warning: compiler doesn't handle negative NaN correctly");
+  }
   EXPECT_EQ(" nan", fmt::format("{: }", nan));
   EXPECT_EQ("NAN", fmt::format("{:F}", nan));
   EXPECT_EQ("nan    ", fmt::format("{:<7}", nan));
@@ -1288,6 +1294,11 @@ TEST(format_test, format_infinity) {
   EXPECT_EQ("inf", fmt::format("{}", inf));
   EXPECT_EQ("+inf", fmt::format("{:+}", inf));
   EXPECT_EQ("-inf", fmt::format("{}", -inf));
+  EXPECT_EQ("  +inf", fmt::format("{:+06}", inf));
+  EXPECT_EQ("  -inf", fmt::format("{:+06}", -inf));
+  EXPECT_EQ("+inf  ", fmt::format("{:<+06}", inf));
+  EXPECT_EQ(" +inf ", fmt::format("{:^+06}", inf));
+  EXPECT_EQ("  +inf", fmt::format("{:>+06}", inf));
   EXPECT_EQ(" inf", fmt::format("{: }", inf));
   EXPECT_EQ("INF", fmt::format("{:F}", inf));
   EXPECT_EQ("inf    ", fmt::format("{:<7}", inf));
EOF_114329324912

# Navigate into the pre-existing build directory created by the Dockerfile
# and rebuild the project to include any changes from the patch in the test binaries.
cd build
cmake --build .

# Execute target tests using ctest, filtering by the specific test name.
# The context indicates the test name corresponds to the specified test file's executable.
ctest --output-on-failure -R "format-test"
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test files
# Navigate back to the repository root first
cd /testbed
git checkout bc13c6de390751ecf8daa1b1ce8f775d104fdc65 "test/format-test.cc"