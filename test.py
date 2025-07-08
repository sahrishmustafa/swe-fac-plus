import argparse
import glob
import json
import os

def combine_jsonl_files(input_paths, output_path):
    count = 0
    with open(output_path, 'w', encoding='utf-8') as outfile:
        for path in input_paths:
            with open(path, 'r', encoding='utf-8') as infile:
                for line in infile:
                    line = line.strip()
                    if line:
                        try:
                            json.loads(line)  # Validate JSON
                            outfile.write(line + '\n')
                            count += 1
                        except json.JSONDecodeError:
                            print(f"Skipping invalid JSON in: {path}")
    print(f"\n✅ Combined {count} entries from {len(input_paths)} files into '{output_path}'")

def main():
    parser = argparse.ArgumentParser(description="Combine multiple JSONL files into one.")
    parser.add_argument("input_folder", help="Folder containing .jsonl files to merge.")
    parser.add_argument("output_file", help="Output .jsonl file path.")
    args = parser.parse_args()

    if not os.path.isdir(args.input_folder):
        raise ValueError(f"Folder not found: {args.input_folder}")

    input_files = sorted(glob.glob(os.path.join(args.input_folder, "*.jsonl")))
    if not input_files:
        raise ValueError(f"No .jsonl files found in {args.input_folder}")

    combine_jsonl_files(input_files, args.output_file)

if __name__ == "__main__":
    main()
