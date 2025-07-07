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

# Test execution
# Navigate into the build directory where the test executables are located.
# The project has already been built by the Dockerfile.
cd build

# Run specific tests: ctest will execute tests matching the regex 'chrono-test',
# which corresponds to the test/chrono-test.cc file.
ctest -R chrono-test
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test file
cd /testbed # Ensure we are in the repository root for git checkout
git checkout c7e6d8afb06cec7b8244f963dc081daf7e70f7f6 "test/chrono-test.cc"