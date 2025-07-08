#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure the target test file is in its original state before applying any patch
git checkout c7e6d8afb06cec7b8244f963dc081daf7e70f7f6 "test/chrono-test.cc"

# Required: apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/test/chrono-test.cc b/test/chrono-test.cc
--- a/test/chrono-test.cc
+++ b/test/chrono-test.cc
@@ -95,6 +95,17 @@ TEST(TimeTest, GMTime) {
   EXPECT_TRUE(EqualTime(tm, fmt::gmtime(t)));
 }
 
+TEST(TimeTest, TimePoint) {
+  std::chrono::system_clock::time_point point = std::chrono::system_clock::now();
+
+  std::time_t t = std::chrono::system_clock::to_time_t(point);
+  std::tm tm = *std::localtime(&t);
+  char strftime_output[256];
+  std::strftime(strftime_output, sizeof(strftime_output), "It is %Y-%m-%d %H:%M:%S", &tm);
+
+  EXPECT_EQ(strftime_output, fmt::format("It is {:%Y-%m-%d %H:%M:%S}", point));
+}
+
 #define EXPECT_TIME(spec, time, duration)                 \
   {                                                       \
     std::locale loc("ja_JP.utf8");                        \
EOF_114329324912

# Required: Rebuild the project after applying the patch to include new/modified tests.
# 1. Create the build directory (if it doesn't exist)
mkdir -p build

# 2. Configure CMake with tests enabled and specified C++ standard
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DFMT_TEST=ON -DCMAKE_CXX_STANDARD=17
if [ $? -ne 0 ]; then
    echo "CMake configuration failed."
    rc=1
    # Ensure cleanup is performed even on failure
    cd /testbed
    git checkout c7e6d8afb06cec7b8244f963dc081daf7e70f7f6 "test/chrono-test.cc"
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# 3. Build the project
cmake --build build
if [ $? -ne 0 ]; then
    echo "CMake build failed."
    rc=1
    # Ensure cleanup is performed even on failure
    cd /testbed
    git checkout c7e6d8afb06cec7b8244f963dc081daf7e70f7f6 "test/chrono-test.cc"
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Test execution
# Navigate into the build directory where the test executables are located
cd build

# Run tests: ctest will execute the specific test case "chrono-test"
# -V for verbose output, --output-on-failure to show stdout/stderr for failed tests.
# -R "chrono-test" to run only tests whose name matches the regex.
ctest -V --output-on-failure -R "chrono-test"
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test file
cd /testbed # Ensure we are in the repository root for git checkout
git checkout c7e6d8afb06cec7b8244f963dc081daf7e70f7f6 "test/chrono-test.cc"