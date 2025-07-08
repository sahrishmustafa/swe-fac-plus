#!/bin/bash
set -uxo pipefail

# Navigate to the repository root for git operations and build commands.
cd /testbed

# Define target commit SHA and the specific test file(s) to be managed.
TARGET_COMMIT_SHA="308510eb4fad9b112ebdd2867b0b96338b0a9a36"
TEST_FILES="test/format-test.cc"
TEST_NAME="format-test" # The specific CTest target name for the test file "test/format-test.cc"

# Cleanup any previous build directory to ensure a clean slate.
echo "Cleaning up any existing build directory..."
rm -rf build

# --- Initial Project Build ---
# Create the build directory and configure CMake.
# This step is essential so that test executables are built before any patching.
echo "Performing initial CMake configuration..."
mkdir build
# Combined CMake configuration flags from context and skeleton (FMT_TEST=ON included to ensure tests are built)
cmake -S /testbed -B /testbed/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=17 \
      -DFMT_DOC=OFF \
      -DFMT_PEDANTIC=ON \
      -DFMT_WERROR=ON \
      -DFMT_TEST=ON
configure_rc=$? # Capture exit code for CMake configure

if [ $configure_rc -ne 0 ]; then
    echo "Initial CMake configure failed with exit code $configure_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Build the project, including the test executables.
# Using -j2 to limit parallel jobs and prevent potential OOM errors, as seen in similar contexts.
echo "Performing initial project build with -j2..."
cmake --build /testbed/build --config Release -j2
build_rc=$? # Capture exit code for CMake build

if [ $build_rc -ne 0 ]; then
    echo "Initial project build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Ensure the target test files are in their pristine state from the target commit
# before applying any patch. This prevents issues if previous runs left changes.
echo "Resetting target test file(s) to original commit state..."
git checkout "${TARGET_COMMIT_SHA}" ${TEST_FILES}

# --- Apply Test Patch ---
# Required: Apply the test patch to update target tests.
# The actual content of the patch will be inserted here by the system.
echo "Applying test patch..."
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

# --- Rebuild Project After Patch ---
# CRITICAL: Rebuild the project after applying the patch. This ensures that
# any new or modified tests from the patch are included in the test executables.
# Using -j2 to limit parallel jobs and prevent potential OOM errors.
echo "Rebuilding project after patch to include test changes with -j2..."
cmake --build /testbed/build --config Release -j2
rebuild_rc=$? # Capture exit code for the rebuild

if [ $rebuild_rc -ne 0 ]; then
    echo "Project rebuild after patch failed with exit code $rebuild_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# --- Execute Tests ---
# Navigate into the build directory where CTest is usually run.
echo "Navigating to build directory and running tests..."
cd /testbed/build

# Execute only the target test using CTest's regex feature.
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed test output on failure.
CTEST_OUTPUT_ON_FAILURE=1 ctest -C Release --output-on-failure -R "${TEST_NAME}"
rc=$? # Capture the exit code of the test command immediately for result parsing.

# --- Cleanup ---
# Navigate back to the repository root for cleanup.
cd /testbed

# Revert changes made by the patch to the target test files.
# This leaves the repository in a clean state after the evaluation.
echo "Cleaning up: Reverting changes made to test files by the patch..."
git checkout "${TARGET_COMMIT_SHA}" ${TEST_FILES}

# Required: Echo the captured exit code. This value is used by the test harness
# to determine the success or failure of the evaluation.
echo "OMNIGRIL_EXIT_CODE=$rc"