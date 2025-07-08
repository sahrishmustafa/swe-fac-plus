#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as all operations are relative to it.
cd /testbed

# Define the target commit SHA and test files to be cleaned/reverted.
TARGET_COMMIT_SHA="69396347af67b0307866a24283fcaaad02f98a59"
TARGET_TEST_FILES=(
    "test/compile-error-test/CMakeLists.txt"
    "test/format-test.cc"
)

# Ensure the target test files are in their original state before applying any patch.
# This resets them to the state at the target commit SHA, undoing any previous changes.
echo "Checking out target files to a clean state..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$TARGET_COMMIT_SHA" "$FILE"
done

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
echo "Applying test patch..."
git apply -v - <<'EOF_114329324912'
diff --git a/test/compile-error-test/CMakeLists.txt b/test/compile-error-test/CMakeLists.txt
--- a/test/compile-error-test/CMakeLists.txt
+++ b/test/compile-error-test/CMakeLists.txt
@@ -6,6 +6,8 @@ project(compile-error-test CXX)
 set(fmt_headers "
   #include <fmt/format.h>
   #include <fmt/xchar.h>
+  #include <fmt/ostream.h>
+  #include <iostream>
 ")
 
 set(error_test_names "")
@@ -154,6 +156,16 @@ expect_compile(format-function-error "
   fmt::format(\"{}\", f);
 " ERROR)
 
+# Formatting an unformattable argument should always be a compile time error
+expect_compile(format-lots-of-arguments-with-unformattable "
+  struct E {};
+  fmt::format(\"\", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, E());
+" ERROR)
+expect_compile(format-lots-of-arguments-with-function "
+  void (*f)();
+  fmt::format(\"\", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, f);
+" ERROR)
+
 # Make sure that compiler features detected in the header
 # match the features detected in CMake.
 if (SUPPORTS_USER_DEFINED_LITERALS)
@@ -181,6 +193,20 @@ if (CMAKE_CXX_STANDARD GREATER_EQUAL 20)
       #error
     #endif
   " ERROR)
+  expect_compile(print-string-number-spec-error "
+    #ifdef FMT_HAS_CONSTEVAL
+      fmt::print(\"{:d}\", \"I am not a number\");
+    #else
+      #error
+    #endif
+  " ERROR)
+  expect_compile(print-stream-string-number-spec-error "
+  #ifdef FMT_HAS_CONSTEVAL
+    fmt::print(std::cout, \"{:d}\", \"I am not a number\");
+  #else
+    #error
+  #endif
+  " ERROR)
 
   # Compile-time argument name check
   expect_compile(format-string-name "
diff --git a/test/format-test.cc b/test/format-test.cc
--- a/test/format-test.cc
+++ b/test/format-test.cc
@@ -1816,6 +1816,7 @@ TEST(format_test, compile_time_string) {
                                   "foo"_a = "foo"));
   EXPECT_EQ("", fmt::format(FMT_STRING("")));
   EXPECT_EQ("", fmt::format(FMT_STRING(""), "arg"_a = 42));
+  EXPECT_EQ("42", fmt::format(FMT_STRING("{answer}"), "answer"_a = Answer()));
 #endif
 
   (void)static_with_null;
@@ -1885,6 +1886,8 @@ TEST(format_test, named_arg_udl) {
       fmt::format("{first}{second}{first}{third}", fmt::arg("first", "abra"),
                   fmt::arg("second", "cad"), fmt::arg("third", 99)),
       udl_a);
+
+  EXPECT_EQ("42", fmt::format("{answer}", "answer"_a = Answer()));
 }
 #endif  // FMT_USE_USER_DEFINED_LITERALS
 
EOF_114329324912

# Navigate into the build directory for recompilation and testing.
# The Dockerfile already creates and enters 'build' during initial setup.
cd build

# Configure CMake for the project. This ensures CMake is aware of any changes from the patch.
echo "Reconfiguring CMake..."
cmake .. -DCMAKE_BUILD_TYPE=Release -DFMT_TEST=ON
cmake_config_rc=$?

if [ $cmake_config_rc -ne 0 ]; then
    echo "CMake configuration failed with exit code $cmake_config_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Required: rebuild the project to include any changes from the patch in the test executables.
# Using -j$(nproc) for optimal parallel compilation, addressing potential Out-Of-Memory issues.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
echo "Building the project..."
cmake --build . -j$(nproc)
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute target tests using ctest.
# The context retrieval agent indicates that `test/compile-error-test/CMakeLists.txt`
# and `test/format-test.cc` are part of the larger test suite built and executed by CTest.
# As CTest typically runs tests based on internal discovery, the most reliable way to ensure
# these specific tests are run is to execute the main CTest suite.
echo "Running tests using ctest..."
export CTEST_OUTPUT_ON_FAILURE=True # This ensures full output for failed tests
ctest -C Release # Run tests configured for the Release build type from within the build directory

rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test files.
# Navigate back to the repository root first to ensure `git checkout` operates correctly.
cd /testbed
echo "Cleaning up: Reverting test file changes..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$TARGET_COMMIT_SHA" "$FILE"
done