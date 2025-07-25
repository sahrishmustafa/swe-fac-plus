#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific target test file to its original state before applying any patch.
# This ensures a clean base for the patch application.
git checkout 47a62db55936e29e1966a26a9aadb5f28237ae37 "tests/ondemand/CMakeLists.txt"

# Apply the test patch to modify/add tests.
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ondemand/CMakeLists.txt b/tests/ondemand/CMakeLists.txt
--- a/tests/ondemand/CMakeLists.txt
+++ b/tests/ondemand/CMakeLists.txt
@@ -13,6 +13,7 @@ add_cpp_test(ondemand_json_pointer_tests     LABELS ondemand acceptance per_impl
 add_cpp_test(ondemand_key_string_tests       LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_misc_tests             LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_number_tests           LABELS ondemand acceptance per_implementation)
+add_cpp_test(ondemand_number_in_string_tests LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_object_tests           LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_object_error_tests     LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_ordering_tests         LABELS ondemand acceptance per_implementation)
diff --git a/tests/ondemand/ondemand_number_in_string_tests.cpp b/tests/ondemand/ondemand_number_in_string_tests.cpp
new file mode 100644
--- /dev/null
+++ b/tests/ondemand/ondemand_number_in_string_tests.cpp
@@ -0,0 +1,273 @@
+#include "simdjson.h"
+#include "test_ondemand.h"
+#include <string>
+
+using namespace simdjson;
+
+namespace number_in_string_tests {
+    const padded_string CRYPTO_JSON = R"(
+    {
+        "ticker":{
+            "base":"BTC",
+            "target":"USD",
+            "price":"443.7807865468",
+            "volume":"31720.1493969300",
+            "change":"Infinity",
+            "markets":[
+                {
+                    "market":"bitfinex",
+                    "price":"447.5000000000",
+                    "volume":"10559.5293639000"
+                },
+                {
+                    "market":"bitstamp",
+                    "price":"448.5400000000",
+                    "volume":"11628.2880079300"
+                },
+                {
+                    "market":"btce",
+                    "price":"432.8900000000",
+                    "volume":"8561.0563600000"
+                }
+            ]
+        },
+        "timestamp":1399490941,
+        "timestampstr":"1399490941"
+    }
+    )"_padded;
+
+    bool array_double() {
+        TEST_START();
+        auto json = R"(["1.2","2.3","-42.3","2.43442e3", "-1.234e3"])"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        size_t counter{0};
+        std::vector<double> expected = {1.2, 2.3, -42.3, 2434.42, -1234};
+        double d;
+        for (auto value : doc) {
+            ASSERT_SUCCESS(value.get_double_in_string().get(d));
+            ASSERT_EQUAL(d,expected[counter++]);
+        }
+        TEST_SUCCEED();
+    }
+
+    bool array_int() {
+        TEST_START();
+        auto json = R"(["1", "2", "-3", "1000", "-7844"])"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        size_t counter{0};
+        std::vector<int> expected = {1, 2, -3, 1000, -7844};
+        int64_t i;
+        for (auto value : doc) {
+            ASSERT_SUCCESS(value.get_int64_in_string().get(i));
+            ASSERT_EQUAL(i,expected[counter++]);
+        }
+        TEST_SUCCEED();
+    }
+
+    bool array_unsigned() {
+        TEST_START();
+        auto json = R"(["1", "2", "24", "9000", "156934"])"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        size_t counter{0};
+        std::vector<int> expected = {1, 2, 24, 9000, 156934};
+        uint64_t u;
+        for (auto value : doc) {
+            ASSERT_SUCCESS(value.get_uint64_in_string().get(u));
+            ASSERT_EQUAL(u,expected[counter++]);
+        }
+        TEST_SUCCEED();
+    }
+
+    bool object() {
+        TEST_START();
+        auto json = R"({"a":"1.2", "b":"-2.342e2", "c":"22", "d":"-112358", "e":"1080", "f":"123456789"})"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        size_t counter{0};
+        std::vector<double> expected = {1.2, -234.2, 22, -112358, 1080, 123456789};
+        double d;
+        int64_t i;
+        uint64_t u;
+        // Doubles
+        ASSERT_SUCCESS(doc.find_field("a").get_double_in_string().get(d));
+        ASSERT_EQUAL(d,expected[counter++]);
+        ASSERT_SUCCESS(doc.find_field("b").get_double_in_string().get(d));
+        ASSERT_EQUAL(d,expected[counter++]);
+        // Integers
+        ASSERT_SUCCESS(doc.find_field("c").get_int64_in_string().get(i));
+        ASSERT_EQUAL(i,expected[counter++]);
+        ASSERT_SUCCESS(doc.find_field("d").get_int64_in_string().get(i));
+        ASSERT_EQUAL(i,expected[counter++]);
+        // Unsigned integers
+        ASSERT_SUCCESS(doc.find_field("e").get_uint64_in_string().get(u));
+        ASSERT_EQUAL(u,expected[counter++]);
+        ASSERT_SUCCESS(doc.find_field("f").get_uint64_in_string().get(u));
+        ASSERT_EQUAL(u,expected[counter++]);
+        TEST_SUCCEED();
+    }
+
+    bool docs() {
+        TEST_START();
+        auto double_doc = R"( "-1.23e1" )"_padded;
+        auto int_doc = R"( "-243" )"_padded;
+        auto uint_doc = R"( "212213" )"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        double d;
+        int64_t i;
+        uint64_t u;
+        // Double
+        ASSERT_SUCCESS(parser.iterate(double_doc).get(doc));
+        ASSERT_SUCCESS(doc.get_double_in_string().get(d));
+        ASSERT_EQUAL(d,-12.3);
+        // Integer
+        ASSERT_SUCCESS(parser.iterate(int_doc).get(doc));
+        ASSERT_SUCCESS(doc.get_int64_in_string().get(i));
+        ASSERT_EQUAL(i,-243);
+        // Unsinged integer
+        ASSERT_SUCCESS(parser.iterate(uint_doc).get(doc));
+        ASSERT_SUCCESS(doc.get_uint64_in_string().get(u));
+        ASSERT_EQUAL(u,212213);
+        TEST_SUCCEED();
+    }
+
+    bool number_parsing_error() {
+        TEST_START();
+        auto json = R"( ["13.06.54", "1.0e", "2e3r4,,."])"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        size_t counter{0};
+        std::string expected[3] = {"13.06.54", "1.0e", "2e3r4,,."};
+        for (auto value : doc) {
+            double d;
+            std::string_view view;
+            ASSERT_ERROR(value.get_double_in_string().get(d),NUMBER_ERROR);
+            ASSERT_SUCCESS(value.get_string().get(view));
+            ASSERT_EQUAL(view,expected[counter++]);
+        }
+        ASSERT_EQUAL(counter,3);
+        TEST_SUCCEED();
+    }
+
+    bool incorrect_type_error() {
+        TEST_START();
+        auto json = R"( ["e", "i", "pi", "one", "zero"])"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        size_t counter{0};
+        std::string expected[5] = {"e", "i", "pi", "one", "zero"};
+        for (auto value : doc) {
+            double d;
+            std::string_view view;
+            ASSERT_ERROR(value.get_double_in_string().get(d),INCORRECT_TYPE);
+            ASSERT_SUCCESS(value.get_string().get(view));
+            ASSERT_EQUAL(view,expected[counter++]);
+        }
+        ASSERT_EQUAL(counter,5);
+        TEST_SUCCEED();
+    }
+
+    bool json_pointer_test() {
+        TEST_START();
+        auto json = R"( ["12.34", { "a":["3","5.6"], "b":{"c":"1.23e1"} }, ["1", "3.5"] ])"_padded;
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(json).get(doc));
+        std::vector<double> expected = {12.34, 5.6, 12.3, 1, 3.5};
+        size_t counter{0};
+        double d;
+        ASSERT_SUCCESS(doc.at_pointer("/0").get_double_in_string().get(d));
+        ASSERT_EQUAL(d,expected[counter++]);
+        ASSERT_SUCCESS(doc.at_pointer("/1/a/1").get_double_in_string().get(d));
+        ASSERT_EQUAL(d,expected[counter++]);
+        ASSERT_SUCCESS(doc.at_pointer("/1/b/c").get_double_in_string().get(d));
+        ASSERT_EQUAL(d,expected[counter++]);
+        ASSERT_SUCCESS(doc.at_pointer("/2/0").get_double_in_string().get(d));
+        ASSERT_EQUAL(d,expected[counter++]);
+        ASSERT_SUCCESS(doc.at_pointer("/2/1").get_double_in_string().get(d));
+        ASSERT_EQUAL(d,expected[counter++]);
+        ASSERT_EQUAL(counter,5);
+        TEST_SUCCEED();
+    }
+
+    bool crypto_timestamp() {
+        TEST_START();
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(CRYPTO_JSON).get(doc));
+        uint64_t u;
+        ASSERT_SUCCESS(doc.at_pointer("/timestampstr").get_uint64_in_string().get(u));
+        ASSERT_EQUAL(u,1399490941);
+        TEST_SUCCEED();
+    }
+
+    bool crypto_market() {
+        TEST_START();
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(CRYPTO_JSON).get(doc));
+        ondemand::array markets;
+        ASSERT_SUCCESS(doc.find_field("ticker").find_field("markets").get_array().get(markets));
+        std::string_view expected_views[3] = {"bitfinex", "bitstamp", "btce"};
+        double expected_prices[3] = {447.5, 448.54, 432.89};
+        double expected_volumes[3] = {10559.5293639, 11628.28800793, 8561.05636};
+        size_t counter{0};
+        for (auto value : markets) {
+            std::string_view view;
+            double price;
+            double volume;
+            ASSERT_SUCCESS(value.find_field("market").get_string().get(view));
+            ASSERT_EQUAL(view,expected_views[counter]);
+            ASSERT_SUCCESS(value.find_field("price").get_double_in_string().get(price));
+            ASSERT_EQUAL(price,expected_prices[counter]);
+            ASSERT_SUCCESS(value.find_field("volume").get_double_in_string().get(volume));
+            ASSERT_EQUAL(volume,expected_volumes[counter]);
+            counter++;
+        }
+        ASSERT_EQUAL(counter,3);
+        TEST_SUCCEED();
+    }
+
+    bool crypto_infinity() {
+        TEST_START();
+        ondemand::parser parser;
+        ondemand::document doc;
+        ASSERT_SUCCESS(parser.iterate(CRYPTO_JSON).get(doc));
+        ondemand::value value;
+        double d;
+        std::string_view view;
+        ASSERT_SUCCESS(doc.find_field("ticker").find_field("change").get(value));
+        ASSERT_ERROR(value.get_double_in_string().get(d), INCORRECT_TYPE);
+        ASSERT_SUCCESS(value.get_string().get(view));
+        ASSERT_EQUAL(view,"Infinity");
+        TEST_SUCCEED();
+    }
+
+    bool run() {
+        return  array_double() &&
+                array_int() &&
+                array_unsigned() &&
+                object() &&
+                docs() &&
+                number_parsing_error() &&
+                incorrect_type_error() &&
+                json_pointer_test() &&
+                crypto_timestamp() &&
+                crypto_market() &&
+                crypto_infinity() &&
+                true;
+    }
+}   // number_in_string_tests
+
+int main(int argc, char *argv[]) {
+  return test_main(argc, argv, number_in_string_tests::run);
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
# Use -j4 for parallel compilation jobs, as specified in the Dockerfile and reference.
cmake --build . -j4

# Check the exit code of the build command. If the build fails, exit early.
if [ $? -ne 0 ]; then
    echo "Build failed after patch application. Exiting with OMNIGRIL_EXIT_CODE=1."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute only the specified target tests.
# The target file tests/ondemand/CMakeLists.txt registers tests with the label 'ondemand'.
# The test execution command provided by the context retrieval agent explicitly uses this label.
# **MODIFICATION**: Limit ctest parallelism to -j4 to prevent Out-Of-Memory errors,
# consistent with the build process.
ctest -L ondemand -j4 --output-on-failure
rc=$?

# Capture the exit code immediately after running the tests.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed root directory for cleanup.
cd /testbed

# Clean up: Undo any changes made to the target test file.
# This ensures that the repository remains in its original state after the test run.
git checkout 47a62db55936e29e1966a26a9aadb5f28237ae37 "tests/ondemand/CMakeLists.txt"