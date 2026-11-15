#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./dart.sh pub get --enforce-lockfile
python3 - <<'PY'
from pathlib import Path
import re
sha = '62af23ffa369c2d2cba13c93e39eee4c90c2325d'
manifest = Path('pubspec.yaml').read_text()
lock = Path('pubspec.lock').read_text()
if 'dependency_overrides:' in manifest or Path('pubspec_overrides.yaml').exists():
    raise SystemExit('Dependency overrides are prohibited for device evidence.')
for name in ('dddart', 'dddart_serialization', 'dddart_repository_indexeddb'):
    block = re.search(r'^  ' + name + r':\n((?:    .*\n|\n)*)', lock, re.M)
    if not block or 'source: git' not in block[1] or not re.search(r'resolved-ref: ["\']?' + sha + r'["\']?\s', block[1]):
        raise SystemExit(f'{name} must resolve to {sha}')
print(f'Verified all three Git dependencies at {sha}; no overrides.')
PY
mkdir -p build
harness_commit="$(git rev-parse HEAD)"
source_dirty=false
if [ -n "$(git status --porcelain -- .)" ]; then source_dirty=true; fi
./dart.sh compile js -O2 "-DHARNESS_COMMIT=$harness_commit" "-DSOURCE_DIRTY=$source_dirty" web/main.dart -o build/main.dart.js
cp web/index.html build/index.html
printf 'Built harness from %s (modified source: %s)\n' "$harness_commit" "$source_dirty"
