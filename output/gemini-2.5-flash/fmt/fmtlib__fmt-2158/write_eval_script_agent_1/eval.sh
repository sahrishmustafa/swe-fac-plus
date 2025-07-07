#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Ensure the target test files are in their original state before applying any patch
# Use the specific commit SHA and target files
git checkout 835b910e7d758efdfdce9f23df1b190deb3373db "test/format-test.cc"

# Required: apply test patch to update target tests (if any)
# The content of the patch will be inserted here programmatically
git apply -v - <<'EOF_114329324912'
diff --git a/test/format-test.cc b/test/format-test.cc
--- a/test/format-test.cc
+++ b/test/format-test.cc
@@ -12,9 +12,11 @@
 #include <climits>
 #include <cmath>
 #include <cstring>
+#include <iterator>
 #include <list>
 #include <memory>
 #include <string>
+#include <type_traits>
 
 // Check if fmt/format.h compiles with windows.h included before it.
 #ifdef _WIN32
@@ -157,6 +159,24 @@ TEST(IteratorTest, TruncatingIterator) {
   EXPECT_EQ(it.base(), p + 1);
 }
 
+
+TEST(IteratorTest, TruncatingIteratorDefaultConstruct) {
+  static_assert(
+      std::is_default_constructible<fmt::detail::truncating_iterator<char*>>::value,
+      "");
+  
+  fmt::detail::truncating_iterator<char*> it;
+  EXPECT_EQ(nullptr, it.base());
+  EXPECT_EQ(std::size_t{0}, it.count());
+}
+
+#ifdef __cpp_lib_ranges
+TEST(IteratorTest, TruncatingIteratorOutputIterator) {
+  static_assert(std::output_iterator<fmt::detail::truncating_iterator<char*>,
+      char>);
+}
+#endif
+
 TEST(IteratorTest, TruncatingBackInserter) {
   std::string buffer;
   auto bi = std::back_inserter(buffer);
EOF_114329324912

# Navigate into the pre-existing build directory created by the Dockerfile
cd build

# Execute target tests using ctest, filtering by the specific test name.
# The context indicates the test name corresponds to the specified test file's executable.
ctest --output-on-failure -R "format-test"
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test files
# Navigate back to the repository root first
cd /testbed
git checkout 835b910e7d758efdfdce9f23df1b190deb3373db "test/format-test.cc"