#!/usr/bin/env bash
set -Eeuo pipefail
set -x

WORKDIR=/tmp/texlive-core-smoke

cleanup() {
  rm -rf "$WORKDIR"
}

mkdir -p "$WORKDIR"
cd "$WORKDIR"
trap cleanup EXIT

echo '== Core smoke 1: TeX engines =='
latex --version
xelatex --version
lualatex --version

echo '== Core smoke 2: required LaTeX packages =='
kpsewhich ctex.sty
kpsewhich xeCJK.sty
kpsewhich fontspec.sty
kpsewhich zhnumber.sty

echo '== Core smoke 3: latexmk =='
command -v latexmk
latexmk -v | head -n 1

echo '== Core smoke 4: font/cache tools =='
command -v fc-cache

if command -v luaotfload-tool >/dev/null 2>&1; then
  luaotfload-tool --version
else
  echo 'WARN: luaotfload-tool not found in PATH; skipping luaotfload-tool check.'
fi

echo '== Core smoke 5: minimal pdfLaTeX compile =='
cat > pdftex-test.tex <<'EOF'
\documentclass{article}
\begin{document}
Hello, TeX Live.

Math test: $E = mc^2$.
\end{document}
EOF

latex -interaction=nonstopmode -halt-on-error pdftex-test.tex
test -s pdftex-test.dvi

echo '== Core smoke 6: minimal XeLaTeX Chinese compile =='
cat > xetex-chinese-test.tex <<'EOF'
\documentclass{ctexart}
\begin{document}
你好，TeX Live。

English test.

数学测试：$E = mc^2$
\end{document}
EOF

xelatex -interaction=nonstopmode -halt-on-error xetex-chinese-test.tex
test -s xetex-chinese-test.pdf

echo '== Core smoke 7: latexmk XeLaTeX compile =='
rm -f xetex-chinese-test.aux xetex-chinese-test.log xetex-chinese-test.pdf

latexmk \
  -xelatex \
  -interaction=nonstopmode \
  -halt-on-error \
  xetex-chinese-test.tex

test -s xetex-chinese-test.pdf

echo '== Core smoke passed =='
