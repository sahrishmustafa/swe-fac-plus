#!/bin/bash
set -euxo pipefail

# Navigate to the repository root as all operations are relative to it.
cd /testbed

# Ensure the target test file is in its original state before applying any patch.
# This resets it to the state at the target commit SHA, undoing any previous changes.
git checkout 8d9d528bf52c60864802844e8acf16db09dae19a "test/core-test.cc"

# Required: apply test patch to update target tests (if any).
# The actual content of the patch will be inserted here by the system.
git apply -v - <<'EOF_114329324912'
diff --git a/test/core-test.cc b/test/core-test.cc
--- a/test/core-test.cc
+++ b/test/core-test.cc
@@ -456,6 +456,66 @@ TEST(FormatDynArgsTest, CustomFormat) {
   EXPECT_EQ("cust=0 and cust=1 and cust=3", result);
 }
 
+TEST(FormatDynArgsTest, NamedInt) {
+  fmt::dynamic_format_arg_store<fmt::format_context> store;
+  store.push_back(fmt::arg("a1", 42));
+  std::string result = fmt::vformat("{a1}", store);
+  EXPECT_EQ("42", result);
+}
+
+TEST(FormatDynArgsTest, NamedStrings) {
+  fmt::dynamic_format_arg_store<fmt::format_context> store;
+  char str[]{"1234567890"};
+  store.push_back(fmt::arg("a1", str));
+  store.push_back(fmt::arg("a2", std::cref(str)));
+  str[0] = 'X';
+
+  std::string result = fmt::vformat(
+      "{a1} and {a2}",
+      store);
+
+  EXPECT_EQ("1234567890 and X234567890", result);
+}
+
+TEST(FormatDynArgsTest, NamedArgByRef) {
+  fmt::dynamic_format_arg_store<fmt::format_context> store;
+
+  // Note: fmt::arg() constructs an object which holds a reference
+  // to its value. It's not an aggregate, so it doesn't extend the
+  // reference lifetime. As a result, it's a very bad idea passing temporary
+  // as a named argument value. Only GCC with optimization level >0
+  // complains about this.
+  //
+  // A real life usecase is when you have both name and value alive
+  // guarantee their lifetime and thus don't want them to be copied into
+  // storages.
+  int a1_val{42};
+  auto a1 = fmt::arg("a1_", a1_val);
+  store.push_back("abc");
+  store.push_back(1.5f);
+  store.push_back(std::cref(a1));
+
+  std::string result = fmt::vformat(
+      "{a1_} and {} and {} and {}",
+      store);
+
+  EXPECT_EQ("42 and abc and 1.5 and 42", result);
+}
+
+TEST(FormatDynArgsTest, NamedCustomFormat) {
+  fmt::dynamic_format_arg_store<fmt::format_context> store;
+  custom_type c{};
+  store.push_back(fmt::arg("c1", c));
+  ++c.i;
+  store.push_back(fmt::arg("c2", c));
+  ++c.i;
+  store.push_back(fmt::arg("c_ref", std::cref(c)));
+  ++c.i;
+
+  std::string result = fmt::vformat("{c1} and {c2} and {c_ref}", store);
+  EXPECT_EQ("cust=0 and cust=1 and cust=3", result);
+}
+
 struct copy_throwable {
   copy_throwable() {}
   copy_throwable(const copy_throwable&) { throw "deal with it"; }
EOF_114329324912

# Navigate into the build directory to rebuild the project.
# The project has already been configured by the Dockerfile's RUN commands.
echo "Navigating to build directory for recompilation..."
cd /testbed/build

# Required: rebuild the project to include any changes from the patch in the test executables.
# CRITICAL: If the build/compilation step fails, the script must immediately set rc=1 and exit.
# Do not continue to run tests if the build fails, as this may run outdated binaries and produce false positive results.
echo "Building the project..."
make -j$(nproc)
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc. Setting OMNIGRIL_EXIT_CODE to 1 and exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute target tests using ctest.
# Set CTEST_OUTPUT_ON_FAILURE=1 for detailed test output on failure.
# Use ctest -R to run only the specified test file by matching its CTest name.
echo "Running target test: core-test"
export CTEST_OUTPUT_ON_FAILURE=1
ctest -R "core-test"
rc=$? # Capture the exit code of the test command immediately.

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the captured exit code for result parsing.

# Cleanup: Revert changes made by the patch to the target test file.
# Navigate back to the repository root first to ensure `git checkout` operates correctly on paths relative to the root.
cd /testbed
git checkout 8d9d528bf52c60864802844e8acf16db09dae19a "test/core-test.cc"