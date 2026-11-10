#!/bin/sh
# Checks that every command of the documents gives what the documents show, in fresh kernels:
#  - the showcase and the manual: their examples are run again and every output must equal the one in examples/;
#  - the guided tour Examples.wl runs as a script without messages;
#  - the first example of the README and every page of the wiki give what they show after each block
#    (Development/check_markdown.wl), the pages at the same time;
#  - the website is up to date with its sources (Development/make_site.py --check).
# Run from anywhere:  sh Development/check_docs.sh      (exit status 0 when everything passes)
cd "$(dirname "$0")/.." || exit 1
status=0
tmp=build/check_docs   # the outputs of this run (build/ is not versioned), overwritten by the next one
mkdir -p "$tmp"
for doc in Showcase Documentation; do
  SRC=$doc/examples.wl OUT=$tmp/$doc wolfram -script Development/run_examples.wl > $tmp/$doc.log 2>&1
  n=$(ls $doc/examples | wc -l)
  if diff -r -q $doc/examples $tmp/$doc > $tmp/$doc.diff; then echo "ok   $doc: $n files, all as published"
  else echo "FAIL $doc: outputs differ from the published ones:"; sed 's/^/     /' $tmp/$doc.diff; status=1; fi
done
out=$(wolfram -script Examples.wl 2>&1 | grep -v '^$')
if [ -z "$out" ]; then echo "ok   Examples.wl: runs without messages"; else echo "FAIL Examples.wl:"; echo "$out" | head -20; status=1; fi
wolfram -script Development/check_markdown.wl README.md "A first example" > $tmp/readme.log 2>&1 || status=1
grep -v '^$' $tmp/readme.log | sed 's/^/     /'
for page in wiki/*.md; do wolfram -script Development/check_markdown.wl "$page" > "$tmp/wiki_$(basename "$page").log" 2>&1 & done; wait
for page in wiki/*.md; do log="$tmp/wiki_$(basename "$page").log"; tail -1 "$log" | sed 's/^/     /'
  grep -q '^ok ' "$log" || { grep -v '^$' "$log" | head -20 | sed 's/^/     /'; status=1; }; done
python3 Development/make_site.py --check | sed 's/^/ok   /' || status=1
python3 Development/make_site.py --check > /dev/null 2>&1 || status=1
exit $status
