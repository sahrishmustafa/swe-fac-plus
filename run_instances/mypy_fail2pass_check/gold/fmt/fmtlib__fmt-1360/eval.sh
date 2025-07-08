#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as operations like git checkout from a specific path require it.
cd /testbed

# Ensure the target test files are in their original state before applying any patch.
# This resets them to the state at the target commit SHA, undoing any previous changes.
git checkout 96f91428c6ad2d19f1ce87ae160b78f52ed989fb "test/core-test.cc" "test/locale-test.cc"

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
diff --git a/test/core-test.cc b/test/core-test.cc
--- a/test/core-test.cc
+++ b/test/core-test.cc
@@ -290,8 +290,6 @@ VISIT_TYPE(long, long long);
 VISIT_TYPE(unsigned long, unsigned long long);
 #endif
 
-VISIT_TYPE(float, double);
-
 #define CHECK_ARG_(Char, expected, value)                                     \
   {                                                                           \
     testing::StrictMock<mock_visitor<decltype(expected)>> visitor;            \
diff --git a/test/locale-test.cc b/test/locale-test.cc
--- a/test/locale-test.cc
+++ b/test/locale-test.cc
@@ -23,7 +23,7 @@ TEST(LocaleTest, DoubleDecimalPoint) {
   fmt::internal::writer w(buf, fmt::internal::locale_ref(loc));
   auto specs = fmt::format_specs();
   specs.type = 'n';
-  w.write_double<double, false>(1.23, specs);
+  w.write_fp<double, false>(1.23, specs);
   EXPECT_EQ(fmt::to_string(buf), "1?23");
 }
 
EOF_114329324912

# Navigate into the pre-existing build directory to rebuild.
# The Dockerfile configured and built the project in the '_build' directory.
cd _build

# Required: rebuild the project to include any changes from the patch in the test executables.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
cmake --build .
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute target tests using ctest.
# As per collected information, individual files cannot be targeted via `make test`.
# `make test` executes the entire CTest suite defined by the project.
# Set CTEST_OUTPUT_ON_FAILURE=1 for detailed test output on failure.
echo "Running make test (full CTest suite)."
CTEST_OUTPUT_ON_FAILURE=1 make test
rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test files.
# Navigate back to the repository root first to ensure `git checkout` operates correctly on paths relative to the root.
cd /testbed
git checkout 96f91428c6ad2d19f1ce87ae160b78f52ed989fb "test/core-test.cc" "test/locale-test.cc"