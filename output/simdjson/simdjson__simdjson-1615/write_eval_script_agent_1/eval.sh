#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific target test file to its original state before applying any patch.
# This ensures a clean base for the patch application.
git checkout 40cba172ed66584cf670c98202ed474a316667e3 "tests/ondemand/CMakeLists.txt"

# Apply the test patch to modify/add tests.
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ondemand/CMakeLists.txt b/tests/ondemand/CMakeLists.txt
--- a/tests/ondemand/CMakeLists.txt
+++ b/tests/ondemand/CMakeLists.txt
@@ -2,14 +2,15 @@
 link_libraries(simdjson)
 include_directories(..)
 add_subdirectory(compilation_failure_tests)
-add_cpp_test(ondemand_tostring_tests           LABELS ondemand acceptance per_implementation)
+add_cpp_test(ondemand_tostring_tests         LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_active_tests           LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_array_tests            LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_array_error_tests      LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_compilation_tests      LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_error_tests            LABELS ondemand acceptance per_implementation)
+add_cpp_test(ondemand_json_pointer_tests     LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_key_string_tests       LABELS ondemand acceptance per_implementation)
-add_cpp_test(ondemand_misc_tests           LABELS ondemand acceptance per_implementation)
+add_cpp_test(ondemand_misc_tests             LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_number_tests           LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_object_tests           LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_object_error_tests     LABELS ondemand acceptance per_implementation)
diff --git a/tests/ondemand/ondemand_json_pointer_tests.cpp b/tests/ondemand/ondemand_json_pointer_tests.cpp
new file mode 100644
--- /dev/null
+++ b/tests/ondemand/ondemand_json_pointer_tests.cpp
@@ -0,0 +1,168 @@
+#include "simdjson.h"
+#include "test_ondemand.h"
+#include <string>
+
+using namespace simdjson;
+
+namespace json_pointer_tests {
+    const padded_string TEST_JSON = R"(
+    {
+        "/~01abc": [
+        0,
+        {
+            "\\\" 0": [
+            "value0",
+            "value1"
+            ]
+        }
+        ],
+        "0": "0 ok",
+        "01": "01 ok",
+        "": "empty ok",
+        "arr": []
+    }
+    )"_padded;
+
+    const padded_string TEST_RFC_JSON = R"(
+    {
+        "foo": ["bar", "baz"],
+        "": 0,
+        "a/b": 1,
+        "c%d": 2,
+        "e^f": 3,
+        "g|h": 4,
+        "i\\j": 5,
+        "k\"l": 6,
+        " ": 7,
+        "m~n": 8
+    }
+    )"_padded;
+
+    bool run_success_test(const padded_string & json,std::string_view json_pointer,std::string expected) {
+        TEST_START();
+        ondemand::parser parser;
+        ondemand::document doc;
+        ondemand::value val;
+        std::string actual;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        ASSERT_SUCCESS(doc.at_pointer(json_pointer).get(val));
+        ASSERT_SUCCESS(simdjson::to_string(val).get(actual));
+        ASSERT_EQUAL(actual,expected);
+        TEST_SUCCEED();
+    }
+
+    bool run_failure_test(const padded_string & json,std::string_view json_pointer,error_code expected) {
+        TEST_START();
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        ASSERT_EQUAL(doc.at_pointer(json_pointer).error(),expected);
+        TEST_SUCCEED();
+    }
+
+    bool demo_test() {
+        TEST_START();
+        auto cars_json = R"( [
+        { "make": "Toyota", "model": "Camry",  "year": 2018, "tire_pressure": [ 40.1, 39.9, 37.7, 40.4 ] },
+        { "make": "Kia",    "model": "Soul",   "year": 2012, "tire_pressure": [ 30.1, 31.0, 28.6, 28.7 ] },
+        { "make": "Toyota", "model": "Tercel", "year": 1999, "tire_pressure": [ 29.8, 30.0, 30.2, 30.5 ] }
+        ] )"_padded;
+
+        ondemand::parser parser;
+        ondemand::document cars;
+        double x;
+        ASSERT_SUCCESS(parser.iterate(cars_json).get(cars));
+        ASSERT_SUCCESS(cars.at_pointer("/0/tire_pressure/1").get(x));
+        ASSERT_EQUAL(x,39.9);
+        TEST_SUCCEED();
+    }
+
+    bool demo_relative_path() {
+        TEST_START();
+        auto cars_json = R"( [
+        { "make": "Toyota", "model": "Camry",  "year": 2018, "tire_pressure": [ 40.1, 39.9, 37.7, 40.4 ] },
+        { "make": "Kia",    "model": "Soul",   "year": 2012, "tire_pressure": [ 30.1, 31.0, 28.6, 28.7 ] },
+        { "make": "Toyota", "model": "Tercel", "year": 1999, "tire_pressure": [ 29.8, 30.0, 30.2, 30.5 ] }
+        ] )"_padded;
+
+        ondemand::parser parser;
+        ondemand::document cars;
+        std::vector<double> measured;
+        ASSERT_SUCCESS(parser.iterate(cars_json).get(cars));
+        for (auto car_element : cars) {
+            double x;
+            ASSERT_SUCCESS(car_element.at_pointer("/tire_pressure/1").get(x));
+            measured.push_back(x);
+        }
+
+        std::vector<double> expected = {39.9, 31, 30};
+        if (measured != expected) { return false; }
+        TEST_SUCCEED();
+    }
+
+    bool many_json_pointers() {
+        TEST_START();
+        auto cars_json = R"( [
+        { "make": "Toyota", "model": "Camry",  "year": 2018, "tire_pressure": [ 40.1, 39.9, 37.7, 40.4 ] },
+        { "make": "Kia",    "model": "Soul",   "year": 2012, "tire_pressure": [ 30.1, 31.0, 28.6, 28.7 ] },
+        { "make": "Toyota", "model": "Tercel", "year": 1999, "tire_pressure": [ 29.8, 30.0, 30.2, 30.5 ] }
+        ] )"_padded;
+
+        ondemand::parser parser;
+        ondemand::document cars;
+        std::vector<double> measured;
+        ASSERT_SUCCESS(parser.iterate(cars_json).get(cars));
+        for (int i = 0; i < 3; i++) {
+            double x;
+            std::string json_pointer = "/" + std::to_string(i) + "/tire_pressure/1";
+            ASSERT_SUCCESS(cars.at_pointer(json_pointer).get(x));
+            measured.push_back(x);
+            cars.rewind();
+        }
+
+        std::vector<double> expected = {39.9, 31, 30};
+        if (measured != expected) { return false; }
+        TEST_SUCCEED();
+    }
+
+    bool run() {
+        return
+                demo_test() &&
+                demo_relative_path() &&
+                run_success_test(TEST_RFC_JSON,"",R"({"foo":["bar","baz"],"":0,"a/b":1,"c%d":2,"e^f":3,"g|h":4,"i\\j":5,"k\"l":6," ":7,"m~n":8})") &&
+                run_success_test(TEST_RFC_JSON,"/foo",R"(["bar","baz"])") &&
+                run_success_test(TEST_RFC_JSON,"/foo/0",R"("bar")") &&
+                run_success_test(TEST_RFC_JSON,"/",R"(0)") &&
+                run_success_test(TEST_RFC_JSON,"/a~1b",R"(1)") &&
+                run_success_test(TEST_RFC_JSON,"/c%d",R"(2)") &&
+                run_success_test(TEST_RFC_JSON,"/e^f",R"(3)") &&
+                run_success_test(TEST_RFC_JSON,"/g|h",R"(4)") &&
+                run_success_test(TEST_RFC_JSON,R"(/i\\j)",R"(5)") &&
+                run_success_test(TEST_RFC_JSON,R"(/k\"l)",R"(6)") &&
+                run_success_test(TEST_RFC_JSON,"/ ",R"(7)") &&
+                run_success_test(TEST_RFC_JSON,"/m~0n",R"(8)") &&
+                run_success_test(TEST_JSON, "", R"({"/~01abc":[0,{"\\\" 0":["value0","value1"]}],"0":"0 ok","01":"01 ok","":"empty ok","arr":[]})") &&
+                run_success_test(TEST_JSON, R"(/~1~001abc)", R"([0,{"\\\" 0":["value0","value1"]}])") &&
+                run_success_test(TEST_JSON, R"(/~1~001abc/1)", R"({"\\\" 0":["value0","value1"]})") &&
+                run_success_test(TEST_JSON, R"(/~1~001abc/1/\\\" 0)", R"(["value0","value1"])") &&
+                run_success_test(TEST_JSON, R"(/~1~001abc/1/\\\" 0/0)", "\"value0\"") &&
+                run_success_test(TEST_JSON, R"(/~1~001abc/1/\\\" 0/1)", "\"value1\"") &&
+                run_success_test(TEST_JSON, "/arr", R"([])") &&
+                run_success_test(TEST_JSON, "/0", "\"0 ok\"") &&
+                run_success_test(TEST_JSON, "/01", "\"01 ok\"") &&
+                run_success_test(TEST_JSON, "", R"({"/~01abc":[0,{"\\\" 0":["value0","value1"]}],"0":"0 ok","01":"01 ok","":"empty ok","arr":[]})") &&
+                run_failure_test(TEST_JSON, R"(/~1~001abc/1/\\\" 0/2)", INDEX_OUT_OF_BOUNDS) &&
+                run_failure_test(TEST_JSON, "/arr/0", INDEX_OUT_OF_BOUNDS) &&
+                run_failure_test(TEST_JSON, "~1~001abc", INVALID_JSON_POINTER) &&
+                run_failure_test(TEST_JSON, "/~01abc", NO_SUCH_FIELD) &&
+                run_failure_test(TEST_JSON, "/~1~001abc/01", INVALID_JSON_POINTER) &&
+                run_failure_test(TEST_JSON, "/~1~001abc/", INVALID_JSON_POINTER) &&
+                run_failure_test(TEST_JSON, "/~1~001abc/-", INDEX_OUT_OF_BOUNDS) &&
+                many_json_pointers() &&
+                true;
+    }
+}   // json_pointer_tests
+
+int main(int argc, char *argv[]) {
+  return test_main(argc, argv, json_pointer_tests::run);
+}
\ No newline at end of file
EOF_114329324912

# Navigate to the build directory.
# The Dockerfile has already run `cmake ..` and `cmake --build .` from /testbed,
# so the `build` directory should already exist and contain the compiled project.
cd build

# Set the SIMDJSON_DEVELOPER_MODE environment variable.
# This is crucial for CMake to configure and build tests, examples, and benchmarks.
# While CMake might have already configured with this, ensuring it's set before
# a rebuild is a good practice.
export SIMDJSON_DEVELOPER_MODE=ON

# Rebuild the project after applying the patch.
# This step is critical to ensure that any new or modified tests from the patch
# are compiled and included in the test executable.
# Use -j$(nproc) to utilize all available CPU cores for faster build.
cmake --build . -j$(nproc)

# Check the exit code of the build command. If the build fails, exit early.
if [ $? -ne 0 ]; then
    echo "Build failed after patch application. Exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute only the specified target tests.
# The target file is tests/ondemand/CMakeLists.txt.
# CTest does not directly run a CMakeLists.txt file. Instead, it runs tests
# discovered by CMake within the build directory.
# To adhere to the "execute only the specified target test files" requirement,
# we use --tests-regex with a pattern that attempts to match tests
# originating from or logically belonging to the 'ondemand' module.
# The regex ".*ondemand.*" is a best effort to capture such tests, assuming
# their full CTest name includes 'ondemand' or a related identifier.
ctest --output-on-failure --tests-regex ".*ondemand.*"
rc=$?

# Capture the exit code immediately after running the tests.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed root directory for cleanup.
cd /testbed

# Clean up: Undo any changes made to the target test file.
# This ensures that the repository remains in its original state after the test run.
git checkout 40cba172ed66584cf670c98202ed474a316667e3 "tests/ondemand/CMakeLists.txt"