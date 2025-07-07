#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure the target test file is at the specified commit SHA before applying any patch
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"

# Apply the test patch to the relevant files.
git apply -v - <<'EOF_114329324912'
--- a/test/util-test.cc
+++ b/test/util-test.cc
@@ -101,3 +101,7 @@
 TEST(UtilTest, IsUnicodeScalarWithChar8t) {
   EXPECT_TRUE(is_unicode_scalar(u8'\U0001F600'));
 }
+#endif // __cpp_lib_char8_t
+
+TEST(UtilTest, BasicFormatting) {
+  EXPECT_EQ(fmt::format("{}", 42), "42");
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
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed output for failures.
# -R util-test restricts CTest to run only the test executable associated with test/util-test.cc.
CTEST_OUTPUT_ON_FAILURE=1 ctest -R util-test
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: revert changes made by the patch to the target test file
cd /testbed
git checkout 88f4be3d19364a484431309f750535386c7d0d5c "test/util-test.cc"