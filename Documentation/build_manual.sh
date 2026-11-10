#!/bin/sh
# Computes the examples and typesets the manual: pdflatex runs until the cross-references (the contents) are settled.
cd "$(dirname "$0")"
export TEXINPUTS="../Development:$TEXINPUTS"   # the common style, n4sd4q.sty
SRC=examples.wl OUT=examples wolfram -script ../Development/run_examples.wl > examples.log 2>&1 || exit 1
pdflatex -interaction=nonstopmode -halt-on-error Summa_Manual.tex > /dev/null || exit 1
for run in 2 3; do
  pdflatex -interaction=nonstopmode Summa_Manual.tex > /dev/null
  grep -q "Rerun to get" Summa_Manual.log || break
done
grep -E "Warning|Overfull|Error|missing example" Summa_Manual.log | grep -v "Font Warning" | head
rm -f Summa_Manual.aux Summa_Manual.out Summa_Manual.toc Summa_Manual.listing
