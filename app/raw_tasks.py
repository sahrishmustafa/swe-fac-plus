import json
import os
import re
import shutil
from abc import ABC, abstractmethod
from os.path import join as pjoin
from pathlib import Path

import httpx

from app import utils as app_utils
from app.log import log_and_print
from app.task import PlainTask, SweTask, Task
from docker import DockerClient

class RawTask(ABC):
    @property
    @abstractmethod
    def task_id(self) -> str:
        raise NotImplementedError("abstract base class")

    @abstractmethod
    def to_task(self) -> Task:
        raise NotImplementedError("abstract base class")

    @abstractmethod
    def dump_meta_data(self, output_dir: str) -> None:
        raise NotImplementedError("abstract base class")


class RawSweTask(RawTask):
    """
    Encapsulate everything required to run one task.
    """

    def __init__(self, task_id: str, setup_info: dict, task_info: dict,client:DockerClient = None):
        # a counter str, format "1/150", which means first task out of 150
        # id from the benchmark
        self._task_id = task_id
        # setup_info (Dict): keys: ['repo_path', 'env_name', 'pre_install', 'install','test_cmd']
        self.setup_info = setup_info
        # task_info (Dict): keys: ['base_commit', 'hints_text', 'created_at',
        # 'test_patch', 'repo', 'problem_statement', 'version', 'instance_id',
        # 'FAIL_TO_PASS', 'PASS_TO_PASS', 'environment_setup_commit']
        self.task_info = task_info
        self.client = client 
    @property
    def task_id(self) -> str:
        return self._task_id

    def to_task(self) -> SweTask:
        task_id = self.task_id
        setup_info = self.setup_info
        task_info = self.task_info
        language = task_info.get('language','None')
        client = self.client
        return SweTask(
            task_id=task_id,
            problem_statement=task_info["problem_statement"],
            repo_path=setup_info["repo_path"],
            repo_cache_path=setup_info["repo_cache_path"],
            # env_name=setup_info["env_name"],
            # pre_install_cmds=setup_info["pre_install"],
            # install_cmd=setup_info["install"],
            # command to run the relevant tests,
            # test_cmd=setup_info["test_cmd"],
            commit=task_info["base_commit"],
            repo_name=task_info["repo"],
            # modifications to the test suite for this task instance,
            patch=task_info["patch"],
            test_patch=task_info["test_patch"],
            # testcases_passing=task_info["PASS_TO_PASS"],
            # testcases_failing=task_info["FAIL_TO_PASS"],
            language=language,
            # image_urls=task_info['image_urls'],
            # reference_setup=task_info['reference_setup'],
            version=task_info['version'],
            client = client,
            task_info = task_info
        )

    def dump_meta_data(self, output_dir: str):
        meta = {
            "task_id": self.task_id,
            "setup_info": self.setup_info,
            "task_info": self.task_info,
        }
        with open(pjoin(output_dir, "meta.json"), "w") as f:
            json.dump(meta, f, indent=4)
        with open(pjoin(output_dir, "problem_statement.txt"), "w") as f:
            f.write(self.task_info["problem_statement"])
        with open(pjoin(output_dir, "developer_patch.diff"), "w") as f:
            f.write(self.task_info["patch"])


class RawGithubTask(RawTask):
    """
    Encapsulate everything required to run ACR on a fresh issue from the internet.
    """

    def __init__(
        self,
        task_id: str,
        clone_link: str,
        commit_hash: str | None,
        issue_link: str,
        setup_dir: str,
        use_comments: bool = False,
    ):
        self._task_id = task_id
        self.clone_link = clone_link
        # if commit_hash is None, assume using the HEAD of default branch
        self.commit_hash = commit_hash
        self.issue_link = issue_link
        self.setup_dir = setup_dir
        self.use_comments = use_comments
        self.clone_path = pjoin(self.setup_dir, self.task_id)
        self.problem_statement, self.created_at = self.fetch_issue()
        self.clone_repo()

    @property
    def task_id(self) -> str:
        return self._task_id

    def clone_repo(self):
        clone_path = Path(self.clone_path)
        if os.path.exists(clone_path):
            log_and_print(
                f"Path {clone_path} already exists. Removing it to get a fresh clone."
            )
            shutil.rmtree(clone_path)
        app_utils.clone_repo(self.clone_link, str(clone_path.parent), clone_path.name)
        log_and_print(f"Cloned source code to {clone_path}.")
        if self.commit_hash is None:
            # let's get the current commit hash
            with app_utils.cd(clone_path):
                self.commit_hash = app_utils.get_current_commit_hash()

    def dump_meta_data(self, output_dir: str):
        meta = {
            "task_info": {
                "base_commit": self.commit_hash,
                "created_at": self.created_at,
                "problem_statement": self.problem_statement,
                "instance_id": self.task_id,
            },
            "setup_info": {"repo_path": self.clone_path},
        }

        meta_file = pjoin(output_dir, "meta.json")

        with open(meta_file, "w") as f:
            json.dump(meta, f, indent=4)

    def fetch_issue(self):
        if "github.com" not in self.issue_link:
            raise NotImplementedError("Only GitHub issues are supported for now.")

        retrieved_issue = self.fetch_github_issue(self.issue_link, self.use_comments)

        if retrieved_issue is None:
            raise RuntimeError(
                f"Failed to retrieve issue information from {self.issue_link}"
            )

        title, body, created_at = retrieved_issue

        body = self.process_links(body)

        problem_statement = f"{title}\n{body}"

        return problem_statement, created_at

    @classmethod
    def process_links(cls, body: str):
        code_pattern = re.compile(
            r"https://github.com/(.*?)/blob/(.*)/(.*)#L(\d+)-L(\d+)"
        )
        replacements = []

        for code_links in code_pattern.finditer(body):
            repo_name = code_links.group(1)
            commit = code_links.group(2)
            file_path = code_links.group(3)
            start_line = int(code_links.group(4))
            end_line = int(code_links.group(5))

            file_contents = httpx.get(
                f"https://raw.githubusercontent.com/{repo_name}/{commit}/{file_path}"
            ).text.splitlines()
            fragment = "\n".join(file_contents[start_line - 1 : end_line])

            replacements.append((code_links.group(0), f"\n```{fragment }```\n"))

        for code_link, replacement in replacements:
            body = body.replace(code_link, code_link + replacement)
        return body

    @classmethod
    def fetch_github_issue(
        cls, issue_url: str, use_comments: bool = False
    ) -> tuple[str, str, str]:
        """Extract owner, repo, and issue number from the URL"""

        # Example issue URL: https://github.com/owner/repo/issues/123

        _, owner, repo, _, issue_number = issue_url.rsplit("/", 4)

        api_url = f"https://api.github.com/repos/{owner}/{repo}/issues/{issue_number}"
        comments_url = f"https://api.github.com/repos/{owner}/{repo}/issues/{issue_number}/comments"

        issue_response = httpx.get(api_url)

        if issue_response.status_code != 200:
            raise RuntimeError(
                f"Failed to fetch issue information: {issue_response.status_code}"
            )

        issue_info = issue_response.json()

        title = issue_info["title"]
        body = issue_info["body"]

        if use_comments:
            comments_response = httpx.get(comments_url)
            if comments_response.status_code != 200:
                raise RuntimeError(
                    f"Failed to fetch comments information: {comments_response.status_code}"
                )

            comments_info = comments_response.json()
            for comment in comments_info:
                if (
                    "user" not in comment
                    or comment["user"]["type"] == "Bot"
                    or comment["user"]["login"] == "acr-bot"
                ):
                    continue

                body += (
                    f"\nUser: {comment['user']['login']}\nComment: {comment['body']}"
                )

        created_at = issue_info["created_at"]

        return title, body, created_at

    def to_task(self) -> PlainTask:
        return PlainTask(
            commit_hash=self.commit_hash,
            local_path=self.clone_path,
            problem_statement=self.problem_statement,
        )


class RawLocalTask(RawTask):
    """
    Encapsulate everything required to run ACR on a local issue on the disk.
    """

    def __init__(self, task_id: str, local_repo: str, issue_file: str):
        self._task_id = task_id
        self.local_repo = local_repo
        self.issue_file = issue_file
        self.commit_hash = self.init_local_repo()
        self.problem_statement = self.read_issue_from_file()

    @property
    def task_id(self) -> str:
        return self._task_id

    def init_local_repo(self):
        with app_utils.cd(self.local_repo):
            if not app_utils.is_git_repo():
                # non git repo - let's make it a git repo first
                app_utils.initialize_git_repo_and_commit()
            commit = app_utils.get_current_commit_hash()
        return commit

    def read_issue_from_file(self) -> str:
        # ignore encoding errors so at least we can have some issue content
        issue = Path(self.issue_file).read_text(errors="ignore")
        return issue

    def dump_meta_data(self, output_dir: str):
        meta = {
            "task_info": {
                "base_commit": self.commit_hash,
                "problem_statement": self.problem_statement,
                "instance_id": self.task_id,
            },
            "setup_info": {"repo_path": self.local_repo},
        }

        meta_file = pjoin(output_dir, "meta.json")

        with open(meta_file, "w") as f:
            json.dump(meta, f, indent=4)

    def to_task(self) -> PlainTask:
        return PlainTask(
            commit_hash=self.commit_hash,
            local_path=self.local_repo,
            problem_statement=self.problem_statement,
        )
