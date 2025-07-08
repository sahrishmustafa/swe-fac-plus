#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as all operations are relative to it.
cd /testbed

# Ensure the target test files are in their original state before applying any patch.
# This resets them to the state at the target commit SHA, undoing any previous changes.
git checkout cfc05e05f08dc0b6fe619831c96f00ee27d99613 "test/color-test.cc"

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
diff --git a/test/color-test.cc b/test/color-test.cc
--- a/test/color-test.cc
+++ b/test/color-test.cc
@@ -20,10 +20,16 @@ TEST(color_test, format) {
       fmt::format(fg(fmt::color::blue) | bg(fmt::color::red), "two color"),
       "\x1b[38;2;000;000;255m\x1b[48;2;255;000;000mtwo color\x1b[0m");
   EXPECT_EQ(fmt::format(fmt::emphasis::bold, "bold"), "\x1b[1mbold\x1b[0m");
+  EXPECT_EQ(fmt::format(fmt::emphasis::faint, "faint"), "\x1b[2mfaint\x1b[0m");
   EXPECT_EQ(fmt::format(fmt::emphasis::italic, "italic"),
             "\x1b[3mitalic\x1b[0m");
   EXPECT_EQ(fmt::format(fmt::emphasis::underline, "underline"),
             "\x1b[4munderline\x1b[0m");
+  EXPECT_EQ(fmt::format(fmt::emphasis::blink, "blink"), "\x1b[5mblink\x1b[0m");
+  EXPECT_EQ(fmt::format(fmt::emphasis::reverse, "reverse"),
+            "\x1b[7mreverse\x1b[0m");
+  EXPECT_EQ(fmt::format(fmt::emphasis::conceal, "conceal"),
+            "\x1b[8mconceal\x1b[0m");
   EXPECT_EQ(fmt::format(fmt::emphasis::strikethrough, "strikethrough"),
             "\x1b[9mstrikethrough\x1b[0m");
   EXPECT_EQ(
EOF_114329324912

# Create and navigate into the build directory.
# The project will be configured and built here.
mkdir -p build
cd build

# Configure CMake for the project.
# -DFMT_TEST=ON enables test compilation.
# -DCMAKE_BUILD_TYPE=Release for optimized build.
echo "Configuring CMake..."
cmake .. -DCMAKE_BUILD_TYPE=Release -DFMT_TEST=ON
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
cmake --build . -j$(nproc)
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute target tests using ctest.
# Set CTEST_OUTPUT_ON_FAILURE=True for detailed test output on failure.
# Use ctest -R to run only the specified test files by matching their CTest names.
echo "Running target tests: color-test"
export CTEST_OUTPUT_ON_FAILURE=True
ctest -R "color-test" -C Release
rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test files.
# Navigate back to the repository root first to ensure `git checkout` operates correctly on paths relative to the root.
cd /testbed
git checkout cfc05e05f08dc0b6fe619831c96f00ee27d99613 "test/color-test.cc"