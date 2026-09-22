// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
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
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1in,y: 0.75in,),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  font: ("Helvetica",),
  fontsize: 10pt,
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= Brett Longworth
<brett-longworth>
Research Associate III, Marine Chemistry and Geochemistry \ McLean Lab, MS\#8, Woods Hole Oceanographic Institution, Woods Hole, MA 02543 \ #link("mailto:blongworth@whoi.edu")[blongworth\@whoi.edu] · (508) 289-1559 · #link("https://orcid.org/0000-0001-8318-2054")[orcid.org/0000-0001-8318-2054]

== Research Interests
<research-interests>
- Dissolved gasses as tracers of ecosystem function in seawater.
- Microcontroller systems for sensors, platforms, and telemetry.
- Shipboard sensor data acquisition and integration.
- Data communication using interactive web applications.
- Improving the efficiency, reliability, and precision of field-deployed quadrupole mass spectrometry.
- Radiocarbon as a tracer of carbon source in natural systems.

== Skills
<skills>
- Proficient in R, Python, SQL, UNIX, Shell, HTML, and LabVIEW.
- Skilled with C++ and Visual Basic.
- Some experience with Matlab, Javascript and C.
- Versioning and collaborative development with git/GitHub.
- Cloud and local development/deployment of data-driven web applications and data pipelines.
- R/Python skills include data analysis, report generation, interactive web applications with Shiny.
- Extensive troubleshooting skills.
- Microcontroller programming for data acquisition and communication using C++ and MicroPython.
- Certified coding and data science instructor for The Carpentries.
- Some design and CAD experience with SOLIDWORKS, Fusion, and KiCAD.
- Development of small and large mass spectrometer beamline improvements and gas handling systems.
- Statistics for data reduction/analysis and quality assessment.
- Qualified WHOI small boat operator.

== Professional Experience
<professional-experience>
/ #strong[Nov 2023 -- Present] Woods Hole Oceanographic Institution --- #emph[LOC-NESS Project]: #block[
Realtime and web-based mapping and data display, underway sensor and shipboard data interfaces. Sensor calibration and data acquisition. Deck operations for CTD and drifters. Data reduction and QA/QC for underway and drifter data.
]

/ #strong[Jan 2023 -- Present] Woods Hole Oceanographic Institution --- #emph[Machine Lab]: #block[
Microcontroller coding, deployment, and troubleshooting of quadrupole mass spectrometer and acoustic Doppler velocimeter based sensors and platforms. Development of platform telemetry systems. Data pipelines for reductions of Gb--Tb sized datasets.
]

/ #strong[Nov 2021 -- Present] Woods Hole Oceanographic Institution --- #emph[NES-LTER Cruises]: #block[
Measured O2/Ar via equilibrator inlet mass spectrometry, sampling for dissolved gasses. Activity planning, deck and lab operations for CTD/Rosette, additional sampling and sample processing for LTER group.
]

/ #strong[Mar 2006 -- Nov 2023] Woods Hole Oceanographic Institution --- #emph[NOSAMS Research Associate]: #block[
Daily operation, maintenance and development for determination of radiocarbon using accelerator mass spectrometry at the National Ocean Sciences AMS facility.
]

/ #strong[Oct 2013] Woods Hole Oceanographic Institution --- #emph[Cruise Leg\: GEOTRACES EPZT, Eastern Pacific]: #block[
Sampling for dissolved noble gasses, radiocarbon, DIC and tritium in seawater. Ran console for rosette casts. Underway analysis of O2/Ar ratios via membrane inlet mass spectrometry.
]

/ #strong[Nov 2011] Woods Hole Oceanographic Institution --- #emph[Cruise Leg\: GEOTRACES NAT, North Atlantic]: #block[
Sampling for dissolved noble gasses, radiocarbon, DIC and tritium in seawater. Ran console for rosette casts. Underway analysis of O2/Ar ratios via membrane inlet mass spectrometry.
]

/ #strong[Jan 2009] Woods Hole Oceanographic Institution --- #emph[Cruise Leg\: ANDREX JC030, Weddell Sea]: #block[
Sampling for dissolved noble gasses, radiocarbon and tritium in seawater.
]

/ #strong[Jan 2008] Woods Hole Oceanographic Institution --- #emph[Cruise Leg\: CLIVAR I6S, 30°E, Southern Ocean]: #block[
Sampling for seawater helium and tritium, onboard dissolved gas extraction for helium analysis.
]

/ #strong[Nov 2004 -- Feb 2006] University of Massachusetts --- #emph[Research Technician], Amherst, MA: #block[
Mapped hydromorphology of stream reaches using palmtop GIS and profiled current and bathymetry using ADCP. Integrated data for use in basin-scale GIS and mesoscale stream habitat models. Coordinated field work for projects on three rivers in the northeastern U.S.
]

/ #strong[Jan 2003 -- Aug 2004] University of Massachusetts --- #emph[Stable Isotope Lab Technician], Amherst, MA: #block[
Tested, developed methods, maintained, and assisted others in the use of a newly installed EA-IRMS system for determining δ13C and δ15N of organic materials and a Finnigan GasBench sample preparation system for analysis of δ18O of water samples.
]

/ #strong[Sep 2002 -- Jun 2005] University of Massachusetts --- #emph[Master's Thesis Research], Amherst, MA: #block[
Developed protocols and gathered data for studies of shale, soil and riverine organic matter in biogeochemistry and stable isotope laboratories. Researched sources of aged organic carbon to the Hudson river system.
]

/ #strong[Jun--Aug 2002, Jul--Aug 2004] Marine Biological Laboratory --- #emph[Field Research Assistant], Toolik Lake LTER, AK: #block[
Studied carbon and nitrogen dynamics of wet sedge and tussock tundra ecosystems at the Arctic LTER using 14C and 15N tracers.
]

/ #strong[Jan--Jun 2002] University of Massachusetts --- #emph[Laboratory Instructor and Manager], Amherst, MA: #block[
Prepared and taught introductory geology laboratory. Coordinated lab activities and field trips for five lab sections and instructors.
]

/ #strong[Jun--Sep 1997] University of Massachusetts --- #emph[Field Research Assistant], Amherst, MA: #block[
Provided apple pest forecasting data and determined effectiveness of treatments in an experimental integrated pest management program in 14 Western Massachusetts orchards.
]

/ #strong[Jan--Jun 1997] University of Massachusetts --- #emph[Independent Study], Amherst, MA: #block[
Studied the deep phylogeny of chordates using cladistic analysis of mitochondrial genomes.
]

== Education
<education>
/ #strong[2001 -- 2005] University of Massachusetts, Amherst, MA: #block[
M.S. Geosciences, August 2005. Thesis: #emph[Role of non-modern carbon pools in riverine and global carbon cycles.]
]

/ #strong[1995 -- 1998] University of Massachusetts, Amherst, MA: #block[
B.S. Biology, concentration in ecology and evolution. Year exchange in Freiburg, Germany.
]

/ #strong[1992 -- 1994] University of Maine, Orono, ME: #block[
Biology and geology (no degree conferred).
]

== Teaching
<teaching>
- #strong[2023 -- present] Organize and help teach two-day Carpentries courses using R, Python, git/GitHub, and shell.
- #strong[2021] Lead instructor for Data Management with SQL. Database skills course for WHOI technical staff.
- #strong[2020] Lead instructor for Reproducible Data Science with R and Git, Software Carpentry course for WHOI technical staff.
- #strong[2020] Lead instructor for R for Reproducible Data Science, Software Carpentry course for WHOI JP/SSF students.
- #strong[2020] Certified as an instructor for The Carpentries.
- #strong[2020] Created WHOI Data Science Slack.
- #strong[2019] Occasional assistance teaching R in NES-LTER summer lecture series.
- #strong[2018] Assisted with Data Carpentry course in introductory R programming.

== Service
<service>
- #strong[2022 -- present] WHOI Technical Ladder Review Implementation Committee
- #strong[2022 -- present] WHOI Ocean Informatics Working Group
- #strong[2020 -- present] WHOI Technical Staff Mentoring Group
- #strong[2024 -- 2025] WHOI Workplace Climate Committee
- #strong[2019 -- 2022] WHOI Technical Staff Committee
- #strong[2019] WHOI Technical Ladders Review Committee

== Awards
<awards>
- #strong[2024 -- 2025] Funding from APO for two two-day Carpentries workshops.
- #strong[2023] Joint funding from APO and DDVPSE for two two-day Carpentries workshops.
- #strong[2021] Technical Staff Training Award. Co-PI with Sarah Glancy and Joe Futrelle. Awarded funds to teach a 4h workshop on relational databases and SQL for WHOI technical staff.
- #strong[2020] Technical Staff Training Award. Lead PI with Amber York, Karen Soenen, and Stace Beaulieu. Awarded funds for three short domain-specific data science workshops and one two-day workshop in reproducible research with R.
- #strong[2019] Technical Staff Training Award. Co-PI with Stace Beaulieu, Amber York, and Karen Soenen to become certified data science instructors for the Carpentries and deliver data science training workshops.
- #strong[2009] Mellon Joint Initiatives Award. Joint award with Laura Robinson to develop a method for direct sputtering of carbonates for AMS.
- #strong[2004] Arctic Climate and Terrestrial Ecosystems Summer Workshop, International Arctic Research Center, University of Alaska, Fairbanks. Workshop and travel expenses.
- #strong[2003] Center for Accelerator Mass Spectrometry, Lawrence Livermore National Laboratory. Use of sample preparation facility and AMS data.
- #strong[2003] Hudson River Foundation, Graduate fellowship.
- #strong[2003] Gloria Radke Memorial Prize, Department of Geosciences, University of Massachusetts.

== Professional Affiliations
<professional-affiliations>
- American Geophysical Union (Biogeosciences Section)
- Symposium of Northeastern Accelerator Personnel (SNEAP)

== Publications
<publications>
Peer-reviewed journal articles, managed in #NormalTok("references.bib"); (kept up to date from ORCID; see #NormalTok("scripts/update_references.py");).

#block[
#block[
Barry, P. H., Moor, J. M. de, Broadley, M. W., Seltzer, A. M., Bekaert, D. V., Patil, K., Bartels, C. G. E., Young, E. D., Longworth, B. E., Barosa, B., Bastianoni, A., Bastoni, D., Cascone, M., Turner, S. J., Tyne, R. L., Anderson, M., Li, K., Curtice, J., Kumar, N., … Giovannelli, D. (2025). Carbon, nitrogen, and noble gas isotopes reveal deep volatile signatures in thermal springs in the Central Volcanic Zone (CVZ) of the Andes. #emph[Earth and Planetary Science Letters], #emph[651], 119169. #link("https://doi.org/10.1016/j.epsl.2024.119169")

] <ref-barry2025andes>
#block[
Longworth, B. E., Burton, J. R., Pendleton, S. L., Moser, S. D., Roberts, M. L., & Kurz, M. D. (2022). Radiocarbon measurement of CO2 from carbonate minerals using a hybrid gas ion source with an open split interface. #emph[Nuclear Instruments and Methods in Physics Research Section B: Beam Interactions with Materials and Atoms], #emph[531], 49--55. #link("https://doi.org/10.1016/j.nimb.2022.08.013")

] <ref-longworth2022radiocarbon>
#block[
Hlavenka, J. D., Abrams, H., Roberts, M. L., Longworth, B. E., & Fallon, S. (2019). Improved C~efficiency and ion beam currents by modifying SNICS cathode material. #emph[Nuclear Instruments and Methods in Physics Research Section B: Beam Interactions with Materials and Atoms], #emph[439], 90--93. #link("https://doi.org/10.1016/j.nimb.2018.11.015")

] <ref-hlavenka2019snics>
#block[
Lardie Gaylord, M. C., Longworth, B. E., Murphy, K., Cobb, C., & McNichol, A. P. (2019). Annual radiocarbon measurements in a century-old European beech tree (Fagus sylvatica) from coastal northeastern North America. #emph[Nuclear Instruments and Methods in Physics Research Section B: Beam Interactions with Materials and Atoms], #emph[456], 264--270. #link("https://doi.org/10.1016/j.nimb.2019.03.029")

] <ref-lardiegaylord2019beech>
#block[
Roberts, M. L., Elder, K. L., Jenkins, W. J., Gagnon, A. R., Xu, L., Hlavenka, J. D., & Longworth, B. E. (2019). 14C blank corrections for 25--100 μg samples at the national ocean sciences AMS laboratory. #emph[Radiocarbon], #emph[61]\(5), 1403--1411. #link("https://doi.org/10.1017/rdc.2019.74")

] <ref-roberts2019blank>
#block[
Jenkins, W. J., Lott, D. E., German, C. R., Cahill, K. L., Goudreau, J., & Longworth, B. (2018). The deep distributions of helium isotopes, radiocarbon, and noble gases along the U.S. GEOTRACES East Pacific Zonal Transect (GP16). #emph[Marine Chemistry], #emph[201], 167--182. #link("https://doi.org/10.1016/j.marchem.2017.03.009")

] <ref-jenkins2018geotraces>
#block[
Hlavenka, J. D., Abrams, H., Roberts, M. L., & Longworth, B. E. (2017). Increased AMS Ion Source Efficiency and Ion Currents by Modifying SNICS Cathode Material and Geometry. #emph[Physics Procedia], #emph[90], 17--21. #link("https://doi.org/10.1016/j.phpro.2017.09.011")

] <ref-hlavenka2017caari>
#block[
Jenkins, W. J., Lott, D. E., Longworth, B. E., Curtice, J. M., & Cahill, K. L. (2015). The distributions of helium isotopes and tritium along the U.S. GEOTRACES North Atlantic sections (GEOTRACES GAO3). #emph[Deep Sea Research Part II: Topical Studies in Oceanography], #emph[116], 21--28. #link("https://doi.org/10.1016/j.dsr2.2014.11.017")

] <ref-jenkins2015geotracesnat>
#block[
Longworth, B. E., Reden, K. F. von, Long, P., & Roberts, M. L. (2015). A high output, large acceptance injector for the NOSAMS Tandetron AMS system. #emph[Nuclear Instruments and Methods in Physics Research Section B: Beam Interactions with Materials and Atoms], #emph[361], 211--216. #link("https://doi.org/10.1016/j.nimb.2015.04.005")

] <ref-longworth2015injector>
#block[
Longworth, B. E., Robinson, L. F., Roberts, M. L., Beaupre, S. R., Burke, A., & Jenkins, W. J. (2013). Carbonate as sputter target material for rapid 14C AMS. #emph[Nuclear Instruments and Methods in Physics Research Section B: Beam Interactions with Materials and Atoms], #emph[294], 328--334. #link("https://doi.org/10.1016/j.nimb.2012.05.014")

] <ref-longworth2013carbonate>
#block[
Roberts, M. L., Burton, J. R., Elder, K. L., Longworth, B. E., McIntyre, C. P., Reden, K. F. von, Han, B. X., Rosenheim, B. E., Jenkins, W. J., Galutschek, E., & McNichol, A. P. (2010). A High-Performance 14C Accelerator Mass Spectrometry System. #emph[Radiocarbon], #emph[52]\(2), 228--235. #link("https://doi.org/10.1017/s0033822200045252")

] <ref-roberts2010highperformance>
#block[
Longworth, B. E., Petsch, S. T., Raymond, P. A., & Bauer, J. E. (2007). Linking lithology and land use to sources of dissolved and particulate organic matter in headwaters of a temperate, passive-margin river system. #emph[Geochimica Et Cosmochimica Acta], #emph[71]\(17), 4233--4250. #link("https://doi.org/10.1016/j.gca.2007.06.056")

] <ref-longworth2007lithology>
#block[
Raymond, P. A., Bauer, J. E., Caraco, N. F., Cole, J. J., Longworth, B., & Petsch, S. T. (2004). Controls on the variability of organic matter and dissolved inorganic carbon ages in northeast US rivers. #emph[Marine Chemistry], #emph[92]\(1-4), 353--366. #link("https://doi.org/10.1016/j.marchem.2004.06.036")

] <ref-raymond2004organicmatter>
] <refs>
== Published Abstracts and Professional Talks
<published-abstracts-and-professional-talks>
- Longworth BE, Burton JR, Pendleton SL, Moser SD, Roberts ML, Kurz MD. (2022). Radiocarbon measurement of CO2 from carbonate minerals using a hybrid gas ion source with an open split interface. Poster presented at AMS-16, Sydney, Australia (remote).
- Longworth BE, Burton J, Hlavenka J, Roberts M. (2021). Progress with the NOSAMS Hybrid Gas Ion Source. Talk presented at SNEAP 2021, Woods Hole, MA.
- Longworth BE, Gagnon A, Burton J, Gospodinova K, Hlavenka J, McNichol A, Roberts M. Development of a Hybrid Gas Ion Source and Gas Inlet Systems at NOSAMS. Poster presented at the 23rd Radiocarbon Conference, Trondheim, Norway.
- Longworth BE, Roberts ML, von Reden KF, Jenkins WJ. Data acquisition and reduction at NOSAMS. Poster presented at AMS-14, Ottawa, Canada.
- Longworth BE. (2016). NOSAMS Tandetron operations and developments. Presented at NAPB 2016, Woods Hole, MA.
- Longworth BE. (2015). NOSAMS Tandetron operations and developments. Presented at NAPB 2015, Woods Hole, MA.
- Longworth BE. (2015). The Many Sources of the NOSAMS Tandetron AMS System. Presented at SNEAP 2015, Albuquerque, NM.
- Longworth BE. (2014). A New Source for the NOSAMS Tandetron. Presented at NAPB 2014, Woods Hole, MA.
- Longworth BE. (2014). Status of the NOSAMS Tandetron. Presented at NAPB 2014, Woods Hole, MA.
- Longworth BE, von Reden KF, Long PA, Roberts ML. A Large Acceptance Tandetron AMS System. Poster presented at AMS-13, Aix-en-Provence, France.
- Longworth BE, Gagnon AR, Long P, von Reden KF, McNichol AP, Roberts ML, Jenkins WJ, and NOSAMS. (2014). Status of Recent Activities and Operations at the US National Ocean Sciences AMS (NOSAMS) Facility. Poster presented at AMS-13, Aix-en-Provence, France.
- Longworth BE, von Reden KF. (2013). Upgrading the NOSAMS Tandetron AMS System from Simultaneous to Sequential Injection. Presented at SNEAP 2013, Woods Hole, MA.
- Longworth BE. (2013). Refurbishing the NOSAMS 3MV Tandetron Accelerator. Presented at SNEAP 2013, Woods Hole, MA.
- Longworth BE. (2012). NOSAMS Tandetron Operations 2012. Presented at NOSAMS Advisory and Policy Board Meeting, Woods Hole, MA.
- Longworth BE. (2011). NOSAMS Tandetron Operations 2011. Presented at NOSAMS Advisory and Policy Board Meeting, Woods Hole, MA.
- Longworth BE, Robinson LF. (2011). Rapid AMS Analysis of Carbonates by Direct Sputtering. Presented at AMS-12, Wellington, NZ.
- Longworth BE, Gagnon AR, Long P, McIntyre CP, von Reden KF, McNichol AP, Roberts ML, Jenkins WJ, and NOSAMS. (2011). Status and Plans at the US National Ocean Sciences AMS Facility. Poster presented at AMS-12, Wellington, NZ.
- Longworth BE. (2010). NOSAMS Tandetron Operations 2010. Presented at NOSAMS Advisory and Policy Board Meeting, Woods Hole, MA.
- Longworth BE, Robinson LF. (2010). Rapid Radiocarbon Analysis of Carbonates by Direct Sputtering. Presented at NOSAMS Advisory and Policy Board Meeting, Woods Hole, MA.
- Longworth BE. (2009). A New Data Acquisition System for NOSAMS. Presented at SNEAP 2009, Tucson, AZ.
- Longworth BE. (2009). NOSAMS Tandetron Operations 2009. Presented at NOSAMS Advisory and Policy Board Meeting, Woods Hole, MA.
- Gagnon AR, Longworth BE, McNichol AP, Xu L, Roberts ML, von Reden K, Elder K, Jenkins W, and NOSAMS. (2008). Recent Activities and Operations at The National Ocean Sciences AMS (NOSAMS) Facility. Presented at AMS-11, Rome, Italy.
- Roberts ML, Burton JR, Longworth BE, Long P, von Reden KF. SNEAP 2008 Lab Report. Presented at SNEAP, Ann Arbor, MI.
- Longworth BE. (2007). Shielding and circuit protection in high-voltage environments. Presented at the Symposium of Northeastern Accelerator Personnel, Salt Lake City, UT.
- Longworth BE, Long P, Trowbridge N, von Reden K, Roberts M. (2007). AMS Operations. Presented to NOSAMS Advisory Panel Board Meeting, Woods Hole, MA.
- Longworth BE, Roberts ML, Long P, von Reden KF, Rosenheim BE, Galutschek E. (2007). NOSAMS Lab Report. Presented at the Symposium of Northeastern Accelerator Personnel, Salt Lake City, UT.
- Longworth BE, Petsch ST, Raymond PA. (2006). Watershed Sources of Aged Riverine Organic Matter to the Hudson-Mohawk River System. Poster presented at AGU Fall Meeting, San Francisco, CA.
- Longworth BE, Petsch ST, Raymond PA. (2003). Ancient sedimentary organic matter in a modern riverine carbon cycle: Hudson-Mohawk River system, New York, USA. Poster presented at INQUA, Reno, NV.
- Longworth BE, Petsch ST, Raymond PA. (2003). Ancient organic matter sources to the Hudson-Mohawk River system: Implications of riverine transport of ancient organic matter for the global biogeochemical carbon cycle. Poster presented at AGU Fall Meeting, San Francisco, CA.
