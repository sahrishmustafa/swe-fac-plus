import os
import json
import csv
from collections import defaultdict
import matplotlib.pyplot as plt

def collect_data(base_folder):
    model_data = defaultdict(list)

    for root, dirs, files in os.walk(base_folder):
        if 'cost.json' in files:
            cost_json_path = os.path.join(root, 'cost.json')
            with open(cost_json_path, 'r') as f:
                data = json.load(f)

            # Skip if essential fields are missing
            required_fields = ['model', 'total_input_tokens', 'total_output_tokens', 'total_cost', 'elapsed_seconds']
            if not all(field in data for field in required_fields):
                print(f"Skipping {cost_json_path}: Missing fields.")
                continue

            model = data['model']
            model_data[model].append({
                'total_input_tokens': data['total_input_tokens'],
                'total_output_tokens': data['total_output_tokens'],
                'total_cost': data['total_cost'],
                'elapsed_seconds': data['elapsed_seconds'],
            })

    return model_data

def compute_summary(model_data):
    summary = []

    for model, runs in model_data.items():
        num_runs = len(runs)
        total_cost = sum(run['total_cost'] for run in runs)
        total_time = sum(run['elapsed_seconds'] for run in runs)
        total_input_tokens = sum(run['total_input_tokens'] for run in runs)
        total_output_tokens = sum(run['total_output_tokens'] for run in runs)

        avg_cost = total_cost / num_runs
        avg_time = total_time / num_runs
        avg_input_tokens = total_input_tokens / num_runs
        avg_output_tokens = total_output_tokens / num_runs

        summary.append({
            'model': model,
            'num_instances': num_runs,
            'total_cost_all_instances': total_cost,
            'total_time_all_instances': total_time,
            'avg_cost': avg_cost,
            'avg_time_seconds': avg_time,
            'avg_input_tokens': avg_input_tokens,
            'avg_output_tokens': avg_output_tokens
        })

    return summary


def save_csv(summary, output_path):
    keys = [
        'model', 'num_instances',
        'total_cost_all_instances', 'total_time_all_instances',
        'avg_cost', 'avg_time_seconds', 'avg_input_tokens', 'avg_output_tokens'
    ]
    with open(output_path, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=keys)
        writer.writeheader()
        for row in summary:
            writer.writerow(row)


def plot_summary(summary, output_folder):
    models = [item['model'] for item in summary]
    avg_costs = [item['avg_cost'] for item in summary]
    avg_times = [item['avg_time_seconds'] for item in summary]

    # Plot: Average Cost
    plt.figure(figsize=(8,5))
    plt.bar(models, avg_costs, color='skyblue')
    plt.ylabel("Average Cost ($)")
    plt.title("Average Cost per Instance by Model")
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig(os.path.join(output_folder, "avg_cost.png"))
    plt.close()

    # Plot: Average Time
    plt.figure(figsize=(8,5))
    plt.bar(models, avg_times, color='lightgreen')
    plt.ylabel("Average Elapsed Time (s)")
    plt.title("Average Time per Instance by Model")
    plt.xticks(rotation=45, ha='right')
    plt.tight_layout()
    plt.savefig(os.path.join(output_folder, "avg_time.png"))
    plt.close()

if __name__ == "__main__":
    #base_folder = "./output/deepseek/deepseek-chat-v3-0324/total/applicable_setup"  # Change to parent directory if needed
    base_folder = "./output/google/gemini-2.5-flash-lite-preview-06-17/applicable_setup"
    #output_folder = "./experiment_results_deepseek"
    output_folder = "./experiment_results_gemini"
    os.makedirs(output_folder, exist_ok=True)

    print("Collecting data...")
    model_data = collect_data(base_folder)

    print("Computing summary...")
    summary = compute_summary(model_data)

    csv_output = os.path.join(output_folder, "swe_builder_model_summary.csv")
    save_csv(summary, csv_output)
    print(f"Saved summary CSV: {csv_output}")

    print("Generating plots...")
    plot_summary(summary, output_folder)
    print(f"Plots saved in {output_folder}")

