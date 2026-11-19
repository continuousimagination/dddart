#!/usr/bin/env bash
# Mutate built HTML/search fixtures and require the real site checker to reject them.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../../tool/documentation/common.sh"
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dddart-site-faults.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
COUNT=0
[[ -f "$ROOT/website/dist/index.html" ]] || fail 'Build the website before running site regression tests.'
mkdir -p "$WORK/site"
export DDDART_SITE_ROOT="$WORK/site" DDDART_SITE_REPO_ROOT="$ROOT"
fresh() { rm -rf "$WORK/site/dist"; cp -R "$ROOT/website/dist" "$WORK/site/dist"; }
change_html() {
  jq -jRs "$1" "$WORK/site/dist/index.html" > "$WORK/changed"
  mv "$WORK/changed" "$WORK/site/dist/index.html"
}
change_search() {
  jq "$1" "$WORK/site/dist/search-index.json" > "$WORK/changed"
  mv "$WORK/changed" "$WORK/site/dist/search-index.json"
}
reject() {
  if bash "$SCRIPT_DIR/check-site.sh" > "$WORK/result" 2>&1; then fail "Expected site failure: $1"; fi
  grep -Fq "$1" "$WORK/result" || { cat "$WORK/result" >&2; fail "Missing site diagnostic: $1"; }
  COUNT=$((COUNT + 1)); printf 'PASS %s\n' "$1"
}
# libxml2 versions differ in whether XPath scalar output ends with a newline.
# Exercise the real checker/parser with newline-terminated output on every host.
fresh
mkdir -p "$WORK/bin"
REAL_XMLLINT=$(command -v xmllint)
export REAL_XMLLINT
cat > "$WORK/bin/xmllint" <<'SH'
#!/usr/bin/env bash
"$REAL_XMLLINT" "$@"
result=$?
printf '\n'
exit "$result"
SH
chmod +x "$WORK/bin/xmllint"
PATH="$WORK/bin:$PATH" bash "$SCRIPT_DIR/check-site.sh" > "$WORK/result" 2>&1 || {
  cat "$WORK/result" >&2; fail 'Newline-terminated parser output was rejected'
}
COUNT=$((COUNT + 1)); printf 'PASS newline-terminated parser output\n'
fresh
change_html 'sub("<h1";"<h2")|sub("</h1>";"</h2>")'
reject 'expected one h1'
fresh
change_html 'sub("<title>[^<]*</title>";"<title></title>")'
reject 'missing title/description'
fresh
change_html 'sub("</body>";"<span id=\"main-content\"></span></body>")'
reject 'duplicate id'
fresh
change_html 'sub("rel=\"canonical\" href=\"[^\"]+\"";"rel=\"canonical\" href=\"https://example.invalid/\"")'
reject 'incorrect canonical URL'
fresh
change_html 'sub("</body>";"<a href=\"/outside-pages/\">bad</a></body>")'
reject 'link escapes Pages subpath'
fresh
change_html 'sub("</body>";"<a href=\"/dddart/docs/missing/\">bad</a></body>")'
reject 'missing local target'
fresh
change_html 'sub("</body>";"<a href=\"/dddart/docs/events/#missing\">bad</a></body>")'
reject 'missing fragment'
fresh
change_html 'sub("</body>";"<a href=\"https://github.com/continuousimagination/dddart/blob/main/missing.dart\">bad</a></body>")'
reject 'missing repository source'
fresh
sed 's@/docs/quickstarts/core/README.md@/README.md@' \
  "$WORK/site/dist/docs/getting-started/index.html" > "$WORK/changed"
mv "$WORK/changed" "$WORK/site/dist/docs/getting-started/index.html"
reject 'Published guides must link to their source revision'
fresh
change_search '.[1].url = .[0].url'
reject 'Search index has duplicate URLs'
fresh
change_search '.[0:1]'
reject 'Search index and source-document counts differ'
fresh
change_search 'del(.[0].text)'
reject 'Incomplete search entry'
fresh
change_search '.[0].url = "/dddart/docs/missing/"'
reject 'Search points to missing page'
printf 'All %s site regression tests passed.\n' "$COUNT"
