#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure the target test file is at the specified commit SHA before applying any patch
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"

# Apply the test patch to the relevant files.
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

# Perform a clean and full rebuild after applying the patch to ensure consistency
cd /testbed
rm -rf build # Remove existing build directory
mkdir build # Create a new build directory
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DFMT_EXTRA_TESTS=ON .. # Reconfigure CMake
make -j$(nproc) # Perform a full clean build

# Execute the specified target test file using CTest.
# Capture its exit code to determine if it crashed.
CTEST_OUTPUT_ON_FAILURE=1 ctest -R util-test
rc=$?

# If the test crashed (ctest returns non-zero for failure, often 8 for segfault),
# run GDB to get a backtrace for diagnostic purposes.
if [ $rc -ne 0 ]; then
  echo "--- Test failed (${rc}), attempting to get GDB backtrace for util-test ---"
  # Temporarily disable exit on error for GDB command, as GDB itself might return non-zero
  # even if it successfully captures a backtrace from a crashing program.
  set +e
  /usr/bin/gdb -ex "set pagination off" -ex "run" -ex "thread apply all bt full" -ex "quit" --batch --args /testbed/build/bin/util-test
  # Re-enable exit on error for the rest of the script, if any.
  set -e
fi

# Report the overall test result based on the CTest execution outcome.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: revert changes made by the patch to the target test file
cd /testbed
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"