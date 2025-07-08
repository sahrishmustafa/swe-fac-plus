#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout target files to their original state before applying any potential patch,
# as per the skeleton's initial checkout step.
git checkout c96ff018fedc7fe087b6f898442458a31a240a28 "tests/ondemand/CMakeLists.txt" "tests/ondemand/ondemand_error_tests.cpp" "tests/ondemand/ondemand_dom_api_tests.cpp" "tests/test_macros.h"

# Required: apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ondemand/CMakeLists.txt b/tests/ondemand/CMakeLists.txt
--- a/tests/ondemand/CMakeLists.txt
+++ b/tests/ondemand/CMakeLists.txt
@@ -4,14 +4,16 @@ include_directories(..)
 add_subdirectory(compilation_failure_tests)
 
 add_cpp_test(ondemand_active_tests      LABELS ondemand acceptance per_implementation)
+add_cpp_test(ondemand_array_tests       LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_compilation_tests LABELS ondemand acceptance per_implementation)
-add_cpp_test(ondemand_dom_api_tests     LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_error_tests       LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_key_string_tests  LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_number_tests      LABELS ondemand acceptance per_implementation)
+add_cpp_test(ondemand_object_tests      LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_ordering_tests    LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_parse_api_tests   LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_readme_examples   LABELS ondemand acceptance per_implementation)
+add_cpp_test(ondemand_scalar_tests      LABELS ondemand acceptance per_implementation)
 add_cpp_test(ondemand_twitter_tests     LABELS ondemand acceptance per_implementation)
 
 if(HAVE_POSIX_FORK AND HAVE_POSIX_WAIT) # assert tests use fork and wait, which aren't on MSVC
@@ -20,8 +22,8 @@ endif()
 
 # Copy the simdjson dll into the tests directory
 if(MSVC)
-  add_custom_command(TARGET ondemand_dom_api_tests POST_BUILD        # Adds a post-build event
+  add_custom_command(TARGET ondemand_parse_api_tests POST_BUILD        # Adds a post-build event
     COMMAND ${CMAKE_COMMAND} -E copy_if_different  # which executes "cmake -E copy_if_different..."
         "$<TARGET_FILE:simdjson>"      # <--this is in-file
-        "$<TARGET_FILE_DIR:ondemand_dom_api_tests>")                 # <--this is out-file path
+        "$<TARGET_FILE_DIR:ondemand_parse_api_tests>")                 # <--this is out-file path
 endif(MSVC)
diff --git a/tests/ondemand/ondemand_array_tests.cpp b/tests/ondemand/ondemand_array_tests.cpp
new file mode 100644
--- /dev/null
+++ b/tests/ondemand/ondemand_array_tests.cpp
@@ -0,0 +1,275 @@
+#include "simdjson.h"
+#include "test_ondemand.h"
+
+using namespace simdjson;
+
+namespace array_tests {
+  using namespace std;
+
+  bool iterate_array() {
+    TEST_START();
+    const auto json = R"([ 1, 10, 100 ])"_padded;
+    const uint64_t expected_value[] = { 1, 10, 100 };
+
+    SUBTEST("ondemand::array", test_ondemand_doc(json, [&](auto doc_result) {
+      ondemand::array array;
+      ASSERT_SUCCESS( doc_result.get(array) );
+
+      size_t i=0;
+      for (auto value : array) {
+        int64_t actual;
+        ASSERT_SUCCESS( value.get(actual) );
+        ASSERT_EQUAL(actual, expected_value[i]);
+        i++;
+      }
+      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
+      return true;
+    }));
+    SUBTEST("simdjson_result<ondemand::array>", test_ondemand_doc(json, [&](auto doc_result) {
+      simdjson_result<ondemand::array> array = doc_result.get_array();
+      size_t i=0;
+      for (simdjson_unused auto value : array) { int64_t actual; ASSERT_SUCCESS( value.get(actual) ); ASSERT_EQUAL(actual, expected_value[i]); i++; }
+      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
+      return true;
+    }));
+    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc_result) {
+      ondemand::document doc;
+      ASSERT_SUCCESS( std::move(doc_result).get(doc) );
+      size_t i=0;
+      for (simdjson_unused auto value : doc) { int64_t actual; ASSERT_SUCCESS( value.get(actual) ); ASSERT_EQUAL(actual, expected_value[i]); i++; }
+      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
+      return true;
+    }));
+    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
+      size_t i=0;
+      for (simdjson_unused auto value : doc_result) { int64_t actual; ASSERT_SUCCESS( value.get(actual) ); ASSERT_EQUAL(actual, expected_value[i]); i++; }
+      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
+      return true;
+    }));
+    TEST_SUCCEED();
+  }
+
+  bool iterate_array_partial_children() {
+    TEST_START();
+    auto json = R"(
+      [
+        0,
+        [],
+        {},
+        { "x": 3, "y": 33 },
+        { "x": 4, "y": 44 },
+        { "x": 5, "y": 55 },
+        { "x": 6, "y": 66 },
+        [ 7, 77, 777 ],
+        [ 8, 88, 888 ],
+        { "a": [ { "b": [ 9, 99 ], "c": 999 }, 9999 ], "d": 99999 },
+        10
+      ]
+    )"_padded;
+    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
+      size_t i = 0;
+      for (auto value : doc_result) {
+        ASSERT_SUCCESS(value);
+
+        switch (i) {
+          case 0: {
+            std::cout << "  - After ignoring empty scalar ..." << std::endl;
+            break;
+          }
+          case 1: {
+            std::cout << "  - After ignoring empty array ..." << std::endl;
+            break;
+          }
+          case 2: {
+            std::cout << "  - After ignoring empty object ..." << std::endl;
+            break;
+          }
+          // Break after using first value in child object
+          case 3: {
+            for (auto [ child_field, error ] : value.get_object()) {
+              ASSERT_SUCCESS(error);
+              ASSERT_EQUAL(child_field.key(), "x");
+              uint64_t x;
+              ASSERT_SUCCESS( child_field.value().get(x) );
+              ASSERT_EQUAL(x, 3);
+              break; // Break after the first value
+            }
+            std::cout << "  - After using first value in child object ..." << std::endl;
+            break;
+          }
+
+          // Break without using first value in child object
+          case 4: {
+            for (auto [ child_field, error ] : value.get_object()) {
+              ASSERT_SUCCESS(error);
+              ASSERT_EQUAL(child_field.key(), "x");
+              break;
+            }
+            std::cout << "  - After reaching (but not using) first value in child object ..." << std::endl;
+            break;
+          }
+
+          // Only look up one field in child object
+          case 5: {
+            uint64_t x;
+            ASSERT_SUCCESS( value["x"].get(x) );
+            ASSERT_EQUAL( x, 5 );
+            std::cout << "  - After looking up one field in child object ..." << std::endl;
+            break;
+          }
+
+          // Only look up one field in child object, but don't use it
+          case 6: {
+            ASSERT_SUCCESS( value["x"] );
+            std::cout << "  - After looking up (but not using) one field in child object ..." << std::endl;
+            break;
+          }
+
+          // Break after first value in child array
+          case 7: {
+            for (auto [ child_value, error ] : value) {
+              ASSERT_SUCCESS(error);
+              uint64_t x;
+              ASSERT_SUCCESS( child_value.get(x) );
+              ASSERT_EQUAL( x, 7 );
+              break;
+            }
+            std::cout << "  - After using first value in child array ..." << std::endl;
+            break;
+          }
+
+          // Break without using first value in child array
+          case 8: {
+            for (auto child_value : value) {
+              ASSERT_SUCCESS(child_value);
+              break;
+            }
+            std::cout << "  - After reaching (but not using) first value in child array ..." << std::endl;
+            break;
+          }
+
+          // Break out of multiple child loops
+          case 9: {
+            for (auto child1 : value.get_object()) {
+              for (auto child2 : child1.value().get_array()) {
+                for (auto child3 : child2.get_object()) {
+                  for (auto child4 : child3.value().get_array()) {
+                    uint64_t x;
+                    ASSERT_SUCCESS( child4.get(x) );
+                    ASSERT_EQUAL( x, 9 );
+                    break;
+                  }
+                  break;
+                }
+                break;
+              }
+              break;
+            }
+            std::cout << "  - After breaking out of quadruply-nested arrays and objects ..." << std::endl;
+            break;
+          }
+
+          // Test the actual value
+          case 10: {
+            uint64_t actual_value;
+            ASSERT_SUCCESS( value.get(actual_value) );
+            ASSERT_EQUAL( actual_value, 10 );
+            break;
+          }
+        }
+
+        i++;
+      }
+      ASSERT_EQUAL( i, 11 ); // Make sure we found all the keys we expected
+      return true;
+    }));
+    return true;
+  }
+
+  bool iterate_empty_array() {
+    TEST_START();
+    auto json = "[]"_padded;
+    SUBTEST("ondemand::array", test_ondemand_doc(json, [&](auto doc_result) {
+      ondemand::array array;
+      ASSERT_SUCCESS( doc_result.get(array) );
+      for (simdjson_unused auto value : array) { TEST_FAIL("Unexpected value"); }
+      return true;
+    }));
+    SUBTEST("simdjson_result<ondemand::array>", test_ondemand_doc(json, [&](auto doc_result) {
+      simdjson_result<ondemand::array> array_result = doc_result.get_array();
+      for (simdjson_unused auto value : array_result) { TEST_FAIL("Unexpected value"); }
+      return true;
+    }));
+    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc_result) {
+      ondemand::document doc;
+      ASSERT_SUCCESS( std::move(doc_result).get(doc) );
+      for (simdjson_unused auto value : doc) { TEST_FAIL("Unexpected value"); }
+      return true;
+    }));
+    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
+      for (simdjson_unused auto value : doc_result) { TEST_FAIL("Unexpected value"); }
+      return true;
+    }));
+    TEST_SUCCEED();
+  }
+
+#if SIMDJSON_EXCEPTIONS
+
+  bool iterate_array_exception() {
+    TEST_START();
+    auto json = R"([ 1, 10, 100 ])"_padded;
+    const uint64_t expected_value[] = { 1, 10, 100 };
+
+    ASSERT_TRUE(test_ondemand_doc(json, [&](auto doc_result) {
+      size_t i=0;
+      for (int64_t actual : doc_result) { ASSERT_EQUAL(actual, expected_value[i]); i++; }
+      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
+      return true;
+    }));
+    TEST_SUCCEED();
+  }
+
+  bool iterate_empty_object_exception() {
+    TEST_START();
+    auto json = R"({})"_padded;
+
+    ASSERT_TRUE(test_ondemand_doc(json, [&](auto doc_result) {
+      for (simdjson_unused ondemand::field field : doc_result.get_object()) {
+        TEST_FAIL("Unexpected field");
+      }
+      return true;
+    }));
+
+    TEST_SUCCEED();
+  }
+
+  bool iterate_empty_array_exception() {
+    TEST_START();
+    auto json = "[]"_padded;
+
+    ASSERT_TRUE(test_ondemand_doc(json, [&](auto doc_result) {
+      for (simdjson_unused ondemand::value value : doc_result) { TEST_FAIL("Unexpected value"); }
+      return true;
+    }));
+
+    TEST_SUCCEED();
+  }
+
+#endif // SIMDJSON_EXCEPTIONS
+
+  bool run() {
+    return
+           iterate_array() &&
+           iterate_empty_array() &&
+           iterate_array_partial_children() &&
+#if SIMDJSON_EXCEPTIONS
+           iterate_array_exception() &&
+#endif // SIMDJSON_EXCEPTIONS
+           true;
+  }
+
+} // namespace dom_api_tests
+
+int main(int argc, char *argv[]) {
+  return test_main(argc, argv, array_tests::run);
+}
diff --git a/tests/ondemand/ondemand_error_tests.cpp b/tests/ondemand/ondemand_error_tests.cpp
--- a/tests/ondemand/ondemand_error_tests.cpp
+++ b/tests/ondemand/ondemand_error_tests.cpp
@@ -39,9 +39,9 @@ namespace error_tests {
       TEST_START();
       TEST_CAST_ERROR("[]", object, INCORRECT_TYPE);
       TEST_CAST_ERROR("[]", bool, INCORRECT_TYPE);
-      TEST_CAST_ERROR("[]", int64, NUMBER_ERROR);
-      TEST_CAST_ERROR("[]", uint64, NUMBER_ERROR);
-      TEST_CAST_ERROR("[]", double, NUMBER_ERROR);
+      TEST_CAST_ERROR("[]", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("[]", uint64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("[]", double, INCORRECT_TYPE);
       TEST_CAST_ERROR("[]", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("[]", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -51,9 +51,9 @@ namespace error_tests {
       TEST_START();
       TEST_CAST_ERROR("{}", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("{}", bool, INCORRECT_TYPE);
-      TEST_CAST_ERROR("{}", int64, NUMBER_ERROR);
-      TEST_CAST_ERROR("{}", uint64, NUMBER_ERROR);
-      TEST_CAST_ERROR("{}", double, NUMBER_ERROR);
+      TEST_CAST_ERROR("{}", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("{}", uint64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("{}", double, INCORRECT_TYPE);
       TEST_CAST_ERROR("{}", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("{}", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -63,9 +63,9 @@ namespace error_tests {
       TEST_START();
       TEST_CAST_ERROR("true", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("true", object, INCORRECT_TYPE);
-      TEST_CAST_ERROR("true", int64, NUMBER_ERROR);
-      TEST_CAST_ERROR("true", uint64, NUMBER_ERROR);
-      TEST_CAST_ERROR("true", double, NUMBER_ERROR);
+      TEST_CAST_ERROR("true", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("true", uint64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("true", double, INCORRECT_TYPE);
       TEST_CAST_ERROR("true", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("true", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -75,9 +75,9 @@ namespace error_tests {
       TEST_START();
       TEST_CAST_ERROR("false", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("false", object, INCORRECT_TYPE);
-      TEST_CAST_ERROR("false", int64, NUMBER_ERROR);
-      TEST_CAST_ERROR("false", uint64, NUMBER_ERROR);
-      TEST_CAST_ERROR("false", double, NUMBER_ERROR);
+      TEST_CAST_ERROR("false", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("false", uint64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("false", double, INCORRECT_TYPE);
       TEST_CAST_ERROR("false", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("false", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -87,9 +87,9 @@ namespace error_tests {
       TEST_START();
       TEST_CAST_ERROR("null", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("null", object, INCORRECT_TYPE);
-      TEST_CAST_ERROR("null", int64, NUMBER_ERROR);
-      TEST_CAST_ERROR("null", uint64, NUMBER_ERROR);
-      TEST_CAST_ERROR("null", double, NUMBER_ERROR);
+      TEST_CAST_ERROR("null", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("null", uint64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("null", double, INCORRECT_TYPE);
       TEST_CAST_ERROR("null", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("null", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -110,7 +110,7 @@ namespace error_tests {
       TEST_CAST_ERROR("-1", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("-1", object, INCORRECT_TYPE);
       TEST_CAST_ERROR("-1", bool, INCORRECT_TYPE);
-      TEST_CAST_ERROR("-1", uint64, NUMBER_ERROR);
+      TEST_CAST_ERROR("-1", uint64, INCORRECT_TYPE);
       TEST_CAST_ERROR("-1", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("-1", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -121,8 +121,8 @@ namespace error_tests {
       TEST_CAST_ERROR("1.1", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("1.1", object, INCORRECT_TYPE);
       TEST_CAST_ERROR("1.1", bool, INCORRECT_TYPE);
-      TEST_CAST_ERROR("1.1", int64, NUMBER_ERROR);
-      TEST_CAST_ERROR("1.1", uint64, NUMBER_ERROR);
+      TEST_CAST_ERROR("1.1", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("1.1", uint64, INCORRECT_TYPE);
       TEST_CAST_ERROR("1.1", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("1.1", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -133,8 +133,8 @@ namespace error_tests {
       TEST_CAST_ERROR("-9223372036854775809", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("-9223372036854775809", object, INCORRECT_TYPE);
       TEST_CAST_ERROR("-9223372036854775809", bool, INCORRECT_TYPE);
-      TEST_CAST_ERROR("-9223372036854775809", int64, NUMBER_ERROR);
-      TEST_CAST_ERROR("-9223372036854775809", uint64, NUMBER_ERROR);
+      TEST_CAST_ERROR("-9223372036854775809", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("-9223372036854775809", uint64, INCORRECT_TYPE);
       TEST_CAST_ERROR("-9223372036854775809", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("-9223372036854775809", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -146,7 +146,7 @@ namespace error_tests {
       TEST_CAST_ERROR("9223372036854775808", object, INCORRECT_TYPE);
       TEST_CAST_ERROR("9223372036854775808", bool, INCORRECT_TYPE);
       // TODO BUG: this should be an error but is presently not
-      // TEST_CAST_ERROR("9223372036854775808", int64, NUMBER_ERROR);
+      // TEST_CAST_ERROR("9223372036854775808", int64, INCORRECT_TYPE);
       TEST_CAST_ERROR("9223372036854775808", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("9223372036854775808", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -157,9 +157,8 @@ namespace error_tests {
       TEST_CAST_ERROR("18446744073709551616", array, INCORRECT_TYPE);
       TEST_CAST_ERROR("18446744073709551616", object, INCORRECT_TYPE);
       TEST_CAST_ERROR("18446744073709551616", bool, INCORRECT_TYPE);
-      TEST_CAST_ERROR("18446744073709551616", int64, NUMBER_ERROR);
-      // TODO BUG: this should be an error but is presently not
-      // TEST_CAST_ERROR("18446744073709551616", uint64, NUMBER_ERROR);
+      TEST_CAST_ERROR("18446744073709551616", int64, INCORRECT_TYPE);
+      TEST_CAST_ERROR("18446744073709551616", uint64, INCORRECT_TYPE);
       TEST_CAST_ERROR("18446744073709551616", string, INCORRECT_TYPE);
       TEST_CAST_ERROR("18446744073709551616", raw_json_string, INCORRECT_TYPE);
       TEST_SUCCEED();
@@ -238,43 +237,43 @@ namespace error_tests {
   bool top_level_array_iterate_error() {
     TEST_START();
     ONDEMAND_SUBTEST("missing comma", "[1 1]",  assert_iterate(doc, { int64_t(1) }, { TAPE_ERROR }));
-    ONDEMAND_SUBTEST("extra comma  ", "[1,,1]", assert_iterate(doc, { int64_t(1) }, { NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("extra comma  ", "[,]",    assert_iterate(doc,                 { NUMBER_ERROR }));
-    ONDEMAND_SUBTEST("extra comma  ", "[,,]",   assert_iterate(doc,                 { NUMBER_ERROR, NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("extra comma  ", "[1,,1]", assert_iterate(doc, { int64_t(1) }, { INCORRECT_TYPE, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("extra comma  ", "[,]",    assert_iterate(doc,                 { INCORRECT_TYPE }));
+    ONDEMAND_SUBTEST("extra comma  ", "[,,]",   assert_iterate(doc,                 { INCORRECT_TYPE, INCORRECT_TYPE, TAPE_ERROR }));
     TEST_SUCCEED();
   }
   bool top_level_array_iterate_unclosed_error() {
     TEST_START();
-    ONDEMAND_SUBTEST("unclosed extra comma", "[,", assert_iterate(doc,                 { NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("unclosed     ", "[1 ",    assert_iterate(doc, { int64_t(1) }, { TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed extra comma", "[,", assert_iterate(doc,                 { INCORRECT_TYPE, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed     ", "[1 ",       assert_iterate(doc, { int64_t(1) }, { TAPE_ERROR }));
     // TODO These pass the user values that may run past the end of the buffer if they aren't careful
     // In particular, if the padding is decorated with the wrong values, we could cause overrun!
-    ONDEMAND_SUBTEST("unclosed extra comma", "[,,", assert_iterate(doc,                 { NUMBER_ERROR, NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("unclosed     ", "[1,",    assert_iterate(doc, { int64_t(1) }, { NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("unclosed     ", "[1",     assert_iterate(doc,                 { NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("unclosed     ", "[",      assert_iterate(doc,                 { NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed extra comma", "[,,", assert_iterate(doc,                 { INCORRECT_TYPE, INCORRECT_TYPE, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed     ", "[1,",        assert_iterate(doc, { int64_t(1) }, { INCORRECT_TYPE, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed     ", "[1",         assert_iterate(doc,                 { NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed     ", "[",          assert_iterate(doc,                 { INCORRECT_TYPE, TAPE_ERROR }));
     TEST_SUCCEED();
   }
 
   bool array_iterate_error() {
     TEST_START();
     ONDEMAND_SUBTEST("missing comma", R"({ "a": [1 1] })",  assert_iterate(doc["a"], { int64_t(1) }, { TAPE_ERROR }));
-    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [1,,1] })", assert_iterate(doc["a"], { int64_t(1) }, { NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [1,,] })",  assert_iterate(doc["a"], { int64_t(1) }, { NUMBER_ERROR }));
-    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [,] })",    assert_iterate(doc["a"],                 { NUMBER_ERROR }));
-    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [,,] })",   assert_iterate(doc["a"],                 { NUMBER_ERROR, NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [1,,1] })", assert_iterate(doc["a"], { int64_t(1) }, { INCORRECT_TYPE, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [1,,] })",  assert_iterate(doc["a"], { int64_t(1) }, { INCORRECT_TYPE }));
+    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [,] })",    assert_iterate(doc["a"],                 { INCORRECT_TYPE }));
+    ONDEMAND_SUBTEST("extra comma  ", R"({ "a": [,,] })",   assert_iterate(doc["a"],                 { INCORRECT_TYPE, INCORRECT_TYPE, TAPE_ERROR }));
     TEST_SUCCEED();
   }
   bool array_iterate_unclosed_error() {
     TEST_START();
-    ONDEMAND_SUBTEST("unclosed extra comma", R"({ "a": [,)",  assert_iterate(doc["a"],                 { NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("unclosed extra comma", R"({ "a": [,,)", assert_iterate(doc["a"],                 { NUMBER_ERROR, NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed extra comma", R"({ "a": [,)",  assert_iterate(doc["a"],                 { INCORRECT_TYPE, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed extra comma", R"({ "a": [,,)", assert_iterate(doc["a"],                 { INCORRECT_TYPE, INCORRECT_TYPE, TAPE_ERROR }));
     ONDEMAND_SUBTEST("unclosed     ", R"({ "a": [1 )",        assert_iterate(doc["a"], { int64_t(1) }, { TAPE_ERROR }));
     // TODO These pass the user values that may run past the end of the buffer if they aren't careful
     // In particular, if the padding is decorated with the wrong values, we could cause overrun!
-    ONDEMAND_SUBTEST("unclosed     ", R"({ "a": [1,)",        assert_iterate(doc["a"], { int64_t(1) }, { NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed     ", R"({ "a": [1,)",        assert_iterate(doc["a"], { int64_t(1) }, { INCORRECT_TYPE, TAPE_ERROR }));
     ONDEMAND_SUBTEST("unclosed     ", R"({ "a": [1)",         assert_iterate(doc["a"],                 { NUMBER_ERROR, TAPE_ERROR }));
-    ONDEMAND_SUBTEST("unclosed     ", R"({ "a": [)",          assert_iterate(doc["a"],                 { NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed     ", R"({ "a": [)",          assert_iterate(doc["a"],                 { INCORRECT_TYPE, TAPE_ERROR }));
     TEST_SUCCEED();
   }
 
@@ -317,7 +316,7 @@ namespace error_tests {
     TEST_START();
     ONDEMAND_SUBTEST("missing colon", R"({ "a"  1, "b": 2 })",    assert_iterate_object(doc.get_object(),                          { TAPE_ERROR }));
     ONDEMAND_SUBTEST("missing key  ", R"({    : 1, "b": 2 })",    assert_iterate_object(doc.get_object(),                          { TAPE_ERROR }));
-    ONDEMAND_SUBTEST("missing value", R"({ "a":  , "b": 2 })",    assert_iterate_object(doc.get_object(),                          { NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("missing value", R"({ "a":  , "b": 2 })",    assert_iterate_object(doc.get_object(),                          { INCORRECT_TYPE, TAPE_ERROR }));
     ONDEMAND_SUBTEST("missing comma", R"({ "a": 1  "b": 2 })",    assert_iterate_object(doc.get_object(), { "a" }, { int64_t(1) }, { TAPE_ERROR }));
     TEST_SUCCEED();
   }
@@ -337,7 +336,7 @@ namespace error_tests {
     // TODO These next two pass the user a value that may run past the end of the buffer if they aren't careful.
     // In particular, if the padding is decorated with the wrong values, we could cause overrun!
     ONDEMAND_SUBTEST("unclosed", R"({ "a": 1          )",    assert_iterate_object(doc.get_object(), { "a" }, { int64_t(1) }, { TAPE_ERROR }));
-    ONDEMAND_SUBTEST("unclosed", R"({ "a":            )",    assert_iterate_object(doc.get_object(),                          { NUMBER_ERROR, TAPE_ERROR }));
+    ONDEMAND_SUBTEST("unclosed", R"({ "a":            )",    assert_iterate_object(doc.get_object(),                          { INCORRECT_TYPE, TAPE_ERROR }));
     ONDEMAND_SUBTEST("unclosed", R"({ "a"             )",    assert_iterate_object(doc.get_object(),                          { TAPE_ERROR }));
     ONDEMAND_SUBTEST("unclosed", R"({                 )",    assert_iterate_object(doc.get_object(),                          { TAPE_ERROR }));
     TEST_SUCCEED();
@@ -399,6 +398,177 @@ namespace error_tests {
     TEST_SUCCEED();
   }
 
+  bool get_fail_then_succeed_bool() {
+    TEST_START();
+    auto json = R"({ "val" : true })"_padded;
+    SUBTEST("simdjson_result<ondemand::value>", test_ondemand_doc(json, [&](auto doc) {
+      simdjson_result<ondemand::value> val = doc["val"];
+      // Get everything that can fail in both forward and backwards order
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_SUCCESS( val.get_bool() );
+      TEST_SUCCEED();
+    }));
+    SUBTEST("ondemand::value", test_ondemand_doc(json, [&](auto doc) {
+      ondemand::value val;
+      ASSERT_SUCCESS( doc["val"].get(val) );
+      // Get everything that can fail in both forward and backwards order
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_SUCCESS( val.get_bool() );
+      TEST_SUCCEED();
+    }));
+    json = R"(true)"_padded;
+    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](simdjson_result<ondemand::document> val) {
+      // Get everything that can fail in both forward and backwards order
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_SUCCESS( val.get_bool());
+      TEST_SUCCEED();
+    }));
+    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc) {
+      ondemand::document val;
+      ASSERT_SUCCESS( std::move(doc).get(val) );      // Get everything that can fail in both forward and backwards order
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), false );
+      ASSERT_SUCCESS( val.get_bool() );
+      TEST_SUCCEED();
+    }));
+
+    TEST_SUCCEED();
+  }
+
+  bool get_fail_then_succeed_null() {
+    TEST_START();
+    auto json = R"({ "val" : null })"_padded;
+    SUBTEST("simdjson_result<ondemand::value>", test_ondemand_doc(json, [&](auto doc) {
+      simdjson_result<ondemand::value> val = doc["val"];
+      // Get everything that can fail in both forward and backwards order
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), true );
+      TEST_SUCCEED();
+    }));
+    SUBTEST("ondemand::value", test_ondemand_doc(json, [&](auto doc) {
+      ondemand::value val;
+      ASSERT_SUCCESS( doc["val"].get(val) );
+      // Get everything that can fail in both forward and backwards order
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), true );
+      TEST_SUCCEED();
+    }));
+    json = R"(null)"_padded;
+    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](simdjson_result<ondemand::document> val) {
+      // Get everything that can fail in both forward and backwards order
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), true );
+      TEST_SUCCEED();
+    }));
+    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc) {
+      ondemand::document val;
+      ASSERT_SUCCESS( std::move(doc).get(val) );      // Get everything that can fail in both forward and backwards order
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_object(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_int64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_uint64(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_double(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_string(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_array(), INCORRECT_TYPE );
+      ASSERT_ERROR( val.get_bool(), INCORRECT_TYPE );
+      ASSERT_EQUAL( val.is_null(), true );
+      TEST_SUCCEED();
+    }));
+
+    //
+    // Do it again for bool
+    //
+    TEST_SUCCEED();
+  }
+
   bool run() {
     return
            empty_document_error() &&
@@ -416,6 +586,8 @@ namespace error_tests {
            object_lookup_miss_unclosed_error() &&
            object_lookup_miss_wrong_key_type_error() &&
            object_lookup_miss_next_error() &&
+           get_fail_then_succeed_bool() &&
+           get_fail_then_succeed_null() &&
            true;
   }
 }
diff --git a/tests/ondemand/ondemand_dom_api_tests.cpp b/tests/ondemand/ondemand_object_tests.cpp
similarity index 62%
rename from tests/ondemand/ondemand_dom_api_tests.cpp
rename to tests/ondemand/ondemand_object_tests.cpp
--- a/tests/ondemand/ondemand_dom_api_tests.cpp
+++ b/tests/ondemand/ondemand_object_tests.cpp
@@ -3,7 +3,7 @@
 
 using namespace simdjson;
 
-namespace dom_api_tests {
+namespace object_tests {
   using namespace std;
 
   bool iterate_object() {
@@ -39,48 +39,6 @@ namespace dom_api_tests {
     TEST_SUCCEED();
   }
 
-  bool iterate_array() {
-    TEST_START();
-    const auto json = R"([ 1, 10, 100 ])"_padded;
-    const uint64_t expected_value[] = { 1, 10, 100 };
-
-    SUBTEST("ondemand::array", test_ondemand_doc(json, [&](auto doc_result) {
-      ondemand::array array;
-      ASSERT_SUCCESS( doc_result.get(array) );
-      size_t i=0;
-      for (auto value : array) {
-        int64_t actual;
-        ASSERT_SUCCESS( value.get(actual) );
-        ASSERT_EQUAL(actual, expected_value[i]);
-        i++;
-      }
-      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
-      return true;
-    }));
-    SUBTEST("simdjson_result<ondemand::array>", test_ondemand_doc(json, [&](auto doc_result) {
-      simdjson_result<ondemand::array> array = doc_result.get_array();
-      size_t i=0;
-      for (simdjson_unused auto value : array) { int64_t actual; ASSERT_SUCCESS( value.get(actual) ); ASSERT_EQUAL(actual, expected_value[i]); i++; }
-      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
-      return true;
-    }));
-    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc_result) {
-      ondemand::document doc;
-      ASSERT_SUCCESS( std::move(doc_result).get(doc) );
-      size_t i=0;
-      for (simdjson_unused auto value : doc) { int64_t actual; ASSERT_SUCCESS( value.get(actual) ); ASSERT_EQUAL(actual, expected_value[i]); i++; }
-      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
-      return true;
-    }));
-    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
-      size_t i=0;
-      for (simdjson_unused auto value : doc_result) { int64_t actual; ASSERT_SUCCESS( value.get(actual) ); ASSERT_EQUAL(actual, expected_value[i]); i++; }
-      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
-      return true;
-    }));
-    TEST_SUCCEED();
-  }
-
   bool iterate_object_partial_children() {
     TEST_START();
     auto json = R"(
@@ -235,143 +193,6 @@ namespace dom_api_tests {
     return true;
   }
 
-  bool iterate_array_partial_children() {
-    TEST_START();
-    auto json = R"(
-      [
-        0,
-        [],
-        {},
-        { "x": 3, "y": 33 },
-        { "x": 4, "y": 44 },
-        { "x": 5, "y": 55 },
-        { "x": 6, "y": 66 },
-        [ 7, 77, 777 ],
-        [ 8, 88, 888 ],
-        { "a": [ { "b": [ 9, 99 ], "c": 999 }, 9999 ], "d": 99999 },
-        10
-      ]
-    )"_padded;
-    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
-      size_t i = 0;
-      for (auto value : doc_result) {
-        ASSERT_SUCCESS(value);
-
-        switch (i) {
-          case 0: {
-            std::cout << "  - After ignoring empty scalar ..." << std::endl;
-            break;
-          }
-          case 1: {
-            std::cout << "  - After ignoring empty array ..." << std::endl;
-            break;
-          }
-          case 2: {
-            std::cout << "  - After ignoring empty object ..." << std::endl;
-            break;
-          }
-          // Break after using first value in child object
-          case 3: {
-            for (auto [ child_field, error ] : value.get_object()) {
-              ASSERT_SUCCESS(error);
-              ASSERT_EQUAL(child_field.key(), "x");
-              uint64_t x;
-              ASSERT_SUCCESS( child_field.value().get(x) );
-              ASSERT_EQUAL(x, 3);
-              break; // Break after the first value
-            }
-            std::cout << "  - After using first value in child object ..." << std::endl;
-            break;
-          }
-
-          // Break without using first value in child object
-          case 4: {
-            for (auto [ child_field, error ] : value.get_object()) {
-              ASSERT_SUCCESS(error);
-              ASSERT_EQUAL(child_field.key(), "x");
-              break;
-            }
-            std::cout << "  - After reaching (but not using) first value in child object ..." << std::endl;
-            break;
-          }
-
-          // Only look up one field in child object
-          case 5: {
-            uint64_t x;
-            ASSERT_SUCCESS( value["x"].get(x) );
-            ASSERT_EQUAL( x, 5 );
-            std::cout << "  - After looking up one field in child object ..." << std::endl;
-            break;
-          }
-
-          // Only look up one field in child object, but don't use it
-          case 6: {
-            ASSERT_SUCCESS( value["x"] );
-            std::cout << "  - After looking up (but not using) one field in child object ..." << std::endl;
-            break;
-          }
-
-          // Break after first value in child array
-          case 7: {
-            for (auto [ child_value, error ] : value) {
-              ASSERT_SUCCESS(error);
-              uint64_t x;
-              ASSERT_SUCCESS( child_value.get(x) );
-              ASSERT_EQUAL( x, 7 );
-              break;
-            }
-            std::cout << "  - After using first value in child array ..." << std::endl;
-            break;
-          }
-
-          // Break without using first value in child array
-          case 8: {
-            for (auto child_value : value) {
-              ASSERT_SUCCESS(child_value);
-              break;
-            }
-            std::cout << "  - After reaching (but not using) first value in child array ..." << std::endl;
-            break;
-          }
-
-          // Break out of multiple child loops
-          case 9: {
-            for (auto child1 : value.get_object()) {
-              for (auto child2 : child1.value().get_array()) {
-                for (auto child3 : child2.get_object()) {
-                  for (auto child4 : child3.value().get_array()) {
-                    uint64_t x;
-                    ASSERT_SUCCESS( child4.get(x) );
-                    ASSERT_EQUAL( x, 9 );
-                    break;
-                  }
-                  break;
-                }
-                break;
-              }
-              break;
-            }
-            std::cout << "  - After breaking out of quadruply-nested arrays and objects ..." << std::endl;
-            break;
-          }
-
-          // Test the actual value
-          case 10: {
-            uint64_t actual_value;
-            ASSERT_SUCCESS( value.get(actual_value) );
-            ASSERT_EQUAL( actual_value, 10 );
-            break;
-          }
-        }
-
-        i++;
-      }
-      ASSERT_EQUAL( i, 11 ); // Make sure we found all the keys we expected
-      return true;
-    }));
-    return true;
-  }
-
   bool object_index_partial_children() {
     TEST_START();
     auto json = R"(
@@ -635,234 +456,6 @@ namespace dom_api_tests {
     TEST_SUCCEED();
   }
 
-  bool iterate_empty_array() {
-    TEST_START();
-    auto json = "[]"_padded;
-    SUBTEST("ondemand::array", test_ondemand_doc(json, [&](auto doc_result) {
-      ondemand::array array;
-      ASSERT_SUCCESS( doc_result.get(array) );
-      for (simdjson_unused auto value : array) { TEST_FAIL("Unexpected value"); }
-      return true;
-    }));
-    SUBTEST("simdjson_result<ondemand::array>", test_ondemand_doc(json, [&](auto doc_result) {
-      simdjson_result<ondemand::array> array_result = doc_result.get_array();
-      for (simdjson_unused auto value : array_result) { TEST_FAIL("Unexpected value"); }
-      return true;
-    }));
-    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc_result) {
-      ondemand::document doc;
-      ASSERT_SUCCESS( std::move(doc_result).get(doc) );
-      for (simdjson_unused auto value : doc) { TEST_FAIL("Unexpected value"); }
-      return true;
-    }));
-    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
-      for (simdjson_unused auto value : doc_result) { TEST_FAIL("Unexpected value"); }
-      return true;
-    }));
-    TEST_SUCCEED();
-  }
-
-  template<typename T>
-  bool test_scalar_value(const padded_string &json, const T &expected, bool test_twice=true) {
-    std::cout << "- JSON: " << json << endl;
-    SUBTEST( "simdjson_result<document>", test_ondemand_doc(json, [&](auto doc_result) {
-      T actual;
-      ASSERT_SUCCESS( doc_result.get(actual) );
-      ASSERT_EQUAL( expected, actual );
-      // Test it twice (scalars can be retrieved more than once)
-      if (test_twice) {
-        ASSERT_SUCCESS( doc_result.get(actual) );
-        ASSERT_EQUAL( expected, actual );
-      }
-      return true;
-    }));
-    SUBTEST( "document", test_ondemand_doc(json, [&](auto doc_result) {
-      T actual;
-      ASSERT_SUCCESS( doc_result.get(actual) );
-      ASSERT_EQUAL( expected, actual );
-      // Test it twice (scalars can be retrieved more than once)
-      if (test_twice) {
-        ASSERT_SUCCESS( doc_result.get(actual) );
-        ASSERT_EQUAL( expected, actual );
-      }
-      return true;
-    }));
-
-    {
-      padded_string whitespace_json = std::string(json) + " ";
-      std::cout << "- JSON: " << whitespace_json << endl;
-      SUBTEST( "simdjson_result<document>", test_ondemand_doc(whitespace_json, [&](auto doc_result) {
-        T actual;
-        ASSERT_SUCCESS( doc_result.get(actual) );
-        ASSERT_EQUAL( expected, actual );
-        // Test it twice (scalars can be retrieved more than once)
-        if (test_twice) {
-          ASSERT_SUCCESS( doc_result.get(actual) );
-          ASSERT_EQUAL( expected, actual );
-        }
-        return true;
-      }));
-      SUBTEST( "document", test_ondemand_doc(whitespace_json, [&](auto doc_result) {
-        T actual;
-        ASSERT_SUCCESS( doc_result.get(actual) );
-        ASSERT_EQUAL( expected, actual );
-        // Test it twice (scalars can be retrieved more than once)
-        if (test_twice) {
-          ASSERT_SUCCESS( doc_result.get(actual) );
-          ASSERT_EQUAL( expected, actual );
-        }
-        return true;
-      }));
-    }
-
-    {
-      padded_string array_json = std::string("[") + std::string(json) + "]";
-      std::cout << "- JSON: " << array_json << endl;
-      SUBTEST( "simdjson_result<value>", test_ondemand_doc(array_json, [&](auto doc_result) {
-        int count = 0;
-        for (simdjson_result<ondemand::value> val_result : doc_result) {
-          T actual;
-          ASSERT_SUCCESS( val_result.get(actual) );
-          ASSERT_EQUAL(expected, actual);
-          // Test it twice (scalars can be retrieved more than once)
-          if (test_twice) {
-            ASSERT_SUCCESS( val_result.get(actual) );
-            ASSERT_EQUAL(expected, actual);
-          }
-          count++;
-        }
-        ASSERT_EQUAL(count, 1);
-        return true;
-      }));
-      SUBTEST( "value", test_ondemand_doc(array_json, [&](auto doc_result) {
-        int count = 0;
-        for (simdjson_result<ondemand::value> val_result : doc_result) {
-          ondemand::value val;
-          ASSERT_SUCCESS( val_result.get(val) );
-          T actual;
-          ASSERT_SUCCESS( val.get(actual) );
-          ASSERT_EQUAL(expected, actual);
-          // Test it twice (scalars can be retrieved more than once)
-          if (test_twice) {
-            ASSERT_SUCCESS( val.get(actual) );
-            ASSERT_EQUAL(expected, actual);
-          }
-          count++;
-        }
-        ASSERT_EQUAL(count, 1);
-        return true;
-      }));
-    }
-
-    {
-      padded_string whitespace_array_json = std::string("[") + std::string(json) + " ]";
-      std::cout << "- JSON: " << whitespace_array_json << endl;
-      SUBTEST( "simdjson_result<value>", test_ondemand_doc(whitespace_array_json, [&](auto doc_result) {
-        int count = 0;
-        for (simdjson_result<ondemand::value> val_result : doc_result) {
-          T actual;
-          ASSERT_SUCCESS( val_result.get(actual) );
-          ASSERT_EQUAL(expected, actual);
-          // Test it twice (scalars can be retrieved more than once)
-          if (test_twice) {
-            ASSERT_SUCCESS( val_result.get(actual) );
-            ASSERT_EQUAL(expected, actual);
-          }
-          count++;
-        }
-        ASSERT_EQUAL(count, 1);
-        return true;
-      }));
-      SUBTEST( "value", test_ondemand_doc(whitespace_array_json, [&](auto doc_result) {
-        int count = 0;
-        for (simdjson_result<ondemand::value> val_result : doc_result) {
-          ondemand::value val;
-          ASSERT_SUCCESS( val_result.get(val) );
-          T actual;
-          ASSERT_SUCCESS( val.get(actual) );
-          ASSERT_EQUAL(expected, actual);
-          // Test it twice (scalars can be retrieved more than once)
-          if (test_twice) {
-            ASSERT_SUCCESS( val.get(actual) );
-            ASSERT_EQUAL(expected, actual);
-          }
-          count++;
-        }
-        ASSERT_EQUAL(count, 1);
-        return true;
-      }));
-    }
-
-    TEST_SUCCEED();
-  }
-
-  bool string_value() {
-    TEST_START();
-    // We can't retrieve a small string twice because it will blow out the string buffer
-    if (!test_scalar_value(R"("hi")"_padded, std::string_view("hi"), false)) { return false; }
-    // ... unless the document is big enough to have a big string buffer :)
-    if (!test_scalar_value(R"("hi"        )"_padded, std::string_view("hi"))) { return false; }
-    TEST_SUCCEED();
-  }
-
-  bool numeric_values() {
-    TEST_START();
-    if (!test_scalar_value<int64_t> ("0"_padded,   0)) { return false; }
-    if (!test_scalar_value<uint64_t>("0"_padded,   0)) { return false; }
-    if (!test_scalar_value<double>  ("0"_padded,   0)) { return false; }
-    if (!test_scalar_value<int64_t> ("1"_padded,   1)) { return false; }
-    if (!test_scalar_value<uint64_t>("1"_padded,   1)) { return false; }
-    if (!test_scalar_value<double>  ("1"_padded,   1)) { return false; }
-    if (!test_scalar_value<int64_t> ("-1"_padded,  -1)) { return false; }
-    if (!test_scalar_value<double>  ("-1"_padded,  -1)) { return false; }
-    if (!test_scalar_value<double>  ("1.1"_padded, 1.1)) { return false; }
-    TEST_SUCCEED();
-  }
-
-  bool boolean_values() {
-    TEST_START();
-    if (!test_scalar_value<bool> ("true"_padded,  true)) { return false; }
-    if (!test_scalar_value<bool> ("false"_padded, false)) { return false; }
-    TEST_SUCCEED();
-  }
-
-  bool null_value() {
-    TEST_START();
-    auto json = "null"_padded;
-    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc_result) {
-      ondemand::document doc;
-      ASSERT_SUCCESS( std::move(doc_result).get(doc) );
-      ASSERT_EQUAL( doc.is_null(), true );
-      return true;
-    }));
-    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
-      ASSERT_EQUAL( doc_result.is_null(), true );
-      return true;
-    }));
-    json = "[null]"_padded;
-    SUBTEST("ondemand::value", test_ondemand_doc(json, [&](auto doc_result) {
-      int count = 0;
-      for (auto value_result : doc_result) {
-        ondemand::value value;
-        ASSERT_SUCCESS( value_result.get(value) );
-        ASSERT_EQUAL( value.is_null(), true );
-        count++;
-      }
-      ASSERT_EQUAL( count, 1 );
-      return true;
-    }));
-    SUBTEST("simdjson_result<ondemand::value>", test_ondemand_doc(json, [&](auto doc_result) {
-      int count = 0;
-      for (auto value_result : doc_result) {
-        ASSERT_EQUAL( value_result.is_null(), true );
-        count++;
-      }
-      ASSERT_EQUAL( count, 1 );
-      return true;
-    }));
-    return true;
-  }
-
   bool object_index() {
     TEST_START();
     auto json = R"({ "a": 1, "b": 2, "c/d": 3})"_padded;
@@ -1140,20 +733,6 @@ namespace dom_api_tests {
     TEST_SUCCEED();
   }
 
-  bool iterate_array_exception() {
-    TEST_START();
-    auto json = R"([ 1, 10, 100 ])"_padded;
-    const uint64_t expected_value[] = { 1, 10, 100 };
-
-    ASSERT_TRUE(test_ondemand_doc(json, [&](auto doc_result) {
-      size_t i=0;
-      for (int64_t actual : doc_result) { ASSERT_EQUAL(actual, expected_value[i]); i++; }
-      ASSERT_EQUAL(i*sizeof(uint64_t), sizeof(expected_value));
-      return true;
-    }));
-    TEST_SUCCEED();
-  }
-
   bool iterate_empty_object_exception() {
     TEST_START();
     auto json = R"({})"_padded;
@@ -1168,65 +747,6 @@ namespace dom_api_tests {
     TEST_SUCCEED();
   }
 
-  bool iterate_empty_array_exception() {
-    TEST_START();
-    auto json = "[]"_padded;
-
-    ASSERT_TRUE(test_ondemand_doc(json, [&](auto doc_result) {
-      for (simdjson_unused ondemand::value value : doc_result) { TEST_FAIL("Unexpected value"); }
-      return true;
-    }));
-
-    TEST_SUCCEED();
-  }
-
-  template<typename T>
-  bool test_scalar_value_exception(const padded_string &json, const T &expected) {
-    std::cout << "- JSON: " << json << endl;
-    SUBTEST( "document", test_ondemand_doc(json, [&](auto doc_result) {
-      ASSERT_EQUAL( expected, T(doc_result) );
-      return true;
-    }));
-    padded_string array_json = std::string("[") + std::string(json) + "]";
-    std::cout << "- JSON: " << array_json << endl;
-    SUBTEST( "value", test_ondemand_doc(array_json, [&](auto doc_result) {
-      int count = 0;
-      for (T actual : doc_result) {
-        ASSERT_EQUAL( expected, actual );
-        count++;
-      }
-      ASSERT_EQUAL(count, 1);
-      return true;
-    }));
-    TEST_SUCCEED();
-  }
-  bool string_value_exception() {
-    TEST_START();
-    return test_scalar_value_exception(R"("hi")"_padded, std::string_view("hi"));
-  }
-
-  bool numeric_values_exception() {
-    TEST_START();
-    if (!test_scalar_value_exception<int64_t> ("0"_padded,   0)) { return false; }
-    if (!test_scalar_value_exception<uint64_t>("0"_padded,   0)) { return false; }
-    if (!test_scalar_value_exception<double>  ("0"_padded,   0)) { return false; }
-    if (!test_scalar_value_exception<int64_t> ("1"_padded,   1)) { return false; }
-    if (!test_scalar_value_exception<uint64_t>("1"_padded,   1)) { return false; }
-    if (!test_scalar_value_exception<double>  ("1"_padded,   1)) { return false; }
-    if (!test_scalar_value_exception<int64_t> ("-1"_padded,  -1)) { return false; }
-    if (!test_scalar_value_exception<double>  ("-1"_padded,  -1)) { return false; }
-    if (!test_scalar_value_exception<double>  ("1.1"_padded, 1.1)) { return false; }
-    TEST_SUCCEED();
-  }
-
-  bool boolean_values_exception() {
-    TEST_START();
-    if (!test_scalar_value_exception<bool> ("true"_padded,  true)) { return false; }
-    if (!test_scalar_value_exception<bool> ("false"_padded, false)) { return false; }
-    TEST_SUCCEED();
-  }
-
-
   bool object_index_exception() {
     TEST_START();
     auto json = R"({ "a": 1, "b": 2, "c/d": 3})"_padded;
@@ -1255,35 +775,24 @@ namespace dom_api_tests {
 
   bool run() {
     return
-           iterate_array() &&
-           iterate_empty_array() &&
            iterate_object() &&
            iterate_empty_object() &&
-           string_value() &&
-           numeric_values() &&
-           boolean_values() &&
-           null_value() &&
            object_index() &&
            object_find_field_unordered() &&
            object_find_field() &&
            nested_object_index() &&
            iterate_object_partial_children() &&
-           iterate_array_partial_children() &&
            object_index_partial_children() &&
 #if SIMDJSON_EXCEPTIONS
            iterate_object_exception() &&
-           iterate_array_exception() &&
-           string_value_exception() &&
-           numeric_values_exception() &&
-           boolean_values_exception() &&
            object_index_exception() &&
            nested_object_index_exception() &&
 #endif // SIMDJSON_EXCEPTIONS
            true;
   }
 
-} // namespace dom_api_tests
+} // namespace object_tests
 
 int main(int argc, char *argv[]) {
-  return test_main(argc, argv, dom_api_tests::run);
+  return test_main(argc, argv, object_tests::run);
 }
diff --git a/tests/ondemand/ondemand_scalar_tests.cpp b/tests/ondemand/ondemand_scalar_tests.cpp
new file mode 100644
--- /dev/null
+++ b/tests/ondemand/ondemand_scalar_tests.cpp
@@ -0,0 +1,278 @@
+#include "simdjson.h"
+#include "test_ondemand.h"
+
+using namespace simdjson;
+
+namespace scalar_tests {
+  using namespace std;
+
+  template<typename T>
+  bool test_scalar_value(const padded_string &json, const T &expected, bool test_twice=true) {
+    std::cout << "- JSON: " << json << endl;
+    SUBTEST( "simdjson_result<document>", test_ondemand_doc(json, [&](auto doc_result) {
+      T actual;
+      ASSERT_SUCCESS( doc_result.get(actual) );
+      ASSERT_EQUAL( expected, actual );
+      // Test it twice (scalars can be retrieved more than once)
+      if (test_twice) {
+        ASSERT_SUCCESS( doc_result.get(actual) );
+        ASSERT_EQUAL( expected, actual );
+      }
+      return true;
+    }));
+    SUBTEST( "document", test_ondemand_doc(json, [&](auto doc_result) {
+      T actual;
+      ASSERT_SUCCESS( doc_result.get(actual) );
+      ASSERT_EQUAL( expected, actual );
+      // Test it twice (scalars can be retrieved more than once)
+      if (test_twice) {
+        ASSERT_SUCCESS( doc_result.get(actual) );
+        ASSERT_EQUAL( expected, actual );
+      }
+      return true;
+    }));
+
+    {
+      padded_string whitespace_json = std::string(json) + " ";
+      std::cout << "- JSON: " << whitespace_json << endl;
+      SUBTEST( "simdjson_result<document>", test_ondemand_doc(whitespace_json, [&](auto doc_result) {
+        T actual;
+        ASSERT_SUCCESS( doc_result.get(actual) );
+        ASSERT_EQUAL( expected, actual );
+        // Test it twice (scalars can be retrieved more than once)
+        if (test_twice) {
+          ASSERT_SUCCESS( doc_result.get(actual) );
+          ASSERT_EQUAL( expected, actual );
+        }
+        return true;
+      }));
+      SUBTEST( "document", test_ondemand_doc(whitespace_json, [&](auto doc_result) {
+        T actual;
+        ASSERT_SUCCESS( doc_result.get(actual) );
+        ASSERT_EQUAL( expected, actual );
+        // Test it twice (scalars can be retrieved more than once)
+        if (test_twice) {
+          ASSERT_SUCCESS( doc_result.get(actual) );
+          ASSERT_EQUAL( expected, actual );
+        }
+        return true;
+      }));
+    }
+
+    {
+      padded_string array_json = std::string("[") + std::string(json) + "]";
+      std::cout << "- JSON: " << array_json << endl;
+      SUBTEST( "simdjson_result<value>", test_ondemand_doc(array_json, [&](auto doc_result) {
+        int count = 0;
+        for (simdjson_result<ondemand::value> val_result : doc_result) {
+          T actual;
+          ASSERT_SUCCESS( val_result.get(actual) );
+          ASSERT_EQUAL(expected, actual);
+          // Test it twice (scalars can be retrieved more than once)
+          if (test_twice) {
+            ASSERT_SUCCESS( val_result.get(actual) );
+            ASSERT_EQUAL(expected, actual);
+          }
+          count++;
+        }
+        ASSERT_EQUAL(count, 1);
+        return true;
+      }));
+      SUBTEST( "value", test_ondemand_doc(array_json, [&](auto doc_result) {
+        int count = 0;
+        for (simdjson_result<ondemand::value> val_result : doc_result) {
+          ondemand::value val;
+          ASSERT_SUCCESS( val_result.get(val) );
+          T actual;
+          ASSERT_SUCCESS( val.get(actual) );
+          ASSERT_EQUAL(expected, actual);
+          // Test it twice (scalars can be retrieved more than once)
+          if (test_twice) {
+            ASSERT_SUCCESS( val.get(actual) );
+            ASSERT_EQUAL(expected, actual);
+          }
+          count++;
+        }
+        ASSERT_EQUAL(count, 1);
+        return true;
+      }));
+    }
+
+    {
+      padded_string whitespace_array_json = std::string("[") + std::string(json) + " ]";
+      std::cout << "- JSON: " << whitespace_array_json << endl;
+      SUBTEST( "simdjson_result<value>", test_ondemand_doc(whitespace_array_json, [&](auto doc_result) {
+        int count = 0;
+        for (simdjson_result<ondemand::value> val_result : doc_result) {
+          T actual;
+          ASSERT_SUCCESS( val_result.get(actual) );
+          ASSERT_EQUAL(expected, actual);
+          // Test it twice (scalars can be retrieved more than once)
+          if (test_twice) {
+            ASSERT_SUCCESS( val_result.get(actual) );
+            ASSERT_EQUAL(expected, actual);
+          }
+          count++;
+        }
+        ASSERT_EQUAL(count, 1);
+        return true;
+      }));
+      SUBTEST( "value", test_ondemand_doc(whitespace_array_json, [&](auto doc_result) {
+        int count = 0;
+        for (simdjson_result<ondemand::value> val_result : doc_result) {
+          ondemand::value val;
+          ASSERT_SUCCESS( val_result.get(val) );
+          T actual;
+          ASSERT_SUCCESS( val.get(actual) );
+          ASSERT_EQUAL(expected, actual);
+          // Test it twice (scalars can be retrieved more than once)
+          if (test_twice) {
+            ASSERT_SUCCESS( val.get(actual) );
+            ASSERT_EQUAL(expected, actual);
+          }
+          count++;
+        }
+        ASSERT_EQUAL(count, 1);
+        return true;
+      }));
+    }
+
+    TEST_SUCCEED();
+  }
+
+  bool string_value() {
+    TEST_START();
+    // We can't retrieve a small string twice because it will blow out the string buffer
+    if (!test_scalar_value(R"("hi")"_padded, std::string_view("hi"), false)) { return false; }
+    // ... unless the document is big enough to have a big string buffer :)
+    if (!test_scalar_value(R"("hi"        )"_padded, std::string_view("hi"))) { return false; }
+    TEST_SUCCEED();
+  }
+
+  bool numeric_values() {
+    TEST_START();
+    if (!test_scalar_value<int64_t> ("0"_padded,   0)) { return false; }
+    if (!test_scalar_value<uint64_t>("0"_padded,   0)) { return false; }
+    if (!test_scalar_value<double>  ("0"_padded,   0)) { return false; }
+    if (!test_scalar_value<int64_t> ("1"_padded,   1)) { return false; }
+    if (!test_scalar_value<uint64_t>("1"_padded,   1)) { return false; }
+    if (!test_scalar_value<double>  ("1"_padded,   1)) { return false; }
+    if (!test_scalar_value<int64_t> ("-1"_padded,  -1)) { return false; }
+    if (!test_scalar_value<double>  ("-1"_padded,  -1)) { return false; }
+    if (!test_scalar_value<double>  ("1.1"_padded, 1.1)) { return false; }
+    TEST_SUCCEED();
+  }
+
+  bool boolean_values() {
+    TEST_START();
+    if (!test_scalar_value<bool> ("true"_padded,  true)) { return false; }
+    if (!test_scalar_value<bool> ("false"_padded, false)) { return false; }
+    TEST_SUCCEED();
+  }
+
+  bool null_value() {
+    TEST_START();
+    auto json = "null"_padded;
+    SUBTEST("ondemand::document", test_ondemand_doc(json, [&](auto doc_result) {
+      ondemand::document doc;
+      ASSERT_SUCCESS( std::move(doc_result).get(doc) );
+      ASSERT_EQUAL( doc.is_null(), true );
+      return true;
+    }));
+    SUBTEST("simdjson_result<ondemand::document>", test_ondemand_doc(json, [&](auto doc_result) {
+      ASSERT_EQUAL( doc_result.is_null(), true );
+      return true;
+    }));
+    json = "[null]"_padded;
+    SUBTEST("ondemand::value", test_ondemand_doc(json, [&](auto doc_result) {
+      int count = 0;
+      for (auto value_result : doc_result) {
+        ondemand::value value;
+        ASSERT_SUCCESS( value_result.get(value) );
+        ASSERT_EQUAL( value.is_null(), true );
+        count++;
+      }
+      ASSERT_EQUAL( count, 1 );
+      return true;
+    }));
+    SUBTEST("simdjson_result<ondemand::value>", test_ondemand_doc(json, [&](auto doc_result) {
+      int count = 0;
+      for (auto value_result : doc_result) {
+        ASSERT_EQUAL( value_result.is_null(), true );
+        count++;
+      }
+      ASSERT_EQUAL( count, 1 );
+      return true;
+    }));
+    return true;
+  }
+
+#if SIMDJSON_EXCEPTIONS
+
+  template<typename T>
+  bool test_scalar_value_exception(const padded_string &json, const T &expected) {
+    std::cout << "- JSON: " << json << endl;
+    SUBTEST( "document", test_ondemand_doc(json, [&](auto doc_result) {
+      ASSERT_EQUAL( expected, T(doc_result) );
+      return true;
+    }));
+    padded_string array_json = std::string("[") + std::string(json) + "]";
+    std::cout << "- JSON: " << array_json << endl;
+    SUBTEST( "value", test_ondemand_doc(array_json, [&](auto doc_result) {
+      int count = 0;
+      for (T actual : doc_result) {
+        ASSERT_EQUAL( expected, actual );
+        count++;
+      }
+      ASSERT_EQUAL(count, 1);
+      return true;
+    }));
+    TEST_SUCCEED();
+  }
+  bool string_value_exception() {
+    TEST_START();
+    return test_scalar_value_exception(R"("hi")"_padded, std::string_view("hi"));
+  }
+
+  bool numeric_values_exception() {
+    TEST_START();
+    if (!test_scalar_value_exception<int64_t> ("0"_padded,   0)) { return false; }
+    if (!test_scalar_value_exception<uint64_t>("0"_padded,   0)) { return false; }
+    if (!test_scalar_value_exception<double>  ("0"_padded,   0)) { return false; }
+    if (!test_scalar_value_exception<int64_t> ("1"_padded,   1)) { return false; }
+    if (!test_scalar_value_exception<uint64_t>("1"_padded,   1)) { return false; }
+    if (!test_scalar_value_exception<double>  ("1"_padded,   1)) { return false; }
+    if (!test_scalar_value_exception<int64_t> ("-1"_padded,  -1)) { return false; }
+    if (!test_scalar_value_exception<double>  ("-1"_padded,  -1)) { return false; }
+    if (!test_scalar_value_exception<double>  ("1.1"_padded, 1.1)) { return false; }
+    TEST_SUCCEED();
+  }
+
+  bool boolean_values_exception() {
+    TEST_START();
+    if (!test_scalar_value_exception<bool> ("true"_padded,  true)) { return false; }
+    if (!test_scalar_value_exception<bool> ("false"_padded, false)) { return false; }
+    TEST_SUCCEED();
+  }
+
+#endif // SIMDJSON_EXCEPTIONS
+
+  bool run() {
+    return
+           string_value() &&
+           numeric_values() &&
+           boolean_values() &&
+           null_value() &&
+#if SIMDJSON_EXCEPTIONS
+           string_value_exception() &&
+           numeric_values_exception() &&
+           boolean_values_exception() &&
+#endif // SIMDJSON_EXCEPTIONS
+           true;
+  }
+
+} // namespace scalar_tests
+
+int main(int argc, char *argv[]) {
+  return test_main(argc, argv, scalar_tests::run);
+}
diff --git a/tests/test_macros.h b/tests/test_macros.h
--- a/tests/test_macros.h
+++ b/tests/test_macros.h
@@ -48,7 +48,7 @@ template<typename T>
 simdjson_really_inline bool assert_success(const T &actual, const char *operation = "result") {
   simdjson::error_code error = to_error_code(actual);
   if (error) {
-    std::cerr << "FAIL: " << operation << " returned error: " << error << std::endl;
+    std::cerr << "FAIL: " << operation << " returned error: " << error << " (" << int(error) << ")" << std::endl;
     return false;
   }
   return true;
EOF_114329324912

# Required: rebuild the project after applying the test patch.
# This ensures that any new or modified tests/code are included in the executables
# before running the tests.
echo "Rebuilding project after applying patch..."
cmake --build build
if [ $? -ne 0 ]; then
    echo "Build failed after patching. Exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    # Ensure cleanup even on build failure
    git checkout c96ff018fedc7fe087b6f898442458a31a240a28 "tests/ondemand/CMakeLists.txt" "tests/ondemand/ondemand_error_tests.cpp" "tests/ondemand/ondemand_dom_api_tests.cpp" "tests/test_macros.h"
    exit 1
fi
echo "Project rebuild complete."

# Required: run target tests
# Navigate into the build directory as specified by the context retrieval agent
# for executing CTest.
cd build
ctest . --output-on-failure -R "(ondemand_error_tests|ondemand_dom_api_tests)"
rc=$? # Capture the exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Echo the captured exit code

# Navigate back to the testbed root for cleanup
cd /testbed 

# Cleanup: Revert changes to the target files to their original state
git checkout c96ff018fedc7fe087b6f898442458a31a240a28 "tests/ondemand/CMakeLists.txt" "tests/ondemand/ondemand_error_tests.cpp" "tests/ondemand/ondemand_dom_api_tests.cpp" "tests/test_macros.h"