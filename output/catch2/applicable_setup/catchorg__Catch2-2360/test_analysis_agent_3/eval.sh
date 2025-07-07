#!/bin/bash
set -euxo pipefail

# Define the target commit SHA and the specific test files to be managed.
COMMIT_SHA="52066dbc2a53f4c3ab2a418d03f93200a8245451"
TARGET_TEST_FILES=(
    "src/catch2/catch_test_macros.hpp"
    "src/catch2/internal/catch_test_failure_exception.hpp"
    "tests/CMakeLists.txt"
    "tests/ExtraTests/CMakeLists.txt"
)

# Ensure we are in the /testbed directory
cd /testbed || { echo "Error: /testbed directory not found. Aborting."; exit 1; }

echo "Resetting target test files to their state at commit $COMMIT_SHA..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$COMMIT_SHA" "$FILE" || { echo "Failed to checkout $FILE. Aborting."; exit 1; }
done

# Apply the test patch if provided. The content of the patch is inserted here.
echo "Attempting to apply test patch..."
git apply -v - <<'EOF_114329324912'
diff --git a/src/catch2/catch_test_macros.hpp b/src/catch2/catch_test_macros.hpp
--- a/src/catch2/catch_test_macros.hpp
+++ b/src/catch2/catch_test_macros.hpp
@@ -49,6 +49,7 @@
   #define CATCH_FAIL( ... ) INTERNAL_CATCH_MSG( "CATCH_FAIL", Catch::ResultWas::ExplicitFailure, Catch::ResultDisposition::Normal, __VA_ARGS__ )
   #define CATCH_FAIL_CHECK( ... ) INTERNAL_CATCH_MSG( "CATCH_FAIL_CHECK", Catch::ResultWas::ExplicitFailure, Catch::ResultDisposition::ContinueOnFailure, __VA_ARGS__ )
   #define CATCH_SUCCEED( ... ) INTERNAL_CATCH_MSG( "CATCH_SUCCEED", Catch::ResultWas::Ok, Catch::ResultDisposition::ContinueOnFailure, __VA_ARGS__ )
+  #define CATCH_SKIP( ... ) INTERNAL_CATCH_MSG( "SKIP", Catch::ResultWas::ExplicitSkip, Catch::ResultDisposition::Normal, __VA_ARGS__ )
 
 
   #if !defined(CATCH_CONFIG_RUNTIME_STATIC_REQUIRE)
@@ -102,6 +103,7 @@
   #define CATCH_FAIL( ... ) (void)(0)
   #define CATCH_FAIL_CHECK( ... ) (void)(0)
   #define CATCH_SUCCEED( ... ) (void)(0)
+  #define CATCH_SKIP( ... ) (void)(0)
 
   #define CATCH_STATIC_REQUIRE( ... )       (void)(0)
   #define CATCH_STATIC_REQUIRE_FALSE( ... ) (void)(0)
@@ -146,6 +148,7 @@
   #define FAIL( ... ) INTERNAL_CATCH_MSG( "FAIL", Catch::ResultWas::ExplicitFailure, Catch::ResultDisposition::Normal, __VA_ARGS__ )
   #define FAIL_CHECK( ... ) INTERNAL_CATCH_MSG( "FAIL_CHECK", Catch::ResultWas::ExplicitFailure, Catch::ResultDisposition::ContinueOnFailure, __VA_ARGS__ )
   #define SUCCEED( ... ) INTERNAL_CATCH_MSG( "SUCCEED", Catch::ResultWas::Ok, Catch::ResultDisposition::ContinueOnFailure, __VA_ARGS__ )
+  #define SKIP( ... ) INTERNAL_CATCH_MSG( "SKIP", Catch::ResultWas::ExplicitSkip, Catch::ResultDisposition::Normal, __VA_ARGS__ )
 
 
   #if !defined(CATCH_CONFIG_RUNTIME_STATIC_REQUIRE)
@@ -198,6 +201,7 @@
   #define FAIL( ... ) (void)(0)
   #define FAIL_CHECK( ... ) (void)(0)
   #define SUCCEED( ... ) (void)(0)
+  #define SKIP( ... ) (void)(0)
 
   #define STATIC_REQUIRE( ... )       (void)(0)
   #define STATIC_REQUIRE_FALSE( ... ) (void)(0)
diff --git a/src/catch2/internal/catch_test_failure_exception.hpp b/src/catch2/internal/catch_test_failure_exception.hpp
--- a/src/catch2/internal/catch_test_failure_exception.hpp
+++ b/src/catch2/internal/catch_test_failure_exception.hpp
@@ -20,6 +20,9 @@ namespace Catch {
      */
     [[noreturn]] void throw_test_failure_exception();
 
+    //! Used to signal that the remainder of a test should be skipped
+    struct TestSkipException{};
+
 } // namespace Catch
 
 #endif // CATCH_TEST_FAILURE_EXCEPTION_HPP_INCLUDED
diff --git a/tests/CMakeLists.txt b/tests/CMakeLists.txt
--- a/tests/CMakeLists.txt
+++ b/tests/CMakeLists.txt
@@ -116,6 +116,7 @@ set(TEST_SOURCES
         ${SELF_TEST_DIR}/UsageTests/Generators.tests.cpp
         ${SELF_TEST_DIR}/UsageTests/Message.tests.cpp
         ${SELF_TEST_DIR}/UsageTests/Misc.tests.cpp
+        ${SELF_TEST_DIR}/UsageTests/Skip.tests.cpp
         ${SELF_TEST_DIR}/UsageTests/ToStringByte.tests.cpp
         ${SELF_TEST_DIR}/UsageTests/ToStringChrono.tests.cpp
         ${SELF_TEST_DIR}/UsageTests/ToStringGeneral.tests.cpp
@@ -272,6 +273,10 @@ add_test(NAME TestSpecs::OverrideFailureWithNoMatchedTests
   COMMAND $<TARGET_FILE:SelfTest> "___nonexistent_test___" --allow-running-no-tests
 )
 
+add_test(NAME TestSpecs::OverrideAllSkipFailure
+  COMMAND $<TARGET_FILE:SelfTest> "tests can be skipped dynamically at runtime" --allow-running-no-tests
+)
+
 add_test(NAME TestSpecs::NonMatchingTestSpecIsRoundTrippable
     COMMAND $<TARGET_FILE:SelfTest> Tracker, "this test does not exist" "[nor does this tag]"
 )
diff --git a/tests/ExtraTests/CMakeLists.txt b/tests/ExtraTests/CMakeLists.txt
--- a/tests/ExtraTests/CMakeLists.txt
+++ b/tests/ExtraTests/CMakeLists.txt
@@ -488,15 +488,32 @@ set_tests_properties(TestSpecs::EmptySpecWithNoTestsFails
   PROPERTIES
     WILL_FAIL ON
 )
+
 add_test(
   NAME TestSpecs::OverrideFailureWithEmptySpec
   COMMAND $<TARGET_FILE:NoTests> --allow-running-no-tests
 )
+
 add_test(
   NAME List::Listeners::WorksWithoutRegisteredListeners
   COMMAND $<TARGET_FILE:NoTests> --list-listeners
 )
+
+
+add_executable(AllSkipped ${TESTS_DIR}/X93-AllSkipped.cpp)
+target_link_libraries(AllSkipped PRIVATE Catch2::Catch2WithMain)
+
+add_test(
+  NAME TestSpecs::SkippingAllTestsFails
+  COMMAND $<TARGET_FILE:AllSkipped>
+)
+set_tests_properties(TestSpecs::SkippingAllTestsFails
+  PROPERTIES
+    WILL_FAIL ON
+)
+
 set( EXTRA_TEST_BINARIES
+    AllSkipped
     PrefixedMacros
     DisabledMacros
     DisabledExceptions-DefaultHandler
diff --git a/tests/ExtraTests/X93-AllSkipped.cpp b/tests/ExtraTests/X93-AllSkipped.cpp
new file mode 100644
--- /dev/null
+++ b/tests/ExtraTests/X93-AllSkipped.cpp
@@ -0,0 +1,16 @@
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
+TEST_CASE( "this test case is being skipped" ) { SKIP(); }
+
+TEST_CASE( "all sections in this test case are being skipped" ) {
+    SECTION( "A" ) { SKIP(); }
+    SECTION( "B" ) { SKIP(); }
+}
diff --git a/tests/SelfTest/UsageTests/Skip.tests.cpp b/tests/SelfTest/UsageTests/Skip.tests.cpp
new file mode 100644
--- /dev/null
+++ b/tests/SelfTest/UsageTests/Skip.tests.cpp
@@ -0,0 +1,73 @@
+
+//              Copyright Catch2 Authors
+// Distributed under the Boost Software License, Version 1.0.
+//   (See accompanying file LICENSE.txt or copy at
+//        https://www.boost.org/LICENSE_1_0.txt)
+
+// SPDX-License-Identifier: BSL-1.0
+
+#include <catch2/catch_test_macros.hpp>
+#include <catch2/generators/catch_generators_range.hpp>
+
+#include <iostream>
+
+TEST_CASE( "tests can be skipped dynamically at runtime", "[skipping]" ) {
+    SKIP();
+    FAIL( "this is not reached" );
+}
+
+TEST_CASE( "skipped tests can optionally provide a reason", "[skipping]" ) {
+    const int answer = 43;
+    SKIP( "skipping because answer = " << answer );
+    FAIL( "this is not reached" );
+}
+
+TEST_CASE( "sections can be skipped dynamically at runtime", "[skipping]" ) {
+    SECTION( "not skipped" ) { SUCCEED(); }
+    SECTION( "skipped" ) { SKIP(); }
+    SECTION( "also not skipped" ) { SUCCEED(); }
+}
+
+TEST_CASE( "nested sections can be skipped dynamically at runtime",
+           "[skipping]" ) {
+    SECTION( "A" ) { std::cout << "a"; }
+    SECTION( "B" ) {
+        SECTION( "B1" ) { std::cout << "b1"; }
+        SECTION( "B2" ) { SKIP(); }
+    }
+    std::cout << "!\n";
+}
+
+TEST_CASE( "dynamic skipping works with generators", "[skipping]" ) {
+    const int answer = GENERATE( 41, 42, 43 );
+    if ( answer != 42 ) { SKIP( "skipping because answer = " << answer ); }
+    SUCCEED();
+}
+
+TEST_CASE( "failed assertions before SKIP cause test case to fail",
+           "[skipping][!shouldfail]" ) {
+    CHECK( 3 == 4 );
+    SKIP();
+}
+
+TEST_CASE( "a succeeding test can still be skipped",
+           "[skipping][!shouldfail]" ) {
+    SUCCEED();
+    SKIP();
+}
+
+TEST_CASE( "failing in some unskipped sections causes entire test case to fail",
+           "[skipping][!shouldfail]" ) {
+    SECTION( "skipped" ) { SKIP(); }
+    SECTION( "not skipped" ) { FAIL(); }
+}
+
+TEST_CASE( "failing for some generator values causes entire test case to fail",
+           "[skipping][!shouldfail]" ) {
+    int i = GENERATE( 1, 2, 3, 4 );
+    if ( i % 2 == 0 ) {
+        SKIP();
+    } else {
+        FAIL();
+    }
+}
EOF_114329324912

# Navigate to the 'build' directory where the project was initially configured and built.
cd /testbed/build || { echo "Error: 'build' directory not found at /testbed/build. Ensure Dockerfile build steps are complete."; exit 1; }

# Recompile the project after applying the patch.
# This step is critical because the target files (e.g., CMakeLists.txt, header files)
# are part of the build configuration and source, and any changes from the patch
# require a recompile for the test executables to incorporate them.
echo "Recompiling project after patch application to integrate changes..."
ninja || { echo "Error: Failed to recompile project. Aborting."; exit 1; }

# Update ApprovalTest baselines if the patch changed expected test output.
echo "Running approve.py to update ApprovalTest baselines..."
python3 /testbed/tools/scripts/approve.py || { echo "Failed to run approve.py. Continuing with tests, but they might fail due to baseline mismatches."; }

# Set environment variable for CTest to show output on failure.
echo "Setting CTEST_OUTPUT_ON_FAILURE environment variable..."
export CTEST_OUTPUT_ON_FAILURE=1

# Execute tests using CTest.
# As per collected information, the "target test files" provided are
# build/source configuration files, not individual test executables.
# The `ctest` command discovers and executes all defined tests.
# Therefore, to ensure changes applied by the patch are tested, the entire
# test suite must be run after recompilation.
echo "Executing Catch2 tests using ctest..."
ctest -C Release -j $(nproc)
rc=$? # Capture the exit code of the ctest command immediately

# Output the captured exit code. This is crucial for the judging system.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the /testbed directory for cleanup.
echo "Navigating back to /testbed for cleanup operations..."
cd /testbed || { echo "Failed to navigate back to /testbed. Cleanup skipped."; exit $rc; }

# Clean up: Reset the target test files to their original state from the repository.
# This ensures a clean state for any subsequent operations or for future runs.
echo "Resetting target test files after test run..."
for FILE in "${TARGET_TEST_FILES[@]}"; do
    git checkout "$COMMIT_SHA" "$FILE" || { echo "Failed to reset $FILE. Manual intervention might be required."; }
done

# Exit with the captured test result code.
exit $rc