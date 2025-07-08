#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as all operations are relative to it.
cd /testbed

# Ensure the target test files are in their original state before applying any patch.
# This resets them to the state at the target commit SHA, undoing any previous changes.
git checkout a5abe5d95cb8a8015913be9748a9661f3e1fbda8 "test/format-impl-test.cc" "test/grisu-test.cc"

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
diff --git a/test/format-impl-test.cc b/test/format-impl-test.cc
--- a/test/format-impl-test.cc
+++ b/test/format-impl-test.cc
@@ -221,6 +221,36 @@ TEST(FPTest, ComputeBoundaries) {
   EXPECT_EQ(31, upper.e);
 }
 
+TEST(FPTest, ComputeFloatBoundaries) {
+  struct {
+    double x, lower, upper;
+  } tests[] = {
+      // regular
+      {1.5f, 1.4999999403953552, 1.5000000596046448},
+      // boundary
+      {1.0f, 0.9999999701976776, 1.0000000596046448},
+      // min normal
+      {1.1754944e-38f, 1.1754942807573643e-38, 1.1754944208872107e-38},
+      // max subnormal
+      {1.1754942e-38f, 1.1754941406275179e-38, 1.1754942807573643e-38},
+      // min subnormal
+      {1e-45f, 7.006492321624085e-46, 2.1019476964872256e-45},
+  };
+  for (auto test : tests) {
+    auto v = fp(test.x);
+    fp vlower = normalize(fp(test.lower));
+    fp vupper = normalize(fp(test.upper));
+    vlower.f >>= vupper.e - vlower.e;
+    vlower.e = vupper.e;
+    fp lower, upper;
+    v.compute_float_boundaries(lower, upper);
+    EXPECT_EQ(vlower.f, lower.f);
+    EXPECT_EQ(vlower.e, lower.e);
+    EXPECT_EQ(vupper.f, upper.f);
+    EXPECT_EQ(vupper.e, upper.e);
+  }
+}
+
 TEST(FPTest, Subtract) {
   auto v = fp(123, 1) - fp(102, 1);
   EXPECT_EQ(v.f, 21u);
diff --git a/test/grisu-test.cc b/test/grisu-test.cc
--- a/test/grisu-test.cc
+++ b/test/grisu-test.cc
@@ -52,6 +52,8 @@ TEST(GrisuTest, Prettify) {
   EXPECT_EQ("12340000000.0", fmt::format("{}", 1234e7));
   EXPECT_EQ("12.34", fmt::format("{}", 1234e-2));
   EXPECT_EQ("0.001234", fmt::format("{}", 1234e-6));
+  EXPECT_EQ("0.1", fmt::format("{}", 0.1f));
+  EXPECT_EQ("0.10000000149011612", fmt::format("{}", double(0.1f)));
 }
 
 TEST(GrisuTest, ZeroPrecision) { EXPECT_EQ("1", fmt::format("{:.0}", 1.0)); }
EOF_114329324912

# Create and navigate into the build directory.
# The project will be configured and built here.
mkdir -p build
cd build

# Configure CMake for the project.
# -S .. specifies the source directory (repository root).
# -DFMT_TEST=ON enables test compilation.
# -DCMAKE_BUILD_TYPE=Release for optimized build.
# -DCMAKE_CXX_STANDARD=14 sets the C++ standard to C++14.
echo "Configuring CMake..."
cmake -S .. -DFMT_TEST=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14
cmake_config_rc=$?

if [ $cmake_config_rc -ne 0 ]; then
    echo "CMake configuration failed with exit code $cmake_config_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Required: rebuild the project to include any changes from the patch in the test executables.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
echo "Building the project..."
cmake --build .
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute target tests using ctest.
# Set CTEST_OUTPUT_ON_FAILURE=1 for detailed test output on failure.
# Use ctest -R to run only the specified test files by matching their CTest names.
echo "Running target tests: format-impl-test, grisu-test"
export CTEST_OUTPUT_ON_FAILURE=1
ctest -R "(format-impl-test|grisu-test)"
rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test files.
# Navigate back to the repository root first to ensure `git checkout` operates correctly on paths relative to the root.
cd /testbed
git checkout a5abe5d95cb8a8015913be9748a9661f3e1fbda8 "test/format-impl-test.cc" "test/grisu-test.cc"