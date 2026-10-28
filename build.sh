#!/bin/sh
# Build every CV version from cv.yml + cv.typ.
#   full    -> cv.pdf, cv.html
#   <other> -> cv-<other>.pdf, cv-<other>.html
# Add a version: add it under `versions:` in cv.yml and to the loop below.
# Live preview: typst watch cv.typ   (add --input version=onepage for others)
set -eu
cd "$(dirname "$0")"

for v in full onepage; do
  if [ "$v" = full ]; then stem=cv; else stem="cv-$v"; fi
  typst compile --input version="$v" cv.typ "$stem.pdf"
  typst compile --features html --input version="$v" cv.typ "$stem.html"
  echo "built $stem.pdf $stem.html"
done
