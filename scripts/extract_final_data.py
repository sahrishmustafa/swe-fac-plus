#!/usr/bin/env python3
"""
Script to extract data from results.json for instances listed in improved_instances.txt
and save the filtered data to final_data.json
"""

import json
import os
from pathlib import Path

def read_improved_instances(file_path):
    """Read the list of improved instances from the text file."""
    instances = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line:  # Skip empty lines
                    instances.append(line)
        print(f"Read {len(instances)} instances from {file_path}")
        return instances
    except FileNotFoundError:
        print(f"Error: File {file_path} not found")
        return []
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return []

def read_results_json(file_path):
    """Read the results.json file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        print(f"Read {len(data)} entries from {file_path}")
        return data
    except FileNotFoundError:
        print(f"Error: File {file_path} not found")
        return []
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON from {file_path}: {e}")
        return []
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return []

def filter_data_by_instances(results_data, target_instances):
    """Filter the results data to only include entries with matching instance_ids."""
    filtered_data = []
    found_instances = set()
    
    for entry in results_data:
        if 'instance_id' in entry:
            if entry['instance_id'] in target_instances:
                filtered_data.append(entry)
                found_instances.add(entry['instance_id'])
    
    # Check for missing instances
    missing_instances = set(target_instances) - found_instances
    if missing_instances:
        print(f"Warning: The following instances were not found in results.json:")
        for instance in missing_instances:
            print(f"  - {instance}")
    
    print(f"Found {len(filtered_data)} matching entries out of {len(target_instances)} target instances")
    return filtered_data

def save_final_data(data, output_path):
    """Save the filtered data to final_data.json."""
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Successfully saved {len(data)} entries to {output_path}")
        return True
    except Exception as e:
        print(f"Error saving to {output_path}: {e}")
        return False

def main():
    """Main function to orchestrate the data extraction process."""
    # Define file paths
    base_dir = Path(__file__).parent
    improved_instances_path = base_dir / "improved_instances.txt"
    results_json_path = base_dir / "output" / "json" / "results" / "results.json"
    final_data_path = base_dir / "final_data.json"
    
    print("Starting data extraction process...")
    print(f"Base directory: {base_dir}")
    print(f"Improved instances file: {improved_instances_path}")
    print(f"Results JSON file: {results_json_path}")
    print(f"Output file: {final_data_path}")
    print("-" * 50)
    
    # Read the list of improved instances
    target_instances = read_improved_instances(improved_instances_path)
    if not target_instances:
        print("No instances to process. Exiting.")
        return
    
    # Read the results.json file
    results_data = read_results_json(results_json_path)
    if not results_data:
        print("No results data to process. Exiting.")
        return
    
    # Filter the data based on the target instances
    filtered_data = filter_data_by_instances(results_data, target_instances)
    
    if not filtered_data:
        print("No matching data found. Exiting.")
        return
    
    # Save the filtered data to final_data.json
    success = save_final_data(filtered_data, final_data_path)
    
    if success:
        print("\nData extraction completed successfully!")
        print(f"Output saved to: {final_data_path}")
    else:
        print("\nData extraction failed!")

if __name__ == "__main__":
    main() 