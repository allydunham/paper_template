# Biology Latex Paper template

A LaTeX template that builds several versions of a paper from one source:

- Styled preprint
- Simple review copy
- Supplement
- Example journal versions (Nature Portfolio, PLOS, Bioinformatics included)
- Submission bundles
- Changes-marked diff
- Review response log
- Word copy (imperfectly translated)

The example paper (`paper.tex`, `supplement.tex`, `metadata.tex`) describes the
template itself; build it with `make` and read `output/preprint.pdf`.

## Requirements

- TeX Live (pdflatex, bibtex, latexmk, latexpand, latexdiff)
- GNU make
- Pandoc 3
- Python 3 (submission bundles only)

## Starting a paper

1. Clone this repo and update remotes.
2. Write in three files:
   - `metadata.tex`: title, authors, affiliations, abstract, keywords and the
     back-matter statements (acknowledgements, funding, availability, etc.)
   - `paper.tex`: the main text
   - `supplement.tex`: the supplementary information
3. Add references to `refs.bib` and finished figures to `figures/`.
4. `make`, then look in `output/`.

## Builds

Finished files go to `output/`; everything intermediate stays in `build/`.

| Command | Output |
|---|---|
| `make` | `preprint.pdf`, `review.pdf`, `supplement.pdf` |
| `make preprint` | preprint: upload to bioRxiv; for arXiv, upload the source flattened with latexpand, with the figures and `build/preprint.bbl` |
| `make review` | review copy: line numbers, double spacing, git version in the date line |
| `make supplement` | supplement |
| `make nature` / `plos` / `bioinformatics` | journal-formatted PDF |
| `make journals` | all journal PDFs |
| `make bundle-<journal>` | `bundle-<journal>.zip`: the submission source (see How it works) |
| `make bundles` | all journal bundles |
| `make response` | response to reviewers, quoting line numbers from the review copy |
| `make diff OLD=submitted` | `diff-review.pdf`: changes since git revision `OLD` (`DIFF_TARGET=preprint` etc. to diff another version) |
| `make docx CSL=nature` | `preprint.docx`: rough Word copy (`CSL` = `nature`, `plos` or `bioinformatics`) |
| `make check` | portability rules for the text, plus the Word conversion |
| `make versions` | record tool versions in `toolchain.txt` |
| `make clean` | remove `build/` and `output/` |

Tag the version you submit (`git tag submitted`) so `make diff` has something to
compare against at revision time.

## How it works

Each version has a short wrapper, `targets/<name>.tex` or
`journals/<name>/<name>.tex`, that sets the document class and layout, defines
how `metadata.tex`'s authors are set in that class, and includes the shared
text. `make` compiles each wrapper with pdfLaTeX and BibTeX (latexmk).

The metadata stays as simple `\newcommand`s (`\papertitle`, `\paperabstract`,
`\paperauthors`, …), and the wrappers use them directly. Most journals accept
this: for instance PLOS says nothing about macros and OUP asks only that macros are few and
submitted with the manuscript. Nature Portfolio asks for personal macros to be
removed, which is a short job by hand at acceptance (see below).

A submission bundle is the journal wrapper flattened into one `.tex` (latexpand)
with the bibliography pasted in and references into the supplement written as
plain numbers (`tools/supp-refs.py`), plus the figures, the journal's class
and style files and the supplement PDF. It is compiled on its own before zipping
to prove it's self-contained.

## Layout

```
metadata.tex        title, authors, abstract, statements          } what you
paper.tex           main text                                     } write
supplement.tex      supplementary information                     }
refs.bib            bibliography
macros.tex          notation shortcuts (plain \newcommand only)
figures/            finished figures: .pdf (LaTeX), .png (Word), .tif (PLOS)
preamble.tex        the few packages the text needs; loaded by every main-text wrapper
targets/            core wrappers: preprint, review, supplement, response
journals/<name>/    one folder per journal: <name>.tex, class/style files, optional journal.mk
tools/supp-refs.py  writes supplement references as plain numbers in bundles
pandoc/             citation styles and the filter used for Word output
```

## Figures

Figures are made elsewhere and copied in, one file per format, named after the
figure's label: `figures/pipeline.pdf` for `\label{fig:pipeline}`. LaTeX uses the
`.pdf`, the Word copy the `.png`, and PLOS bundles the `.tif` (renamed
`Fig1.tif`, …). Only the formats a build uses need to exist.

## Writing guidelines

The text is compiled by several journal classes, by pandoc, and by submission systems running older TeX installations.
This makes the following guidelines helpful baselines but individual cases will vary.
By defauly `make` enforces the first two rules.

- **Cite with `\citep` only.** PLOS and Nature Portfolio use numbered styles whose
  `.bst` files don't support natbib's `\citet`. Write "as shown previously
  \citep{key}" rather than "\citet{key} showed".
- **No packages or macro definitions in `paper.tex` or `supplement.tex`.** Add
  macros to `macros.tex`, and packages to `preamble.tex` only if every journal
  class tolerates them. Avoid `cleveref`, `siunitx`, TikZ and `minted`.
- **Keep Methods as one `\section{Methods}`**, running to the next `\section`.
  The Nature build moves it to the end, as Nature Portfolio requires.
- **Refer to figures by bare name** (`\includegraphics{pipeline}`), without a
  path or extension: Editorial Manager flattens uploaded folders.
- **Prefix supplement labels with `S:`** (`\label{S:fig:growth}`) and cite them
  from the main text as `\ref{S:fig:growth}`. The supplement refers back to the
  main text with `M:` (`\ref{M:eq:logistic}`).
- **Mark lines you'll cite in a response** with `\linelabel{rev:name}` in
  `paper.tex`; cite them in `targets/response.tex` as `\ref{R:rev:name}`.
- Keep the abstract to one paragraph with no citations.

## Journals

The journal folders are working examples that show each journal's formatting
and the submission process. Publishers revise their templates, so treat a
folder as a starting point and update it by hand when you submit:

1. Download the publisher's current LaTeX template from its author guidelines.
2. Replace the class and `.bst` files in the folder with the new ones.
3. Compare the publisher's sample `.tex` with `<name>.tex`: class options,
   bibliography style, front-matter commands, back-matter headings. Update the
   wrapper to match.
4. `make <name> bundle-<name>`, and check the PDF against the author guidelines.

Notes on the examples:

- **Nature Portfolio** (`journals/nature/`): Springer Nature's `sn-jnl` class
  with the `sn-nature` reference style. `journal.mk` moves Methods to the end.
  Springer recommends pasting the `.bbl` into the `.tex`, which the bundle does.
- **PLOS** (`journals/plos/`): follows PLOS's LaTeX template, with three
  deliberate differences. natbib replaces `cite`, giving the same numbered
  output; section numbers are turned off in the wrapper rather than in the
  text; and figures are left out of the PDF, as PLOS requires, with
  `journal.mk` asking for TIFFs in the bundle. The author summary is written
  in `plos.tex`.
- **Bioinformatics** (`journals/bioinformatics/`): OUP's authoring template,
  author-year citations via `plainnat`. The structured abstract is written in
  `bioinformatics.tex`.

### Adding a journal

1. Copy the closest folder to `journals/<name>/`, rename its `.tex` to
   `<name>.tex`, and put the publisher's class and `.bst` files in it.
2. In `<name>.tex`, set the class, bibliography style and section layout from
   the publisher's sample file, and define `\paperauthor[3]`,
   `\correspondingauthor[4]` and `\paperaffiliation[5]` (arguments as in
   `metadata.tex`) to produce the class's author commands. The three examples
   show three different styles.
3. If the journal wants TIFF figures, add a `journal.mk` containing
   `BUNDLE_FIGURES_<name> := tif`.
4. `make <name> bundle-<name>`. The Makefile finds new folders automatically.

## Before final submission

The template gets a journal version most of the way; expect to tune the
accepted version by hand. Typically:

- Check the wrapper against the publisher's current template and author
  guidelines (see Journals above).
- If the journal asks for no personal macros (Nature Portfolio does), replace
  the `\paper…` commands in the bundle's `.tex` with their text, and the
  shortcuts from `macros.tex` with their definitions.
- Adjust anything the journal wants that the example doesn't do: section
  headings, statement order, figure legends placed after the references, and
  so on.

## Known limitations

- The Word copy is for sharing drafts, not for submission. Display equations are
  converted but not numbered (references to them are); tables lose their
  partial rules; affiliations are dropped.
  If word is needed for submission manual correction will likely be required.
- In the review build, `lineno` doesn't number display-equation lines.
- The supplement quotes equation and figure numbers from the preprint. If a
  journal version numbers them differently, check the supplement against it.
- The response letter quotes line numbers from the review copy. If reviewers
  saw a journal-generated PDF, check the numbers against that.

## Reproducibility

For each paper, commit the `journals/` folder you submit with, and the output
of `make versions`, so the paper can be rebuilt as submitted.

## Development

Two branches are used by default: `release` for a stable version and `dev` for the working copy.
Contributions are welcome via pull request.
The initial version was generated largely via LLM and then checked and somewhat refined by hand.
Ultimately the target is a visual document so the main test is the generated targets matching what
I want - make sure the same is true for any derived versions!
