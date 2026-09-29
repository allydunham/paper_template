# Nature Portfolio puts Methods after the Discussion. Move paper.tex's
# \section{Methods} (up to the next \section) to the end.

$(BUILD)/nature.pdf: $(BUILD)/paper-methods-last.tex

$(BUILD)/paper-methods-last.tex: paper.tex | $(BUILD)
	awk '/^\\section[{]/ { m = ($$0 ~ /^\\section[{]Methods[}]/) } \
	     m { methods = methods $$0 "\n"; next } { print } \
	     END { printf "%s", methods }' paper.tex > $@
