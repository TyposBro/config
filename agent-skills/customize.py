#!/usr/bin/env python3
"""Apply TyposBro's intentional overrides to pinned third-party skills."""

import json
from pathlib import Path
import sys


def user_invoked_skills() -> set[str]:
    manifest = json.loads(Path(__file__).with_name("manifest.json").read_text())
    skills = manifest["upstream"] + manifest["local"]
    return {skill["name"] for skill in skills if skill["invocation"] == "user"}


def make_user_invoked(path: Path) -> None:
    text = path.read_text()
    if "disable-model-invocation:" in text:
        return

    if not text.startswith("---\n"):
        raise RuntimeError(f"missing frontmatter in {path}")

    end = text.find("\n---\n", 4)
    if end == -1:
        raise RuntimeError(f"unterminated frontmatter in {path}")

    path.write_text(text[:end] + "\ndisable-model-invocation: true" + text[end:])


def replace_exact(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f"expected pinned text missing in {path}: {old[:80]!r}")
    path.write_text(text.replace(old, new, 1))


def customize_prototype(root: Path) -> None:
    replace_exact(
        root / "prototype/SKILL.md",
        "6. **Capture it when done.** Fold any validated decision into the real code, then capture the prototype itself as a **primary source**: commit it to a throwaway branch, out of main, and leave a context pointer to that branch on the implementation issue. Capture the answer too — the verdict and the question it settled — in the issue or a commit. The main branch keeps only the validated decision.",
        "6. **Clean it up when done.** Fold any validated decision into the real code, delete the throwaway prototype, and summarize the question and verdict for the user. Preserve it in a branch or issue only when the user explicitly asks.",
    )
    replace_exact(
        root / "prototype/UI.md",
        "### 6. Capture the answer and clean up",
        "### 6. Keep the answer and clean up",
    )
    replace_exact(
        root / "prototype/UI.md",
        "Once a variant has won, capture the answer — which variant and why — then capture the prototype the way the [SKILL](SKILL.md) describes. Fold the winner into the real code and move the rest onto the throwaway branch, not into main:",
        "Once a variant has won, record which variant won and why, fold the winner into the real code, and delete the temporary variants and switcher:",
    )
    replace_exact(
        root / "prototype/UI.md",
        "- **Sub-shape A** — fold the winner into the existing page; drop the losing variants and the switcher from main.\n- **Sub-shape B** — promote the winning variant to a real route; drop the throwaway route and the switcher from main.\n\nThe full set of variants is the primary source, so it lands on the throwaway branch, not the bin — variant components and the switcher left in the main branch rot fast and confuse the next reader.",
        "- **Sub-shape A** — fold the winner into the existing page; delete the losing variants and the switcher.\n- **Sub-shape B** — promote the winning variant to a real route; delete the throwaway route and the switcher.\n\nDo not preserve losing variants in a branch or issue unless the user explicitly asks. Temporary variant code rots quickly and confuses the next reader.",
    )
    replace_exact(
        root / "prototype/LOGIC.md",
        "### 7. Capture the answer and the prototype",
        "### 7. Keep the answer and clean up",
    )
    replace_exact(
        root / "prototype/LOGIC.md",
        "Once the prototype has answered its question, capture the answer, then capture the prototype the way the [SKILL](SKILL.md) describes. The logic-specific mapping: the validated reducer / machine / function set lifts into the real module (the decision, absorbed); the TUI shell rides along to the throwaway branch that keeps the prototype as a primary source.",
        "Once the prototype has answered its question, record the answer, lift any validated reducer, machine, or function set into the real module, and delete the TUI shell. Preserve the shell in a branch or issue only when the user explicitly asks.",
    )


def customize_diagnosis(root: Path) -> None:
    path = root / "diagnosing-bugs/SKILL.md"
    replace_exact(
        path,
        "Stop and say so explicitly. List what you tried. Ask the user for: (a) access to whatever environment reproduces it, (b) a captured artifact (HAR file, log dump, core dump, screen recording with timestamps), or (c) permission to add temporary production instrumentation. Do **not** proceed to hypothesise without a loop.",
        "State the limitation explicitly and list what you tried. Ask for access, a captured artifact, or permission to add temporary production instrumentation only when those are genuinely required. Use the strongest observable signal available and label unverified conclusions; targeted source inspection may still be necessary to construct a workable loop.",
    )
    replace_exact(
        path,
        "- [ ] **Fast** — seconds, not minutes.",
        "- [ ] **Practical** — as fast as the real environment allows; tighten it when the cost is justified.",
    )
    replace_exact(
        path,
        "If you catch yourself reading code to build a theory before this command exists, **stop — jumping straight to a hypothesis is the exact failure this skill prevents.** No red-capable command, no Phase 2.",
        "Prefer establishing a red-capable command before deep theorizing. When source inspection is necessary to build the command, keep it targeted at constructing the signal rather than choosing a fix.",
    )
    replace_exact(
        path,
        "Do not proceed until you have reproduced **and** minimised.",
        "Minimise until additional reduction is no longer worth the cost; document any irreducible environment or timing dependencies.",
    )
    replace_exact(
        path,
        "**Show the ranked list to the user before testing.** They often have domain knowledge that re-ranks instantly (\"we just deployed a change to #3\"), or know hypotheses they've already ruled out. Cheap checkpoint, big time saver. Don't block on it — proceed with your ranking if the user is AFK.",
        "Keep the ranked list in working notes. Surface it only when the user has domain knowledge or a decision materially depends on their input; otherwise test the ranking directly.",
    )


def customize_tdd(root: Path) -> None:
    path = root / "tdd/SKILL.md"
    replace_exact(
        path,
        "**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam. You can't test everything — agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.",
        "**Test at deliberate seams.** Before writing a test, identify the public seam under test. Ask the user only when multiple seams have materially different trade-offs; otherwise choose the highest stable public interface and proceed.",
    )
    replace_exact(
        path,
        "- **Refactoring is not part of the loop.** It belongs to the review stage (see the `code-review` skill), not the red → green implementation cycle.",
        "- **Refactor after green.** Improve design only while the test stays green; do not mix speculative refactoring into the minimal change that first makes it pass.",
    )
    replace_exact(
        path,
        "Ask: \"What's the public interface, and which seams should we test?\"",
        "Use this question internally: \"What is the public interface, and which seams should we test?\"",
    )


def remove_deleted_skill_handoff(root: Path) -> None:
    path = root / "diagnosing-bugs/SKILL.md"
    replace_exact(
        path,
        "**Then ask: what would have prevented this bug?** If the answer involves architectural change (no good test seam, tangled callers, hidden coupling) hand off to the `/improve-codebase-architecture` skill with the specifics. Make the recommendation **after** the fix is in, not before — you have more information now than when you started.",
        "**Then ask: what would have prevented this bug?** If the answer involves architectural change (no good test seam, tangled callers, hidden coupling), report the specific follow-up after the fix is in. Do not turn it into an unrequested refactor.",
    )


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: customize.py <skills-root>")

    root = Path(sys.argv[1]).resolve()
    for name in user_invoked_skills():
        make_user_invoked(root / name / "SKILL.md")

    customize_prototype(root)
    customize_diagnosis(root)
    customize_tdd(root)
    remove_deleted_skill_handoff(root)


if __name__ == "__main__":
    main()
