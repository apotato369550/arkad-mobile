"""Python mirror of lib/services/prompt_loader.dart — same `{{var}}` substitution
scheme, reading from tools/agent_lab/prompts/ instead of the bundled Flutter asset."""

from functools import lru_cache
from pathlib import Path

PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"


@lru_cache(maxsize=None)
def load_prompt_template(name: str) -> str:
    return (PROMPTS_DIR / f"{name}.md").read_text(encoding="utf-8").rstrip()


def render_prompt(name: str, vars: dict[str, str]) -> str:
    text = load_prompt_template(name)
    for key, value in vars.items():
        text = text.replace(f"{{{{{key}}}}}", value)
    return text
