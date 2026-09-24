#!/bin/bash

set -e

PACKAGE_PATH="${1:-.}"

cd "$PACKAGE_PATH"

expected_outputs() {
  local source_root
  local source_file
  local part_path

  for source_root in lib test; do
    if [ ! -d "$source_root" ]; then
      continue
    fi

    while IFS= read -r -d '' source_file; do
      while IFS= read -r part_path; do
        if [ -n "$part_path" ]; then
          echo "$(dirname "$source_file")/$part_path"
        fi
      done < <(
        # Formatted Dart directives start in column zero. Requiring that shape
        # avoids treating example source embedded in test strings as a part.
        sed -nE \
          "s/^part[[:space:]]+'([^']+\\.g\\.dart)';[[:space:]]*$/\\1/p" \
          "$source_file"
      )
    done < <(
      find "$source_root" -type f -name '*.dart' ! -name '*.g.dart' -print0
    )
  done
}

# A stale ignored output must not make a failed generation look successful.
while IFS= read -r expected_output; do
  if [ -n "$expected_output" ]; then
    rm -f "$expected_output"
  fi
done < <(expected_outputs)

dart run build_runner build --delete-conflicting-outputs

MISSING_OUTPUT=0
while IFS= read -r expected_output; do
  if [ -n "$expected_output" ] && [ ! -f "$expected_output" ]; then
    echo "Expected generated output is missing: $expected_output" >&2
    MISSING_OUTPUT=1
  fi
done < <(expected_outputs)

exit "$MISSING_OUTPUT"
