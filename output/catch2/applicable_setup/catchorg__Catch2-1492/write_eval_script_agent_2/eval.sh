#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory
cd /testbed

# Checkout the specific test files to their original state at the commit SHA.
# This ensures a clean state before applying any potential patches.
git checkout 0387fb64ced7c3626b3164207c2d29aadb9ceaf2 "include/internal/catch_test_case_tracker.cpp" "include/internal/catch_test_case_tracker.h" "projects/SelfTest/IntrospectiveTests/PartTracker.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/include/internal/catch_test_case_tracker.cpp b/include/internal/catch_test_case_tracker.cpp
--- a/include/internal/catch_test_case_tracker.cpp
+++ b/include/internal/catch_test_case_tracker.cpp
@@ -190,6 +190,17 @@ namespace TestCaseTracking {
         }
     }
 
+    bool SectionTracker::isComplete() const {
+        bool complete = true;
+
+        if ((m_filters.empty() || m_filters[0] == "") ||
+             std::find(m_filters.begin(), m_filters.end(),
+                       m_nameAndLocation.name) != m_filters.end())
+            complete = TrackerBase::isComplete();
+        return complete;
+
+    }
+
     bool SectionTracker::isSectionTracker() const { return true; }
 
     SectionTracker& SectionTracker::acquire( TrackerContext& ctx, NameAndLocation const& nameAndLocation ) {
diff --git a/include/internal/catch_test_case_tracker.h b/include/internal/catch_test_case_tracker.h
--- a/include/internal/catch_test_case_tracker.h
+++ b/include/internal/catch_test_case_tracker.h
@@ -140,6 +140,8 @@ namespace TestCaseTracking {
 
         bool isSectionTracker() const override;
 
+        bool isComplete() const override;
+
         static SectionTracker& acquire( TrackerContext& ctx, NameAndLocation const& nameAndLocation );
 
         void tryOpen();
diff --git a/projects/SelfTest/IntrospectiveTests/PartTracker.tests.cpp b/projects/SelfTest/IntrospectiveTests/PartTracker.tests.cpp
--- a/projects/SelfTest/IntrospectiveTests/PartTracker.tests.cpp
+++ b/projects/SelfTest/IntrospectiveTests/PartTracker.tests.cpp
@@ -324,3 +324,33 @@ TEST_CASE( "Tracker" ) {
         //   two sections within a generator
     }
 }
+
+static bool previouslyRun = false;
+static bool previouslyRunNested = false;
+
+TEST_CASE( "#1394", "[.][approvals][tracker]" ) {
+    // -- Don't re-run after specified section is done
+    REQUIRE(previouslyRun == false);
+
+    SECTION( "RunSection" ) {
+        previouslyRun = true;
+    }
+    SECTION( "SkipSection" ) {
+        // cause an error if this section is called because it shouldn't be
+        REQUIRE(1 == 0);
+    }
+}
+
+TEST_CASE( "#1394 nested", "[.][approvals][tracker]" ) {
+    REQUIRE(previouslyRunNested == false);
+
+    SECTION( "NestedRunSection" ) {
+        SECTION( "s1" ) {
+            previouslyRunNested = true;
+        }
+    }
+    SECTION( "NestedSkipSection" ) {
+        // cause an error if this section is called because it shouldn't be
+        REQUIRE(1 == 0);
+    }
+}
EOF_114329324912

# --- Pre-build Step ---
# Execute the single header generation script required by Catch2's build process.
# This step is included as it's common for Catch2 builds and was present in a working skeleton.
python3 scripts/generateSingleHeader.py

# --- Build Steps ---
# Create a dedicated build directory to perform an out-of-source build.
mkdir build
# Change into the build directory. All subsequent build commands will be executed here.
cd build

# Configure CMake for a Debug build with C++17 standard and test options.
# Updated CMAKE_CXX_STANDARD to 17 as per test log analysis.
cmake -S .. -B . \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCATCH_BUILD_EXTRA_TESTS=ON \
    -DCATCH_ENABLE_WERROR=ON \
    -DCATCH_BUILD_TESTING=ON

# Compile the project using all available CPU cores for speed.
cmake --build . -j "$(nproc)"

# --- Test Execution ---
# Current directory is 'build'.
# Run the CTest suite.
# As per the collected information, CTest automatically discovers and runs the compiled
# test executables (including projects/SelfTest/IntrospectiveTests/PartTracker.tests.cpp).
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed output in case of test failures.
CTEST_OUTPUT_ON_FAILURE=1 ctest -j "$(nproc)"
rc=$? # Capture the exit code of the test command immediately after execution.

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific files again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout 0387fb64ced7c3626b3164207c2d29aadb9ceaf2 "include/internal/catch_test_case_tracker.cpp" "include/internal/catch_test_case_tracker.h" "projects/SelfTest/IntrospectiveTests/PartTracker.tests.cpp"