"""Replace references into the supplement with plain numbers.

    latexpand journals/plos/plos.tex | python tools/supp-refs.py build/supp-labels.tex

Journals receive the supplement as a separate PDF, so a submitted .tex cannot
look up \\ref{S:...} itself. This replaces each \\ref{S:...} (and \\eqref) with
the number LaTeX gave it in the supplement build, and removes the \\newlabel
lines the other builds use for those references. Standard library only.
"""

import re
import sys


def main():
    labels = {}
    with open(sys.argv[1], encoding="utf-8") as f:
        for line in f:
            m = re.match(r"\\newlabel\{(S:[^}]*)\}\{\{([^}]*)\}", line)
            if m:
                labels[m.group(1)] = m.group(2)

    tex = sys.stdin.read()
    tex = re.sub(r"^\\newlabel\{S:.*\n", "", tex, flags=re.MULTILINE)

    def number(m):
        eq, label = m.groups()
        if label not in labels:
            sys.exit(f"supp-refs: no number for {label}; is it labelled in supplement.tex?")
        return f"({labels[label]})" if eq else labels[label]

    sys.stdout.write(re.sub(r"\\(eq)?ref\{(S:[^}]*)\}", number, tex))


if __name__ == "__main__":
    main()
