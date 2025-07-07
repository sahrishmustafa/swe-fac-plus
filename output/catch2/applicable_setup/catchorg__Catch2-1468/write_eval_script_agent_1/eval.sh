#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory
cd /testbed

# Checkout the specific test files to their original state at the commit SHA.
# This ensures a clean state before applying any potential patches.
# The listed files include documentation and header files, which are included
# for a complete reset, even though only .cpp files are actual tests.
git checkout 4902cd721586822ded795afe0c418c553137306a "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/docs/test-cases-and-sections.md b/docs/test-cases-and-sections.md
--- a/docs/test-cases-and-sections.md
+++ b/docs/test-cases-and-sections.md
@@ -95,7 +95,8 @@ Other than the additional prefixes and the formatting in the console reporter th
 ## Type parametrised test cases
 
 In addition to `TEST_CASE`s, Catch2 also supports test cases parametrised
-by type, in the form of `TEMPLATE_TEST_CASE`.
+by types, in the form of `TEMPLATE_TEST_CASE` and
+`TEMPLATE_PRODUCT_TEST_CASE`.
 
 * **TEMPLATE_TEST_CASE(** _test name_ , _tags_,  _type1_, _type2_, ..., _typen_ **)**
 
@@ -147,9 +148,48 @@ TEMPLATE_TEST_CASE( "vectors can be sized and resized", "[vector][template]", in
 }
 ```
 
+* **TEMPLATE_PRODUCT_TEST_CASE(** _test name_ , _tags_, (_template-type1_, _template-type2_, ..., _template-typen_), (_template-arg1_, _template-arg2_, ..., _template-argm_) **)**
+
+_template-type1_ through _template-typen_ is list of template template
+types which should be combined with each of _template-arg1_ through
+ _template-argm_, resulting in _n * m_ test cases. Inside the test case,
+the resulting type is available under the name of `TestType`.
+
+To specify more than 1 type as a single _template-type_ or _template-arg_,
+you must enclose the types in an additional set of parentheses, e.g.
+`((int, float), (char, double))` specifies 2 template-args, each
+consisting of 2 concrete types (`int`, `float` and `char`, `double`
+respectively). You can also omit the outer set of parentheses if you
+specify only one type as the full set of either the _template-types_,
+or the _template-args_.
+
+
+Example:
+```
+template< typename T>
+struct Foo {
+    size_t size() {
+        return 0;
+    }
+};
+
+TEMPLATE_PRODUCT_TEST_CASE("A Template product test case", "[template][product]", (std::vector, Foo), (int, float)) {
+    TestType x;
+    REQUIRE(x.size() == 0);
+}
+```
+
+You can also have different arities in the _template-arg_ packs:
+```
+TEMPLATE_PRODUCT_TEST_CASE("Product with differing arities", "[template][product]", std::tuple, (int, (int, double), (int, double, float))) {
+    TestType x;
+    REQUIRE(std::tuple_size<TestType>::value >= 1);
+}
+```
+
 _While there is an upper limit on the number of types you can specify
-in single `TEMPLATE_TEST_CASE`, the limit is very high and should not
-be encountered in practice._
+in single `TEMPLATE_TEST_CASE` or `TEMPLATE_PRODUCT_TEST_CASE`, the limit
+is very high and should not be encountered in practice._
 
 ---
 
diff --git a/docs/test-fixtures.md b/docs/test-fixtures.md
--- a/docs/test-fixtures.md
+++ b/docs/test-fixtures.md
@@ -31,16 +31,22 @@ class UniqueTestsFixture {
 The two test cases here will create uniquely-named derived classes of UniqueTestsFixture and thus can access the `getID()` protected method and `conn` member variables. This ensures that both the test cases are able to create a DBConnection using the same method (DRY principle) and that any ID's created are unique such that the order that tests are executed does not matter.
 
 
-Catch2 also provides `TEMPLATE_TEST_CASE_METHOD` that can be used together
-with templated fixtures to perform tests for multiple different types.
-However, unlike `TEST_CASE_METHOD`, `TEMPLATE_TEST_CASE_METHOD` requires
-the tag specification to be non-empty, as it is followed by further macros
-arguments.
+Catch2 also provides `TEMPLATE_TEST_CASE_METHOD` and
+`TEMPLATE_PRODUCT_TEST_CASE_METHOD` that can be used together
+with templated fixtures and templated template fixtures to perform
+tests for multiple different types. Unlike `TEST_CASE_METHOD`,
+`TEMPLATE_TEST_CASE_METHOD` and `TEMPLATE_PRODUCT_TEST_CASE_METHOD` do
+require the tag specification to be non-empty, as it is followed by
+further macro arguments.
 
 Also note that, because of limitations of the C++ preprocessor, if you
 want to specify a type with multiple template parameters, you need to
 enclose it in parentheses, e.g. `std::map<int, std::string>` needs to be
 passed as `(std::map<int, std::string>)`.
+In the case of `TEMPLATE_PRODUCT_TEST_CASE_METHOD`, if a member of the
+type list should consist of more than single type, it needs to be enclosed
+in another pair of parentheses, e.g. `(std::map, std::pair)` and
+`((int, float), (char, double))`.
 
 Example:
 ```cpp
@@ -54,11 +60,29 @@ struct Template_Fixture {
 TEMPLATE_TEST_CASE_METHOD(Template_Fixture,"A TEMPLATE_TEST_CASE_METHOD based test run that succeeds", "[class][template]", int, float, double) {
     REQUIRE( Template_Fixture<TestType>::m_a == 1 );
 }
+
+template<typename T>
+struct Template_Template_Fixture {
+    Template_Template_Fixture() {}
+
+    T m_a;
+};
+
+template<typename T>
+struct Foo_class {
+    size_t size() {
+        return 0;
+    }
+};
+
+TEMPLATE_PRODUCT_TEST_CASE_METHOD(Template_Template_Fixture, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD based test succeeds", "[class][template]", (Foo_class, std::vector), int) {
+    REQUIRE( Template_Template_Fixture<TestType>::m_a.size() == 0 );
+}
 ```
 
 _While there is an upper limit on the number of types you can specify
-in single `TEMPLATE_TEST_CASE`, the limit is very high and should not
-be encountered in practice._
+in single `TEMPLATE_TEST_CASE_METHOD` or `TEMPLATE_PRODUCT_TEST_CASE_METHOD`,
+the limit is very high and should not be encountered in practice._
 
 ---
 
diff --git a/include/internal/catch_test_registry.h b/include/internal/catch_test_registry.h
--- a/include/internal/catch_test_registry.h
+++ b/include/internal/catch_test_registry.h
@@ -14,6 +14,7 @@
 #include "catch_stringref.h"
 #include "catch_type_traits.hpp"
 #include "catch_preprocessor.hpp"
+#include "catch_meta.hpp"
 
 namespace Catch {
 
@@ -150,6 +151,38 @@ struct AutoReg : NonCopyable {
             return 0;\
         }();
 
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2(TestName, TestFuncName, Name, Tags, TmplTypes, TypesList) \
+        CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS                      \
+        template<typename TestType> static void TestFuncName();       \
+        namespace {                                                   \
+            template<typename... Types>                               \
+            struct TestName {                                         \
+                TestName() {                                          \
+                    CATCH_INTERNAL_CHECK_UNIQUE_TYPES(Types...)       \
+                    int index = 0;                                    \
+                    using expander = int[];                           \
+                    (void)expander{(Catch::AutoReg( Catch::makeTestInvoker( &TestFuncName<Types> ), CATCH_INTERNAL_LINEINFO, Catch::StringRef(), Catch::NameAndTags{ Name " - " + Catch::StringMaker<int>::convert(index++), Tags } ), 0)... };/* NOLINT */ \
+                }                                                     \
+            };                                                        \
+            static int INTERNAL_CATCH_UNIQUE_NAME( globalRegistrar ) = [](){ \
+                using TestInit = combine<INTERNAL_CATCH_REMOVE_PARENS(TmplTypes)> \
+                            ::with_types<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(TypesList)>::into<TestName>::type; \
+                TestInit();                                           \
+                return 0;                                             \
+            }();                                                      \
+        }                                                             \
+        CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS                    \
+        template<typename TestType>                                   \
+        static void TestFuncName()
+
+#ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE(Name, Tags, ...)\
+        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2(INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ),Name,Tags,__VA_ARGS__)
+#else
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE(Name, Tags, ...)\
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, __VA_ARGS__ ) )
+#endif
+
     #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( TestNameClass, TestName, ClassName, Name, Tags, ... ) \
         CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS \
         namespace{ \
@@ -180,4 +213,39 @@ struct AutoReg : NonCopyable {
         INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, __VA_ARGS__ ) )
 #endif
 
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2(TestNameClass, TestName, ClassName, Name, Tags, TmplTypes, TypesList)\
+        CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS \
+        template<typename TestType> \
+            struct TestName : INTERNAL_CATCH_REMOVE_PARENS(ClassName <TestType>) { \
+                void test();\
+            };\
+        namespace {\
+            template<typename...Types>\
+            struct TestNameClass{\
+                TestNameClass(){\
+                    CATCH_INTERNAL_CHECK_UNIQUE_TYPES(Types...)\
+                    int index = 0;\
+                    using expander = int[];\
+                    (void)expander{(Catch::AutoReg( Catch::makeTestInvoker( &TestName<Types>::test ), CATCH_INTERNAL_LINEINFO, #ClassName, Catch::NameAndTags{ Name " - " + Catch::StringMaker<int>::convert(index++), Tags } ), 0)... };/* NOLINT */ \
+                }\
+            };\
+            static int INTERNAL_CATCH_UNIQUE_NAME( globalRegistrar ) = [](){\
+                using TestInit = combine<INTERNAL_CATCH_REMOVE_PARENS(TmplTypes)>\
+                            ::with_types<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(TypesList)>::into<TestNameClass>::type;\
+                TestInit();\
+                return 0;\
+            }(); \
+        }\
+        CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS \
+        template<typename TestType> \
+        void TestName<TestType>::test()
+
+#ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD( ClassName, Name, Tags, ... )\
+        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, __VA_ARGS__ )
+#else
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD( ClassName, Name, Tags, ... )\
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, __VA_ARGS__ ) )
+#endif
+
 #endif // TWOBLUECUBES_CATCH_TEST_REGISTRY_HPP_INCLUDED
diff --git a/projects/SelfTest/UsageTests/Class.tests.cpp b/projects/SelfTest/UsageTests/Class.tests.cpp
--- a/projects/SelfTest/UsageTests/Class.tests.cpp
+++ b/projects/SelfTest/UsageTests/Class.tests.cpp
@@ -46,6 +46,18 @@ struct Template_Fixture {
     T m_a;
 };
 
+template<typename T>
+struct Template_Fixture_2 {
+    Template_Fixture_2() {}
+
+    T m_a;
+};
+
+template< typename T>
+struct Template_Foo {
+    size_t size() { return 0; }
+};
+
 #endif
 
 
@@ -62,6 +74,11 @@ TEMPLATE_TEST_CASE_METHOD(Template_Fixture, "A TEMPLATE_TEST_CASE_METHOD based t
     REQUIRE( Template_Fixture<TestType>::m_a == 1 );
 }
 
+TEMPLATE_PRODUCT_TEST_CASE_METHOD(Template_Fixture_2, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD based test run that succeeds","[class][template][product]",(std::vector,Template_Foo),(int,float))
+{
+    REQUIRE( Template_Fixture_2<TestType>::m_a.size() == 0 );
+}
+
 // We should be able to write our tests within a different namespace
 namespace Inner
 {
@@ -74,6 +91,11 @@ namespace Inner
     {
         REQUIRE( Template_Fixture<TestType>::m_a == 2 );
     }
+
+    TEMPLATE_PRODUCT_TEST_CASE_METHOD(Template_Fixture_2, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD based test run that fails","[.][class][template][product][failing]",(std::vector,Template_Foo),(int,float))
+    {
+        REQUIRE( Template_Fixture_2<TestType>::m_a.size() == 1 );
+    }
 }
 
 
diff --git a/projects/SelfTest/UsageTests/Misc.tests.cpp b/projects/SelfTest/UsageTests/Misc.tests.cpp
--- a/projects/SelfTest/UsageTests/Misc.tests.cpp
+++ b/projects/SelfTest/UsageTests/Misc.tests.cpp
@@ -61,6 +61,11 @@ CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS
 static AutoTestReg autoTestReg;
 CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS
 
+template<typename T>
+struct Foo {
+    size_t size() { return 0; }
+};
+
 #endif
 
 TEST_CASE( "random SECTION tests", "[.][sections][failing]" ) {
@@ -301,6 +306,15 @@ TEMPLATE_TEST_CASE( "TemplateTest: vectors can be sized and resized", "[vector][
     }
 }
 
+TEMPLATE_PRODUCT_TEST_CASE("A Template product test case", "[template][product]", (std::vector, Foo), (int, float)) {
+    TestType x;
+    REQUIRE(x.size() == 0);
+}
+
+TEMPLATE_PRODUCT_TEST_CASE("Product with differing arities", "[template][product]", std::tuple, (int, (int, double), (int, double, float))) {
+    REQUIRE(std::tuple_size<TestType>::value >= 1);
+}
+
 // https://github.com/philsquared/Catch/issues/166
 TEST_CASE("A couple of nested sections followed by a failure", "[failing][.]") {
     SECTION("Outer")
EOF_114329324912

# --- Pre-build Step ---
# Execute the single header generation script required by Catch2's build process.
python3 scripts/generateSingleHeader.py

# --- Build Steps ---
# Create a dedicated build directory to perform an out-of-source build.
mkdir Build-Debug
# Change into the build directory. All subsequent build commands will be executed here.
cd Build-Debug

# Configure CMake for a Debug build with specific C++ standard support and test options.
cmake .. \
    -DCMAKE_BUILD_TYPE=Debug \
    -DUSE_CPP14=ON \
    -DUSE_CPP17=ON \
    -DCATCH_BUILD_EXTRA_TESTS=ON \
    -DCATCH_ENABLE_WERROR=ON \
    -DCATCH_BUILD_TESTING=ON

# Compile the project using all available CPU cores for speed.
make -j "$(nproc)"

# --- Test Execution ---
# Current directory is 'Build-Debug'.
# Run the CTest suite.
# As per the collected information, CTest automatically discovers and runs the compiled
# test executables (including those from Class.tests.cpp and Misc.tests.cpp).
# CTEST_OUTPUT_ON_FAILURE=1 ensures detailed output in case of test failures.
CTEST_OUTPUT_ON_FAILURE=1 ctest -j "$(nproc)"
rc=$? # Capture the exit code of the test command immediately after execution.

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific files again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout 4902cd721586822ded795afe0c418c553137306a "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"