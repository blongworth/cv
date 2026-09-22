# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "requests",
#     "bibtexparser<2",
# ]
# ///
"""Update references.bib from an ORCID record.

Looks up all works listed on an ORCID profile, finds the ones with a DOI that
aren't already in references.bib, fetches clean BibTeX for each from Crossref
(via DOI content negotiation), and appends them to references.bib.

Usage:
    uv run scripts/update_references.py
    uv run scripts/update_references.py --orcid 0000-0001-8318-2054
    uv run scripts/update_references.py --dry-run

Works without a DOI (e.g. conference talks/posters, book chapters not
registered with a DOI) are reported but not added automatically -- add those
to references.bib or the "Published Abstracts and Professional Talks" list
in cv.qmd by hand.
"""

from __future__ import annotations

import argparse
import re
import sys
import time
import unicodedata
from pathlib import Path

import bibtexparser
import requests
from bibtexparser.bwriter import BibTexWriter
from bibtexparser.bparser import BibTexParser

DEFAULT_ORCID = "0000-0001-8318-2054"
ORCID_API = "https://pub.orcid.org/v3.0"
USER_AGENT = "cv-reference-updater/1.0 (+https://github.com/; mailto:none@example.com)"
STOPWORDS = {
    "a", "an", "the", "of", "in", "on", "for", "and", "to", "with", "from",
    "using", "by", "at", "as", "into", "via", "is", "are",
}

REPO_ROOT = Path(__file__).resolve().parent.parent
BIB_PATH = REPO_ROOT / "references.bib"


def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]", "", text.lower())


def strip_html(text: str) -> str:
    return re.sub(r"</?[a-zA-Z][^>]*>", "", text)


def fetch_orcid_dois(orcid: str) -> tuple[list[str], list[str]]:
    """Return (dois, titles_without_doi) for all works on the ORCID record."""
    resp = requests.get(
        f"{ORCID_API}/{orcid}/works",
        headers={"Accept": "application/json", "User-Agent": USER_AGENT},
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()

    dois: list[str] = []
    no_doi_titles: list[str] = []
    for group in data.get("group", []):
        summary = group["work-summary"][0]
        title = summary.get("title", {}).get("title", {}).get("value", "(untitled)")
        ext_ids = summary.get("external-ids", {}).get("external-id", [])
        doi = next(
            (e["external-id-value"] for e in ext_ids if e["external-id-type"].lower() == "doi"),
            None,
        )
        if doi:
            dois.append(doi.lower())
        else:
            no_doi_titles.append(title)
    return dois, no_doi_titles


def fetch_bibtex_for_doi(doi: str) -> str | None:
    try:
        resp = requests.get(
            f"https://doi.org/{doi}",
            headers={"Accept": "application/x-bibtex", "User-Agent": USER_AGENT},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.text
    except requests.RequestException as exc:
        print(f"  warning: could not fetch BibTeX for {doi}: {exc}", file=sys.stderr)
        return None


def make_key(entry: dict, existing_keys: set[str]) -> str:
    author_field = entry.get("author", "")
    first_author = author_field.split(" and ")[0] if author_field else "unknown"
    last_name = first_author.split(",")[0].strip() if "," in first_author else first_author.strip()
    last_name_slug = slugify(last_name) or "unknown"

    year = re.sub(r"\D", "", entry.get("year", "")) or "n.d."

    title_words = re.findall(r"[A-Za-z0-9]+", strip_html(entry.get("title", "")))
    title_word = next((w for w in title_words if w.lower() not in STOPWORDS), "untitled")
    title_word_slug = slugify(title_word) or "untitled"

    base_key = f"{last_name_slug}{year}{title_word_slug}"
    key = base_key
    suffix = ord("a")
    while key in existing_keys:
        key = f"{base_key}{chr(suffix)}"
        suffix += 1
    return key


def load_existing() -> bibtexparser.bibdatabase.BibDatabase:
    if not BIB_PATH.exists():
        return bibtexparser.bibdatabase.BibDatabase()
    parser = BibTexParser(common_strings=True)
    parser.ignore_nonstandard_types = False
    with BIB_PATH.open(encoding="utf-8") as f:
        return bibtexparser.load(f, parser=parser)


def write_bib(db: bibtexparser.bibdatabase.BibDatabase) -> None:
    db.entries = sorted(db.entries, key=lambda e: e.get("year", "0"), reverse=True)
    writer = BibTexWriter()
    writer.indent = "  "
    writer.comma_first = False
    writer.order_entries_by = None
    with BIB_PATH.open("w", encoding="utf-8") as f:
        f.write(bibtexparser.dumps(db, writer))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--orcid", default=DEFAULT_ORCID, help=f"ORCID iD (default: {DEFAULT_ORCID})")
    ap.add_argument("--dry-run", action="store_true", help="Report what would change without writing")
    args = ap.parse_args()

    print(f"Fetching works for ORCID {args.orcid}...")
    dois, no_doi_titles = fetch_orcid_dois(args.orcid)

    db = load_existing()
    existing_dois = {
        e["doi"].lower() for e in db.entries if e.get("doi")
    }
    existing_keys = {e["ID"] for e in db.entries}

    new_dois = [d for d in dois if d not in existing_dois]
    print(f"{len(dois)} works with a DOI on ORCID, {len(new_dois)} not yet in references.bib.")

    added = []
    parser = BibTexParser(common_strings=True)
    for doi in new_dois:
        print(f"Fetching Crossref BibTeX for {doi}...")
        raw = fetch_bibtex_for_doi(doi)
        if not raw:
            continue
        fetched = bibtexparser.loads(raw, parser=parser)
        if not fetched.entries:
            print(f"  warning: no BibTeX entry parsed for {doi}", file=sys.stderr)
            continue
        entry = fetched.entries[0]
        entry["title"] = strip_html(entry.get("title", ""))
        entry["doi"] = doi
        entry.setdefault("url", f"https://doi.org/{doi}")
        entry["ID"] = make_key(entry, existing_keys)
        existing_keys.add(entry["ID"])
        db.entries.append(entry)
        added.append(entry["ID"])
        time.sleep(0.3)

    if added:
        print(f"Added {len(added)} new entries: {', '.join(added)}")
        if not args.dry_run:
            write_bib(db)
            print(f"Wrote {BIB_PATH}")
        else:
            print("(dry run, references.bib not modified)")
    else:
        print("No new entries to add.")

    if no_doi_titles:
        print(f"\n{len(no_doi_titles)} ORCID work(s) have no DOI and were skipped "
              "(add manually if relevant):")
        for title in no_doi_titles:
            print(f"  - {title}")


if __name__ == "__main__":
    main()
