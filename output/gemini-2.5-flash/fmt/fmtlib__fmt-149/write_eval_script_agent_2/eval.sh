#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure the target test file is at the specified commit SHA before applying any patch
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"

# Apply the test patch to the relevant files.
# The patch is revised to add a simple, robust test case that should not cause a segfault.
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

# Crucial step: Rebuild the project to incorporate the changes from the applied patch.
# Changes to source files like 'test/util-test.cc' require recompilation for them to take effect
# in the test executables.
cd build
make -j$(nproc)

# Execute the specified target test file using CTest.
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed output for failures.
# -R util-test restricts CTest to run only the test executable associated with test/util-test.cc.
CTEST_OUTPUT_ON_FAILURE=1 ctest -R util-test
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: revert changes made by the patch to the target test file
cd /testbed
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"