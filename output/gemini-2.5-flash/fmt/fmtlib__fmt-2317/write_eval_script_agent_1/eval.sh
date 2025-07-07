#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Ensure the target test files are in their original state before applying any patch
# Use the specific commit SHA and target files
git checkout 7612f18dc8e0112e64e0845a1ebe9da6cfb8a123 "test/format-test.cc"

# Required: apply test patch to update target tests (if any)
# The content of the patch will be inserted here programmatically
git apply -v - <<'EOF_114329324912'
diff --git a/test/format-test.cc b/test/format-test.cc
--- a/test/format-test.cc
+++ b/test/format-test.cc
@@ -1215,6 +1215,8 @@ TEST(format_test, format_double) {
   EXPECT_EQ("392.650000", fmt::format("{:f}", 392.65));
   EXPECT_EQ("392.650000", fmt::format("{:F}", 392.65));
   EXPECT_EQ("42", fmt::format("{:L}", 42.0));
+  EXPECT_EQ("    0x1.0cccccccccccdp+2", fmt::format("{:24a}", 4.2));
+  EXPECT_EQ("0x1.0cccccccccccdp+2    ", fmt::format("{:<24a}", 4.2));
   char buffer[buffer_size];
   safe_sprintf(buffer, "%e", 392.65);
   EXPECT_EQ(buffer, fmt::format("{0:e}", 392.65));
EOF_114329324912

# Navigate into the pre-existing build directory created by the Dockerfile
# and rebuild the project to include any changes from the patch in the test binaries.
cd build
cmake --build .

# Execute target tests using ctest, filtering by the specific test name.
# The context indicates the test name corresponds to the specified test file's executable.
# For 'test/format-test.cc', the generated executable is typically 'format-test'.
ctest --output-on-failure -R "format-test"
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test files
# Navigate back to the repository root first
cd /testbed
git checkout 7612f18dc8e0112e64e0845a1ebe9da6cfb8a123 "test/format-test.cc"