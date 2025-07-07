#!/bin/bash
set -uxo pipefail

# Ensure we are in the /testbed directory
cd /testbed

# Reset target files to their original state before applying the patch (if any changes were made previously)
git checkout 01ef7076f50f5f2b481ddf082e1afca3c926983f "include/internal/catch_test_spec.cpp" "include/internal/catch_test_spec.h" "include/internal/catch_test_spec_parser.cpp" "include/internal/catch_test_spec_parser.h"

# Apply the test patch to update target tests if provided
git apply -v - <<'EOF_114329324912'
diff --git a/include/internal/catch_test_spec.cpp b/include/internal/catch_test_spec.cpp
--- a/include/internal/catch_test_spec.cpp
+++ b/include/internal/catch_test_spec.cpp
@@ -91,5 +91,9 @@ namespace Catch {
         } );
         return matches;
     }
+    
+    const TestSpec::vectorStrings& TestSpec::getInvalidArgs() const{
+        return  (m_invalidArgs);
+    }
 
 }
diff --git a/include/internal/catch_test_spec.h b/include/internal/catch_test_spec.h
--- a/include/internal/catch_test_spec.h
+++ b/include/internal/catch_test_spec.h
@@ -73,14 +73,16 @@ namespace Catch {
             std::vector<TestCase const*> tests;
         };
         using Matches = std::vector<FilterMatch>;
+        using vectorStrings = std::vector<std::string>;
 
         bool hasFilters() const;
         bool matches( TestCaseInfo const& testCase ) const;
         Matches matchesByFilter( std::vector<TestCase> const& testCases, IConfig const& config ) const;
+        const vectorStrings & getInvalidArgs() const;
 
     private:
         std::vector<Filter> m_filters;
-
+        std::vector<std::string> m_invalidArgs;
         friend class TestSpecParser;
     };
 }
diff --git a/include/internal/catch_test_spec_parser.cpp b/include/internal/catch_test_spec_parser.cpp
--- a/include/internal/catch_test_spec_parser.cpp
+++ b/include/internal/catch_test_spec_parser.cpp
@@ -20,8 +20,13 @@ namespace Catch {
         m_substring.reserve(m_arg.size());
         m_patternName.reserve(m_arg.size());
         m_realPatternPos = 0;
+        
         for( m_pos = 0; m_pos < m_arg.size(); ++m_pos )
-            visitChar( m_arg[m_pos] );
+          //if visitChar fails
+           if( !visitChar( m_arg[m_pos] ) ){ 
+               m_testSpec.m_invalidArgs.push_back(arg);
+               break;
+           }
         endMode();
         return *this;
     }
@@ -29,38 +34,32 @@ namespace Catch {
         addFilter();
         return m_testSpec;
     }
-    void TestSpecParser::visitChar( char c ) {
+    bool TestSpecParser::visitChar( char c ) {
         if( (m_mode != EscapedName) && (c == '\\') ) {
             escape();
-            m_substring += c;
-            m_patternName += c;
-            m_realPatternPos++;
-            return;
+            addCharToPattern(c);
+            return true;
         }else if((m_mode != EscapedName) && (c == ',') )  {
-            endMode();
-            addFilter();
-            return;
+            return separate();
         }
 
         switch( m_mode ) {
         case None:
             if( processNoneChar( c ) )
-                return;
+                return true;
             break;
         case Name:
             processNameChar( c );
             break;
         case EscapedName:
             endMode();
-            m_substring += c;
-            m_patternName += c;
-            m_realPatternPos++;
-            return;
+            addCharToPattern(c);
+            return true;
         default:
         case Tag:
         case QuotedName:
             if( processOtherChar( c ) )
-                return;
+                return true;
             break;
         }
 
@@ -69,6 +68,7 @@ namespace Catch {
             m_patternName += c;
             m_realPatternPos++;
         }
+        return true;
     }
     // Two of the processing methods return true to signal the caller to return
     // without adding the given character to the current pattern strings
@@ -161,6 +161,20 @@ namespace Catch {
       m_mode = lastMode;
     }
     
+    bool TestSpecParser::separate() {  
+      if( (m_mode==QuotedName) || (m_mode==Tag) ){
+         //invalid argument, signal failure to previous scope.
+         m_mode = None;
+         m_pos = m_arg.size();
+         m_substring.clear();
+         m_patternName.clear();
+         return false;
+      }
+      endMode();
+      addFilter();
+      return true; //success
+    }
+    
     TestSpec parseTestSpec( std::string const& arg ) {
         return TestSpecParser( ITagAliasRegistry::get() ).parse( arg ).testSpec();
     }
diff --git a/include/internal/catch_test_spec_parser.h b/include/internal/catch_test_spec_parser.h
--- a/include/internal/catch_test_spec_parser.h
+++ b/include/internal/catch_test_spec_parser.h
@@ -41,7 +41,7 @@ namespace Catch {
         TestSpec testSpec();
 
     private:
-        void visitChar( char c );
+        bool visitChar( char c );
         void startNewMode( Mode mode );
         bool processNoneChar( char c );
         void processNameChar( char c );
@@ -51,6 +51,8 @@ namespace Catch {
         bool isControlChar( char c ) const;
         void saveLastMode();
         void revertBackToLastMode();
+        void addFilter();
+        bool separate();
         
         template<typename T>
         void addPattern() {
@@ -73,8 +75,13 @@ namespace Catch {
             m_exclusion = false;
             m_mode = None;
         }
-
-        void addFilter();
+        
+        inline void addCharToPattern(char c) {
+            m_substring += c;
+            m_patternName += c;
+            m_realPatternPos++;
+        }
+        
     };
     TestSpec parseTestSpec( std::string const& arg );
 
EOF_114329324912

# Step 1: Run the project-specific pre-build script to generate single header
echo "Running generateSingleHeader.py..."
python3 scripts/generateSingleHeader.py || { echo "generateSingleHeader.py failed."; exit 1; }

# Step 2: Create a separate build directory and navigate into it
echo "Creating and entering build directory..."
mkdir -p Build-Debug
cd Build-Debug

# Step 3: Configure CMake with required flags
echo "Configuring CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCATCH_BUILD_EXAMPLES=ON \
    -DCATCH_BUILD_EXTRA_TESTS=ON \
    -DCMAKE_CXX_STANDARD=11 \
    -DCMAKE_CXX_STANDARD_REQUIRED=On \
    -DCMAKE_CXX_EXTENSIONS=OFF || { echo "CMake configuration failed."; exit 1; }

# Step 4: Compile the project
echo "Compiling project with make..."
# FIX: Changed -j$(nproc) to -j1 to address OOM issue during compilation.
make -j1 || { echo "Compilation failed."; exit 1; }

# Step 5: Execute tests using CTest
# The collected information states that the target files are source files
# and ctest will execute the compiled test executables (like SelfTest) which include
# these source file's tests internally.
echo "Running CTest tests..."
CTEST_OUTPUT_ON_FAILURE=1 ctest -j$(nproc)
rc=$? # Capture the exit code of the ctest command

# Output the captured exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed directory for cleanup
cd /testbed

# Clean up: Reset the modified files to their original state
git checkout 01ef7076f50f5f2b481ddf082e1afca3c926983f "include/internal/catch_test_spec.cpp" "include/internal/catch_test_spec.h" "include/internal/catch_test_spec_parser.cpp" "include/internal/catch_test_spec_parser.h"

# Remove the build directory to ensure a clean state for future runs
rm -rf Build-Debug

exit $rc