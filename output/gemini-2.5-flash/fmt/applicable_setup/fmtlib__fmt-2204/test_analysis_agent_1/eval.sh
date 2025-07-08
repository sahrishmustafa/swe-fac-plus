#!/bin/bash
set -uxo pipefail

# Navigate to the repository root
cd /testbed

# Ensure the target test files are in their original state before applying any patch
# Use the specific commit SHA and target files
git checkout 308510eb4fad9b112ebdd2867b0b96338b0a9a36 "test/format-test.cc"

# Required: apply test patch to update target tests (if any)
# The content of the patch will be inserted here programmatically
git apply -v - <<'EOF_114329324912'
diff --git a/test/format-test.cc b/test/format-test.cc
--- a/test/format-test.cc
+++ b/test/format-test.cc
@@ -217,6 +217,23 @@ static void check_move_buffer(
   EXPECT_EQ(alloc, buffer2.get_allocator().get());
 }
 
+TEST(BufferAppenderTest, BufferAppenderDefaultConstruct) {
+  // back_insert_iterator is not default-constructible before C++20, so
+  // buffer_appender can only be default-constructible when back_insert_iterator
+  // is.
+  static_assert(
+      std::is_default_constructible<
+          std::back_insert_iterator<fmt::detail::buffer<char>>>::value ==
+      std::is_default_constructible<fmt::detail::buffer_appender<char>>::value,
+      "");
+}
+
+#ifdef __cpp_lib_ranges
+TEST(BufferAppenderTest, BufferAppenderOutputIterator) {
+  static_assert(std::output_iterator<fmt::detail::buffer_appender<char>, char>);
+}
+#endif
+
 TEST(MemoryBufferTest, MoveCtorInlineBuffer) {
   std::allocator<char> alloc;
   basic_memory_buffer<char, 5, std_allocator> buffer((std_allocator(&alloc)));
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
git checkout 308510eb4fad9b112ebdd2867b0b96338b0a9a36 "test/format-test.cc"