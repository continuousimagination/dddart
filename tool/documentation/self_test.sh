#!/usr/bin/env bash
# Fault-inject the real Bash documentation gate; no external service credentials.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dddart-doc-faults.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
COUNT=0
MODE=${1:-all}
case "$MODE" in all|--static);; *) fail 'Usage: self_test.sh [--static]';; esac

pass() { COUNT=$((COUNT + 1)); printf 'PASS %s\n' "$1"; }
expect_failure() {
  local message=$1; shift
  if "$@" > "$WORK/result" 2>&1; then fail "Expected failure: $message"; fi
  grep -Fq "$message" "$WORK/result" || { cat "$WORK/result" >&2; fail "Missing diagnostic: $message"; }
}
replace() {
  local path=$1 before=$2 after=$3
  jq -jRs --arg before "$before" --arg after "$after" '
    split($before) | if length < 2 then error("Replacement target missing")
    else .[0] + $after + (.[1:] | join($before)) end' "$CASE/$path" > "$WORK/changed"
  mv "$WORK/changed" "$CASE/$path"
}
fresh() { rm -rf "$WORK/case"; cp -R "$WORK/baseline" "$WORK/case"; CASE="$WORK/case"; }
gate() { DDDART_DOC_ROOT="$CASE" bash "$SCRIPT_DIR/validate.sh" "$@"; }
check_failure() { expect_failure "$1" gate check; pass "$2"; }

# Export tokenizer regressions preserve comment, string and conditional handling.
cat > "$WORK/exports.dart" <<'DART'
/// Keep internal types out of this export namespace.
library;
// export 'line_comment.dart';
/* export 'block_comment.dart';
   /* Nested Dart comments are allowed. */
   export 'still_commented.dart'; */
export 'public.dart';
DART
jq -eRs "$DOC_JQ dart_exports == [\"'public.dart'\"]" "$WORK/exports.dart" >/dev/null
pass 'export prose and nested/line comments are ignored'
cat > "$WORK/exports.dart" <<'DART'
const example = '''
export 'example.dart';
''';
const rawExample = r"export 'raw_example.dart'; //";
const escaped = 'It\'s not an export';
export 'https://example.com/public.dart';
DART
jq -eRs "$DOC_JQ dart_exports == [\"'https://example.com/public.dart'\"]" "$WORK/exports.dart" >/dev/null
pass 'raw/multiline/escaped literals cannot create directives'
cat > "$WORK/exports.dart" <<'DART'
export /* public API */ 'base.dart'
  if (dart.library.io) 'native.dart'
  show First, Second;
export 'other.dart' // internal implementation
  hide Internal;
DART
jq -eRs "$DOC_JQ dart_exports == [\"'base.dart' if (dart.library.io) 'native.dart' show First, Second\", \"'other.dart' hide Internal\"]" "$WORK/exports.dart" >/dev/null
pass 'conditional and filtered export contracts are retained'

bash "$SCRIPT_DIR/validate.sh" check
mkdir -p "$WORK/baseline"
repository_files "$ROOT" > "$WORK/files"
(cd "$ROOT" && tar -cf "$WORK/source.tar" -T "$WORK/files")
tar -xf "$WORK/source.tar" -C "$WORK/baseline"

fresh
printf '\n```dart\nvoid unclassified() {}\n```\n' >> "$CASE/README.md"
check_failure 'unchecked Dart snippet' 'new root snippet needs a checked source'
fresh
printf '# New guide\n' > "$CASE/docs/NEW_GUIDE.md"
check_failure 'surface inventory differs' 'new standalone guide requires inventory review'
fresh
printf '\n```dart\nMissingType sample;\n```\n' >> "$CASE/packages/dddart/IDENTITY_GUIDE.md"
check_failure 'IDENTITY_GUIDE.md: unchecked' 'standalone guide snippets are checked'
fresh
printf '\n/// ```dart\n/// MissingType sample;\n/// ```\n' >> "$CASE/packages/dddart/lib/src/entity.dart"
check_failure 'entity.dart: unchecked' 'deep API comments are checked'
fresh
printf '\n[Missing](missing.md)\n' >> "$CASE/packages/dddart/IDENTITY_GUIDE.md"
check_failure 'broken local link' 'broken relative links fail'
fresh
printf '\nUse Dart **9.9.9** for this example.\n' >> "$CASE/README.md"
check_failure 'keep tool and SDK versions in manifests' 'SDK requirements cannot be duplicated in prose'
fresh
printf '\n```yaml\n' >> "$CASE/README.md"
cat "$CASE/docs/quickstarts/json/pubspec.yaml.txt" >> "$CASE/README.md"
printf '\n```\n' >> "$CASE/README.md"
check_failure 'link the example pubspec' 'dependency constraints cannot be copied into a guide'
fresh
replace docs/quickstarts/json/README.md '[example pubspec](pubspec.yaml.txt)' 'example pubspec'
check_failure 'quickstart must link its example pubspec' 'quickstarts must retain their installation manifest link'
fresh
core_git_ref=$(sed -n 's/^ *ref: //p' "$CASE/docs/quickstarts/core/pubspec.yaml.txt")
replace docs/quickstarts/json/pubspec.yaml.txt "ref: $core_git_ref" 'ref: 0000000000000000000000000000000000000000'
check_failure "must match the core example pubspec's revision" 'quickstarts reject a different dependency revision'
fresh
printf '\n[Missing](https://github.com/continuousimagination/dddart/blob/main/docs/README.md#gone)\n' >> "$CASE/README.md"
check_failure 'broken local anchor' 'broken repository URL anchors fail'
fresh
replace tool/validation/inventory.json 'Handle a stale revision' 'Ignore a stale revision'
check_failure 'sample listing differs' 'sample execution claims cannot drift'
fresh
replace packages/dddart/example/README.md 'dart run events_example.dart' 'dart run missing.dart'
check_failure 'show how to run an inventoried program' 'sample guides launch an existing entrypoint'
fresh
replace packages/dddart/CHANGELOG.md '> Historical record; it may describe retired APIs. For current usage, start at' 'Removed notice'
check_failure 'historical document lacks' 'historical exemptions require a visible notice'
fresh
replace website/src/pages/index.astro "code: readQuickstart('docs/quickstarts/core/bin/main.dart')" 'code: `MissingType value;`'
check_failure 'Homepage Dart code' 'homepage cannot embed unchecked source'
for fence in '~~~' '````'; do
  fresh
  printf '\n%sDart\nMissingType value;\n%s\n' "$fence" "$fence" >> "$CASE/README.md"
  expect_failure 'unchecked Dart snippet' gate check
done
pass 'tilde and longer fences cannot bypass source checking'
fresh
replace docs/quickstarts/json/README.md "guestName: 'Sam'" "guestName: 'Revised'"
gate snippets | jq -e '.["docs/quickstarts/json/bin/main.dart"].text | contains("Revised")' >/dev/null
pass 'editing the guide changes the extracted program'
fresh
mkdir -p "$CASE/docs/quickstarts/sqlite/lib"
touch "$CASE/docs/quickstarts/sqlite/lib/note.dart"
check_failure 'also exists as a repository file' 'committed copies of snippets are rejected'
fresh
cat "$CASE/docs/quickstarts/sqlite/README.md" >> "$CASE/docs/quickstarts/json/README.md"
check_failure 'Duplicate quickstart snippet' 'a path cannot have two Markdown owners'
fresh
replace docs/quickstarts/sqlite/README.md '<!-- /dddart-source -->' '<!-- missing end -->'
check_failure 'malformed or unclosed' 'an incomplete snippet cannot consume the following block'
fresh
replace docs/quickstarts/core/README.md 'dart pub get' 'dart pub missing'
check_failure 'missing documented command dart pub get' 'required commands are checked after extraction'
fresh
printf "\nexport 'src/unreviewed.dart';\n" >> "$CASE/packages/dddart_json/lib/dddart_json.dart"
check_failure 'public exports differ' 'new public exports require review'
fresh
printf "\n// export 'not_public.dart';\n/* export 'also_not_public.dart'; */\n" >> "$CASE/packages/dddart_repository_sql/lib/generator.dart"
gate check > "$WORK/result" 2>&1
pass 'comment-only export mentions preserve the inventory'
fresh
replace docs/quickstarts/json/pubspec.yaml.txt $'  build_runner: ^2.4.0\n' ''
check_failure 'pubspec must declare build_runner' 'missing builder fails before execution'
fresh
replace docs/quickstarts/slack_server/README.md $'dart compile kernel bin/main.dart -o build/server.dill\n' ''
check_failure 'slack_server: compile commands' 'compile-only examples cannot lose compilation'

if [[ "$MODE" != --static ]]; then
  need dart
  TIMEOUT=$(timeout_tool)
  fresh
  jq '(.testTagPolicies[]|select(.service.kind == "mysql")|.service.port)=0' "$CASE/tool/validation/inventory.json" > "$WORK/inventory"
  mv "$WORK/inventory" "$CASE/tool/validation/inventory.json"
  expect_failure 'Required mysql service unavailable' gate run mysql
  pass 'required database service fails rather than skipping'
  mkdir -p "$WORK/archives/packages" "$WORK/archives/tars" "$WORK/tmp"
  for package in dddart dddart_json dddart_serialization; do
    mkdir -p "$WORK/archives/packages/$package"
    (cd "$ROOT/packages/$package" && "$TIMEOUT" --kill-after=5 300 dart pub publish --skip-validation "--to-archive=$WORK/archives/tars/$package.tar.gz") > "$WORK/stage-log" 2>&1 || { cat "$WORK/stage-log" >&2; fail "Archive staging failed: $package"; }
    tar -xzf "$WORK/archives/tars/$package.tar.gz" -C "$WORK/archives/packages/$package"
  done
  export DDDART_DOC_ARCHIVES="$WORK/archives"
  export TMPDIR="$WORK/tmp"
  fresh
  replace docs/quickstarts/json/README.md 'package:dddart/dddart.dart' 'package:missing_domain/missing.dart'
  expect_failure 'command dart run build_runner build' gate run json
  grep -Fq 'lib/reservation.dart' "$WORK/result"
  pass 'broken import fails real fresh generation'
  fresh
  replace docs/quickstarts/json/README.md 'SeatCount(value: 2)' 'SeatCount(seats: 2)'
  expect_failure "No named parameter with the name 'seats'" gate run json
  pass 'broken constructor in Markdown fails compilation'
  fresh
  replace docs/quickstarts/json/README.md "part 'reservation.g.dart';" "part 'missing.g.dart';"
  expect_failure 'missing.g.dart' gate run json
  pass 'wrong owning part fails with fresh outputs'
  fresh
  replace docs/quickstarts/json/README.md $'\nSam\n' $'\nIncorrect\n'
  expect_failure 'bin/main.dart expected stdout' gate run json
  pass 'wrong runtime output fails after successful compilation'
  [[ -z "$(find "$WORK/tmp" -mindepth 1 -maxdepth 1 -name 'dddart-*' -print)" ]] || fail 'Failed consumers left temporary directories'
fi
printf 'All %s documentation regression tests passed (%s).\n' "$COUNT" "$MODE"
