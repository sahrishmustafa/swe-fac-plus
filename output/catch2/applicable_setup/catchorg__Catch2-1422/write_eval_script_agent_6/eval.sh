#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory
cd /testbed

# Checkout the specific test file to its original state at the commit SHA.
# This ensures a clean slate before applying any potential patches.
git checkout 1faccd601d904a951142d8fba82914a8325b764e "projects/SelfTest/IntrospectiveTests/CmdLine.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/projects/SelfTest/IntrospectiveTests/CmdLine.tests.cpp b/projects/SelfTest/IntrospectiveTests/CmdLine.tests.cpp
--- a/projects/SelfTest/IntrospectiveTests/CmdLine.tests.cpp
+++ b/projects/SelfTest/IntrospectiveTests/CmdLine.tests.cpp
@@ -280,7 +280,6 @@ TEST_CASE( "Process can be configured on command line", "[config][command-line]"
         CHECK(config.processName == "");
     }
 
-
     SECTION("default - no arguments") {
         auto result = cli.parse({"test"});
         CHECK(result);
@@ -345,8 +344,15 @@ TEST_CASE( "Process can be configured on command line", "[config][command-line]"
         SECTION("Only one reporter is accepted") {
             REQUIRE_FALSE(cli.parse({ "test", "-r", "xml", "-r", "junit" }));
         }
-    }
+        SECTION("must match one of the available ones") {
+            auto result = cli.parse({"test", "--reporter", "unsupported"});
+            CHECK(!result);
 
+#ifndef CATCH_CONFIG_DISABLE_MATCHERS
+            REQUIRE_THAT(result.errorMessage(), Contains("Unrecognized reporter"));
+#endif
+        }
+    }
 
     SECTION("debugger") {
         SECTION("-b") {
EOF_114329324912

# Navigate to the build directory where Catch2 and its tests were compiled.
# The Dockerfile ensures this directory exists and the project is built.
cd build

# Execute the SelfTest executable which is located in the projects/SelfTest subdirectory
# within the build directory, and filter for tests related to CmdLine.
# Catch2 test executables use square brackets for tags to filter tests.
./projects/SelfTest/SelfTest "[CmdLine]"
rc=$? # Capture the exit code of the test command

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific test file again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout 1faccd601d904a951142d8fba82914a8325b764e "projects/SelfTest/IntrospectiveTests/CmdLine.tests.cpp"