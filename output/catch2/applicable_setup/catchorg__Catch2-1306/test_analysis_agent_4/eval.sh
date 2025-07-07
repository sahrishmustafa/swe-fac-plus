#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned.
cd /testbed

# Checkout the specific target test file to ensure it's in a clean state before patching.
# This prepares the file for the patch application.
git checkout 021fcee63667e346c619e04bbae932bcea562334 "projects/SelfTest/UsageTests/ToStringWhich.tests.cpp"

# Apply the test patch to the specified file.
# The actual patch content will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/projects/SelfTest/UsageTests/ToStringWhich.tests.cpp b/projects/SelfTest/UsageTests/ToStringWhich.tests.cpp
--- a/projects/SelfTest/UsageTests/ToStringWhich.tests.cpp
+++ b/projects/SelfTest/UsageTests/ToStringWhich.tests.cpp
@@ -20,6 +20,7 @@ struct has_operator { };
 struct has_maker {};
 struct has_maker_and_operator {};
 struct has_neither {};
+struct has_template_operator {};
 
 std::ostream& operator<<(std::ostream& os, const has_operator&) {
     os << "operator<<( has_operator )";
@@ -31,6 +32,12 @@ std::ostream& operator<<(std::ostream& os, const has_maker_and_operator&) {
     return os;
 }
 
+template <typename StreamT>
+StreamT& operator<<(StreamT& os, const has_template_operator&) {
+    os << "operator<<( has_template_operator )";
+    return os;
+}
+
 namespace Catch {
     template<>
     struct StringMaker<has_maker> {
@@ -69,6 +76,12 @@ TEST_CASE("stringify( has_neither )", "[toString]") {
     REQUIRE( ::Catch::Detail::stringify(item) == "{ !!! }" );
 }
 
+// Call the templated operator
+TEST_CASE( "stringify( has_template_operator )", "[toString]" ) {
+    has_template_operator item;
+    REQUIRE( ::Catch::Detail::stringify( item ) == "operator<<( has_template_operator )" );
+}
+
 
 // Vectors...
 
EOF_114329324912

# Build the project. The Dockerfile only configures CMake; the build step must be executed here.
# This ensures that the SelfTest executable containing the target tests is compiled.
# If the build fails, the script will exit immediately with status 1,
# preventing subsequent commands from executing and incorrectly reporting success.
cmake --build Build -j $(nproc) || exit 1

# Navigate into the CMake build directory to run tests with ctest.
pushd Build

# Execute tests using ctest.
# CTEST_OUTPUT_ON_FAILURE=1 ensures that full test output is shown on failure.
# -j $(nproc) runs tests in parallel.
# -R "ToStringWhich" filters tests to only those originating from "ToStringWhich.tests.cpp".
# This regex is based on how Catch2's catch_discover_tests typically names tests,
# incorporating parts of the source file name.
CTEST_OUTPUT_ON_FAILURE=1 ctest -j $(nproc) -R "ToStringWhich"

# Capture the exit code of the test command.
rc=$?

# Return to the original /testbed directory.
popd

# Echo the exit code for the test analysis agent.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: Discard any changes made to the target test file by the patch.
git checkout 021fcee63667e346c619e04bbae932bcea562334 "projects/SelfTest/UsageTests/ToStringWhich.tests.cpp"