#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Ensure the target test files are in their original state before applying any patch
# Use the specific commit SHA and target files
git checkout 96f91428c6ad2d19f1ce87ae160b78f52ed989fb "test/core-test.cc" "test/locale-test.cc"

# Required: apply test patch to update target tests (if any)
# The content of the patch will be inserted here programmatically
git apply -v - <<'EOF_114329324912'
diff --git a/test/core-test.cc b/test/core-test.cc
--- a/test/core-test.cc
+++ b/test/core-test.cc
@@ -290,8 +290,6 @@ VISIT_TYPE(long, long long);
 VISIT_TYPE(unsigned long, unsigned long long);
 #endif
 
-VISIT_TYPE(float, double);
-
 #define CHECK_ARG_(Char, expected, value)                                     \
   {                                                                           \
     testing::StrictMock<mock_visitor<decltype(expected)>> visitor;            \
diff --git a/test/locale-test.cc b/test/locale-test.cc
--- a/test/locale-test.cc
+++ b/test/locale-test.cc
@@ -23,7 +23,7 @@ TEST(LocaleTest, DoubleDecimalPoint) {
   fmt::internal::writer w(buf, fmt::internal::locale_ref(loc));
   auto specs = fmt::format_specs();
   specs.type = 'n';
-  w.write_double<double, false>(1.23, specs);
+  w.write_fp<double, false>(1.23, specs);
   EXPECT_EQ(fmt::to_string(buf), "1?23");
 }
 
EOF_114329324912

# Navigate into the pre-existing build directory created by the Dockerfile
cd build

# Execute target tests using ctest, filtering by the specified test names.
# The context indicates test names correspond to file names.
ctest --output-on-failure -R "core-test|locale-test"
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test files
# Navigate back to the repository root first
cd /testbed
git checkout 96f91428c6ad2d19f1ce87ae160b78f52ed989fb "test/core-test.cc" "test/locale-test.cc"