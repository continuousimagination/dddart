#!/usr/bin/env bash
# Checked source documentation and isolated Dart consumers, orchestrated in Bash.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
ROOT=$(cd "${DDDART_DOC_ROOT:-$SCRIPT_DIR/../..}" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dddart-docs.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
METADATA="$ROOT/docs/quickstarts/workflows.json"
INVENTORY="$ROOT/tool/validation/inventory.json"

collect_sources() {
  repository_files "$ROOT" > "$WORK/files.txt"
  jq -Rn '[inputs]' < "$WORK/files.txt" > "$WORK/files.json"
  jq -r '.[] | select(test("\\.(md|mdx|rst)$") or
    (test("^packages/.*\\.dart$") and test("/(lib|example)/") and (endswith(".g.dart")|not)) or
    startswith("docs/quickstarts/") or . == "website/src/pages/index.astro")' "$WORK/files.json" > "$WORK/sources.txt"
  load_sources "$ROOT" "$WORK/sources.txt" "$WORK/sources.json"
}

check_sources() {
  collect_sources
  local check_filter
  IFS= read -r -d '' check_filter <<'JQ' || true
  $sources[0] as $db | $files[0] as $files | $metadata[0] as $meta |
  $inventory[0] as $inventory | $surfaces[0].documents as $surfaces |
  ($inventory.packages | map({key:.name,value:.}) | from_entries) as $packages |
  def content($path): $db[$path] // error("Missing canonical input: " + $path);
  def same($a;$b): ($a|sort) == ($b|sort);
  def relative: test("^(?!/)(?!.*(?:^|/)\\.\\.(?:/|$))[^\\\\]+$");
  def sample_table:
    ["| Source | Coverage / runtime context |", "| --- | --- |"] +
    [.entrypoints[] |
      ({run:"Compiled and run; finite local demonstration.",
        compile:"Compiled only; running requires application configuration or a long-running server.",
        service:"Compiled and run against the lane\u0027s required local database service."}[.action] //
        error("Retired/unvalidated sample is still inventoried")) as $description |
      "| [" + .path + "](" + .path + ") | " + $description + " " +
      (.reason|gsub("\\|";"\\|")|gsub("\n";" ")) + " |"] | join("\n");
  require(($meta.revision|test("^[0-9a-f]{40}$")); "Expected a full Git revision") |
  require(($meta.workflows|map(.name)|length) == ($meta.workflows|map(.name)|unique|length); "Duplicate workflow") |
  require(same([$files[]|select(startswith("docs/quickstarts/"))|split("/")|select(length>3)|.[2]]|unique;
               [$meta.workflows[].name]); "Unclassified quickstart directory") |
  reduce $meta.workflows[] as $w (.;
    ("docs/quickstarts/" + $w.name + "/") as $base |
    require(same($w.allowedLocalPackages; [$w.packages[] as $p|$packages[$p].allowedLocalPackages[]]|unique);
            $w.name + ": local closure differs from shared package inventory") |
    require(($w.files|map(.destination)|length) == ($w.files|map(.destination)|unique|length) and
            any($w.files[]; .destination == "pubspec.yaml"); $w.name + ": duplicate destination or missing pubspec") |
    require(all($w.files[]; (.source|relative) and (.destination|relative) and (.source|endswith(".g.dart")|not));
            $w.name + ": invalid fixture path/generated input") |
    require(same([$files[]|select(startswith($base) and endswith(".dart"))|ltrimstr($base)];
                 [$w.files[].source|select(endswith(".dart"))]); $w.name + ": unclassified/missing canonical Dart input") |
    (content($base + "pubspec.yaml.txt")) as $pubspec |
    require(([$pubspec|scan("(?m)^ +ref: (.+)$")|.[0]]|unique) == [$meta.revision];
            $w.name + ": Git setup must use the shared immutable code revision") |
    ([$w.commandsFiles[] as $f | content($base+$f)|split("\n")[]|command_args]) as $commands |
    require(any($commands[]; . == ["dart","pub","get"]); $w.name + ": missing documented command dart pub get") |
    require(any($commands[]; . == ["dart","analyze","--fatal-infos"]); $w.name + ": missing documented analysis") |
    require(($w.generation|not) or ($pubspec|test("(?m)^  build_runner:")); $w.name + ": pubspec must declare build_runner") |
    require(($w.generation|not) or
      (any($commands[]; . == ["dart","run","build_runner","clean"]) and
       any($commands[]; . == ["dart","run","build_runner","build","--delete-conflicting-outputs"]));
      $w.name + ": missing clean generation commands") |
    require(same([$commands[]|select(length == 3 and .[:2] == ["dart","run"])|.[2]]; [$w.runs[].path]);
            $w.name + ": run commands and expected-output inventory disagree") |
    require(same([$commands[]|select(.[:2] == ["dart","compile"])|.[3]]; $w.compile // []);
            $w.name + ": compile commands and coverage inventory disagree")) |
  # Every included file has an executable workflow/sample owner.
  ([$meta.workflows[] as $w |
      ($w.files[].source, $w.commandsFiles[], $w.runs[].stdoutFile) |
      {key:("docs/quickstarts/"+$w.name+"/"+.),value:$w.name}] +
   [$inventory.examples[] as $e | $e.entrypoints[] |
      {key:($e.path+"/"+.path),value:$e.name}] | from_entries) as $owners |
  require(all($owners|keys[]; $db[.] != null); "Missing canonical workflow/sample input") |
  reduce $inventory.examples[] as $e (.;
    content($e.path + "/README.md") as $guide |
    require(($guide|contains($e|sample_table)); $e.path + "/README.md: sample coverage table differs from shared inventory") |
    require(($guide|contains("dart tool/validation/validate.dart example "+$e.name+" --mode=ci"));
            $e.path + "/README.md: missing exact sample validation command")) |
  # Homepage code imports the same whole files the quickstart gate executes.
  content("website/src/pages/index.astro") as $home |
  ([$home | scan("import (\\w+) from \u0027([^\u0027]+\\.dart)\\?raw\u0027;") |
    {key:.[0],value:(("website/src/pages/"+.[1])|normalize_path)}] | from_entries) as $imports |
  ([$home|scan("\\bcode:[ \\t]*([^,}\\n]+)")|.[0]]|map(trim)) as $used |
  require(($used|length)>0 and all($used[]; $imports[.] != null); "Homepage Dart code must use canonical raw source imports") |
  require(all($used[]; $owners[$imports[.]] != null); "Homepage Dart import lacks a checked workflow/sample owner") |
  require(same([$files[]|select(test("\\.(md|mdx|rst)$"))]; $surfaces|keys);
          "Documentation surface inventory differs") |
  reduce ($surfaces|to_entries[]) as $entry (.;
    require($entry.value == "current" or $entry.value == "historical" or
            ($entry.value == "internal" and ($entry.key|startswith(".kiro/steering/")));
            $entry.key + ": invalid documentation category") |
    require($entry.value != "historical" or (content($entry.key)|contains(
      "> Historical record; it may describe retired APIs. For current usage, start at"));
      $entry.key + ": historical document lacks a visible current-guide notice")) |
  [$db|to_entries[] |
    select(($surfaces[.key] == "current") or
      ((.key|test("^packages/.*\\.dart$")) and (.key|test("/(lib|example)/")))) |
    .key as $path | {path:$path,text:(.value|doc_text($path))}] as $documents |
  reduce $documents[] as $doc ({inclusions:[],links:[],documents:($documents|length)};
    ($doc.text|matches(source_pattern)) as $included |
    require(([$doc.text|scan("(?m)^<!-- dddart-source:")]|length) == ($included|length);
            $doc.path + ": malformed or unclosed source inclusion") |
    reduce $included[] as $inc (.;
      require($owners[$inc.source] != null; $doc.path + ": included source lacks a checked workflow: " + $inc.source) |
      require($inc.body == (content($inc.source)|sub("[[:space:]]+$";""));
              $doc.path + ": stale inclusion of " + $inc.source + "; run documentation sync") |
      .inclusions += [$inc.source]) |
    require(([$doc.text|gsub(source_pattern;"")|matches(fence_pattern)[]|
               select((.language|ascii_downcase) == "dart")]|length) == 0;
            $doc.path + ": unchecked Dart snippet; use a canonical source inclusion") |
    .links += [$doc.text|links[]|{document:$doc.path,url:.}]) |
  . as $result |
  require(all([$meta.workflows[] as $w | $w.files[]|select(.source|endswith(".dart"))|
    "docs/quickstarts/"+$w.name+"/"+.source][];
    . as $source | $result.inclusions|index($source) != null);
    "Executable fixture is not published in current docs") |
  (content("docs/PUBLIC_API.md")) as $api |
  [$db|keys[]|select(test("^packages/[^/]+/lib/[^/]+\\.dart$"))] as $entrypoints |
  require(same([$api|scan("(?m)^### `([^`]+)`")|.[0]];
    [$entrypoints[]|split("/")|.[1]+"/"+.[3]]); "API entrypoint inventory differs") |
  reduce $entrypoints[] as $path (.;
    ($path|split("/")|.[1]+"/"+.[3]) as $label |
    ($api|split("### `"+$label+"`")[1]|split("\n### ")[0]|
      [scan("(?m)^- `([^`]+)`")|.[0]]) as $recorded |
    require($recorded == (content($path)|dart_exports); $label+": public exports differ from docs/PUBLIC_API.md")) |
  require(same([content("docs/CAPABILITIES.md")|scan("(?m)^\\| (dddart\\w*) \\|")|.[0]];
               $packages|keys); "Capability matrix differs from shared inventory") |
  . + {workflows:($meta.workflows|length),examples:($inventory.examples|length),revision:$meta.revision}
JQ
  jq -n --slurpfile sources "$WORK/sources.json" --slurpfile files "$WORK/files.json" \
    --slurpfile metadata "$METADATA" --slurpfile inventory "$INVENTORY" \
    --slurpfile surfaces "$ROOT/tool/documentation/surfaces.json" \
    "$DOC_JQ $check_filter" > "$WORK/checked.json"
  check_links
  jq -r '"Checked \(.documents) current documentation/API surfaces, \(.inclusions|length) canonical inclusions, \(.workflows) workflows, \(.examples) sample guides, local links and public exports."' "$WORK/checked.json"
}

check_links() {
  local document reference target fragment relative revision
  revision=$(jq -r .revision "$METADATA")
  jq -r '.links[] | [.document,.url] | @tsv' "$WORK/checked.json" > "$WORK/links.tsv"
  while IFS=$'\t' read -r document reference; do
    case "$reference" in
      https://github.com/continuousimagination/dddart/blob/*|https://github.com/continuousimagination/dddart/tree/*)
        relative=${reference#https://github.com/continuousimagination/dddart/}; relative=${relative#*/}
        case "${relative%%/*}" in main|"$revision") relative=${relative#*/};; *) continue;; esac;;
      *://*|mailto:*|tel:*|data:*|/*) continue;;
      \#*) relative="$document$reference";;
      *) relative="${document%/*}/$reference"; [[ "$document" == */* ]] || relative=$reference;;
    esac
    fragment=''
    if [[ "$relative" == *'#'* ]]; then fragment=$(url_decode "${relative#*#}"); relative=${relative%%#*}; fi
    relative=$(url_decode "${relative%%\?*}")
    relative=$(jq -nr --arg path "$relative" "$DOC_JQ \$path | normalize_path")
    target="$ROOT/$relative"
    [[ -e "$target" ]] || fail "$document: broken local link $reference"
    case "$target" in *.md|*.mdx|*.rst)
      if [[ -n "$fragment" ]]; then
        jq -eRs --arg fragment "$fragment" "$DOC_JQ anchors | index(\$fragment) != null" "$target" >/dev/null ||
          fail "$document: broken local anchor $reference"
      fi;;
    esac
  done < "$WORK/links.tsv"
}

sync_sources() {
  collect_sources
  local path filter
  IFS= read -r -d '' filter <<'JQ' || true
  . as $text | reduce (matches(source_pattern)[]) as $inc ($text;
    if $sources[0][$inc.source] == null then error("Missing inclusion source: "+$inc.source)
    else ("<!-- dddart-source: "+$inc.source+" -->\n```"+$inc.language+"\n"+$inc.body+"\n```\n<!-- /dddart-source -->") as $old |
      ("<!-- dddart-source: "+$inc.source+" -->\n```"+$inc.language+"\n"+
       ($sources[0][$inc.source]|sub("[[:space:]]+$";""))+"\n```\n<!-- /dddart-source -->") as $new |
      split($old)|join($new) end)
JQ
  while IFS= read -r path; do
    [[ "$path" == *.dart ]] && continue
    grep -q '<!-- dddart-source:' "$ROOT/$path" || continue
    jq -jRs --slurpfile sources "$WORK/sources.json" "$DOC_JQ $filter" "$ROOT/$path" > "$WORK/synced"
    if ! cmp -s "$ROOT/$path" "$WORK/synced"; then cp "$WORK/synced" "$ROOT/$path"; printf 'Refreshed %s\n' "$path"; fi
  done < "$WORK/sources.txt"
}

# Command execution is deliberately argv-based. Never eval documentation content.
run_command() {
  local cwd=$1 label=$2 limit=$3 code=0; shift 3
  printf '%s: ' "$label"; printf '%q ' "$@"; printf '\n'
  (cd "$cwd" && "$TIMEOUT" --kill-after=5 "$limit" "$@") > "$WORK/stdout" 2> "$WORK/stderr" || code=$?
  if [[ $code != 0 ]]; then
    cat "$WORK/stdout" "$WORK/stderr" >&2
    fail "$label: command $* failed (exit $code)"
  fi
}

require_service() {
  local workflow=$1 kind host port
  kind=$(jq -r '.service | if . == "mongodb" then "mongo" else . end' "$workflow")
  [[ "$kind" != none ]] || return 0
  host=$(jq -r --arg kind "$kind" '[.testTagPolicies[].service | select(.kind == $kind)][0].host // empty' "$INVENTORY")
  port=$(jq -r --arg kind "$kind" '[.testTagPolicies[].service | select(.kind == $kind)][0].port // empty' "$INVENTORY")
  [[ -n "$host" && "$port" =~ ^[0-9]+$ ]] || fail "No shared service policy for $kind"
  "$TIMEOUT" --kill-after=1 3 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" 2>/dev/null ||
    fail "Required $kind service unavailable at $host:$port"
}

stage_packages() {
  local selected=$1 destination=$2 package path
  mkdir -p "$destination/packages" "$destination/archives"
  while IFS= read -r package; do
    path=$(jq -r --arg name "$package" '.packages[]|select(.name == $name)|.path' "$INVENTORY")
    safe_relative "$path"
    [[ ! -e "$destination/archives/$package.tar.gz" ]] || fail "Refusing to reuse Pub archive: $package"
    mkdir -p "$destination/packages/$package"
    run_command "$ROOT/$path" "Pub archive $package (NOT hosted proof)" 300 \
      dart pub publish --skip-validation "--to-archive=$destination/archives/$package.tar.gz"
    tar -xzf "$destination/archives/$package.tar.gz" -C "$destination/packages/$package"
  done < <(jq -r '[.[].allowedLocalPackages[]]|unique[]' "$selected")
}

run_workflow() (
  local workflow=$1 archive_root=$2 source_mode=$3 name base app label path destination command_line expected entrypoint part refs
  name=$(jq -r .name "$workflow"); base="$ROOT/docs/quickstarts/$name"
  app=$(mktemp -d "${TMPDIR:-/tmp}/dddart-consumer.XXXXXX")
  trap 'rm -rf "$app"' EXIT
  label="docs/quickstarts/$name ($source_mode)"
  while IFS=$'\t' read -r path destination; do
    safe_relative "$path"; safe_relative "$destination"
    mkdir -p "$app/$(dirname "$destination")"; cp "$base/$path" "$app/$destination"
  done < <(jq -r '.files[]|[.source,.destination]|@tsv' "$workflow")
  if [[ "$source_mode" == local ]]; then
    # Remove only the top-level DDDart override block; preserve the exact manifest otherwise.
    jq -jRs 'gsub("(?m)^dependency_overrides:\n(?:[ \\t].*\n|\n)*";"")' "$app/pubspec.yaml" > "$app/pubspec.yaml.tmp"
    mv "$app/pubspec.yaml.tmp" "$app/pubspec.yaml"
    printf '\ndependency_overrides:\n' >> "$app/pubspec.yaml"
    while IFS= read -r path; do
      printf '  %s:\n    path: %s\n' "$path" "$(jq -nr --arg path "$archive_root/packages/$path" '$path|tojson')" >> "$app/pubspec.yaml"
    done < <(jq -r '.allowedLocalPackages[]' "$workflow")
  fi
  while IFS= read -r path; do
    while IFS= read -r command_line || [[ -n "$command_line" ]]; do
      [[ -n "${command_line// /}" && "$command_line" != \#* ]] || continue
      local words=() argv=() additions=() word
      jq -en --arg line "$command_line" "$DOC_JQ \$line|command_args" >/dev/null
      read -r -a words <<< "$command_line"
      for word in "${words[@]}"; do
        case "$word" in BOOKING_*=*) additions+=("$word");; *) argv+=("$word");; esac
      done
      if [[ ${#additions[@]} -gt 0 ]]; then
        run_command "$app" "$label/$path" 180 env "${additions[@]}" "${argv[@]}"
      else run_command "$app" "$label/$path" 180 "${argv[@]}"; fi
      if [[ ${#argv[@]} == 3 && "${argv[0]} ${argv[1]}" == 'dart run' ]]; then
        expected=$(jq -r --arg path "${argv[2]}" '.runs[]|select(.path == $path)|.stdoutFile' "$workflow")
        cmp -s "$WORK/stdout" "$base/$expected" || {
          diff -u "$base/$expected" "$WORK/stdout" >&2 || true
          fail "$label: ${argv[2]} expected stdout differs"
        }
      fi
    done < "$base/$path"
  done < <(jq -r '.commandsFiles[]' "$workflow")
  # Only handwritten consumer inputs are examined; each owning part must be generated.
  while IFS= read -r path; do
    while IFS= read -r part; do
      [[ -f "$app/$(dirname "$path")/$part" ]] || fail "$label: generation did not produce $part for $path"
    done < <(jq -rRs '[scan("(?m)^part [\"\u0027]([^\"\u0027]+\\.g\\.dart)[\"\u0027];")|.[0]][]' "$app/$path")
  done < <(jq -r '.files[].destination|select(endswith(".dart"))' "$workflow")
  run_command "$app" "$label" 180 dart pub deps --json
  jq -e --slurpfile workflow "$workflow" '
    [.packages[]|select((.name|startswith("dddart")) and .kind != "root")|.name]|sort == ($workflow[0].allowedLocalPackages|sort)' "$WORK/stdout" >/dev/null ||
    fail "$label: resolved DDDart closure differs"
  if [[ "$source_mode" == git ]]; then
    refs=$(jq -Rc 'scan("resolved-ref: [\"\u0027]?([0-9a-f]{40})")|.[0]' "$app/pubspec.lock" | jq -s 'unique')
    jq -en --argjson refs "$refs" --arg revision "$(jq -r .revision "$METADATA")" '$refs == [$revision]' >/dev/null || fail "$label: lockfile revision differs"
  fi
  while IFS= read -r entrypoint; do
    mkdir -p "$app/build"
    path="build/$(basename "${entrypoint%.dart}").js"
    run_command "$app" "$label" 180 dart compile js "$entrypoint" -o "$path"
    run_command "$app" "$label" 180 node "$SCRIPT_DIR/node_runner.cjs" "$path"
    expected=$(jq -r --arg path "$entrypoint" '.runs[]|select(.path == $path)|.stdoutFile' "$workflow")
    cmp -s "$WORK/stdout" "$base/$expected" || fail "$label: JavaScript output mismatch"
  done < <(jq -r '.javascript[]?' "$workflow")
  printf 'PASS %s; temporary application cleaned up.\n' "$label"
)

main() {
  local action=${1:-check} name='' service=all source_mode=local arg workflow archive_root variable
  [[ $# == 0 ]] || shift
  for arg in "$@"; do
    case "$arg" in
      --service-kind=*) service=${arg#*=};; --source=*) source_mode=${arg#*=};;
      --*) fail "Unknown option: $arg";; *) [[ -z "$name" ]] || fail 'Specify one workflow'; name=$arg;;
    esac
  done
  case "$source_mode" in local|git);; *) fail 'Source must be local or git';; esac
  case "$service" in all|none|mysql|mongo|dynamodb);; *) fail 'Unknown service kind';; esac
  case "$action" in
    sync) sync_sources; return;;
    check) check_sources; return;;
    all|run) check_sources;;
    *) fail 'Usage: validate.sh check|sync|all|run [workflow] [--source=local|git] [--service-kind=all|none|mysql|mongo|dynamodb]';;
  esac
  TIMEOUT=$(timeout_tool); need dart; need tar
  # Do not inherit hook Git state or the caller's example-specific settings.
  while IFS='=' read -r variable _; do
    case "$variable" in GIT_*|BOOKING_*) unset "$variable";; esac
  done < <(env)
  export CI=true
  jq --arg action "$action" --arg name "$name" --arg service "$service" '[.workflows[]|
    select(($action == "all" or .name == $name) and
      ($service == "all" or (.service|if . == "mongodb" then "mongo" else . end) == $service))]' "$METADATA" > "$WORK/selected.json"
  [[ $(jq length "$WORK/selected.json") -gt 0 ]] || fail 'No workflows selected'
  while IFS= read -r workflow; do
    printf '%s\n' "$workflow" > "$WORK/workflow.json"; require_service "$WORK/workflow.json"
  done < <(jq -c '.[]' "$WORK/selected.json")
  archive_root="${DDDART_DOC_ARCHIVES:-$WORK/staged}"
  if [[ "$source_mode" == local && -z "${DDDART_DOC_ARCHIVES:-}" ]]; then stage_packages "$WORK/selected.json" "$archive_root"; fi
  while IFS= read -r workflow; do
    printf '%s\n' "$workflow" > "$WORK/workflow.json"
    run_workflow "$WORK/workflow.json" "$archive_root" "$source_mode"
  done < <(jq -c '.[]' "$WORK/selected.json")
}
main "$@"
