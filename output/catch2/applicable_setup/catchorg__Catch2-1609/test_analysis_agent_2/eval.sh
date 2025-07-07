#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory.
# The Dockerfile sets /testbed/build as WORKDIR initially, so we need to go up one level.
cd /testbed

# Checkout the specific test files to their original state at the commit SHA.
# This ensures a clean state before applying any potential patches.
git checkout bd703dd74be7fd2413eb0c01662a491bcebea430 "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/docs/test-cases-and-sections.md b/docs/test-cases-and-sections.md
--- a/docs/test-cases-and-sections.md
+++ b/docs/test-cases-and-sections.md
@@ -6,6 +6,7 @@
 [Tag aliases](#tag-aliases)<br>
 [BDD-style test cases](#bdd-style-test-cases)<br>
 [Type parametrised test cases](#type-parametrised-test-cases)<br>
+[Signature based parametrised test cases](#signature-based-parametrised-test-cases)<br>
 
 While Catch fully supports the traditional, xUnit, style of class-based fixtures containing test case methods this is not the preferred style.
 
@@ -191,6 +192,56 @@ _While there is an upper limit on the number of types you can specify
 in single `TEMPLATE_TEST_CASE` or `TEMPLATE_PRODUCT_TEST_CASE`, the limit
 is very high and should not be encountered in practice._
 
+
+## Signature based parametrised test cases
+
+In addition to [type parametrised test cases](#type-parametrised-test-cases) Catch2 also supports
+signature base parametrised test cases, in form of `TEMPLATE_TEST_CASE_SIG` and `TEMPLATE_PRODUCT_TEST_CASE_SIG`.
+These test cases have similar syntax like [type parametrised test cases](#type-parametrised-test-cases), with one
+additional positional argument which specifies the signature.
+
+### Signature
+Signature has some strict rules for these tests cases to work properly:
+* signature with multiple template parameters e.g. `typename T, size_t S` must have this format in test case declaration
+  `((typename T, size_t S), T, S)`
+* signature with variadic template arguments e.g. `typename T, size_t S, typename...Ts` must have this format in test case declaration
+  `((typename T, size_t S, typename...Ts), T, S, Ts...)`
+* signature with single non type template parameter e.g. `int V` must have this format in test case declaration `((int V), V)`
+* signature with single type template parameter e.g. `typename T` should not be used as it is in fact `TEMPLATE_TEST_CASE`
+
+Currently Catch2 support up to 11 template parameters in signature
+
+### Examples
+
+* **TEMPLATE_TEST_CASE_SIG(** _test name_ , _tags_,  _signature_, _type1_, _type2_, ..., _typen_ **)**
+
+Inside `TEMPLATE_TEST_CASE_SIG` test case you can use the names of template parameters as defined in _signature_. 
+
+```cpp
+TEMPLATE_TEST_CASE_SIG("TemplateTestSig: arrays can be created from NTTP arguments", "[vector][template][nttp]",
+  ((typename T, int V), T, V), (int,5), (float,4), (std::string,15), ((std::tuple<int, float>), 6)) {
+
+    std::array<T, V> v;
+    REQUIRE(v.size() > 1);
+}
+```
+
+* **TEMPLATE_PRODUCT_TEST_CASE_SIG(** _test name_ , _tags_, _signature_, (_template-type1_, _template-type2_, ..., _template-typen_), (_template-arg1_, _template-arg2_, ..., _template-argm_) **)**
+
+```cpp
+
+template<typename T, size_t S>
+struct Bar {
+    size_t size() { return S; }
+};
+
+TEMPLATE_PRODUCT_TEST_CASE_SIG("A Template product test case with array signature", "[template][product][nttp]", ((typename T, size_t S), T, S), (std::array, Bar), ((int, 9), (float, 42))) {
+    TestType x;
+    REQUIRE(x.size() > 0);
+}
+```
+
+
 ---
 
 [Home](Readme.md#top)
diff --git a/docs/test-fixtures.md b/docs/test-fixtures.md
--- a/docs/test-fixtures.md
+++ b/docs/test-fixtures.md
@@ -84,6 +84,33 @@ _While there is an upper limit on the number of types you can specify
 in single `TEMPLATE_TEST_CASE_METHOD` or `TEMPLATE_PRODUCT_TEST_CASE_METHOD`,
 the limit is very high and should not be encountered in practice._
 
+
+Catch2 also provides `TEMPLATE_TEST_CASE_METHOD_SIG` and `TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG` to support
+fixtures using non-type template parameters. These test cases work similar to `TEMPLATE_TEST_CASE_METHOD` and `TEMPLATE_PRODUCT_TEST_CASE_METHOD`,
+with additional positional argument for [signature](test-cases-and-sections.md#signature-based-parametrised-test-cases).
+
+Example:
+```cpp
+template <int V>
+struct Nttp_Fixture{
+    int value = V;
+};
+
+TEMPLATE_TEST_CASE_METHOD_SIG(Nttp_Fixture, "A TEMPLATE_TEST_CASE_METHOD_SIG based test run that succeeds", "[class][template][nttp]",((int V), V), 1, 3, 6) {
+    REQUIRE(Nttp_Fixture<V>::value > 0);
+}
+
+template< typename T, size_t V>
+struct Template_Foo_2 {
+    size_t size() { return V; }
+};
+
+TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG(Template_Fixture_2, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG based test run that succeeds", "[class][template][product][nttp]", ((typename T, size_t S), T, S),(std::array, Template_Foo_2), ((int,2), (float,6)))
+{
+    REQUIRE(Template_Fixture_2<TestType>{}.m_a.size() >= 2);
+}
+```
+
 ---
 
 [Home](Readme.md#top)
diff --git a/include/internal/catch_test_registry.h b/include/internal/catch_test_registry.h
--- a/include/internal/catch_test_registry.h
+++ b/include/internal/catch_test_registry.h
@@ -60,18 +60,47 @@ struct AutoReg : NonCopyable {
             };                            \
         }                                 \
         void TestName::test()
-    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION( TestName, ... )  \
-        template<typename TestType>                                             \
-        static void TestName()
-    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION( TestName, ClassName, ... )    \
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION_2( TestName, TestFunc, Name, Tags, Signature, ... )  \
+        INTERNAL_CATCH_DEFINE_SIG_TEST(TestFunc, INTERNAL_CATCH_REMOVE_PARENS(Signature))
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION_2( TestNameClass, TestName, ClassName, Name, Tags, Signature, ... )    \
         namespace{                                                                                  \
-            template<typename TestType>                                                             \
-            struct TestName : INTERNAL_CATCH_REMOVE_PARENS(ClassName <TestType>) {     \
-                void test();                                                                        \
-            };                                                                                      \
+            namespace INTERNAL_CATCH_MAKE_NAMESPACE(TestName) {                                      \
+            INTERNAL_CATCH_DECLARE_SIG_TEST_METHOD(TestName, ClassName, INTERNAL_CATCH_REMOVE_PARENS(Signature));\
         }                                                                                           \
-        template<typename TestType>                                                                 \
-        void TestName::test()
+        }                                                                                           \
+        INTERNAL_CATCH_DEFINE_SIG_TEST_METHOD(TestName, INTERNAL_CATCH_REMOVE_PARENS(Signature))
+
+    #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION(Name, Tags, ...) \
+            INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, typename TestType, __VA_ARGS__ )
+    #else
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION(Name, Tags, ...) \
+            INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, typename TestType, __VA_ARGS__ ) )
+    #endif  
+
+    #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_SIG_NO_REGISTRATION(Name, Tags, Signature, ...) \
+            INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, Signature, __VA_ARGS__ )
+    #else
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_SIG_NO_REGISTRATION(Name, Tags, Signature, ...) \
+            INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, Signature, __VA_ARGS__ ) )
+    #endif
+
+    #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION( ClassName, Name, Tags,... ) \
+            INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, typename T, __VA_ARGS__ )
+    #else
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION( ClassName, Name, Tags,... ) \
+            INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, typename T, __VA_ARGS__ ) )
+    #endif
+
+    #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_SIG_NO_REGISTRATION( ClassName, Name, Tags, Signature, ... ) \
+            INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, Signature, __VA_ARGS__ )
+    #else
+        #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_SIG_NO_REGISTRATION( ClassName, Name, Tags, Signature, ... ) \
+            INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_NO_REGISTRATION_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, Signature, __VA_ARGS__ ) )
+    #endif
 #endif
 
     ///////////////////////////////////////////////////////////////////////////////
@@ -111,46 +140,61 @@ struct AutoReg : NonCopyable {
         CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS
 
     ///////////////////////////////////////////////////////////////////////////////
-    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_2(TestName, TestFunc, Name, Tags, ... )\
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_2(TestName, TestFunc, Name, Tags, Signature, ... )\
         CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS \
-        template<typename TestType> \
-        static void TestFunc();\
+        CATCH_INTERNAL_SUPPRESS_ZERO_VARIADIC_WARNINGS \
+        INTERNAL_CATCH_DECLARE_SIG_TEST(TestFunc, INTERNAL_CATCH_REMOVE_PARENS(Signature));\
         namespace {\
+        namespace INTERNAL_CATCH_MAKE_NAMESPACE(TestName){\
+            INTERNAL_CATCH_TYPE_GEN\
+            INTERNAL_CATCH_NTTP_GEN(INTERNAL_CATCH_REMOVE_PARENS(Signature))\
+            INTERNAL_CATCH_NTTP_REG_GEN(TestFunc,INTERNAL_CATCH_REMOVE_PARENS(Signature))\
             template<typename...Types> \
             struct TestName{\
-                template<typename...Ts> \
-                TestName(Ts...names){\
+                TestName(){\
+                    int index = 0;                                    \
+                    constexpr char const* tmpl_types[] = {CATCH_REC_LIST(INTERNAL_CATCH_STRINGIZE_WITHOUT_PARENS, __VA_ARGS__)};\
                     using expander = int[];\
-                    (void)expander{(Catch::AutoReg( Catch::makeTestInvoker( &TestFunc<Types> ), CATCH_INTERNAL_LINEINFO, Catch::StringRef(), Catch::NameAndTags{ names, Tags } ), 0)... };/* NOLINT */ \
+                    (void)expander{(reg_test(Types{}, Catch::NameAndTags{ Name " - " + std::string(tmpl_types[index]), Tags } ), index++, 0)... };/* NOLINT */ \
                 }\
             };\
-            INTERNAL_CATCH_TEMPLATE_REGISTRY_INITIATE(TestName, Name, __VA_ARGS__) \
+            static int INTERNAL_CATCH_UNIQUE_NAME( globalRegistrar ) = [](){\
+            TestName<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(__VA_ARGS__)>();\
+            return 0;\
+        }();\
+        }\
         }\
         CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS \
-        template<typename TestType> \
-        static void TestFunc()
+        CATCH_INTERNAL_UNSUPPRESS_ZERO_VARIADIC_WARNINGS \
+        INTERNAL_CATCH_DEFINE_SIG_TEST(TestFunc,INTERNAL_CATCH_REMOVE_PARENS(Signature))
 
 #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
     #define INTERNAL_CATCH_TEMPLATE_TEST_CASE(Name, Tags, ...) \
-        INTERNAL_CATCH_TEMPLATE_TEST_CASE_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, __VA_ARGS__ )
+        INTERNAL_CATCH_TEMPLATE_TEST_CASE_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, typename TestType, __VA_ARGS__ )
 #else
     #define INTERNAL_CATCH_TEMPLATE_TEST_CASE(Name, Tags, ...) \
-        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, __VA_ARGS__ ) )
-#endif
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, typename TestType, __VA_ARGS__ ) )
+#endif  
 
-    #define INTERNAL_CATCH_TEMPLATE_REGISTRY_INITIATE(TestName, Name, ...)\
-        static int INTERNAL_CATCH_UNIQUE_NAME( globalRegistrar ) = [](){\
-            TestName<CATCH_REC_LIST(INTERNAL_CATCH_REMOVE_PARENS, __VA_ARGS__)>(CATCH_REC_LIST_UD(INTERNAL_CATCH_TEMPLATE_UNIQUE_NAME,Name, __VA_ARGS__));\
-            return 0;\
-        }();
+#ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_SIG(Name, Tags, Signature, ...) \
+        INTERNAL_CATCH_TEMPLATE_TEST_CASE_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, Signature, __VA_ARGS__ )
+#else
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_SIG(Name, Tags, Signature, ...) \
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, Signature, __VA_ARGS__ ) )
+#endif
 
-    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2(TestName, TestFuncName, Name, Tags, TmplTypes, TypesList) \
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2(TestName, TestFuncName, Name, Tags, Signature, TmplTypes, TypesList) \
         CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS                      \
+        CATCH_INTERNAL_SUPPRESS_ZERO_VARIADIC_WARNINGS                \
         template<typename TestType> static void TestFuncName();       \
-        namespace {                                                   \
+        namespace {\
+        namespace INTERNAL_CATCH_MAKE_NAMESPACE(TestName) {                                     \
+            INTERNAL_CATCH_TYPE_GEN                                                  \
+            INTERNAL_CATCH_NTTP_GEN(INTERNAL_CATCH_REMOVE_PARENS(Signature))         \
             template<typename... Types>                               \
             struct TestName {                                         \
-                TestName() {                                          \
+                void reg_tests() {                                          \
                     int index = 0;                                    \
                     using expander = int[];                           \
                     constexpr char const* tmpl_types[] = {CATCH_REC_LIST(INTERNAL_CATCH_STRINGIZE_WITHOUT_PARENS, INTERNAL_CATCH_REMOVE_PARENS(TmplTypes))};\
@@ -160,63 +204,92 @@ struct AutoReg : NonCopyable {
                 }                                                     \
             };                                                        \
             static int INTERNAL_CATCH_UNIQUE_NAME( globalRegistrar ) = [](){ \
-                using TestInit = Catch::combine<INTERNAL_CATCH_REMOVE_PARENS(TmplTypes)> \
-                            ::with_types<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(TypesList)>::into<TestName>::type; \
-                TestInit();                                           \
+                using TestInit = decltype(create<TestName, INTERNAL_CATCH_REMOVE_PARENS(TmplTypes)>(TypeList<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(INTERNAL_CATCH_REMOVE_PARENS(TypesList))>{})); \
+                TestInit t;                                           \
+                t.reg_tests();                                        \
                 return 0;                                             \
             }();                                                      \
         }                                                             \
+        }                                                             \
         CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS                    \
+        CATCH_INTERNAL_UNSUPPRESS_ZERO_VARIADIC_WARNINGS              \
         template<typename TestType>                                   \
         static void TestFuncName()
 
 #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
     #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE(Name, Tags, ...)\
-        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2(INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ),Name,Tags,__VA_ARGS__)
+        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2(INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, typename T,__VA_ARGS__)
 #else
     #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE(Name, Tags, ...)\
-        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, __VA_ARGS__ ) )
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, typename T, __VA_ARGS__ ) )
+#endif
+
+#ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_SIG(Name, Tags, Signature, ...)\
+        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2(INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, Signature, __VA_ARGS__)
+#else
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_SIG(Name, Tags, Signature, ...)\
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), Name, Tags, Signature, __VA_ARGS__ ) )
 #endif
 
-    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( TestNameClass, TestName, ClassName, Name, Tags, ... ) \
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( TestNameClass, TestName, ClassName, Name, Tags, Signature, ... ) \
         CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS \
-        namespace{ \
-            template<typename TestType> \
-            struct TestName : INTERNAL_CATCH_REMOVE_PARENS(ClassName <TestType>) { \
-                void test();\
-            };\
+        CATCH_INTERNAL_SUPPRESS_ZERO_VARIADIC_WARNINGS \
+        namespace {\
+        namespace INTERNAL_CATCH_MAKE_NAMESPACE(TestName){ \
+            INTERNAL_CATCH_TYPE_GEN\
+            INTERNAL_CATCH_NTTP_GEN(INTERNAL_CATCH_REMOVE_PARENS(Signature))\
+            INTERNAL_CATCH_DECLARE_SIG_TEST_METHOD(TestName, ClassName, INTERNAL_CATCH_REMOVE_PARENS(Signature));\
+            INTERNAL_CATCH_NTTP_REG_METHOD_GEN(TestName, INTERNAL_CATCH_REMOVE_PARENS(Signature))\
             template<typename...Types> \
             struct TestNameClass{\
-                template<typename...Ts> \
-                TestNameClass(Ts...names){\
+                TestNameClass(){\
+                    int index = 0;                                    \
+                    constexpr char const* tmpl_types[] = {CATCH_REC_LIST(INTERNAL_CATCH_STRINGIZE_WITHOUT_PARENS, __VA_ARGS__)};\
                     using expander = int[];\
-                    (void)expander{(Catch::AutoReg( Catch::makeTestInvoker( &TestName<Types>::test ), CATCH_INTERNAL_LINEINFO, #ClassName, Catch::NameAndTags{ names, Tags } ), 0)... };/* NOLINT */ \
+                    (void)expander{(reg_test(Types{}, #ClassName, Catch::NameAndTags{ Name " - " + std::string(tmpl_types[index]), Tags } ), index++, 0)... };/* NOLINT */ \
                 }\
             };\
-            INTERNAL_CATCH_TEMPLATE_REGISTRY_INITIATE(TestNameClass, Name, __VA_ARGS__)\
+            static int INTERNAL_CATCH_UNIQUE_NAME( globalRegistrar ) = [](){\
+                TestNameClass<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(__VA_ARGS__)>();\
+                return 0;\
+        }();\
+        }\
         }\
         CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS\
-        template<typename TestType> \
-        void TestName<TestType>::test()
+        CATCH_INTERNAL_UNSUPPRESS_ZERO_VARIADIC_WARNINGS\
+        INTERNAL_CATCH_DEFINE_SIG_TEST_METHOD(TestName, INTERNAL_CATCH_REMOVE_PARENS(Signature))
 
 #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
     #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD( ClassName, Name, Tags,... ) \
-        INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, __VA_ARGS__ )
+        INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, typename T, __VA_ARGS__ )
 #else
     #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD( ClassName, Name, Tags,... ) \
-        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, __VA_ARGS__ ) )
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, typename T, __VA_ARGS__ ) )
 #endif
 
-    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2(TestNameClass, TestName, ClassName, Name, Tags, TmplTypes, TypesList)\
+#ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_SIG( ClassName, Name, Tags, Signature, ... ) \
+        INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, Signature, __VA_ARGS__ )
+#else
+    #define INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_SIG( ClassName, Name, Tags, Signature, ... ) \
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____C_L_A_S_S____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ) , ClassName, Name, Tags, Signature, __VA_ARGS__ ) )
+#endif
+
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2(TestNameClass, TestName, ClassName, Name, Tags, Signature, TmplTypes, TypesList)\
         CATCH_INTERNAL_SUPPRESS_GLOBALS_WARNINGS \
+        CATCH_INTERNAL_SUPPRESS_ZERO_VARIADIC_WARNINGS \
         template<typename TestType> \
             struct TestName : INTERNAL_CATCH_REMOVE_PARENS(ClassName <TestType>) { \
                 void test();\
             };\
         namespace {\
+        namespace INTERNAL_CATCH_MAKE_NAMESPACE(TestNameClass) {\
+            INTERNAL_CATCH_TYPE_GEN                  \
+            INTERNAL_CATCH_NTTP_GEN(INTERNAL_CATCH_REMOVE_PARENS(Signature))\
             template<typename...Types>\
             struct TestNameClass{\
-                TestNameClass(){\
+                void reg_tests(){\
                     int index = 0;\
                     using expander = int[];\
                     constexpr char const* tmpl_types[] = {CATCH_REC_LIST(INTERNAL_CATCH_STRINGIZE_WITHOUT_PARENS, INTERNAL_CATCH_REMOVE_PARENS(TmplTypes))};\
@@ -226,22 +299,33 @@ struct AutoReg : NonCopyable {
                 }\
             };\
             static int INTERNAL_CATCH_UNIQUE_NAME( globalRegistrar ) = [](){\
-                using TestInit = Catch::combine<INTERNAL_CATCH_REMOVE_PARENS(TmplTypes)>\
-                            ::with_types<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(TypesList)>::into<TestNameClass>::type;\
-                TestInit();\
+                using TestInit = decltype(create<TestNameClass, INTERNAL_CATCH_REMOVE_PARENS(TmplTypes)>(TypeList<INTERNAL_CATCH_MAKE_TYPE_LISTS_FROM_TYPES(INTERNAL_CATCH_REMOVE_PARENS(TypesList))>{}));\
+                TestInit t;\
+                t.reg_tests();\
                 return 0;\
             }(); \
         }\
+        }\
         CATCH_INTERNAL_UNSUPPRESS_GLOBALS_WARNINGS \
+        CATCH_INTERNAL_UNSUPPRESS_ZERO_VARIADIC_WARNINGS \
         template<typename TestType> \
         void TestName<TestType>::test()
 
 #ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
     #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD( ClassName, Name, Tags, ... )\
-        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, __VA_ARGS__ )
+        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, typename T, __VA_ARGS__ )
 #else
     #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD( ClassName, Name, Tags, ... )\
-        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, __VA_ARGS__ ) )
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, typename T,__VA_ARGS__ ) )
 #endif
 
+#ifndef CATCH_CONFIG_TRADITIONAL_MSVC_PREPROCESSOR
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG( ClassName, Name, Tags, Signature, ... )\
+        INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, Signature, __VA_ARGS__ )
+#else
+    #define INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG( ClassName, Name, Tags, Signature, ... )\
+        INTERNAL_CATCH_EXPAND_VARGS( INTERNAL_CATCH_TEMPLATE_PRODUCT_TEST_CASE_METHOD_2( INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____ ), INTERNAL_CATCH_UNIQUE_NAME( ____C_A_T_C_H____T_E_M_P_L_A_T_E____T_E_S_T____F_U_N_C____ ), ClassName, Name, Tags, Signature,__VA_ARGS__ ) )
+#endif
+
+
 #endif // TWOBLUECUBES_CATCH_TEST_REGISTRY_HPP_INCLUDED
diff --git a/projects/SelfTest/UsageTests/Class.tests.cpp b/projects/SelfTest/UsageTests/Class.tests.cpp
--- a/projects/SelfTest/UsageTests/Class.tests.cpp
+++ b/projects/SelfTest/UsageTests/Class.tests.cpp
@@ -7,6 +7,7 @@
  */
 
 #include "catch.hpp"
+#include <array>
 
 namespace{ namespace ClassTests {
 
@@ -58,6 +59,15 @@ struct Template_Foo {
     size_t size() { return 0; }
 };
 
+template< typename T, size_t V>
+struct Template_Foo_2 {
+    size_t size() { return V; }
+};
+
+template <int V>
+struct Nttp_Fixture{
+    int value = V;
+};
 #endif
 
 
@@ -74,11 +84,20 @@ TEMPLATE_TEST_CASE_METHOD(Template_Fixture, "A TEMPLATE_TEST_CASE_METHOD based t
     REQUIRE( Template_Fixture<TestType>::m_a == 1 );
 }
 
+TEMPLATE_TEST_CASE_METHOD_SIG(Nttp_Fixture, "A TEMPLATE_TEST_CASE_METHOD_SIG based test run that succeeds", "[class][template][nttp]",((int V), V), 1, 3, 6) {
+    REQUIRE(Nttp_Fixture<V>::value > 0);
+}
+
 TEMPLATE_PRODUCT_TEST_CASE_METHOD(Template_Fixture_2, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD based test run that succeeds","[class][template][product]",(std::vector,Template_Foo),(int,float))
 {
     REQUIRE( Template_Fixture_2<TestType>::m_a.size() == 0 );
 }
 
+TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG(Template_Fixture_2, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG based test run that succeeds", "[class][template][product][nttp]", ((typename T, size_t S), T, S),(std::array, Template_Foo_2), ((int,2), (float,6)))
+{
+    REQUIRE(Template_Fixture_2<TestType>{}.m_a.size() >= 2);
+}
+
 // We should be able to write our tests within a different namespace
 namespace Inner
 {
@@ -92,10 +111,19 @@ namespace Inner
         REQUIRE( Template_Fixture<TestType>::m_a == 2 );
     }
 
+    TEMPLATE_TEST_CASE_METHOD_SIG(Nttp_Fixture, "A TEMPLATE_TEST_CASE_METHOD_SIG based test run that fails", "[.][class][template][nttp][failing]", ((int V), V), 1, 3, 6) {
+        REQUIRE(Nttp_Fixture<V>::value == 0);
+    }
+
     TEMPLATE_PRODUCT_TEST_CASE_METHOD(Template_Fixture_2, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD based test run that fails","[.][class][template][product][failing]",(std::vector,Template_Foo),(int,float))
     {
         REQUIRE( Template_Fixture_2<TestType>::m_a.size() == 1 );
     }
+
+    TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG(Template_Fixture_2, "A TEMPLATE_PRODUCT_TEST_CASE_METHOD_SIG based test run that fails", "[.][class][template][product][nttp][failing]", ((typename T, size_t S), T, S), (std::array, Template_Foo_2), ((int, 2), (float, 6)))
+    {
+        REQUIRE(Template_Fixture_2<TestType>{}.m_a.size() < 2);
+    }
 }
 
 
diff --git a/projects/SelfTest/UsageTests/Misc.tests.cpp b/projects/SelfTest/UsageTests/Misc.tests.cpp
--- a/projects/SelfTest/UsageTests/Misc.tests.cpp
+++ b/projects/SelfTest/UsageTests/Misc.tests.cpp
@@ -18,6 +18,7 @@
 #include <cerrno>
 #include <limits>
 #include <sstream>
+#include <array>
 
 namespace { namespace MiscTests {
 
@@ -66,6 +67,10 @@ struct Foo {
     size_t size() { return 0; }
 };
 
+template<typename T, size_t S>
+struct Bar {
+    size_t size() { return S; }
+};
 #endif
 
 TEST_CASE( "random SECTION tests", "[.][sections][failing]" ) {
@@ -306,11 +311,56 @@ TEMPLATE_TEST_CASE( "TemplateTest: vectors can be sized and resized", "[vector][
     }
 }
 
+TEMPLATE_TEST_CASE_SIG("TemplateTestSig: vectors can be sized and resized", "[vector][template][nttp]", ((typename TestType, int V), TestType, V), (int,5), (float,4), (std::string,15), ((std::tuple<int, float>), 6)) {
+
+    std::vector<TestType> v(V);
+
+    REQUIRE(v.size() == V);
+    REQUIRE(v.capacity() >= V);
+
+    SECTION("resizing bigger changes size and capacity") {
+        v.resize(2 * V);
+
+        REQUIRE(v.size() == 2 * V);
+        REQUIRE(v.capacity() >= 2 * V);
+    }
+    SECTION("resizing smaller changes size but not capacity") {
+        v.resize(0);
+
+        REQUIRE(v.size() == 0);
+        REQUIRE(v.capacity() >= V);
+
+        SECTION("We can use the 'swap trick' to reset the capacity") {
+            std::vector<TestType> empty;
+            empty.swap(v);
+
+            REQUIRE(v.capacity() == 0);
+        }
+    }
+    SECTION("reserving bigger changes capacity but not size") {
+        v.reserve(2 * V);
+
+        REQUIRE(v.size() == V);
+        REQUIRE(v.capacity() >= 2 * V);
+    }
+    SECTION("reserving smaller does not change size or capacity") {
+        v.reserve(0);
+
+        REQUIRE(v.size() == V);
+        REQUIRE(v.capacity() >= V);
+    }
+}
+
 TEMPLATE_PRODUCT_TEST_CASE("A Template product test case", "[template][product]", (std::vector, Foo), (int, float)) {
     TestType x;
     REQUIRE(x.size() == 0);
 }
 
+TEMPLATE_PRODUCT_TEST_CASE_SIG("A Template product test case with array signature", "[template][product][nttp]", ((typename T, size_t S), T, S), (std::array, Bar), ((int, 9), (float, 42))) {
+    TestType x;
+    REQUIRE(x.size() > 0);
+}
+
 TEMPLATE_PRODUCT_TEST_CASE("Product with differing arities", "[template][product]", std::tuple, (int, (int, double), (int, double, float))) {
     REQUIRE(std::tuple_size<TestType>::value >= 1);
 }
EOF_114329324912

# Navigate to the build directory where the Catch2 'SelfTest' executable is located.
# The Dockerfile ensures this directory exists and the project is built.
cd build

# Execute the specific test cases from Class.tests.cpp and Misc.tests.cpp using the Catch2 SelfTest executable.
# Tests from Class.tests.cpp are typically tagged with [class] or [classification].
# Tests from Misc.tests.cpp are typically tagged with [misc].
# We combine these tags to run only the relevant tests efficiently.
# The --success flag ensures a non-zero exit code upon test failure, which is critical for automation.
./projects/SelfTest "[class],[classification],[misc]" --success
rc=$? # Capture the exit code of the test command

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific test files again to revert any changes made by the patch.
# This ensures that the file system is clean after the test run.
git checkout bd703dd74be7fd2413eb0c01662a491bcebea430 "docs/test-cases-and-sections.md" "docs/test-fixtures.md" "include/internal/catch_test_registry.h" "projects/SelfTest/UsageTests/Class.tests.cpp" "projects/SelfTest/UsageTests/Misc.tests.cpp"