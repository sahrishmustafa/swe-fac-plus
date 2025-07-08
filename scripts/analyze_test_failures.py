import os
import re
import json
import argparse
import multiprocessing
from tqdm import tqdm

# --- Configuration ---
PREV_FILE_NAME  = "test_output_prev_apply.txt"
AFTER_FILE_NAME = "test_output_after_apply.txt"
EXIT_CODE_RE    = re.compile(r"OMNIGRIL_EXIT_CODE=(\d+)")

# --- Regexes for Framework-specific failure lines ---
GTEST_BRACKETED_RE   = re.compile(r"\[\s*FAILED\s*\]\s*(\d+)\s+tests?", re.IGNORECASE)
GTEST_FINAL_RE       = re.compile(r"(\d+)\s+FAILED TESTS", re.IGNORECASE)
GTEST_OUT_OF_RE      = re.compile(r"(\d+)\s+tests? failed out of \d+", re.IGNORECASE)

CATCH2_FAILURE_RE    = re.compile(r"test cases:\s+\d+\s+\|\s+\d+\s+passed\s+\|\s+(\d+)\s+failed", re.IGNORECASE)
DOCTEST_FAILURE_RE   = re.compile(r"failures:\s*(\d+)", re.IGNORECASE)
PYTEST_FAILURE_RE    = re.compile(r"=+ *(\d+)\s+failed", re.IGNORECASE)


def parse_framework_failures(content: str) -> int | None:
    """Try parsing known failure line formats from different test frameworks."""
    for line in content.splitlines():
        # GTest patterns
        if match := GTEST_BRACKETED_RE.search(line):
            return int(match.group(1))
        if match := GTEST_FINAL_RE.search(line):
            return int(match.group(1))
        if match := GTEST_OUT_OF_RE.search(line):
            return int(match.group(1))

        # Catch2
        if match := CATCH2_FAILURE_RE.search(line):
            return int(match.group(1))

        # Doctest
        if match := DOCTEST_FAILURE_RE.search(line):
            return int(match.group(1))

        # PyTest
        if match := PYTEST_FAILURE_RE.search(line):
            return int(match.group(1))

    return None


def parse_exit_code(content: str) -> int | None:
    """Fallback: extract exit code if failure count isn't available."""
    match = EXIT_CODE_RE.search(content)
    if match:
        return int(match.group(1))
    return None


def count_failures(content: str) -> int | None:
    """Combined parser: prefer test failure counts, fallback to exit code."""
    failures = parse_framework_failures(content)
    if failures is not None:
        return failures

    exit_code = parse_exit_code(content)
    if exit_code is not None:
        return 1 if exit_code != 0 else 0

    return None


def process_instance(path: str) -> tuple[str, bool]:
    """Evaluate if test output improved for this instance."""
    inst_id = os.path.basename(path)
    prev_path  = os.path.join(path, PREV_FILE_NAME)
    after_path = os.path.join(path, AFTER_FILE_NAME)

    if not os.path.isfile(prev_path) or not os.path.isfile(after_path):
        return inst_id, False

    with open(prev_path, 'r', encoding='utf-8', errors='ignore') as f:
        prev_content = f.read()
    with open(after_path, 'r', encoding='utf-8', errors='ignore') as f:
        after_content = f.read()

    prev_failures  = count_failures(prev_content)
    after_failures = count_failures(after_content)

    if prev_failures is None or after_failures is None:
        return inst_id, False

    # core rule: only count as improved if number of failing tests decreased
    return inst_id, after_failures < prev_failures


def evaluate_improvements(base_dir: str, output_txt: str, processes: int):
    """Parallel evaluation and output of improved instances."""
    instance_dirs = [
        os.path.join(base_dir, d)
        for d in os.listdir(base_dir)
        if os.path.isdir(os.path.join(base_dir, d))
    ]

    with multiprocessing.Pool(processes) as pool:
        results = list(tqdm(
            pool.imap(process_instance, instance_dirs),
            total=len(instance_dirs),
            desc="Evaluating"
        ))

    improved = [inst_id for inst_id, is_better in results if is_better]

    with open(output_txt, 'w', encoding='utf-8') as out:
        for inst_id in improved:
            out.write(f"{inst_id}\n")

    print(f"\nFound {len(improved)} improved instances.")
    print(f"Written to: {output_txt}")


def main():
    parser = argparse.ArgumentParser(description="Detect test improvements across different frameworks.")
    parser.add_argument("base_dir", help="Path to the base folder containing instance subdirectories.")
    parser.add_argument("output_file", help="Path to write improved instance IDs.")
    parser.add_argument("--processes", type=int, default=16, help="Number of processes to use.")
    args = parser.parse_args()

    if not os.path.isdir(args.base_dir):
        parser.error(f"Directory not found: {args.base_dir}")
    if args.processes < 1:
        parser.error("--processes must be >= 1")

    evaluate_improvements(args.base_dir, args.output_file, args.processes)


if __name__ == "__main__":
    multiprocessing.freeze_support()
    main()
