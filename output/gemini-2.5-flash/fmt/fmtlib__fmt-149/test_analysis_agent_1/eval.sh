#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned and built
cd /testbed

# Ensure the target test file is in a clean state before applying the patch.
# This assumes the patch is intended for test/util-test.cc
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"

# Apply the test patch. The content is provided via heredoc standard input.
# The actual patch content will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/test/util-test.cc b/test/util-test.cc
--- a/test/util-test.cc
+++ b/test/util-test.cc
@@ -423,7 +423,7 @@ ARG_INFO(POINTER, const void *, pointer);
 ARG_INFO(CUSTOM, Arg::CustomValue, custom);
 
 #define CHECK_ARG_INFO(Type, field, value) { \
-  Arg arg = {}; \
+  Arg arg = Arg(); \
   arg.field = value; \
   EXPECT_EQ(value, ArgInfo<Arg::Type>::get(arg)); \
 }
@@ -442,7 +442,7 @@ TEST(ArgTest, ArgInfo) {
   CHECK_ARG_INFO(WSTRING, wstring.value, WSTR);
   int p = 0;
   CHECK_ARG_INFO(POINTER, pointer, &p);
-  Arg arg = {};
+  Arg arg = Arg();
   arg.custom.value = &p;
   EXPECT_EQ(&p, ArgInfo<Arg::CUSTOM>::get(arg).value);
 }
@@ -842,3 +842,30 @@ TEST(UtilTest, IsEnumConvertibleToInt) {
 }
 #endif
 
+template <typename T>
+bool check_enable_if(
+    typename fmt::internal::EnableIf<sizeof(T) == sizeof(int), T>::type *) {
+  return true;
+}
+
+template <typename T>
+bool check_enable_if(
+    typename fmt::internal::EnableIf<sizeof(T) != sizeof(int), T>::type *) {
+  return false;
+}
+
+TEST(UtilTest, EnableIf) {
+  int i = 0;
+  EXPECT_TRUE(check_enable_if<int>(&i));
+  char c = 0;
+  EXPECT_FALSE(check_enable_if<char>(&c));
+}
+
+TEST(UtilTest, Conditional) {
+  int i = 0;
+  fmt::internal::Conditional<true, int, char>::type *pi = &i;
+  (void)pi;
+  char c = 0;
+  fmt::internal::Conditional<false, int, char>::type *pc = &c;
+  (void)pc;
+}
EOF_114329324912

# CRITICAL: Rebuild the project after applying the patch to ensure any
# modified source files (including test sources) are recompiled and new
# test binaries are generated or updated.
# Navigate to the build directory.
cd build

# Execute the make command to recompile the project.
# Use -j "$(nproc)" for parallel compilation.
# If the build fails, capture the error, set rc=1, and exit immediately.
make -j "$(nproc)"
if [ $? -ne 0 ]; then
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute the tests using CTest via make test from the build directory.
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed output on test failures.
# As per collected information, test/util-test.cc is part of the general
# make test command, and there is no specific command to run only this file.
# Running `make test` will pick up the changes from the patched file.
CTEST_OUTPUT_ON_FAILURE=1 make test
rc=$? # Capture the exit code of the test execution

# Go back to the /testbed root directory for cleanup.
cd ..

# Echo the exit code in the required format for Omnigril.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: revert changes to the target test file to its original state.
# This ensures the repository is clean for subsequent runs if any.
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"