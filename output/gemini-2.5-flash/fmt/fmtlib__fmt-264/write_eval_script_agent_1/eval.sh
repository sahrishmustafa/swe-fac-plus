#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned and built
cd /testbed

# Ensure the target test file is in a clean state before applying the patch.
# The Dockerfile already checked out the specific commit, but this ensures the
# individual file is pristine if previous runs modified it.
git checkout 97e9ed11bce828235a25e2cb72910fa6928ffdf5 "test/CMakeLists.txt"

# Apply the test patch. The content is provided via heredoc standard input.
# The actual patch content will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/test/CMakeLists.txt b/test/CMakeLists.txt
--- a/test/CMakeLists.txt
+++ b/test/CMakeLists.txt
@@ -10,12 +10,6 @@ function (target_link_cppformat target)
   endif ()
 endfunction ()
 
-function (fmt_target_include_directories)
-  if (CMAKE_MAJOR_VERSION VERSION_GREATER 2.8.10)
-    target_include_directories(${ARGN})
-  endif ()
-endfunction ()
-
 # We compile Google Test ourselves instead of using pre-compiled libraries.
 # See the Google Test FAQ "Why is it not recommended to install a
 # pre-compiled copy of Google Test (for example, into /usr/local)?"
@@ -24,7 +18,7 @@ endfunction ()
 add_library(gmock STATIC
   ${FMT_GMOCK_DIR}/gmock-gtest-all.cc ${FMT_GMOCK_DIR}/gmock/gmock.h
   ${FMT_GMOCK_DIR}/gtest/gtest.h ${FMT_GMOCK_DIR}/gtest/gtest-spi.h)
-fmt_target_include_directories(gmock INTERFACE ${FMT_GMOCK_DIR})
+target_include_directories(gmock INTERFACE ${FMT_GMOCK_DIR})
 find_package(Threads)
 if (Threads_FOUND)
   target_link_libraries(gmock ${CMAKE_THREAD_LIBS_INIT})
@@ -43,7 +37,7 @@ check_cxx_source_compiles("
 check_cxx_source_compiles("
   #include <initializer_list>
   int main() {}" FMT_INITIALIZER_LIST)
-  
+
 if (NOT FMT_VARIADIC_TEMPLATES OR NOT FMT_INITIALIZER_LIST)
   add_definitions(-DGTEST_LANG_CXX11=0)
 endif ()
EOF_114329324912

# CRITICAL: Rebuild the project after applying the patch to ensure any
# modified source files (including test sources or build configurations like CMakeLists.txt)
# are recompiled and new test binaries are generated or updated.
# Navigate to the build directory.
cd build

# Reconfigure CMake and then compile the project.
# Re-running cmake after patching CMakeLists.txt is crucial for changes to take effect.
cmake -DCMAKE_BUILD_TYPE=Release -DFMT_PEDANTIC=ON -DFMT_TEST=ON ..
if [ $? -ne 0 ]; then
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

make -j "$(nproc)"
if [ $? -ne 0 ]; then
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute the tests using CTest via make test from the build directory.
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed output on test failures.
# Since test/CMakeLists.txt is a build configuration file, patching it
# implies that subsequent 'make test' will pick up any changes affecting test discovery or execution.
CTEST_OUTPUT_ON_FAILURE=1 make test
rc=$? # Capture the exit code of the test execution

# If tests failed, attempt to get GDB stack traces for specific failing executables.
if [ "$rc" -ne 0 ]; then
    echo "Tests failed. Attempting to get GDB stack traces for specific failing executables."
    # Define the full paths to the test executables that might fail.
    # Note: These paths are relative to the `/testbed` root, but we are currently in `/testbed/build`.
    # So we need to provide absolute paths or navigate appropriately.
    FAITH_FAILING_TEST_EXECUTABLES=("/testbed/build/test/format-test" "/testbed/build/test/util-test")
    
    for test_exe in "${FAITH_FAILING_TEST_EXECUTABLES[@]}"; do
        if [ -f "$test_exe" ]; then
            echo "--- Running $test_exe under GDB to capture stack trace ---"
            # '-q' for quiet, '-batch' for non-interactive, '-ex' for commands
            gdb -q -batch -ex "run" -ex "thread apply all bt full" -ex "quit" "$test_exe" 2>&1 || true
            echo "--- End of GDB output for $test_exe ---"
        else
            echo "Warning: Test executable '$test_exe' not found. Skipping GDB trace."
        fi
    done
fi

# Go back to the /testbed root directory for cleanup.
cd ..

# Echo the exit code in the required format for Omnigril.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: revert changes to the target test file to its original state.
# This ensures the repository is clean for subsequent runs if any.
git checkout 97e9ed11bce828235a25e2cb72910fa6928ffdf5 "test/CMakeLists.txt"