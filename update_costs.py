import os
import json

# Define the new costs
NEW_INPUT_COST_PER_TOKEN = 0.00000010 
NEW_OUTPUT_COST_PER_TOKEN = 0.00000040


def calc_cost(input_tokens: int, output_tokens: int) -> float:
    """
    Calculates the cost of a request based on the number of input/output tokens.
    """
    input_cost = NEW_INPUT_COST_PER_TOKEN * input_tokens
    output_cost = NEW_OUTPUT_COST_PER_TOKEN * output_tokens
    cost = input_cost + output_cost
    print(
        f"Updating cost: input_tokens={input_tokens}, output_tokens={output_tokens}, cost={cost:.6f}"
    )
    return cost

def update_cost_json(folder_path):
    for root, dirs, files in os.walk(folder_path):
        if 'cost.json' in files:
            cost_json_path = os.path.join(root, 'cost.json')
            with open(cost_json_path, 'r') as f:
                data = json.load(f)

            # Check for required fields
            if 'total_input_tokens' not in data or 'total_output_tokens' not in data:
                print(f"Skipping {cost_json_path}: Missing token fields.")
                continue

            # Update token costs
            data['input_cost_per_token'] = NEW_INPUT_COST_PER_TOKEN
            data['output_cost_per_token'] = NEW_OUTPUT_COST_PER_TOKEN

            # Recalculate total cost
            total_input_tokens = data['total_input_tokens']
            total_output_tokens = data['total_output_tokens']
            data['total_cost'] = calc_cost(total_input_tokens, total_output_tokens)

            # Save changes
            with open(cost_json_path, 'w') as f:
                json.dump(data, f, indent=4)
            
            print(f"Updated: {cost_json_path}")

if __name__ == "__main__":
    base_folder = "./output/google/gemini-2.5-flash-lite-preview-06-17/applicable_setup"
    update_cost_json(base_folder)
