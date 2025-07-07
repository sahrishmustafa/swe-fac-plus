import json
import os
from pathlib import Path
import re
import requests

import fnmatch
from argparse import ArgumentTypeError
from datasets import Dataset, load_dataset
from datetime import datetime
from dotenv import load_dotenv
from functools import cache
# from git import Repo
from typing import cast, List, Optional
from typing import TypedDict
# from constants import (
#     SWEbenchInstance,
#     MAP_REPO_TO_ENV_YML_PATHS,
#     MAP_REPO_TO_REQS_PATHS,
#     NON_TEST_EXTS,
#     SWE_BENCH_URL_RAW,
# )

load_dotenv()

# Constants - Task Instance Class
class SWEbenchInstance(TypedDict):
    repo: str
    instance_id: str
    base_commit: str
    patch: str
    test_patch: str
    problem_statement: str
    hints_text: str
    created_at: str
    version: str
    FAIL_TO_PASS: str
    PASS_TO_PASS: str
    environment_setup_commit: str
    dockerfile: str
    eval_script: str

def load_omnigirl_dataset(name="princeton-nlp/SWE-bench", split="test") -> list[SWEbenchInstance]:
    """
    Load SWE-bench dataset from Hugging Face Datasets or local .json/.jsonl file
    """
    # Load from local .json/.jsonl file
    if name.endswith(".json"):
        return [
            cast(SWEbenchInstance, instance)
            for instance in json.loads(Path(name).read_text())
        ]
    elif name.endswith(".jsonl"):
        return [
            cast(SWEbenchInstance, json.loads(line.strip()))
            for line in Path(name).read_text().splitlines()
        ]

    # Load from Hugging Face Datasets
    if name.lower() in {"swe-bench", "swebench", "swe_bench"}:
        name = "princeton-nlp/SWE-bench"
    elif name.lower() in {"swe-bench-lite", "swebench-lite", "swe_bench_lite", "swe-bench_lite", "lite"}:
        name = "princeton-nlp/SWE-bench_Lite"
    dataset = cast(Dataset, load_dataset(name, split=split))
    return [cast(SWEbenchInstance, instance) for instance in dataset]


### MARK - Patch Correction
PATCH_PATTERN = re.compile(
    r"(?:diff[\w\_\.\ \/\-]+\n)?\-\-\-\s+a\/(?:.*?)\n\+\+\+\s+b\/(?:.*?)(?=diff\ |\-\-\-\ a\/|\Z)",
    re.DOTALL,
)
PATCH_FILE_PATTERN = re.compile(r"\-\-\-\s+a\/(?:.+)\n\+\+\+\s+b\/(?:.+)")
PATCH_HUNK_PATTERN = re.compile(
    r"\@\@\s+\-(\d+),(\d+)\s+\+(\d+),(\d+)\s+\@\@(.+?)(?=diff\ |\-\-\-\ a\/|\@\@\ \-|\Z)",
    re.DOTALL,
)


def get_first_idx(charlist):
    """Get index of first occurrence of "-" or "+" in charlist"""
    first_min = charlist.index("-") if "-" in charlist else len(charlist)
    first_plus = charlist.index("+") if "+" in charlist else len(charlist)
    return min(first_min, first_plus)


def get_last_idx(charlist):
    """Get index of last occurrence of "-" or "+" in charlist"""
    char_idx = get_first_idx(charlist[::-1])
    last_idx = len(charlist) - char_idx
    return last_idx + 1


def strip_content(hunk):
    """Remove trailing non +/- lines and trailing whitespace per line per hunk"""
    first_chars = list(map(lambda x: None if not len(x) else x[0], hunk.split("\n")))
    first_idx = get_first_idx(first_chars)
    last_idx = get_last_idx(first_chars)
    new_lines = list(map(lambda x: x.rstrip(), hunk.split("\n")[first_idx:last_idx]))
    new_hunk = "\n" + "\n".join(new_lines) + "\n"
    return new_hunk, first_idx - 1


def get_hunk_stats(pre_start, pre_len, post_start, post_len, hunk, total_delta):
    """Recalculate hunk start/end position and diff delta"""
    stats = {"context": 0, "added": 0, "subtracted": 0}
    hunk = hunk.split("\n", 1)[-1].strip("\n")
    for line in hunk.split("\n"):
        if line.startswith("-"):
            stats["subtracted"] += 1
        elif line.startswith("+"):
            stats["added"] += 1
        else:
            stats["context"] += 1
    context = stats["context"]
    added = stats["added"]
    subtracted = stats["subtracted"]
    pre_len = context + subtracted
    post_start = pre_start + total_delta
    post_len = context + added
    total_delta = total_delta + (post_len - pre_len)
    return pre_start, pre_len, post_start, post_len, total_delta


def extract_minimal_patch(model_patch):
    """
    Wrapper function that takes hunk and
    * Removes trailing non +/- lines and trailing whitespace per line per hunk
    * Recalculates hunk start/end position and diff delta
    * Returns new patch
    """
    model_patch = model_patch.lstrip("\n")
    new_patch = ""
    for patch in PATCH_PATTERN.findall(model_patch):
        total_delta = 0
        patch_header = PATCH_FILE_PATTERN.findall(patch)[0]
        if patch_header:
            new_patch += patch_header + "\n"
        for hunk in PATCH_HUNK_PATTERN.findall(patch):
            pre_start, pre_len, post_start, post_len, content = hunk
            pre_start, pre_len, post_start, post_len, content = list(
                map(lambda x: int(x) if x.isnumeric() else x, hunk)
            )
            content, adjust_pre_start = strip_content(content)
            pre_start += adjust_pre_start
            pre_start, pre_len, post_start, post_len, total_delta = get_hunk_stats(
                pre_start, pre_len, post_start, post_len, content, total_delta
            )
            new_patch += (
                f"@@ -{pre_start},{pre_len} +{post_start},{post_len} @@{content}"
            )
    return new_patch


def has_attribute_or_import_error(log_before):
    """
    Check to see if Attribute/Import-prefix is in log text

    Args:
        log_before (str): Validation log text before patch application
    """
    log_before = log_before.lower()

    if any([x in log_before for x in ["attribute", "import"]]):

        def get_lines_with_word(text, target_word):
            # Function to extract line(s) that contains target_word
            text, target_word = text.lower(), target_word.lower()
            lines, hits = text.split("\n")[::-1], []
            for line in lines:
                if target_word in line:
                    hits.append(line)
            return hits

        # Get line with Attribute/Import error
        lines_1 = get_lines_with_word(log_before, "attribute")
        lines_2 = get_lines_with_word(log_before, "import")
        lines_1 = " ".join(lines_1)
        lines_2 = " ".join(lines_2)

        if any([(x in lines_1 or x in lines_2) for x in ["error", "fail"]]):
            return True
    return False


def get_requirements(instance: SWEbenchInstance) -> str:
    """
    Get requirements.txt for given task instance

    Args:
        instance (dict): task instance
    Returns:
        requirements.txt (str): Returns requirements.txt as string
    """
    # Attempt to find requirements.txt at each path based on task instance's repo
    commit = (
        instance["environment_setup_commit"]
        if "environment_setup_commit" in instance
        else instance["base_commit"]
    )

    return get_requirements_by_commit(instance["repo"], commit)


def generate_pytest_command(test_file_path: str) -> str:
    test_file_mapping = [
        ("check-*.test", "testcheck.py", "TypeCheckSuite",'mypy'),  
        ("cmdline*.test", "testcmdline.py", "PythonCmdlineSuite",'mypy'),  
        ("daemon.test", "testdaemon.py", "DaemonSuite",'mypy'),  
        ("fine-grained-cache*.test", "testfinegrainedcache.py", "FineGrainedCacheSuite",'mypy'),  
        ("fine-grained*.test", "testfinegrained.py", "FineGrainedSuite",'mypy'),  
        ("semanal-error*.test", "testsemanal.py", "SemAnalErrorSuite",'mypy'),  
        ("semanal-symtable*.test", "testsemanal.py", "SemAnalSymtableSuite",'mypy'),  
        ("semanal-typeinfo*.test", "testsemanal.py", "SemAnalTypeInfoSuite",'mypy'),  
        ("semanal-*.test", "testsemanal.py", "SemanticAnalyzerSuite",'mypy'),  
        ("deps.test", "testdeps.py", "GetDependenciesSuite",'mypy'), 
        ("deps-*.test", "testdeps.py", "GetDependenciesSuite",'mypy'),  
        ("diff.test", "testdiff.py", "ASTDiffSuite",'mypy'),  
        ("pep561.test", "testpep561.py", "PEP561Suite",'mypy'),  
        ("pythoneval*.test", "testpythoneval.py", "PythonEvaluationSuite",'mypy'),  
        ("ref-info.test", "test_ref_info.py", "RefInfoSuite",'mypy'),  
        ("reports.test", "testreports.py", "CoberturaReportSuite",'mypy'),  
        ("stubgen.test", "teststubgen.py", "StubgenPythonSuite",'mypy'),  
        ("errorstream.test", "testerrorstream.py", "ErrorStreamSuite",'mypy'),  
        ("merge.test", "testmerge.py", "ASTMergeSuite",'mypy'),  
        ("outputjson.test", "testoutput.py", "OutputJSONsuite",'mypy'),  
        ("pythoneval.test","testpythoneval.py","PythonEvaluationSuite",'mypy'),
        ("python2eval.test","testpythoneval.py","PythonEvaluationSuite",'mypy'),
        ("pythoneval-asyncio.test","testpythoneval.py","PythonEvaluationSuite",'mypy'),
        ("parse*.test", "testparse.py", "ParseSuite",'mypy'),  
        ('typexport-basic*.test','testtypegen.py','TypeExportSuite','mypy'),
        ("alwaysdefined.test", "test_alwaysdefined.py", "TestAlwaysDefined",'mypyc'),  
        ("analysis.test", "test_analysis.py", "TestAnalysis",'mypyc'),  
        ("commandline.test", "test_commandline.py", "TestCommandLine",'mypyc'),  
        ("exceptions*.test", "test_exceptions.py", "TestExceptionTransform",'mypyc'),  
        ("irbuild-*.test", "test_irbuild.py", "TestGenOps",'mypyc'),  
        ("lowering-*.test", "test_lowering.py", "TestLowering",'mypyc'),  
        ("opt-copy-propagation.test", "test_optimizations.py", "TestCopyPropagation",'mypyc'),  
        ("opt-flag-elimination.test", "test_optimizations.py", "TestFlagElimination",'mypyc'),  
        ("refcount.test", "test_refcount.py", "TestRefCountTransform",'mypyc'),  
        ("run-*.test", "test_run.py", "TestRun",'mypyc'),  
        ("tuplename.test", "test_tuplename.py", "TupleNameSuite",'mypyc'),  
        ("typeops.test", "test_typeops.py", "TypeOpsSuite",'mypyc')  
    ]

    test_file_name = os.path.basename(test_file_path)
    
    for pattern, test_py, suite_class, prefix in test_file_mapping:
        if fnmatch.fnmatch(test_file_name, pattern):
            pytest_command = f"{prefix}/test/{test_py}::{suite_class}::{test_file_name}"
            return pytest_command
    
    print(test_file_path)
    raise ValueError(f"No matching test suite for the test file: {test_file_path}")


# Enhanced C++ test command generation
def detect_cpp_build_system(repo_path: str) -> str:
    """Detect the build system used in the C++ project."""
    if os.path.exists(os.path.join(repo_path, 'CMakeLists.txt')):
        return 'cmake'
    elif os.path.exists(os.path.join(repo_path, 'Makefile')):
        return 'make'
    elif os.path.exists(os.path.join(repo_path, 'BUILD')) or os.path.exists(os.path.join(repo_path, 'WORKSPACE')):
        return 'bazel'
    elif os.path.exists(os.path.join(repo_path, 'meson.build')):
        return 'meson'
    else:
        return 'unknown'


def detect_cpp_test_framework(repo_path: str, test_files: List[str]) -> str:
    """Detect the testing framework used."""
    # Check for framework-specific files or patterns
    framework_indicators = {
        'catch2': ['catch.hpp', 'catch2/', 'TEST_CASE', 'SCENARIO'],
        'gtest': ['gtest/', 'googletest/', 'TEST(', 'TEST_F(', 'EXPECT_'],
        'doctest': ['doctest.h', 'doctest/', 'TEST_CASE', 'SUBCASE'],
        'boost_test': ['boost/test/', 'BOOST_AUTO_TEST_CASE', 'BOOST_TEST'],
        'cppunit': ['cppunit/', 'CPPUNIT_TEST_SUITE', 'CPPUNIT_TEST'],
    }
    
    # Check file contents for framework patterns
    for test_file in test_files:
        full_path = os.path.join(repo_path, test_file) if not os.path.isabs(test_file) else test_file
        if os.path.exists(full_path):
            try:
                with open(full_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    for framework, indicators in framework_indicators.items():
                        if any(indicator in content for indicator in indicators):
                            return framework
            except (UnicodeDecodeError, IOError):
                continue
    
    # Check for framework directories/files
    for framework, indicators in framework_indicators.items():
        for indicator in indicators:
            if any(indicator in path for path in test_files):
                return framework
    
    return 'unknown'


def is_cpp_test_file(file_path: str) -> bool:
    """Determine if a file is likely a C++ test file."""
    if not file_path.endswith(('.cpp', '.cc', '.cxx', '.c++')):
        return False
    
    file_lower = file_path.lower()
    test_indicators = [
        '/test', '/tests', 'test/', 'tests/',
        '_test.', 'test_', '.test.',
        'unittest', 'unit_test',
        'spec.', '_spec.'
    ]
    
    return any(indicator in file_lower for indicator in test_indicators)


def generate_cpp_test_command(test_file_path: str, repo_path: str = '.') -> List[str]:
    """Generate plausible C++ test commands for a given test file."""
    build_system = detect_cpp_build_system(repo_path)
    test_framework = detect_cpp_test_framework(repo_path, [test_file_path])
    
    test_file = os.path.basename(test_file_path)
    test_name = os.path.splitext(test_file)[0]
    
    commands = []
    
    # Build system specific commands
    if build_system == 'cmake':
        # CMake/CTest approach
        commands.extend([
            'cmake --build build --target all',
            'ctest --test-dir build --output-on-failure'
        ])
        
        # Direct binary execution as fallback
        possible_paths = [
            f'./build/tests/{test_name}',
            f'./build/{test_name}',
            f'./build/test/{test_name}',
            f'./tests/{test_name}',
        ]
        commands.extend(possible_paths)
        
    elif build_system == 'make':
        commands.extend([
            'make test',
            f'make {test_name}',
            f'./{test_name}',
            f'./tests/{test_name}',
        ])
        
    elif build_system == 'bazel':
        # Bazel uses different syntax
        commands.extend([
            f'bazel test //tests:{test_name}',
            'bazel test //tests:all',
            f'bazel run //tests:{test_name}',
        ])
        
    elif build_system == 'meson':
        commands.extend([
            'meson test -C build',
            f'./build/tests/{test_name}',
        ])
        
    else:
        # Generic fallback commands
        commands.extend([
            f'g++ -std=c++17 -o {test_name} {test_file_path} && ./{test_name}',
            f'clang++ -std=c++17 -o {test_name} {test_file_path} && ./{test_name}',
            f'./{test_name}',
            f'./tests/{test_name}',
            f'./build/{test_name}',
            'ctest --output-on-failure'  # Fallback to ctest
        ])
    
    return commands


def get_test_directives(instance) -> List[str]:
    """
    Get test directives from the test_patch of a task instance.
    Enhanced to handle C++/cpp repos with better detection and multiple command options.
    """
    repo = instance.get('repo', '').lower()
    test_patch = instance.get('test_patch', '')
    diff_pat = r"diff --git a/.* b/(.*)"
    directives = re.findall(diff_pat, test_patch)
    
    # Check if this is a C++ repository
    cpp_indicators = ['cpp', 'c++', 'catch2', 'gtest', 'googletest', 'cmake']
    is_cpp_repo = any(indicator in repo for indicator in cpp_indicators)
    
    if is_cpp_repo:
        # Filter for C++ test files
        cpp_test_files = [d for d in directives if is_cpp_test_file(d)]
        
        if cpp_test_files:
            # Generate commands for each test file
            all_commands = []
            for test_file in cpp_test_files:
                commands = generate_cpp_test_command(test_file)
                all_commands.extend(commands)
            
            # Remove duplicates while preserving order
            seen = set()
            unique_commands = []
            for cmd in all_commands:
                if cmd not in seen:
                    seen.add(cmd)
                    unique_commands.append(cmd)
            
            return unique_commands
        else:
            # No specific test files found, return generic commands
            return [
                'ctest --output-on-failure',
                'make test',
                'bazel test //...',
                'meson test'
            ]
    
    # Fallback for non-C++ repos
    return directives


def str2bool(v):
    """
    Minor helper function to convert string to boolean
    """
    if isinstance(v, bool):
        return v
    if v.lower() in ("yes", "true", "t", "y", "1"):
        return True
    elif v.lower() in ("no", "false", "f", "n", "0"):
        return False
    else:
        raise ArgumentTypeError("Boolean value expected.")


def parse_ctest_log(log_content):
    """
    Parse CTest and GoogleTest log output and return a dict mapping test names to status.
    Status is one of: 'PASSED', 'FAILED', 'SKIPPED', 'NONE'
    """
    test_status = {}
    
    # Match CTest summary lines
    test_line_re = re.compile(r"Test #?\d+: ([\w\-\./]+).*?(\*\*\*Failed|Passed|Skipped)", re.IGNORECASE)
    for match in test_line_re.finditer(log_content):
        name, status = match.groups()
        if "fail" in status.lower():
            test_status[name] = "FAILED"
        elif "pass" in status.lower():
            test_status[name] = "PASSED"
        elif "skip" in status.lower():
            test_status[name] = "SKIPPED"
    
    # Match GoogleTest lines
    gtest_fail_re = re.compile(r"\[\s*FAILED\s*\]\s+([\w\-.]+)", re.IGNORECASE)
    gtest_pass_re = re.compile(r"\[\s*OK\s*\]\s+([\w\-.]+)", re.IGNORECASE)
    
    for match in gtest_fail_re.finditer(log_content):
        name = match.group(1)
        test_status[name] = "FAILED"
    
    for match in gtest_pass_re.finditer(log_content):
        name = match.group(1)
        if name not in test_status:  # Don't overwrite a failure
            test_status[name] = "PASSED"
    
    return test_status