# Builds for the paper. `make help` lists the targets.
# Written for GNU make 3.81 (the version macOS ships), so no newer features.
#
# Each version is a wrapper (targets/<name>.tex or journals/<name>/<name>.tex)
# compiled with latexmk. Intermediate files stay in build/; finished PDFs,
# bundles and the Word copy are copied to output/.

BUILD   := build
OUT     := output
LATEXMK := latexmk
# Only used for submission bundles. Any Python 3 will do (standard library
# only), e.g. make PYTHON=python3.
PYTHON  ?= uv run --quiet --no-project python

CORE := preprint review supplement
# Every folder in journals/ is a journal target: journals/<name>/<name>.tex,
# its class/style files and an optional journal.mk with extra settings.
JOURNALS := $(notdir $(wildcard journals/*))

# Citation style for .docx output: a file in pandoc/ (nature, plos, bioinformatics).
CSL ?= nature
# Git revision `make diff` compares against, and the target it diffs.
OLD ?= submitted
DIFF_TARGET ?= review

TEX_SOURCES := paper.tex metadata.tex macros.tex preamble.tex refs.bib
FIGURES     := $(wildcard figures/*.pdf)
SUPP_LABELS := $(BUILD)/supp-labels.tex
VERSION     := $(BUILD)/version.tex

wrapper = $(if $(filter $(1),$(JOURNALS)),journals/$(1)/$(1).tex,targets/$(1).tex)

.PHONY: all help $(CORE) $(JOURNALS) response journals bundles docx check \
        check-body diff versions clean FORCE
.DELETE_ON_ERROR:
.SECONDARY:

all: $(addprefix $(OUT)/,$(addsuffix .pdf,$(CORE))) check-body
	@# The supplement cites the preprint's labels; rerun it now they exist.
	@$(LATEXMK) -silent targets/supplement.tex && cp $(BUILD)/supplement.pdf $(OUT)/

help:
	@echo "make                  output/preprint.pdf, review.pdf, supplement.pdf"
	@echo "make preprint         preprint (bioRxiv / arXiv)"
	@echo "make review           review copy: line numbers, double spacing, git version"
	@echo "make supplement       supplement"
	@echo "make <journal>        journal-formatted PDF; journals: $(JOURNALS)"
	@echo "make journals         all journal PDFs"
	@echo "make bundle-<journal> output/bundle-<journal>.zip: submission source, test-compiled"
	@echo "make bundles          all journal bundles"
	@echo "make response         response to reviewers"
	@echo "make diff OLD=<rev>   changes-marked PDF against a git revision (DIFF_TARGET=review)"
	@echo "make docx CSL=nature  rough Word copy via pandoc"
	@echo "make check            portability rules for the text + docx conversion"
	@echo "make versions         record the toolchain in toolchain.txt"
	@echo "make clean            remove build/ and output/"

include $(wildcard journals/*/journal.mk)

$(CORE) $(JOURNALS) response: %: $(OUT)/%.pdf

journals: $(JOURNALS)

$(BUILD) $(OUT):
	mkdir -p $@

# --- PDFs --------------------------------------------------------------------

$(BUILD)/%.pdf: targets/%.tex $(TEX_SOURCES) $(FIGURES) $(SUPP_LABELS) | $(BUILD)
	$(LATEXMK) $<

define JOURNAL_RULE
$(BUILD)/$(1).pdf: journals/$(1)/$(1).tex $(wildcard journals/$(1)/*) $(TEX_SOURCES) $(FIGURES) $(SUPP_LABELS) | $(BUILD)
	$(LATEXMK) $$<
endef
$(foreach j,$(JOURNALS),$(eval $(call JOURNAL_RULE,$(j))))

$(BUILD)/review.pdf: targets/preprint.tex $(VERSION)
$(BUILD)/response.pdf: $(BUILD)/review.pdf $(BUILD)/supplement.pdf

# The supplement reads build/preprint.aux for its M: labels when it exists.
$(BUILD)/supplement.pdf: targets/supplement.tex supplement.tex metadata.tex macros.tex refs.bib $(FIGURES) | $(BUILD)
	$(LATEXMK) $<

$(OUT)/%.pdf: $(BUILD)/%.pdf | $(OUT)
	cp $< $@

# Supplement labels (S:...) for the main text, as plain \newlabel lines.
# Only replaced when they change, so the main PDFs don't rebuild needlessly.
$(SUPP_LABELS): $(BUILD)/supplement.pdf
	@sed -n '/^\\newlabel{S:/p' $(BUILD)/supplement.aux > $@.tmp
	@if cmp -s $@.tmp $@; then rm $@.tmp; else mv $@.tmp $@; fi

$(VERSION): FORCE | $(BUILD)
	@v=$$(git describe --always --dirty 2>/dev/null || echo unversioned); \
	if [ "$$(cat $@ 2>/dev/null)" != "$$v" ]; then echo "$$v" > $@; fi

FORCE:

# --- submission bundles ------------------------------------------------------
# The journal wrapper flattened into one .tex with the bibliography pasted in
# and references into the supplement replaced by plain numbers, the figures it
# uses (named after their fig: labels, in the format its journal.mk sets;
# TIFFs are renamed Fig1.tif, Fig2.tif, ...), the class/style files from its
# folder and the supplement. The bundle is compiled on its own before zipping
# to prove it is self-contained.

bundles: $(addprefix bundle-,$(JOURNALS))

bundle-%: $(OUT)/bundle-%.zip ;

$(OUT)/bundle-%.zip: $(BUILD)/%.pdf $(BUILD)/supplement.pdf tools/supp-refs.py | $(OUT)
	rm -rf $(BUILD)/bundle-$* $@
	mkdir -p $(BUILD)/bundle-$*
	latexpand --expand-bbl $(BUILD)/$*.bbl journals/$*/$*.tex | \
	  $(PYTHON) tools/supp-refs.py $(SUPP_LABELS) > $(BUILD)/bundle-$*/$*.tex
	sed -n 's/^\\newlabel{fig:\([^}]*\)}{{\([^}]*\)}.*/\1 \2/p' $(BUILD)/$*.aux | \
	while read name num; do \
	  if [ "$(or $(BUNDLE_FIGURES_$*),pdf)" = tif ]; then \
	    cp figures/$$name.tif $(BUILD)/bundle-$*/Fig$$num.tif; \
	  else \
	    cp figures/$$name.pdf $(BUILD)/bundle-$*/; \
	  fi; \
	done
	cp $(BUILD)/supplement.pdf $(filter-out %.tex %.mk,$(wildcard journals/$*/*)) $(BUILD)/bundle-$*/
	cd $(BUILD)/bundle-$* && \
	  pdflatex -interaction=nonstopmode -halt-on-error $*.tex > /dev/null && \
	  pdflatex -interaction=nonstopmode -halt-on-error $*.tex > /dev/null
	rm -f $(BUILD)/bundle-$*/$*.aux $(BUILD)/bundle-$*/$*.log $(BUILD)/bundle-$*/$*.out
	cd $(BUILD) && zip -qr $(CURDIR)/$@ bundle-$*
	@echo "Wrote $@"

# --- Word, checks, diffs -----------------------------------------------------

docx: $(OUT)/preprint.docx

# Flattened first, so the \cmidrule lines pandoc cannot parse can be dropped;
# label numbers come from the .aux files via the Lua filter.
$(OUT)/preprint.docx: $(BUILD)/preprint.pdf pandoc/$(CSL).csl pandoc/resolve-refs.lua | $(OUT)
	latexpand targets/preprint.tex | \
	  sed -E 's/\\cmidrule(\([a-z]*\))?\{[^}]*\}//g' | \
	  pandoc --from latex --citeproc --bibliography refs.bib \
	    --csl pandoc/$(CSL).csl --lua-filter pandoc/resolve-refs.lua \
	    -M aux=$(BUILD)/preprint.aux,$(SUPP_LABELS) \
	    --resource-path=.:figures --default-image-extension=png -o $@

# The text must stay in the subset every version and pandoc understand.
# The source scan runs first so its message isn't hidden by a LaTeX error.
check: check-body docx
	@echo "check: text uses only portable constructs; docx conversion succeeded"

check-body:
	@if grep -nE '\\(citet|cref|Cref|SI|usepackage|newcommand)[^a-zA-Z]|tikzpicture|minted' \
	    paper.tex supplement.tex; then \
	  echo "check: the lines above use something not every version supports (see README)"; \
	  exit 1; \
	fi

# Both versions are flattened with latexpand (latexdiff's own --flatten looks
# for \input files relative to the target file, not the project root).
diff: $(BUILD)/$(DIFF_TARGET).pdf | $(OUT)
	rm -rf $(BUILD)/diff-old
	mkdir -p $(BUILD)/diff-old
	git archive $(OLD) | tar -x -C $(BUILD)/diff-old
	cd $(BUILD)/diff-old && latexpand $(call wrapper,$(DIFF_TARGET)) > ../diff-old.tex
	latexpand $(call wrapper,$(DIFF_TARGET)) > $(BUILD)/diff-new.tex
	latexdiff $(BUILD)/diff-old.tex $(BUILD)/diff-new.tex > $(BUILD)/diff-$(DIFF_TARGET).tex
	$(LATEXMK) $(BUILD)/diff-$(DIFF_TARGET).tex
	cp $(BUILD)/diff-$(DIFF_TARGET).pdf $(OUT)/
	@echo "Wrote $(OUT)/diff-$(DIFF_TARGET).pdf"

# --- housekeeping ------------------------------------------------------------

versions:
	@{ pdflatex --version | head -1; bibtex --version | head -1; \
	   latexmk -v | sed -n '/Version/{p;q;}'; latexpand --version | head -1; \
	   latexdiff --version 2>&1 | head -1; pandoc --version | head -1; \
	   $(PYTHON) --version; } > toolchain.txt
	@cat toolchain.txt

clean:
	rm -rf $(BUILD) $(OUT)
