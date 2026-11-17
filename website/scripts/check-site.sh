#!/usr/bin/env bash
# Validate the actual GitHub Pages output with Bash, jq and libxml2's HTML parser.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../../tool/documentation/common.sh"
need xmllint
SITE=$(cd "${DDDART_SITE_ROOT:-$SCRIPT_DIR/..}" && pwd)
REPO=$(cd "${DDDART_SITE_REPO_ROOT:-$SITE/..}" && pwd)
DIST="$SITE/dist"
ORIGIN=https://continuousimagination.github.io
BASE=/dddart/
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dddart-site-check.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
[[ -d "$DIST" ]] || fail 'No HTML output. Build the website first.'

xpath() {
  local result=0
  xmllint --html --nonet --nowarning --xpath "$2" "$1" 2> "$WORK/xml-errors" || result=$?
  # libxml2 uses 10 for a valid, empty node-set.
  if [[ $result != 0 && $result != 10 ]]; then cat "$WORK/xml-errors" >&2; fail "Cannot parse HTML: $1"; fi
}

find "$DIST" -type f -name '*.html' | LC_ALL=C sort > "$WORK/pages.txt"
[[ -s "$WORK/pages.txt" ]] || fail 'No HTML output. Build the website first.'
while IFS= read -r path; do
  relative=${path#"$DIST/"}
  public="$BASE$relative"; public=${public%index.html}
  xpath "$path" '//*/@id' > "$WORK/ids"
  xpath "$path" '//a/@href | //link/@href | //img/@src | //script/@src | //source/@src' > "$WORK/references"
  xpath "$path" 'string(//title)' > "$WORK/title"
  xpath "$path" 'string(//meta[@name="description"]/@content)' > "$WORK/description"
  xpath "$path" 'string(//link[@rel="canonical"]/@href)' > "$WORK/canonical"
  xpath "$path" 'count(//h1)' > "$WORK/headings"
  jq -n --arg path "$relative" --arg public "$public" \
    --rawfile ids "$WORK/ids" --rawfile references "$WORK/references" \
    --rawfile title "$WORK/title" --rawfile description "$WORK/description" \
    --rawfile canonical "$WORK/canonical" --rawfile headings "$WORK/headings" \
    "$DOC_JQ "'
    def attributes: [scan("=\"([^\"]*)\"")|.[0]|html_decode];
    {path:$path, public:$public, ids:($ids|attributes), references:($references|attributes),
     title:($title|trim), description:($description|trim), canonical:($canonical|trim), h1:($headings|trim|tonumber)}'
done < "$WORK/pages.txt" | jq -s '.' > "$WORK/pages.json"

jq -e --arg origin "$ORIGIN" "$DOC_JQ "'
  reduce .[] as $page (true;
    require($page.h1 == 1; $page.path+": expected one h1") |
    require(($page.title|length)>0 and ($page.description|length)>0; $page.path+": missing title/description") |
    require($page.canonical == ($origin+$page.public); $page.path+": incorrect canonical URL") |
    require(($page.ids|length) == ($page.ids|unique|length); $page.path+": duplicate id"))' "$WORK/pages.json" >/dev/null

jq -r '.[] as $page | $page.references[] | [$page.path,$page.public,.]|@tsv' "$WORK/pages.json" > "$WORK/links.tsv"
reference_count=0
while IFS=$'\t' read -r page public reference; do
  reference_count=$((reference_count + 1))
  case "$reference" in
    https://github.com/continuousimagination/dddart/blob/*|https://github.com/continuousimagination/dddart/tree/*|https://github.com/continuousimagination/dddart/edit/*)
      target=${reference#https://github.com/continuousimagination/dddart/}; target=${target#*/}; target=${target#*/}
      target=$(url_decode "${target%%[\?#]*}")
      target=$(jq -nr --arg path "$target" "$DOC_JQ \$path|normalize_path")
      [[ -e "$REPO/$target" ]] || fail "$page: missing repository source $reference"
      continue;;
    "$ORIGIN"/*) target=${reference#"$ORIGIN"};;
    http://continuousimagination.github.io/*) target=${reference#http://continuousimagination.github.io};;
    //continuousimagination.github.io/*) target=${reference#//continuousimagination.github.io};;
    *:*|//*) continue;;
    /*) target=$reference;;
    \#*|\?*) target="$public$reference";;
    *) target="${public%/*}/$reference";;
  esac
  case "$target" in "$BASE"*) ;; *) fail "$page: link escapes Pages subpath: $reference";; esac
  fragment=''
  if [[ "$target" == *'#'* ]]; then fragment=$(url_decode "${target#*#}"); target=${target%%#*}; fi
  target=$(url_decode "${target%%\?*}"); target=${target#"$BASE"}
  target=$(jq -nr --arg path "$target" "$DOC_JQ \$path|normalize_path")
  [[ ! -d "$DIST/$target" ]] || target="${target:+$target/}index.html"
  [[ -f "$DIST/$target" ]] || fail "$page: missing local target $reference"
  if [[ -n "$fragment" && "$target" == *.html ]]; then
    jq -e --arg target "$target" --arg fragment "$fragment" \
      '[.[]|select(.path == $target)|.ids[]]|index($fragment) != null' "$WORK/pages.json" >/dev/null ||
      fail "$page: missing fragment $reference"
  fi
done < "$WORK/links.tsv"

doc_count=$(find "$SITE/src/content/docs" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
jq -e --argjson count "$doc_count" --arg base "$BASE" --slurpfile pages "$WORK/pages.json" "$DOC_JQ "'
  require(length == $count; "Search index and source-document counts differ") |
  require(length == (map(.url)|unique|length); "Search index has duplicate URLs") |
  reduce .[] as $entry (true;
    require(all(["title","description","section","url","text"][]; ($entry[.]//""|length)>0); "Incomplete search entry") |
    require(($entry.url|startswith($base)); "Search URL escapes Pages subpath") |
    ($entry.url|ltrimstr($base)|rtrimstr("/")) as $relative |
    require(any($pages[0][]; .path == ($relative+"/index.html")); "Search points to missing page: "+$entry.url))' "$DIST/search-index.json" >/dev/null
printf 'Checked %s HTML pages, %s links/assets, and %s searchable guides. All checks passed.\n' \
  "$(jq length "$WORK/pages.json")" "$reference_count" "$doc_count"
