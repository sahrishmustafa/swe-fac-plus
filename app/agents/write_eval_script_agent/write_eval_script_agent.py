from app.data_structures import MessageThread
from app.agents.write_eval_script_agent import write_eval_script_utils
from app.agents.agent import Agent
from app.task import Task
import os
import shutil
import re
DIFF_MODIFIED_FILE_REGEX = r"--- a/(.*)"
from app.log import (
    print_acr,
    print_banner,
    print_retrieval,
)
from os.path import join as pjoin
from loguru import logger

class WriteEvalScriptAgent(Agent):
    """
    Agent responsible for generating or modifying an evaluation script (`eval.sh`).
    Manages its own thread, versioning, and directories for each run.
    """
    api_functions: list[str] = []
    def __init__(
        self,
        task: Task,
        output_dir: str,
        repo_basic_info: str,
    ):
        super().__init__(agent_id = "WriteEvalScriptAgent")
        self.task = task
        self.output_dir = os.path.abspath(output_dir)
        self.test_patch = self.task.test_patch
        self.test_files = self.get_test_files()
        self.initial_skeleton = self.get_initial_eval_script_skeleton()
        self.run_count = 0
        self.repo_basic_info = repo_basic_info
        self.reference_setup = None
        self.dockerfile = None
        self.init_msg_thread()


    def get_test_files(self):
        test_files = re.findall(DIFF_MODIFIED_FILE_REGEX, self.test_patch)
        return test_files
        
    def init_msg_thread(self) -> None:
        self.msg_thread = MessageThread()
        self.add_system_message(write_eval_script_utils.get_system_prompt_eval_script())
        self.add_user_message(self.repo_basic_info)
        
        
    def add_reference_message(self) -> None:
        if self.reference_setup:
            version = self.reference_setup.get('version', 'unknown')
            skeleton = self.reference_setup.get('eval_script_skeleton', '')
            reference_text = (
                f"I've pulled an eval script skeleton from version {version} of this repo that worked well in a similar context. "
                "This is provided purely as a reference—if its structure and commands align with your current environment, you may "
                "adapt parts of it to save time; otherwise, feel free to adjust or ignore it. "
                "Note that the full test_patch is quite long and has been omitted here to conserve space:\n\n"
                f"{skeleton}"
            )
            self.add_user_message(reference_text)



    def get_latest_write_output_dir(self) -> str:
        return os.path.join(self.output_dir, f"write_eval_script_agent_{self.run_count}")

    
        
    def get_initial_eval_script_skeleton(self):
        HEREDOC_DELIMITER = "EOF_114329324912"
        test_files = self.test_files
        reset_test_files = ['"' + t + '"' for t in test_files]
        # Reset test files to the state they should be in before the patch.
        reset_tests_command = f"git checkout {self.task.commit} {' '.join(reset_test_files)}"
        apply_test_patch_command = (
            f"git apply -v - <<'{HEREDOC_DELIMITER}'\n[CONTENT OF TEST PATCH]\n{HEREDOC_DELIMITER}"
        )
        # apply_test_patch_command = (
        #     f"git apply -v - <<'{HEREDOC_DELIMITER}'\n{self.test_patch}\n{HEREDOC_DELIMITER}"
        # )
        
        eval_commands = [
            f"cd /testbed",
        ]
        eval_commands += [
            reset_tests_command,
            apply_test_patch_command,
            reset_tests_command,  # Revert tests after done, leave the repo in the same state as before
        ]
        return "\n".join(["#!/bin/bash", "set -uxo pipefail"] + eval_commands) + "\n"

    def get_latest_eval_script_skeleton(self) -> str:
        """Read the latest saved skeleton to avoid long scripts."""
        skel_path = os.path.join(self.get_latest_write_output_dir(), 'eval_skeleton.sh')
        try:
            with open(skel_path, 'r') as f:
                return f.read()
        except Exception:
            return self.initial_skeleton
        
    def get_latest_eval_script(self) -> str:
        eval_script = None
        try:
            eval_script_path = f'{self.get_latest_write_output_dir()}/eval.sh'
            with open(eval_script_path, 'r') as file:
                eval_script = file.read()
        except Exception as e:
            logger.error(e)
        return eval_script

    def run_task(
        self,
        print_callback=None
    ) -> tuple[str, str, bool]:
        """
        Generate or modify the evaluation script based on the shared message_thread.
        Returns raw_output, summary, success.
        """
        print_banner(f"Task {self.task.task_id} Iteration ROUND {self.iteration_num}: Eval Script Generation ")
        
        prev_dir = self.get_latest_write_output_dir()
        self.run_count += 1
        curr_dir = self.get_latest_write_output_dir()
        os.makedirs(curr_dir, exist_ok=True)

        prev_script = os.path.join(prev_dir, 'eval.sh')
        prev_skel = os.path.join(prev_dir, 'eval_skeleton.sh')
        # decide create vs modify
        dockerfile_msg = f'The dockerfile environment you are running tests on:\n{self.dockerfile}\n\n'
        if os.path.exists(prev_script):
            # modify: use only skeleton to prompt changes
            self.add_user_message(dockerfile_msg)
            msg_prev_eval_script = f'Previous generated eval script skeleton (Test patch omitted because of its long length):\n{self.get_latest_eval_script_skeleton()}\n\n'
            self.add_user_message(msg_prev_eval_script)
            self.add_reference_message()
            modify_prompt = """Please modify current eval script according to collected information. 
            Return modified eval script in defined format. Wrap results in <script></script>.
            """
            self.add_user_message(modify_prompt)
        else:
            # initial: provide skeleton
            self.add_user_message(dockerfile_msg)
            self.add_reference_message()
            self.add_user_message(write_eval_script_utils.get_user_prompt_init_eval_script(self.initial_skeleton))

        task_output = write_eval_script_utils.write_eval_script_with_retries(
            self.msg_thread,
            curr_dir,
            self.test_patch,
            self.task,
            retries=3,
            print_callback=print_callback
        )

        # validate or fallback
        script_path = os.path.join(curr_dir, 'eval.sh')
        ok = os.path.isfile(script_path)
        if not ok and os.path.exists(prev_script):
            shutil.copy(prev_script, script_path)
            ok = False
        summary = (
            "Evaluation script created/updated successfully." if ok
            else "Evaluation script generation failed."
        )
        eval_script_output_dir = self.get_latest_write_output_dir()
        conversation_file = pjoin(eval_script_output_dir, f"conversation.json")
        self.msg_thread.save_to_file(conversation_file)
        # self.init_msg_thread()
        return task_output, summary, ok
