#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as defined in the Dockerfile
cd /testbed

# Reset target test files to ensure a clean state before applying patch.
# This ensures that git apply operates on the original file content for the specified files.
git checkout 4acc51828f7f93f3b2058a63f54d112af4034503 "tests/CMakeLists.txt" "tests/SelfTest/UsageTests/Misc.tests.cpp"

# Apply the test patch to the specified files.
# The actual content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
diff --git a/tests/CMakeLists.txt b/tests/CMakeLists.txt
--- a/tests/CMakeLists.txt
+++ b/tests/CMakeLists.txt
@@ -78,6 +78,7 @@ endif(MSVC) #Temporary workaround
 set(TEST_SOURCES
         ${SELF_TEST_DIR}/TestRegistrations.cpp
         ${SELF_TEST_DIR}/IntrospectiveTests/Algorithms.tests.cpp
+        ${SELF_TEST_DIR}/IntrospectiveTests/AssertionHandler.tests.cpp
         ${SELF_TEST_DIR}/IntrospectiveTests/Clara.tests.cpp
         ${SELF_TEST_DIR}/IntrospectiveTests/CmdLine.tests.cpp
         ${SELF_TEST_DIR}/IntrospectiveTests/CmdLineHelpers.tests.cpp
diff --git a/tests/SelfTest/IntrospectiveTests/AssertionHandler.tests.cpp b/tests/SelfTest/IntrospectiveTests/AssertionHandler.tests.cpp
new file mode 100644
--- /dev/null
+++ b/tests/SelfTest/IntrospectiveTests/AssertionHandler.tests.cpp
@@ -0,0 +1,17 @@
+
+//              Copyright Catch2 Authors
+// Distributed under the Boost Software License, Version 1.0.
+//   (See accompanying file LICENSE.txt or copy at
+//        https://www.boost.org/LICENSE_1_0.txt)
+
+// SPDX-License-Identifier: BSL-1.0
+
+#include <catch2/catch_test_macros.hpp>
+
+TEST_CASE( "Incomplete AssertionHandler", "[assertion-handler][!shouldfail]" ) {
+    Catch::AssertionHandler catchAssertionHandler(
+        "REQUIRE"_catch_sr,
+        CATCH_INTERNAL_LINEINFO,
+        "Dummy",
+        Catch::ResultDisposition::Normal );
+}
diff --git a/tests/SelfTest/UsageTests/Misc.tests.cpp b/tests/SelfTest/UsageTests/Misc.tests.cpp
--- a/tests/SelfTest/UsageTests/Misc.tests.cpp
+++ b/tests/SelfTest/UsageTests/Misc.tests.cpp
@@ -217,6 +217,18 @@ TEST_CASE("Testing checked-if 3", "[checked-if][!shouldfail]") {
     SUCCEED();
 }
 
+[[noreturn]]
+TEST_CASE("Testing checked-if 4", "[checked-if][!shouldfail]") {
+    CHECKED_ELSE(true) {}
+    throw std::runtime_error("Uncaught exception should fail!");
+}
+
+[[noreturn]]
+TEST_CASE("Testing checked-if 5", "[checked-if][!shouldfail]") {
+    CHECKED_ELSE(false) {}
+    throw std::runtime_error("Uncaught exception should fail!");
+}
+
 TEST_CASE( "xmlentitycheck" ) {
     SECTION( "embedded xml: <test>it should be possible to embed xml characters, such as <, \" or &, or even whole <xml>documents</xml> within an attribute</test>" ) {
         SUCCEED(); // We need this here to stop it failing due to no tests
EOF_114329324912

# Re-configure CMake project with the specified flags after applying the patch.
# This is crucial if tests/CMakeLists.txt was modified, to reflect changes in the build system.
# -Bbuild: Specifies 'build' as the binary directory
# -H.: Specifies the current directory as the source directory
# -DCMAKE_BUILD_TYPE=Release: For an optimized build
# -DCMAKE_CXX_STANDARD=17: Specifies the C++ standard
# -DCATCH_DEVELOPMENT_BUILD=ON: Crucial for building tests and development features
# -G Ninja: Specifies Ninja as the build system generator
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCATCH_DEVELOPMENT_BUILD=ON \
    -G Ninja

# Re-build the project using CMake's build command, specifying the build directory.
# This command compiles the source code and creates executables, including tests,
# picking up any changes from the patch and re-configuration.
cmake --build build

# Execute the SelfTest binary directly.
# The test log analysis agent indicated that ctest failed to discover tests,
# so directly running the compiled test executable is the workaround.
./build/tests/SelfTest
rc=$? # Capture the exit code of the test binary execution

# Echo the final exit code for the judge to process
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: Reset the target test files to their original state,
# ensuring the repository is left in a clean state after the tests.
git checkout 4acc51828f7f93f3b2058a63f54d112af4034503 "tests/CMakeLists.txt" "tests/SelfTest/UsageTests/Misc.tests.cpp"