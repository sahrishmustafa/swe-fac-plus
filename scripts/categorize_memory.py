import json
import os
import sys
import time
from datetime import datetime
import yaml
from openai import OpenAI, OpenAIError
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

# Define issue categories
CATEGORIES = [
    "Syntax and Compilation Errors",
    "Memory Management Issues",
    "Logic and Semantic Errors",
    "Concurrency and Threading Issues",
    "Undefined Behavior",
    "Build and Dependency Issues",
    "Security Vulnerabilities",
    "Testing and Validation Failures",
    "Code Quality and Maintainability Problems",
    "Documentation and Style Violations"
]

# Load configuration from config.yaml
def load_config():
    try:
        with open("config.yaml", "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
        if "provider_base_urls" not in config:
            print("Error: provider_base_urls not found in config.yaml")
            sys.exit(1)
        return config
    except Exception as e:
        print(f"Error loading config.yaml: {e}")
        sys.exit(1)

# Load API keys from secrets.yaml
def load_secrets():
    try:
        with open("secrets.yaml", "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except Exception as e:
        print(f"Error loading secrets.yaml: {e}")
        sys.exit(1)

# Initialize OpenAI client based on provider and model
def initialize_client(provider, api_key, provider_base_urls):
    base_url = provider_base_urls.get(provider)
    if not base_url:
        print(f"Error: No base URL defined for provider {provider} in config.yaml")
        sys.exit(1)
    try:
        client = OpenAI(base_url=base_url, api_key=api_key)
        return client
    except Exception as e:
        print(f"Error initializing OpenAI client for {provider}: {e}")
        sys.exit(1)

# Function to classify the context using OpenAI API with problem statement
@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=4, max=40),
    retry=retry_if_exception_type(OpenAIError),
    before_sleep=lambda retry_state: print(f"Retrying in {retry_state.next_action.sleep} seconds...")
)
def classify_issue_with_statement(client, model, problem_statement, categories):
    prompt = f"""
    Given this problem statement from a C++ GitHub issue, classify it into one of the following categories: {', '.join(categories)}.
    
    Problem Statement:
    {problem_statement}

    Return ONLY the category name, nothing else.
    """
    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}]
    )
    category = response.choices[0].message.content.strip()
    for cat in categories:
        if cat.lower() in category.lower():
            return cat
    return category

# Function to classify using test patch, patch, and hints text
@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=4, max=40),
    retry=retry_if_exception_type(OpenAIError),
    before_sleep=lambda retry_state: print(f"Retrying in {retry_state.next_action.sleep} seconds...")
)
def classify_issue_with_patches(client, model, test_patch, patch, hints_text, instance_id, repo, categories):
    prompt = f"""
    Given this test patch, code patch, and hints text from a C++ GitHub issue, classify it into one of the following categories: {', '.join(categories)}.

    Repository: {repo}
    Instance ID: {instance_id}

    Test Patch:
    {test_patch}

    Code Patch:
    {patch}

    Hints Text:
    {hints_text}

    Return ONLY the category name, nothing else.
    """
    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}]
    )
    category = response.choices[0].message.content.strip()
    for cat in categories:
        if cat.lower() in category.lower():
            return cat
    return category

# Main execution
if __name__ == "__main__":
    # Load configurations
    config = load_config()
    secrets = load_secrets()

    # Get provider base URLs
    provider_base_urls = config.get("provider_base_urls", {})
    if not provider_base_urls:
        print("Error: provider_base_urls must be defined in config.yaml")
        sys.exit(1)

    # Get active model and provider
    active_model = config.get("active_model", {})
    provider = active_model.get("provider")
    model_name = active_model.get("model")
    
    if not provider or not model_name:
        print("Error: active_model must specify provider and model in config.yaml")
        sys.exit(1)

    # Validate model is in the supported models list
    supported_models = config.get("models", {}).get(provider, [])
    if model_name not in supported_models:
        print(f"Error: Model {model_name} not found in {provider} models in config.yaml")
        sys.exit(1)

    # Get API key from secrets.yaml
    api_key = secrets.get(f"{provider}_api_key")
    if not api_key or api_key == "YOUR_API_KEY_HERE":
        print(f"Error: {provider}_api_key not set or invalid in secrets.yaml")
        print(f"Please set {provider}_api_key in secrets.yaml")
        sys.exit(1)

    # Initialize OpenAI client
    client = initialize_client(provider, api_key, provider_base_urls)

    # Read the input JSONL file and process each issue
    input_file = "data/nlohmann/nlohmann.jsonl"
    output_file = "data/nlohmann/categorized_instances_nlohmann.jsonl"
    log_file = "data/nlohmann/categorization_log_nlohmann.txt"

    with open(input_file, "r", encoding="utf-8") as infile, \
         open(output_file, "w", encoding="utf-8") as outfile, \
         open(log_file, "w", encoding="utf-8") as logfile:

        # Write log header
        logfile.write(f"Issue Categorization Log - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} PKT\n")
        logfile.write("Issue ID".ljust(25) + " | " + "Basis".ljust(30) + " | " + "Category".ljust(60) + "\n")
        logfile.write("-" * 125 + "\n")
        logfile.flush()

        total_count = 0

        for line in infile:
            try:
                issue = json.loads(line.strip())
                instance_id = issue.get("instance_id", "Unknown")
                repo = issue.get("repo", "Unknown")
                total_count += 1
                
                problem_statement = issue.get("problem_statement", "")
                if problem_statement and problem_statement.strip():
                    category = classify_issue_with_statement(client, model_name, problem_statement, CATEGORIES)
                    basis = "Based on problem statement"
                    print(f"Issue {instance_id}: Classified as {category} (using problem statement)")
                else:
                    test_patch = issue.get("test_patch", "")
                    patch = issue.get("patch", "")
                    hints_text = issue.get("hints_text", "")
                    if not test_patch and not patch and not hints_text:
                        category = f"Error: No content available"
                        basis = "Fallback - no content available"
                        print(f"Issue {instance_id}: No content available, returning error")
                    else:
                        category = classify_issue_with_patches(client, model_name, test_patch, patch, hints_text, instance_id, repo, CATEGORIES)
                        basis = "Based on test patch, code patch, and hints text"
                        print(f"Issue {instance_id}: Classified as {category} (using patches and hints)")
                
                simple_output = {
                    "instance_id": instance_id,
                    "issue_numbers": issue.get("issue_numbers", []),
                    "pull_number": issue.get("pull_number", None),
                    "category": category
                }
                
                logfile.write(f"{instance_id[:30].ljust(25)} | {basis[:29].ljust(30)} | {category[:60].ljust(60)}\n")
                logfile.flush()
                
                json.dump(simple_output, outfile, ensure_ascii=False)
                outfile.write("\n")
                outfile.flush()
                
                time.sleep(6)  # Throttle to stay under 10 requests/min
                
            except json.JSONDecodeError as e:
                print(f"Error parsing JSON line: {e}")
                continue
            except Exception as e:
                print(f"Error processing issue: {e}")
                continue

        logfile.write("\n" + "="*125 + "\n")
        logfile.write(f"SUMMARY:\n")
        logfile.write(f"Total issues processed: {total_count}\n")

    print(f"Output written to {output_file}")
    print(f"Log written to {log_file}")
    print(f"Summary: {total_count} issues processed")