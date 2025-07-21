"""
An agent, which is only responsible for the write_dockerfile tool call.
"""

import json
import shutil
from collections.abc import Callable, Iterable
from copy import deepcopy
from os.path import join as pjoin
from pathlib import Path
import os
from loguru import logger

from app import globals
from app.data_structures import MessageThread, MethodId
from app.log import print_acr, print_patch_generation
from app.model import common
from app.task import Task
import re




SYSTEM_PROMPT_EVAL_SCRIPT = """You are a software agent specialized in writing evaluation scripts to run tests inside a Docker environment.  
Your task is to generate an **evaluation script** that executes the given test files in the prepared Docker environment.  

You will receive the following information:
- **Collected environment details** from the **context retrieval agent**, including dependencies, test execution commands, and special setup steps.
- **The generated Dockerfile** that defines the environment in which the tests will be executed.
- **A list of test files** that must be executed, provided by the user.
- **An evaluation script skeleton (`eval_script_skeleton`) that MUST be followed.**

### Your Responsibilities:
1. Ensure the evaluation script properly activates the environment inside the Docker container.
2. Apply the test patch (if needed) before executing the tests.
3. **After applying the test patch, always rebuild the test binary or recompile the project as required, so that any new or modified tests are included in the executable.**
4. Use the correct test execution commands as collected by the **context retrieval agent**.

The generated script must follow best practices, ensuring all necessary steps are performed to successfully run the tests."""



USER_PROMPT_INIT_EVAL_SCRIPT = """Generate an **evaluation script** based on the collected environment setup and test execution information.  
The script must execute the provided test files inside the specified Docker environment.

### **Requirements:**
1. **Activate the environment**: Ensure the correct environment (e.g., Conda, venv) is activated before running the tests.
2. **Apply the test patch (if required)**: The test patch may need to be applied before running the tests.
3. **Rebuild the test binary or recompile the project after applying the test patch**: This ensures that any new or updated tests from the patch are present in the compiled test executable.
4. **Execute the given test files** using the correct command found by the context retrieval agent.
5. **Ensure proper cleanup**: After running the tests, any modified files should be reset.

### Important Notes:
1. You must **execute only the specified target test files**, rather than running all tests in the repository.  
   - Running all tests can be highly time-consuming and unnecessary.  
   - Ensure that only the **required test cases** are executed based on the provided test file list.  

2. **Optimize execution efficiency by combining multiple test commands into a single command** whenever possible.  
   - Avoid running multiple separate test commands if they can be executed in one batch.  
   - This reduces redundant initialization overhead and speeds up execution.  

3. **Ensure that the output of the evaluation script is concise and structured**, making it easier for the **test log analysis agent** to process.  
   - Avoid excessive logging, unnecessary debug information, or verbose output.  

4. **Follow the structure of the reference evaluation script or eval script skeleton whenever available.  
   - Use **a simple, minimalistic structure** similar to the reference eval script to ensure clarity and maintainability.  
   - The script should be easy to modify and extend without unnecessary complexity.  

5. **The actual test patch content is omitted here for brevity (marked with [CONTENT OF TEST PATCH] placeholder).
    -You must generate the complete git apply command structure, including the heredoc syntax with delimiter (EOF_114329324912).

    -The placeholder will be programmatically replaced with the actual patch content during script execution.

    -Example structure:
    git apply -v - <<'EOF_114329324912'\n[CONTENT OF TEST PATCH]\nEOF_114329324912

6. **After applying the test patch, you must rebuild the test binary or recompile the project so that the new or modified tests are included in the executable.**
    - For example, if using CMake, you might run `cmake --build .` or `make` after patching.
    - If using another build system, use the appropriate command to ensure the test binary is up to date.

7. You MUST capture the exit code immediately after running the tests using ``rc=$? '', and then echo: ``OMNIGRIL_EXIT_CODE=$rc''. This ensures the judge can determine whether the tests passed successfully.

Eval script skeleton:
{eval_script_skeleton}

### **Example Format:**
The script must be wrapped in `<script>` tags. Example:

<script>
#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
pip install -r test-requirements.txt && pip install -e . 

git checkout 6de254ef00f99ce5284ab947f2dd1179db6d28f6 "test-data/unit/check-functions.test" "test-data/unit/check-redefine.test"

# Required: apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Required: rebuild test binary so new/updated tests are included
make  # or cmake --build . or the appropriate build command for the project

# Required: run target tests
pytest --no-header -rA --tb=no -p no:cacheprovider -n4 mypy/test/testcheck.py::TypeCheckSuite::check-functions.test mypy/test/testcheck.py::TypeCheckSuite::check-redefine.test
rc=$?            #Required, save exit code\n 
echo "OMNIGRIL_EXIT_CODE=$rc" #Required, echo test status
git checkout 6de254ef00f99ce5284ab947f2dd1179db6d28f6 "test-data/unit/check-functions.test" "test-data/unit/check-redefine.test"
</script>
"""

HEREDOC_DELIMITER = "EOF_114329324912"

apply_test_patch_command = f"git apply -v - <<'{HEREDOC_DELIMITER}'\n[CONTENT OF TEST PATCH]\n{HEREDOC_DELIMITER}"



def get_system_prompt_eval_script():
    return SYSTEM_PROMPT_EVAL_SCRIPT


def get_user_prompt_init_eval_script(eval_script_skeleton):
    return USER_PROMPT_INIT_EVAL_SCRIPT.format(eval_script_skeleton=eval_script_skeleton)

    
def write_eval_script_with_retries(
    message_thread: MessageThread,
    output_dir: str,
    test_patch: str,
    task: Task,
    retries=3,
    print_callback: Callable[[dict], None] | None = None,
) -> tuple[str, float, int, int]:
    """
    Since the agent may not always write an applicable patch, we allow for retries.
    This is a wrapper around the actual run.
    """
    # (1) replace system prompt
    # messages = deepcopy(message_thread.messages)
    new_thread = message_thread
    # new_thread: MessageThread = MessageThread(messages=messages)
    # # (2) add the initial user prompt
    # user_prompt_init=USER_PROMPT_INIT.format(eval_script_skeleton=eval_script_skeleton)
    # user_prompt_init +="\nFor contents in <original></original> and <patched></patched>, please do not contain them in extra ```\n```. Something like <original>\n```js\n```</original> is forbidden. Keep these contents clean."
    # new_thread.add_user(user_prompt_init)
    # print_acr(user_prompt_init, "dockerfile generation", print_callback=print_callback)
    script_extracted = None
    can_stop = False
    result_msg = ""
    os.makedirs(output_dir, exist_ok=True)
    for i in range(1, retries + 2):
        if i > 1:
            debug_file = pjoin(output_dir, f"debug_agent_write_eval_script_{i - 1}.json")
            with open(debug_file, "w") as f:
                json.dump(new_thread.to_msg(), f, indent=4)

        if can_stop or i > retries:
            break

        logger.info(f"Trying to extract a eval script. Try {i} of {retries}.")

        raw_dockerfile_file = pjoin(output_dir, f"agent_eval_script_raw_{i}")

        # actually calling model
        res_text, *_ = common.SELECTED_MODEL.call(new_thread.to_msg())

        new_thread.add_model(res_text, [])  # no tools

        logger.info(f"Raw script and produced in try {i}. Writing script into file.")

        with open(raw_dockerfile_file, "w") as f:
            f.write(res_text)

        print_patch_generation(
            res_text, f"try {i} / {retries}", print_callback=print_callback
        )

        # Attemp to extract a real patch from the raw patch
        # Extract Dockerfile content from model response using regex

        
        # Initialize extraction flags
        script_extracted = extract_eval_script_from_response(res_text, output_dir,test_patch)


        # Determine if both files are extracted
        can_stop = script_extracted 

        if can_stop:
            result_msg = "Successfully extracted eval_script."
            print_acr(result_msg, f"eval script generation try {i}/{retries}", print_callback=print_callback)
            break
        else:
            feedback = "Failed to extract "
            feedback += "Script" if not script_extracted else ""
            new_thread.add_user(feedback + ". Please return result in defined format.")
            print_acr(feedback, f"Retry {i}/{retries}", print_callback=print_callback)

    if result_msg == '':
        result_msg = 'Failed to extract'
        
    return result_msg

def replace_heredoc_content(original_content, test_patch):
    """替换 heredoc 中的内容为指定的 test_patch"""
    lines = original_content.splitlines()
    output_lines = []
    in_heredoc = False
    heredoc_delimiter = "EOF_114329324912"
    
    for line in lines:
        if f" - <<'{heredoc_delimiter}'" in line:
            # 找到 heredoc 开始行
            output_lines.append(line)
            in_heredoc = True
            # 直接插入 test_patch 内容
            output_lines.extend(test_patch.splitlines())
        elif in_heredoc and line == heredoc_delimiter:
            # 找到 heredoc 结束行
            output_lines.append(line)
            in_heredoc = False
        elif not in_heredoc:
            # 非 heredoc 内容保持不变
            output_lines.append(line)
    
    return '\n'.join(output_lines)


def  extract_eval_script_from_response(res_text: str, output_dir: str, test_patch:str):
        # Process eval.sh
        script_path = pjoin(output_dir, "eval.sh")
        script_skeleton_path = pjoin(output_dir, "eval_skeleton.sh")
        script_extracted = False
        # Pattern 1: <script> tags
        script_matches = re.findall(r"<script>([\s\S]*?)</script>", res_text)
        for content in script_matches:
            clean_content = content.strip()
            if clean_content:
                lines = clean_content.splitlines()
                if len(lines) >= 2 and "```" in lines[0] and "```" in lines[-1]:
                    lines = lines[1:-1]
                filtered_content = '\n'.join(lines)
                filtered_content_with_test_patch = replace_heredoc_content(filtered_content,test_patch)
                with open(script_skeleton_path, "w") as f:
                    f.write(filtered_content)
                with open(script_path, "w") as f:
                    f.write(filtered_content_with_test_patch)
                script_extracted = True
                break

        # Pattern 2: ```script code block
        if not script_extracted:
            script_code_blocks = re.findall(r"```\s*script\s*([\s\S]*?)```", res_text, re.IGNORECASE)
            for content in script_code_blocks:
                clean_content = content.strip()
                if clean_content:
                    lines = clean_content.splitlines()
                    if len(lines) >= 2 and "```" in lines[0] and "```" in lines[-1]:
                        lines = lines[1:-1]
                    filtered_content = '\n'.join(lines)
                    filtered_content_with_test_patch = replace_heredoc_content(filtered_content,test_patch)
                    with open(script_skeleton_path, "w") as f:
                        f.write(filtered_content)
                    with open(script_path, "w") as f:
                        f.write(filtered_content_with_test_patch)
                    script_extracted = True
                    break
        
        # Pattern 3: ```bash code block
        if not script_extracted:
            bash_code_blocks = re.findall(r"```\s*bash.*([\s\S]*?)```", res_text, re.IGNORECASE)
            for content in bash_code_blocks:
                clean_content = content.strip()
                if clean_content:
                    lines = clean_content.splitlines()
                    if len(lines) >= 2 and "```" in lines[0] and "```" in lines[-1]:
                        lines = lines[1:-1]
                    filtered_content = '\n'.join(lines)
                    filtered_content_with_test_patch = replace_heredoc_content(filtered_content,test_patch)
                    with open(script_skeleton_path, "w") as f:
                        f.write(filtered_content)
                    with open(script_path, "w") as f:
                        f.write(filtered_content_with_test_patch)
                    
                    
                    script_extracted = True
                    break
        return script_extracted 


