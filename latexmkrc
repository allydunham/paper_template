# latexmk settings shared by every target. Run latexmk from the project root
# (the Makefile does this) so that \input and figure paths resolve from here.

$pdf_mode = 1;                 # pdflatex: what journal submission systems use
$out_dir  = 'build';
$bibtex_use = 2;               # run bibtex when needed; clean .bbl with -C

$pdflatex = 'pdflatex -interaction=nonstopmode -halt-on-error -file-line-error %O %S';

# Journal classes and .bst files in journals/<name>/. Absolute, because
# latexmk runs bibtex from inside the build directory.
use Cwd;
ensure_path('TEXINPUTS', getcwd() . '/journals//');
ensure_path('BSTINPUTS', getcwd() . '/journals//');
