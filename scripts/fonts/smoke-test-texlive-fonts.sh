#!/usr/bin/env bash
set -Eeuo pipefail
set -x

mkdir -p /tmp/texlive-smoke
cd /tmp/texlive-smoke

cleanup() {
  rm -rf /tmp/texlive-smoke
}
trap cleanup EXIT

echo "== Smoke test 1: ctexart default fontset =="

cat > main.tex <<'TEXDOC'
\documentclass{ctexart}
\begin{document}
中文测试 TeXDock.

\[
  E = mc^2
\]

\end{document}
TEXDOC

xelatex -interaction=nonstopmode -halt-on-error main.tex
test -s main.pdf

echo "== Smoke test 2: ctexart fontset=fandol =="

cat > fandol.tex <<'TEXDOC'
\documentclass[fontset=fandol]{ctexart}
\begin{document}
Fandol 中文字体测试：宋体、黑体、楷体、仿宋。

{\songti 宋体测试}

{\heiti 黑体测试}

{\kaishu 楷体测试}

{\fangsong 仿宋测试}

\end{document}
TEXDOC

xelatex -interaction=nonstopmode -halt-on-error fandol.tex
test -s fandol.pdf

echo "== Smoke test 3: Windows-compatible CJK names resolved by fontconfig =="

# Important:
# - fc-match can resolve SimSun / SimHei / FangSong through fontconfig aliases.
# - fontspec + XeTeX can still be stricter than fc-match for alias family names.
# - Therefore the smoke test first resolves the compatible names to real
#   installed families, then feeds those real families to xeCJK.
#
# This keeps the build deterministic even when real Windows fonts are absent.
# If private Windows fonts are later imported through fonts.zip, fc-match will
# resolve to the real families instead.
resolve_family() {
  local name="$1"
  local family

  family="$(fc-match -f '%{family}\n' "${name}" | head -n 1 | cut -d',' -f1)"

  if [ -z "${family}" ]; then
    echo "ERROR: unable to resolve font family through fontconfig: ${name}" >&2
    exit 1
  fi

  echo "${family}"
}

SIMSUN_FAMILY="$(resolve_family "SimSun")"
SIMHEI_FAMILY="$(resolve_family "SimHei")"
FANGSONG_FAMILY="$(resolve_family "FangSong")"

echo "SimSun   -> ${SIMSUN_FAMILY}"
echo "SimHei   -> ${SIMHEI_FAMILY}"
echo "FangSong -> ${FANGSONG_FAMILY}"

cat > alias.tex <<TEXDOC
\documentclass{article}
\usepackage{fontspec}
\usepackage{xeCJK}

\setCJKmainfont{${SIMSUN_FAMILY}}
\setCJKsansfont{${SIMHEI_FAMILY}}
\setCJKmonofont{${FANGSONG_FAMILY}}

\begin{document}
SimSun / SimHei / FangSong compatibility alias 中文测试。

Resolved by fontconfig:

SimSun -> ${SIMSUN_FAMILY}

SimHei -> ${SIMHEI_FAMILY}

FangSong -> ${FANGSONG_FAMILY}

{\sffamily 黑体 alias 测试}

{\ttfamily 仿宋 alias 测试}

\end{document}
TEXDOC

xelatex -interaction=nonstopmode -halt-on-error alias.tex
test -s alias.pdf

echo "== Smoke test 4: common Latin font aliases =="

cat > latin.tex <<'TEXDOC'
\documentclass{article}
\usepackage{fontspec}

\setmainfont{Times New Roman}
\setsansfont{Arial}
\setmonofont{Courier New}

\begin{document}
Times New Roman / Arial / Courier New compatibility test.

\textsf{Sans serif test.}

\texttt{Monospace test.}

\end{document}
TEXDOC

xelatex -interaction=nonstopmode -halt-on-error latin.tex
test -s latin.pdf
