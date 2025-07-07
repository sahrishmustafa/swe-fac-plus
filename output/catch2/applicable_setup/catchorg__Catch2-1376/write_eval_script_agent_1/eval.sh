#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory
cd /testbed

# Checkout the specific test file to its original state at the commit SHA
# This ensures a clean state before applying any potential patches.
git checkout 1eb42eed974f944401091325bbe8e61b38fd0678 "projects/SelfTest/UsageTests/ToStringGeneral.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/projects/SelfTest/UsageTests/ToStringGeneral.tests.cpp b/projects/SelfTest/UsageTests/ToStringGeneral.tests.cpp
--- a/projects/SelfTest/UsageTests/ToStringGeneral.tests.cpp
+++ b/projects/SelfTest/UsageTests/ToStringGeneral.tests.cpp
@@ -116,6 +116,18 @@ TEST_CASE("Static arrays are convertible to string", "[toString]") {
     }
 }
 
+#ifdef CATCH_CONFIG_CPP17_STRING_VIEW
+
+TEST_CASE("String views are stringified like other strings", "[toString][approvals]") {
+    std::string_view view{"abc"};
+    CHECK(Catch::Detail::stringify(view) == R"("abc")");
+
+    std::string_view arr[] { view };
+    CHECK(Catch::Detail::stringify(arr) == R"({ "abc" })");
+}
+
+#endif
+
 namespace {
 
 struct WhatException : std::exception {
EOF_114329324912

# Navigate to the build directory where the Catch2 'SelfTest' executable and CTest infrastructure are located.
# The Dockerfile ensures this directory exists and the project is built.
cd Build

# Execute the specific test cases related to ToStringGeneral.tests.cpp using ctest.
# We use a regex filter to attempt to run only tests originating from ToStringGeneral.tests.cpp,
# assuming test names registered with CTest contain "ToStringGeneral".
# CTEST_OUTPUT_ON_FAILURE=1 is crucial for seeing test output on failure.
# -j $(nproc) allows parallel test execution.
# -R ".*ToStringGeneral.*" filters tests by name matching the given regex.
CTEST_OUTPUT_ON_FAILURE=1 ctest -j $(nproc) -R ".*ToStringGeneral.*"
rc=$? # Capture the exit code of the test command

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific test file again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout 1eb42eed974f944401091325bbe8e61b38fd0678 "projects/SelfTest/UsageTests/ToStringGeneral.tests.cpp"