#!/usr/bin/env bash
# Shared Bash helpers. jq handles text/JSON transformations; no extra runtime.
set -euo pipefail

fail() { printf '%s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Required tool missing: $1"; }
need jq

# Keep all paths relative to a declared root. Reject absolute paths and traversal.
safe_relative() {
  case "$1" in ''|/*|..|../*|*/../*|*/..|*\\*) fail "Unsafe relative path: $1";; esac
}
repository_files() {
  need git
  local root=$1 path
  if [[ -e "$root/.git" ]]; then
    while IFS= read -r -d '' path; do
      [[ -f "$root/$path" ]] || continue
      case "$path" in *$'\n'*|*$'\t'*) fail 'Control characters in repository paths are unsupported';; esac
      printf '%s\n' "$path"
    done < <(git -C "$root" ls-files -z --cached --others --exclude-standard)
  else
    (cd "$root" && find . \( -name .git -o -name .dart_tool -o -name node_modules -o -name build -o -name dist -o -name .astro -o -name coverage -o -name __pycache__ \) -prune -o -type f -print) | sed 's|^./||'
  fi | LC_ALL=C sort -u
}
# jq's raw file loader preserves trailing newlines (shell substitutions do not).
load_sources() {
  local root=$1 list=$2 destination=$3 path
  while IFS= read -r path; do
    jq -Rs --arg path "$path" '{key:$path,value:.}' "$root/$path"
  done < "$list" | jq -s 'from_entries' > "$destination"
}
url_decode() {
  local value=$1
  # Escape literal backslashes before interpreting only URI %XX bytes.
  value=${value//\\/\\\\}
  value=${value//%/\\x}
  printf '%b' "$value"
}
timeout_tool() {
  if command -v timeout >/dev/null 2>&1; then printf '%s\n' timeout
  elif command -v gtimeout >/dev/null 2>&1; then printf '%s\n' gtimeout
  else fail 'GNU timeout is required for execution checks (macOS: brew install coreutils)'; fi
}

# jq definitions shared by the documentation and HTML checks.
IFS= read -r -d '' DOC_JQ <<'JQ' || true
def require($ok; $message): if $ok then . else error($message) end;
def trim: sub("^[[:space:]]+";"") | sub("[[:space:]]+$";"");
def normalize_path:
  reduce split("/")[] as $part ([];
    if $part == "" or $part == "." then .
    elif $part == ".." then if length == 0 then error("Path escapes root") else .[:-1] end
    else . + [$part] end) | join("/");
def parent: split("/")[:-1] | join("/");
def doc_text($path):
  if $path|endswith(".dart") then
    ([scan("(?m)^[ \\t]*/// ?(.*)$") | .[0]] +
     [scan("(?s)/\\*\\*(.*?)\\*/") | .[0] | gsub("(?m)^[ \\t]*\\* ?";"")]) | join("\n")
  else . end;
def fence_pattern: "(?ms)^(?<fence>`{3,}|~{3,})(?<language>[\\w-]*)[^\\n]*\\n(?<body>.*?)^\\k<fence>[ \\t]*$";
def without_fences: gsub(fence_pattern; "");
def source_pattern: "(?s)<!-- dddart-source: (?<source>[^>\\n]+) -->\\n```(?<language>\\w+)\\n(?<body>.*?)\\n```\\n<!-- /dddart-source -->";
def matches($pattern): [match($pattern; "g") | .captures | map({key:.name,value:.string}) | from_entries];
def anchors:
  . as $text |
  (without_fences | matches("(?m)^#{1,6} +(?<heading>.+?) *#*$")) |
  reduce .[] as $h ({counts:{}, result:[]};
    ($h.heading | gsub("\\[(?<label>[^]]+)\\]\\([^)]*\\)"; .label) |
      gsub("<[^>]+>";"") | ascii_downcase | trim |
      gsub("[^\\p{L}\\p{N}_ -]";"") | gsub(" ";"-")) as $slug |
    (.counts[$slug] // 0) as $n |
    .counts[$slug] = ($n + 1) |
    .result += [$slug + (if $n == 0 then "" else "-" + ($n|tostring) end)]) |
  .result + [$text | scan("(?:id|name)=[\"']([^\"']+)") | .[0]];
def links:
  without_fences |
  ([scan("\\[[^]\\n]*\\]\\((<[^>]+>|[^\\s)]+)(?:\\s+[\"'][^\\n]*?[\"'])?\\)") | .[0] | ltrimstr("<") | rtrimstr(">")] +
   [scan("(?m)^[ \\t]*\\[[^]]+\\]:[ \\t]*(\\S+)") | .[0]] +
   [scan("(?:href|src)=[\"']([^\"']+)") | .[0]]);
def html_decode:
  gsub("&quot;";"\"") | gsub("&apos;|&#39;";"'") |
  gsub("&lt;";"<") | gsub("&gt;";">") | gsub("&amp;";"&");
# Lexical export scanning: nested block comments, line comments, raw/escaped/
# multiline strings. Literals are masked before recognizing Dart directives.
def dart_exports:
  def block_end:
    if .depth == 0 then .
    else ([.rest | match("/\\*|\\*/")][0] // null) as $m |
      if $m == null then error("Unterminated Dart block comment") else
        .depth += (if $m.string == "/*" then 1 else -1 end) |
        .rest = .rest[($m.offset+2):] | block_end end end;
  def lex:
    if .rest == "" then . else
      ([.rest | match("//|/\\*|r?(?:\"\"\"|'''|\"|')")][0] // null) as $m |
      if $m == null then .code += .rest | .rest = ""
      else .code += .rest[:$m.offset] | .rest = .rest[$m.offset:] |
        if .rest|startswith("//") then .rest |= sub("^[^\\n]*";"") | .code += " "
        elif .rest|startswith("/*") then .rest = .rest[2:] | .depth = 1 | block_end | .code += " "
        else
          ($m.string|startswith("r")) as $raw |
          ($m.string|ltrimstr("r")) as $quote |
          .rest = .rest[($m.string|length):] |
          ([.rest | match(if $raw then "(?s).*?" + $quote
                         else "(?s)(?:\\\\.|(?!" + $quote + ").)*" + $quote end)][0] // null) as $end |
          if $end == null then error("Unterminated Dart string") else
            .code += ("\u0000" + (.strings|length|tostring) + "\u0000") |
            .strings += [$m.string + $end.string] |
            .rest = .rest[($end.string|length):] end
        end | lex end end;
  {rest:.,code:"",strings:[]} | lex | .strings as $strings |
  [.code | scan("\\bexport[[:space:]]*(\u0000[0-9]+\u0000[^;]*);") | .[0] |
    gsub("\u0000(?<index>[0-9]+)\u0000"; $strings[.index|tonumber]) |
    gsub("[[:space:]]+";" ") | trim];
def command_words:
  trim | select(. != "" and (startswith("#")|not)) |
  require(test("^[A-Za-z0-9_./=:-]+(?:[ \\t]+[A-Za-z0-9_./=:-]+)*$");
          "Documented commands require simple argv tokens, without shell expansions") |
  split(" ") | map(select(. != ""));
def command_args:
  command_words | map(select(test("^BOOKING_[A-Z0-9_]+=.*$")|not)) |
  require(.[0] == "dart" or . == ["mkdir","-p","build"]; "Unsupported documented command");
JQ
