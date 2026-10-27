"""Bold "Longworth, <initials>" in the rendered bibliography.

Quarto's typst format expands the CSL bibliography into plain Typst markup
before compiling (kept via `keep-typ: true` in _quarto.yml), and CSL styles
have no standard way to conditionally bold one specific author's name. So
this runs as a project post-render hook: it patches the kept <stem>.typ to
wrap the CV owner's name in #strong[...] within each bibliography entry, then
recompiles the PDF with `typst compile`, and removes the intermediate .typ.

Every rendered output is processed (e.g. cv.* and, under `--profile onepage`,
cv-onepage.*), using the QUARTO_PROJECT_OUTPUT_FILES list Quarto passes to
post-render scripts; falls back to cv.* when run by hand.

Wired up via `project.post-render` in _quarto.yml -- runs automatically
after every `quarto render`.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Matches "Longworth," followed by one or more ". "-style initials, e.g.
# "Longworth, B. E." or "Longworth, B." -- stops before any trailing space
# so it never eats the space before the next author/word.
NAME_RE = re.compile(r"Longworth,(?: [A-Z]\.)+")

# Bibliography entries are emitted as `#block[ ... ] <ref-KEY>`.
ENTRY_RE = re.compile(r"(#block\[\n)(.*?)(\n\] <ref-[^>]+>)", re.DOTALL)

# HTML entries are emitted as `<div id="ref-KEY" class="csl-entry" ...>...</div>`.
HTML_ENTRY_RE = re.compile(
    r'(<div id="ref-[^"]+" class="csl-entry"[^>]*>)(.*?)(</div>)', re.DOTALL
)


def bold_names(entry_text: str) -> str:
    return NAME_RE.sub(lambda m: f"#strong[{m.group(0)}]", entry_text)


def output_stems() -> list[Path]:
    """Output paths without suffix, e.g. [REPO_ROOT / "cv"]."""
    files = os.environ.get("QUARTO_PROJECT_OUTPUT_FILES", "").splitlines()
    stems = {(REPO_ROOT / f).with_suffix("") for f in files if f.strip()}
    return sorted(stems) or [REPO_ROOT / "cv"]


def patch_html(html_path: Path) -> None:
    """Wrap the CV owner's name in <strong> within each HTML csl-entry."""
    text = html_path.read_text(encoding="utf-8")
    patched, n = HTML_ENTRY_RE.subn(
        lambda m: (
            m.group(1)
            # Lookbehind skips names already bolded by a previous run (a stale
            # cv.html survives e.g. `quarto render --to typst`).
            + re.sub(
                r"(?<!<strong>)" + NAME_RE.pattern,
                lambda n: f"<strong>{n.group(0)}</strong>",
                m.group(2),
            )
            + m.group(3)
        ),
        text,
    )
    html_path.write_text(patched, encoding="utf-8")
    print(f"bold_bib_names: patched {n} bibliography entries in {html_path.name}")


def patch_typst(typ_path: Path, pdf_path: Path) -> None:
    text = typ_path.read_text(encoding="utf-8")
    patched, n = ENTRY_RE.subn(
        lambda m: m.group(1) + bold_names(m.group(2)) + m.group(3), text
    )
    typ_path.write_text(patched, encoding="utf-8")
    print(f"bold_bib_names: patched {n} bibliography entries in {typ_path.name}")

    result = subprocess.run(
        ["typst", "compile", str(typ_path), str(pdf_path)],
        cwd=REPO_ROOT,
        check=False,
    )
    if result.returncode != 0:
        print("bold_bib_names: typst recompile failed", file=sys.stderr)
        sys.exit(result.returncode)

    typ_path.unlink()


def main() -> None:
    for stem in output_stems():
        html_path = stem.with_suffix(".html")
        typ_path = stem.with_suffix(".typ")
        if html_path.exists():
            patch_html(html_path)
        # No .typ means nothing to do -- e.g. rendering to a non-typst format.
        if typ_path.exists():
            patch_typst(typ_path, stem.with_suffix(".pdf"))


if __name__ == "__main__":
    main()
