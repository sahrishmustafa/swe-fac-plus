#!/bin/bash
set -uxo pipefail

# Ensure we are in the /testbed directory
cd /testbed

# Define the target commit SHA and the specific test file to be managed.
# This ensures that even if the file was modified locally or by a previous run,
# it is reset to its state at the target commit before applying any patch.
COMMIT_SHA="65c9a1d31a338f28ef93cd61c475efc40f6cc42e"
TARGET_TEST_FILE="tests/SelfTest/UsageTests/Compilation.tests.cpp"

echo "Resetting $TARGET_TEST_FILE to its state at commit $COMMIT_SHA..."
git checkout "$COMMIT_SHA" "$TARGET_TEST_FILE" || { echo "Failed to checkout $TARGET_TEST_FILE. Aborting."; exit 1; }

# Apply the test patch if provided. The content of the patch is inserted here
# programmatically by the evaluation system.
echo "Attempting to apply test patch..."
git apply -v - <<'EOF_114329324912'
diff --git a/tests/SelfTest/UsageTests/Compilation.tests.cpp b/tests/SelfTest/UsageTests/Compilation.tests.cpp
--- a/tests/SelfTest/UsageTests/Compilation.tests.cpp
+++ b/tests/SelfTest/UsageTests/Compilation.tests.cpp
@@ -277,3 +277,42 @@ namespace {
 TEST_CASE("Immovable types are supported in basic assertions", "[compilation][.approvals]") {
     REQUIRE(ImmovableType{} == ImmovableType{});
 }
+
+namespace adl {
+
+struct always_true {
+    explicit operator bool() const { return true; }
+};
+
+#define COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(op) \
+template <class T, class U> \
+auto operator op (T&&, U&&) { \
+    return always_true{}; \
+}
+
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(==)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(!=)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(<)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(>)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(<=)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(>=)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(|)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(&)
+COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR(^)
+
+#undef COMPILATION_TEST_DEFINE_UNIVERSAL_OPERATOR
+
+}
+
+TEST_CASE("ADL universal operators don't hijack expression deconstruction", "[compilation][.approvals]") {
+    REQUIRE(adl::always_true{});
+    REQUIRE(0 == adl::always_true{});
+    REQUIRE(0 != adl::always_true{});
+    REQUIRE(0 < adl::always_true{});
+    REQUIRE(0 > adl::always_true{});
+    REQUIRE(0 <= adl::always_true{});
+    REQUIRE(0 >= adl::always_true{});
+    REQUIRE(0 | adl::always_true{});
+    REQUIRE(0 & adl::always_true{});
+    REQUIRE(0 ^ adl::always_true{});
+}
EOF_114329324912

# Navigate to the 'Build' directory, where the CMake-generated executables and tests reside.
# The Dockerfile has already performed the build steps, including creating and populating 'Build'.
echo "Navigating to /testbed/Build directory for test execution..."
cd /testbed/Build || { echo "Error: 'Build' directory not found at /testbed/Build. Ensure build steps completed in Dockerfile."; exit 1; }

# IMPORTANT: Recompile the project after applying the patch to incorporate changes.
# This ensures that any modifications made by the patch to source files (like tests/SelfTest/UsageTests/Compilation.tests.cpp)
# are compiled into the test executables, making the new/modified tests discoverable.
echo "Recompiling project after patch application to integrate changes..."
make -j $(nproc) || { echo "Error: Failed to recompile project. Aborting."; exit 1; }

# Execute the specific Catch2 self-test executable directly.
# The previous attempt with `ctest -R "Catch2_SelfTest"` failed to find tests,
# indicating that direct execution of the binary is required for these tests.
# The executable for self-tests is located at `./tests/SelfTest` relative to the Build directory.
echo "Directly executing Catch2 SelfTest executable: ./tests/SelfTest"
./tests/SelfTest
rc=$? # Capture the exit code of the executable immediately

# Output the captured exit code. This is crucial for the judging system.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the /testbed directory for cleanup.
echo "Navigating back to /testbed for cleanup operations..."
cd /testbed || { echo "Failed to navigate back to /testbed. Cleanup skipped."; exit $rc; }

# Clean up: Reset the target test file to its original state from the repository.
# This ensures a clean state for any subsequent operations or for future runs.
echo "Resetting $TARGET_TEST_FILE after test run..."
git checkout "$COMMIT_SHA" "$TARGET_TEST_FILE" || { echo "Failed to reset $TARGET_TEST_FILE. Manual intervention might be required."; }

# Exit with the captured test result code.
exit $rc