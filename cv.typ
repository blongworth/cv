// CV template. All content lives in cv.yml; this file only does layout.
//
// Build:   sh build.sh                         (every version, PDF + HTML)
// Preview: typst watch cv.typ                  (full)
//          typst watch --input version=onepage cv.typ cv-onepage.pdf

#let cv = yaml("cv.yml")
#let version = sys.inputs.at("version", default: "full")
#assert(version in cv.versions, message: "unknown version: " + version)
#let vcfg = cv.versions.at(version)

// Text lookup order: this version, its fallbacks, then full.
#let chain = (version,) + vcfg.at("fallback", default: ()) + ("full",)
#let pick(x) = {
  if type(x) != dictionary { return x }
  for k in chain {
    if k in x { return x.at(k) }
  }
  none
}
#let shown(item) = version in item.at("in", default: ("full",))
#let md(s) = eval(str(s), mode: "markup")

#let is-html() = target() == "html"

#let header = cv.header
#let orcid-url = "https://orcid.org/" + header.orcid
#let orcid-link = link(orcid-url, "orcid.org/" + header.orcid)

#set document(title: header.name + " CV", author: header.name)

// ---------------------------------------------------------------- styling

// HTML export shifts headings down a level: `=` -> h2, `==` -> h3.
#let html-css = ```
body { font-family: Helvetica, Arial, sans-serif; font-size: 10pt; max-width: 8in; margin: 2em auto; padding: 0 1em; line-height: 1.35; }
h2 { font-size: 20pt; margin: 0 0 0.2em; }
h3 { font-size: 11pt; letter-spacing: 0.5pt; text-transform: uppercase; border-bottom: 0.5pt solid #999; margin: 1.4em 0 0.5em; }
p, ul { margin: 0.3em 0; }
ul { padding-left: 1.2em; }
.contact p { margin: 0; }
.entry { display: grid; grid-template-columns: max-content 1fr; column-gap: 0.5em; margin: 0.5em 0; font-weight: bold; }
.entry .text { grid-column: 1 / -1; padding-left: 1em; font-weight: normal; }
a { color: inherit; }
section[role="doc-bibliography"] ul { padding-left: 0; }
section[role="doc-bibliography"] li { margin: 0.4em 0; }
.hanging-indent li { padding-left: 2em; text-indent: -2em; }
```.text

#show: body => context {
  if is-html() {
    html.elem("style", html-css)
    body
  } else {
    set page(paper: "us-letter", margin: vcfg.margin.pairs().map(((k, v)) => (k, eval(v))).to-dict(), numbering: "1")
    set text(font: "Helvetica", size: 10pt)
    set par(justify: false, leading: 0.55em)
    set block(spacing: 0.75em)
    set list(spacing: 0.5em)
    show heading.where(level: 1): it => block(above: 0em, below: 0.4em, text(size: 20pt, weight: "bold", it.body))
    show heading.where(level: 2): it => block(above: 1.1em, below: 0.5em)[
      #set text(size: 11pt, weight: "bold", tracking: 0.5pt)
      #upper(it.body)
      #v(-0.6em)
      #line(length: 100%, stroke: 0.5pt + luma(60%))
    ]
    body
  }
}

// Bold the CV owner's name in every reference.
#show bibliography: it => {
  set par(spacing: 0.6em)
  show regex("Longworth, [A-Z]\.(?:\s?[A-Z]\.)*"): strong
  it
}

// ---------------------------------------------------------------- pieces

// Experience/education entry: **dates** org — _role_, location; text below.
#let entry(e) = {
  let head = e.org
  if "role" in e { head += [ — #emph(md(e.role))] }
  if "location" in e { head += [, #e.location] }
  let text-body = md(pick(e.text))
  context if is-html() {
    html.elem("div", attrs: (class: "entry"))[
      #html.elem("span", attrs: (class: "dates"), e.dates)
      #html.elem("span", attrs: (class: "org"), head)
      #html.elem("div", attrs: (class: "text"), text-body)
    ]
  } else {
    block(breakable: false, spacing: 0.6em)[
      #set par(leading: 0.5em)
      #grid(columns: (auto, 1fr), column-gutter: 0.35em, strong(e.dates), strong(head))
      #v(-0.3em)
      #pad(left: 1em, text-body)
    ]
  }
}

#let section-title(s) = heading(level: 2, pick(s.title))

#let plain-list(s) = {
  section-title(s)
  list(..pick(s.items).map(md))
}

#let dated-list(s) = {
  section-title(s)
  list(..s.items.filter(shown).map(i => [*#i.year* #md(i.text)]))
}

#let entries(s) = {
  section-title(s)
  for e in s.items.filter(shown) { entry(e) }
}

#let labeled-list(s) = {
  section-title(s)
  list(..s.items.map(i => [*#i.label:* #md(i.text)]))
}

#let pubs(s) = {
  section-title(s)
  let style = vcfg.at("pub-style", default: "apa")
  let sel = vcfg.at("pubs", default: "all")
  if sel == "all" {
    bibliography("references.bib", full: true, style: style, title: none)
  } else {
    for k in sel { cite(label(k), form: none) }
    bibliography("references.bib", style: style, title: none)
  }
  if pick(s.at("orcid-note", default: none)) == true [
    Full publication list: #orcid-link
  ]
}

#let renderers = (
  interests: plain-list,
  skills: plain-list,
  experience: entries,
  education: entries,
  teaching: dated-list,
  service: dated-list,
  awards: dated-list,
  affiliations: plain-list,
  summary: labeled-list,
  pubs: pubs,
  abstracts: plain-list,
)

// ---------------------------------------------------------------- document

= #header.name

#context {
  let lines = (
    header.title,
    header.address,
    [#link("mailto:" + header.email, header.email) · #header.phone · #orcid-link],
  )
  if is-html() {
    html.elem("div", attrs: (class: "contact"), lines.map(l => html.elem("p", l)).join())
  } else {
    lines.join(linebreak())
  }
}

#for name in vcfg.sections {
  assert(name in renderers, message: "no renderer for section: " + name)
  renderers.at(name)(cv.at(name))
}
