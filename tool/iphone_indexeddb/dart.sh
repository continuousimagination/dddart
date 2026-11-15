#!/usr/bin/env bash
# Select a compatible SDK without changing the user's default Dart or Flutter.
set -euo pipefail
DART_SELECTED="$(python3 - <<'PY'
import os, re, shutil, subprocess, sys
candidates = [os.environ.get('DART_BIN'), shutil.which('dart')]
flutter = shutil.which('flutter')
if flutter:
    candidates.append(os.path.join(os.path.dirname(os.path.realpath(flutter)), 'cache', 'dart-sdk', 'bin', 'dart'))
for candidate in candidates:
    if not candidate or not os.path.isfile(candidate):
        continue
    result = subprocess.run([candidate, '--version'], capture_output=True, text=True)
    match = re.search(r'version: (\d+)\.(\d+)\.', result.stdout + result.stderr)
    if result.returncode == 0 and match and (3, 12) <= tuple(map(int, match.groups())) < (4, 0):
        print(candidate)
        sys.exit(0)
sys.exit('Dart >=3.12 and <4 is needed for the locked test dependencies. Set DART_BIN to a compatible Dart executable (including Flutter/bin/cache/dart-sdk/bin/dart).')
PY
)"
exec "$DART_SELECTED" "$@"
