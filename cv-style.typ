// Typst styling tweaks for the CV, included via `include-in-header`.

#set text(size: 10pt)
#set par(justify: false, leading: 0.55em)

// Tighten default block spacing
#set block(spacing: 0.75em)

// H1: name/title block — no rule, slightly larger, tight spacing below
#show heading.where(level: 1): it => {
  set text(size: 20pt, weight: "bold")
  block(above: 0em, below: 0.4em, it.body)
}

// H2: section headings — small caps, bottom rule, generous spacing above
#show heading.where(level: 2): it => {
  block(above: 1.1em, below: 0.5em)[
    #set text(size: 11pt, weight: "bold", tracking: 0.5pt)
    #upper(it.body)
    #v(-0.6em)
    #line(length: 100%, stroke: 0.5pt + luma(60%))
  ]
}

#set terms(hanging-indent: 0pt, spacing: 0.6em)
#show terms: it => {
  set par(leading: 0.5em)
  it
}

#set list(spacing: 0.5em)
