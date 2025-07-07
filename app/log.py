import time
from collections.abc import Callable
from os import get_terminal_size

from loguru import logger
from rich.console import Console
from rich.markdown import Markdown
from rich.markup import escape
from rich.panel import Panel
import logging
from pathlib import Path
import threading

logger_lock = threading.Lock()

def terminal_width():
    try:
        return get_terminal_size().columns
    except OSError:
        return 80


WIDTH = min(120, terminal_width() - 10)

console = Console()

print_stdout = True


def log_exception(exception):
    logger.exception(exception)


def print_banner(msg: str) -> None:
    if not print_stdout:
        return

    banner = f" {msg} ".center(WIDTH, "=")
    console.print()
    console.print(banner, style="bold")
    console.print()


def replace_html_tags(content: str):
    """
    Helper method to process the content before printing to markdown.
    """
    replace_dict = {
        "<file>": "[file]",
        "<class>": "[class]",
        "<func>": "[func]",
        "<method>": "[method]",
        "<code>": "[code]",
        "<original>": "[original]",
        "<patched>": "[patched]",
        "</file>": "[/file]",
        "</class>": "[/class]",
        "</func>": "[/func]",
        "</method>": "[/method]",
        "</code>": "[/code]",
        "</original>": "[/original]",
        "</patched>": "[/patched]",
    }
    for key, value in replace_dict.items():
        content = content.replace(key, value)
    return content


def print_acr(
    msg: str, desc="", print_callback: Callable[[dict], None] | None = None
) -> None:
    if not print_stdout:
        return

    msg = replace_html_tags(msg)
    markdown = Markdown(msg)

    name = "SweEnvSetupAgent"
    if desc:
        title = f"{name} ({desc})"
    else:
        title = name

    panel = Panel(
        markdown, title=title, title_align="left", border_style="magenta", width=WIDTH
    )
    console.print(panel)

    if print_callback:
        print_callback(
            {"title": f"{name} ({desc})", "message": msg, "category": "SweEnvSetupAgent"}
        )


def print_retrieval(
    msg: str, desc="", print_callback: Callable[[dict], None] | None = None
) -> None:
    if not print_stdout:
        return

    msg = replace_html_tags(msg)
    markdown = Markdown(msg)

    name = "Context Retrieval Agent"
    if desc:
        title = f"{name} ({desc})"
    else:
        title = name

    panel = Panel(
        markdown, title=title, title_align="left", border_style="blue", width=WIDTH
    )
    console.print(panel)
    if print_callback:
        print_callback(
            {
                "title": f"{name} ({desc})",
                "message": msg,
                "category": "context_retrieval_agent",
            }
        )


def print_patch_generation(
    msg: str, desc="", print_callback: Callable[[dict], None] | None = None
) -> None:
    if not print_stdout:
        return

    msg = replace_html_tags(msg)
    markdown = Markdown(msg)

    name = "Patch Generation"
    if desc:
        title = f"{name} ({desc})"
    else:
        title = name

    panel = Panel(
        markdown, title=title, title_align="left", border_style="yellow", width=WIDTH
    )
    console.print(panel)
    if print_callback:
        print_callback(
            {
                "title": f"{name} ({desc})",
                "message": msg,
                "category": "patch_generation",
            }
        )


def print_fix_loc_generation(
    msg: str, desc="", print_callback: Callable[[dict], None] | None = None
) -> None:
    if not print_stdout:
        return

    msg = replace_html_tags(msg)
    markdown = Markdown(msg)

    name = "Fix Location Generation"
    if desc:
        title = f"{name} ({desc})"
    else:
        title = name

    panel = Panel(
        markdown, title=title, title_align="left", border_style="green", width=WIDTH
    )
    console.print(panel)
    if print_callback:
        print_callback(
            {
                "title": f"{name} ({desc})",
                "message": msg,
                "category": "fix_loc_generation",
            }
        )


def print_issue(content: str) -> None:
    if not print_stdout:
        return

    title = "Issue description"
    panel = Panel(
        escape(content),
        title=title,
        title_align="left",
        border_style="red",
        width=WIDTH,
    )
    console.print(panel)


def log_and_print(msg):
    logger.info(msg)
    if print_stdout:
        console.print(msg)


def log_and_cprint(msg, **kwargs):
    logger.info(msg)
    if print_stdout:
        console.print(msg, **kwargs)


def log_and_always_print(msg):
    """
    A mode which always print to stdout, no matter what.
    Useful when running multiple tasks and we just want to see the important information.
    """
    logger.info(msg)
    # always include time for important messages
    t = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    console.print(f"\n[{t}] {msg}")


def print_with_time(msg):
    """
    Print a msg to console with timestamp.
    """
    t = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    console.print(f"\n[{t}] {msg}")


def setup_logger(instance_id: str, log_file: Path, mode="w"):
    """
    This logger is used for logging the build process of images and containers.
    It writes logs to the log file.
    """
    with logger_lock:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        new_logger = logging.getLogger(f"{instance_id}.{log_file.name}")
        handler = logging.FileHandler(log_file, mode=mode)
        formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
        handler.setFormatter(formatter)
        new_logger.addHandler(handler)
        new_logger.setLevel(logging.INFO)
        new_logger.propagate = False
        setattr(new_logger, "log_file", log_file)
        return new_logger

def close_logger(new_logger):
    # To avoid too many open files
    with logger_lock:
        for handler in new_logger.handlers:
            handler.close()
            new_logger.removeHandler(handler)