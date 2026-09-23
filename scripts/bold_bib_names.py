"""Bold "Longworth, <initials>" in the rendered bibliography.

Quarto's typst format expands the CSL bibliography into plain Typst markup
before compiling (kept via `keep-typ: true` in _quarto.yml), and CSL styles
have no standard way to conditionally bold one specific author's name. So
this runs as a project post-render hook: it patches the kept cv.typ to wrap
the CV owner's name in #strong[...] within each bibliography entry, then
recompiles the PDF with `typst compile`, and removes the intermediate .typ.

Wired up via `project.post-render` in _quarto.yml -- runs automatically
after every `quarto render`.
"""

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TYP_PATH = REPO_ROOT / "cv.typ"
PDF_PATH = REPO_ROOT / "cv.pdf"

# Matches "Longworth," followed by one or more ". "-style initials, e.g.
# "Longworth, B. E." or "Longworth, B." -- stops before any trailing space
# so it never eats the space before the next author/word.
NAME_RE = re.compile(r"Longworth,(?: [A-Z]\.)+")

# Bibliography entries are emitted as `#block[ ... ] <ref-KEY>`.
ENTRY_RE = re.compile(r"(#block\[\n)(.*?)(\n\] <ref-[^>]+>)", re.S)


def bold_names(entry_text: str) -> str:
    return NAME_RE.sub(lambda m: f"#strong[{m.group(0)}]", entry_text)


def main() -> None:
    if not TYP_PATH.exists():
        # Nothing to do -- e.g. rendering to a format other than typst.
        return

    text = TYP_PATH.read_text(encoding="utf-8")
    patched, n = ENTRY_RE.subn(
        lambda m: m.group(1) + bold_names(m.group(2)) + m.group(3), text
    )
    TYP_PATH.write_text(patched, encoding="utf-8")
    print(f"bold_bib_names: patched {n} bibliography entries in cv.typ")

    result = subprocess.run(
        ["typst", "compile", str(TYP_PATH), str(PDF_PATH)],
        cwd=REPO_ROOT,
    )
    if result.returncode != 0:
        print("bold_bib_names: typst recompile failed", file=sys.stderr)
        sys.exit(result.returncode)

    TYP_PATH.unlink()


if __name__ == "__main__":
    main()
