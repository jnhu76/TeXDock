#!/usr/bin/env bash
set -Eeuo pipefail

PDF_WORKER="/overleaf/node_modules/pdfjs-dist/build/pdf.worker.mjs"

if [ ! -f "$PDF_WORKER" ]; then
  echo "ERROR: pdf.worker.mjs not found: $PDF_WORKER" >&2
  exit 1
fi

echo "Patching pdfjs-dist worker wasm imports: $PDF_WORKER"

sed -i \
  "s#new URL('qcms_bg.wasm', import.meta.url)#new URL(/* webpackIgnore: true */ 'qcms_bg.wasm', import.meta.url)#g" \
  "$PDF_WORKER"

sed -i \
  's#new URL("openjpeg.wasm", import.meta.url).href#new URL(/* webpackIgnore: true */ "openjpeg.wasm", import.meta.url).href#g' \
  "$PDF_WORKER"

grep -nE 'qcms_bg\.wasm|openjpeg\.wasm' "$PDF_WORKER"