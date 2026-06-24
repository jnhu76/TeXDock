#!/usr/bin/env bash
set -euo pipefail

echo "== TeX binaries =="
which latexmk
which pdflatex
which xelatex
which lualatex
which biber
which makeindex

which xindy || true
which makeglossaries || true
which dvisvgm || true

latexmk -v
biber --version

echo "== Python / Pygments =="
which python3
python3 --version
which pygmentize
pygmentize -V

echo "== latexindent / Perl modules =="
which latexindent
latexindent --version || true

perl -MYAML::Tiny -e 'print "YAML::Tiny ok\n"'
perl -MFile::HomeDir -e 'print "File::HomeDir ok\n"'
perl -MFile::Which -e 'print "File::Which ok\n"'
perl -MUnicode::GCString -e 'print "Unicode::GCString ok\n"'
perl -MLog::Log4perl -e 'print "Log::Log4perl ok\n"'
perl -MIPC::System::Simple -e 'print "IPC::System::Simple ok\n"'
perl -MCapture::Tiny -e 'print "Capture::Tiny ok\n"'

echo "== Shell escape tools =="
which inkscape
inkscape --version | head -n1 || true

which rsvg-convert
rsvg-convert --version | head -n1 || true

which dot
dot -V || true

which gnuplot
gnuplot --version || true

which asy
asy --version | head -n2 || true

which qpdf
qpdf --version | head -n1 || true

which pdftoppm
pdftoppm -v 2>&1 | head -n1 || true

which pdfinfo
pdfinfo -v 2>&1 | head -n1 || true

if command -v magick >/dev/null 2>&1; then
  magick -version | head -n2 || true
elif command -v convert >/dev/null 2>&1; then
  convert -version | head -n2 || true
else
  echo "imagemagick command not found"
  exit 1
fi

echo "== Fontconfig quick checks =="
fc-match "Noto Serif CJK SC"
fc-match "Noto Sans CJK SC"
fc-match "WenQuanYi Micro Hei"
fc-match "DejaVu Serif"
fc-match "Noto Color Emoji"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "== Compile minted with shell-escape =="
cat > minted-test.tex <<'EOF'
\documentclass{article}
\usepackage{minted}
\begin{document}
Hello minted.
\begin{minted}{python}
print("hello")
\end{minted}
\end{document}
EOF

latexmk -pdf -shell-escape -interaction=nonstopmode -halt-on-error minted-test.tex

echo "== Compile biber/biblatex =="
cat > biber-test.tex <<'EOF'
\documentclass{article}
\usepackage[backend=biber]{biblatex}
\addbibresource{refs.bib}
\begin{document}
Test citation \cite{knuth1984}.
\printbibliography
\end{document}
EOF

cat > refs.bib <<'EOF'
@book{knuth1984,
  author = {Donald E. Knuth},
  title = {The TeXbook},
  year = {1984},
  publisher = {Addison-Wesley}
}
EOF

latexmk -pdf -interaction=nonstopmode -halt-on-error biber-test.tex

echo "== Compile XeLaTeX CJK =="
cat > cjk-test.tex <<'EOF'
\documentclass{article}
\usepackage{xeCJK}
\setCJKmainfont{Noto Serif CJK SC}
\begin{document}
中文测试。Hello CJK.
\end{document}
EOF

latexmk -xelatex -interaction=nonstopmode -halt-on-error cjk-test.tex

echo "== Compile LuaLaTeX CJK =="
cat > lua-cjk-test.tex <<'EOF'
\documentclass{article}
\usepackage{luatexja-fontspec}
\setmainjfont{Noto Serif CJK SC}
\begin{document}
中文测试。Hello LuaLaTeX CJK.
\end{document}
EOF

latexmk -lualatex -interaction=nonstopmode -halt-on-error lua-cjk-test.tex

echo "== Complete TeXLive smoke test passed =="