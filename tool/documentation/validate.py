#!/usr/bin/env python3
"""Validate published snippets and execute isolated documentation consumers."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import unicodedata
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
INCLUSION = re.compile(
    r'<!-- dddart-source: ([^>\n]+) -->\n```(\w+)\n(.*?)\n```\n<!-- /dddart-source -->',
    re.S,
)
FENCE = re.compile(
    r'^(?P<fence>`{3,}|~{3,})(?P<language>[\w-]*)[^\n]*\n'
    r'(?P<body>.*?)^(?P=fence)[ \t]*$', re.M | re.S,
)
IGNORED = {'.git', '.dart_tool', 'node_modules', 'build', 'dist', '.astro',
           '.pub-cache', 'coverage', '__pycache__'}
DOCUMENT_SUFFIXES = {'.md', '.mdx', '.rst'}
HISTORICAL_NOTICE = '> Historical record; it may describe retired APIs. For current usage, start at'


class Failure(RuntimeError):
    pass


def read_json(path):
    return json.loads(path.read_text())


def safe_path(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise Failure(f'Path escapes its declared root: {relative}')
    return path


def repository_files(root):
    # Include new untracked documentation while respecting repository ignores.
    if (root / '.git').exists():
        result = subprocess.run(['git', '-C', str(root), 'ls-files', '-z',
                                 '--cached', '--others', '--exclude-standard'],
                                check=True, capture_output=True, text=True)
        return sorted({root / name for name in result.stdout.split('\0')
                       if name and (root / name).is_file()})
    # Fault-test source snapshots deliberately have no Git checkout.
    return sorted(p for p in root.rglob('*') if p.is_file()
                  and not IGNORED.intersection(p.relative_to(root).parts))


def document_paths(root=ROOT):
    return [p for p in repository_files(root)
            if p.suffix in DOCUMENT_SUFFIXES or
            (p.suffix == '.dart' and any(part in ('lib', 'example') for part in p.relative_to(root).parts)
             and p.relative_to(root).parts[0] == 'packages'
             and not p.name.endswith('.g.dart'))]


def document_text(path):
    text = path.read_text()
    if path.suffix == '.dart':
        # Only documentation, not strings or executable code in the same file.
        lines = [m[1] for m in re.finditer(r'^\s*/// ?(.*)$', text, re.M)]
        lines += [re.sub(r'^\s*\* ?', '', m[1], flags=re.M)
                  for m in re.finditer(r'/\*\*(.*?)\*/', text, re.S)]
        text = '\n'.join(lines)
    return text


def example_table(example):
    rows = ['| Source | Coverage / runtime context |', '| --- | --- |']
    descriptions = {
        'run': 'Compiled and run; finite local demonstration.',
        'compile': 'Compiled only; running requires application configuration or a long-running server.',
        'service': "Compiled and run against the lane's required local database service.",
    }
    for entry in example['entrypoints']:
        if entry['action'] not in descriptions:
            raise Failure(f"{example['name']}: retired/unvalidated sample is still inventoried")
        reason = entry['reason'].replace('|', r'\|').replace('\n', ' ')
        rows.append(f"| [{entry['path']}]({entry['path']}) | {descriptions[entry['action']]} {reason} |")
    return '\n'.join(rows)


def current_documents(root):
    surfaces = read_json(root / 'tool/documentation/surfaces.json')['documents']
    paths = document_paths(root)
    discovered = {str(p.relative_to(root)) for p in paths if p.suffix in DOCUMENT_SUFFIXES}
    if discovered != set(surfaces):
        raise Failure(f'Documentation surface inventory differs: {sorted(discovered ^ set(surfaces))}')
    current = []
    for path in paths:
        label = str(path.relative_to(root))
        kind = surfaces.get(label, 'current')
        if kind == 'historical':
            if HISTORICAL_NOTICE not in path.read_text():
                raise Failure(f'{label}: historical document lacks a visible current-guide notice')
        elif kind == 'internal':
            if not label.startswith('.kiro/steering/'):
                raise Failure(f'{label}: internal exemption is only for agent steering files')
        elif kind == 'current':
            current.append(path)
        else:
            raise Failure(f'{label}: unknown documentation category {kind}')
    return current


def markdown_anchors(text):
    # GitHub-style heading IDs, including duplicate suffixes.
    anchors = set()
    counts = {}
    for match in re.finditer(r'^#{1,6}\s+(.+?)\s*#*$', FENCE.sub('', text), re.M):
        heading = re.sub(r'\[([^]]+)\]\([^)]*\)', r'\1', match[1])
        heading = re.sub(r'<[^>]+>', '', heading).lower().strip()
        slug = ''.join(c for c in heading if c in '-_ ' or
                       unicodedata.category(c)[0] in 'LN').replace(' ', '-')
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        anchors.add(slug + (f'-{count}' if count else ''))
    anchors.update(re.findall(r'(?:id|name)=["\']([^"\']+)', text))
    return anchors


def check_links(root, path, text):
    text = FENCE.sub('', text)
    targets = re.findall(r'\[[^]\n]*\]\((<[^>]+>|[^\s)]+)(?:\s+["\'][^\n]*?["\'])?\)', text)
    targets += re.findall(r'^\s*\[[^]]+\]:\s*(\S+)', text, re.M)
    targets += re.findall(r'(?:href|src)=["\']([^"\']+)', text)
    for raw in targets:
        raw = raw.strip('<>')
        url = urlsplit(raw)
        if url.scheme or url.netloc:
            own = re.fullmatch(r'/continuousimagination/dddart/(?:blob|tree)/([^/]+)/(.*)', url.path)
            if url.netloc != 'github.com' or not own:
                continue  # External availability is not a deterministic local gate.
            # Other immutable revisions can intentionally link historical evidence.
            revision = read_json(root / 'docs/quickstarts/workflows.json')['revision']
            if own[1] not in ('main', revision):
                continue
            target = safe_path(root, unquote(own[2]))
        elif url.path.startswith('/'):
            continue  # Site routes/assets/anchors are verified by the website checker.
        else:
            target = safe_path(root, str(path.parent.relative_to(root) / unquote(url.path))) if url.path else path
        if not target.exists():
            raise Failure(f'{path.relative_to(root)}: broken local link {raw}')
        if url.fragment and target.suffix in DOCUMENT_SUFFIXES:
            if unquote(url.fragment) not in markdown_anchors(target.read_text()):
                raise Failure(f'{path.relative_to(root)}: broken local anchor {raw}')


def check_homepage(root, owners):
    path = root / 'website/src/pages/index.astro'
    text = path.read_text()
    imports = dict(re.findall(r"import (\w+) from '([^']+\.dart)\?raw';", text))
    used = re.findall(r'\bcode:\s*([^,}\n]+)', text)
    if not used or any(name.strip() not in imports for name in used):
        raise Failure('Homepage Dart code must use canonical raw source imports')
    for name in used:
        source = (path.parent / imports[name.strip()]).resolve()
        if not source.is_relative_to(root.resolve()) or str(source.relative_to(root)) not in owners:
            raise Failure('Homepage Dart import lacks a checked workflow/sample owner')


def check(root=ROOT):
    root = root.resolve()
    metadata = read_json(root / 'docs/quickstarts/workflows.json')
    inventory = read_json(root / 'tool/validation/inventory.json')
    documents = current_documents(root)
    packages = {p['name']: p for p in inventory['packages']}
    owners = {}
    names = set()
    for workflow in metadata['workflows']:
        name = workflow['name']
        if name in names:
            raise Failure(f'Duplicate workflow: {name}')
        names.add(name)
        base = root / 'docs/quickstarts' / name
        closure = {dep for p in workflow['packages']
                   for dep in packages[p]['allowedLocalPackages']}
        if set(workflow['allowedLocalPackages']) != closure:
            raise Failure(f'{name}: local closure differs from shared package inventory')
        sources = {f['source'] for f in workflow['files']}
        destinations = [f['destination'] for f in workflow['files']]
        if len(destinations) != len(set(destinations)) or 'pubspec.yaml' not in destinations:
            raise Failure(f'{name}: duplicate destination or missing pubspec')
        actual = {str(p.relative_to(base)) for p in base.rglob('*.dart')}
        if actual != {s for s in sources if s.endswith('.dart')}:
            raise Failure(f'{name}: unclassified/missing canonical Dart input: {actual ^ sources}')
        if any(s.endswith('.g.dart') for s in sources):
            raise Failure(f'{name}: generated parts must not be fixtures')
        for item in workflow['files']:
            safe_path(base, item['destination'])
        inputs = sources | set(workflow['commandsFiles']) | {
            run['stdoutFile'] for run in workflow['runs']}
        for source in inputs:
            path = safe_path(base, source)
            if not path.is_file():
                raise Failure(f'{name}: missing canonical input {source}')
            owners[str(path.relative_to(root))] = name
        pubspec = (base / 'pubspec.yaml.txt').read_text()
        refs = re.findall(r'^\s+ref: (.+)$', pubspec, re.M)
        if not refs or set(refs) != {metadata['revision']}:
            raise Failure(f'{name}: Git setup must use the shared immutable code revision')
        if not re.fullmatch(r'[0-9a-f]{40}', metadata['revision']):
            raise Failure('Expected a full Git revision')
        commands = [parse_command(line) for file in workflow['commandsFiles']
                    for line in (base / file).read_text().splitlines()
                    if line.strip() and not line.startswith('#')]
        args = [command for _, command in commands]
        required = [['dart', 'pub', 'get'], ['dart', 'analyze', '--fatal-infos']]
        if workflow['generation']:
            if not re.search(r'^  build_runner:', pubspec, re.M):
                raise Failure(f'{name}: generated workflow pubspec must declare build_runner')
            required += [['dart', 'run', 'build_runner', 'clean'],
                         ['dart', 'run', 'build_runner', 'build', '--delete-conflicting-outputs']]
        for command in required:
            if command not in args:
                raise Failure(f'{name}: missing documented command {shlex.join(command)}')
        runs = [c[2] for c in args if len(c) == 3 and c[:2] == ['dart', 'run']]
        if set(runs) != {run['path'] for run in workflow['runs']}:
            raise Failure(f'{name}: run commands and expected-output inventory disagree')
        compiled = [c[3] for c in args if len(c) >= 4 and c[:2] == ['dart', 'compile']]
        if set(compiled) != set(workflow.get('compile', [])):
            raise Failure(f'{name}: compile commands and coverage inventory disagree')
    if names != {p.name for p in (root / 'docs/quickstarts').iterdir() if p.is_dir()}:
        raise Failure('Unclassified quickstart directory')
    for example in inventory['examples']:
        readme = root / example['path'] / 'README.md'
        if not readme.is_file() or example_table(example) not in readme.read_text():
            raise Failure(f"{example['path']}/README.md: sample coverage table differs from shared inventory")
        command = f"dart tool/validation/validate.dart example {example['name']} --mode=ci"
        if command not in readme.read_text():
            raise Failure(f'{readme.relative_to(root)}: missing exact sample validation command')
        for entry in example['entrypoints']:
            source = f"{example['path']}/{entry['path']}"
            if not safe_path(root, source).is_file():
                raise Failure(f'Missing inventoried example: {source}')
            owners[source] = example['name']
    check_homepage(root, owners)
    seen_sources = set()
    inclusions = 0
    for path in documents:
        text = document_text(path)
        check_links(root, path, text)
        label = str(path.relative_to(root))
        spans = []
        for match in INCLUSION.finditer(text):
            source = match[1]
            if source not in owners:
                raise Failure(f'{label}: included source lacks a checked workflow: {source}')
            if match[3] != safe_path(root, source).read_text().rstrip():
                raise Failure(f'{label}: stale inclusion of {source}; run documentation sync')
            spans.append((match.start(), match.end()))
            seen_sources.add(source)
            inclusions += 1
        if len(re.findall(r'^<!-- dddart-source:', text, re.M)) != len(spans):
            raise Failure(f'{label}: malformed or unclosed source inclusion')
        dart_index = 0
        for match in FENCE.finditer(text):
            if match['language'].lower() != 'dart':
                continue
            dart_index += 1
            if any(start <= match.start() < end for start, end in spans):
                continue
            key = f'{label}#dart-{dart_index}'
            raise Failure(f'{key}: unchecked Dart snippet; use a canonical source inclusion '
                          'owned by an executable workflow or shared sample lane')
    for workflow in metadata['workflows']:
        for item in workflow['files']:
            if item['source'].endswith('.dart'):
                source = f'docs/quickstarts/{workflow["name"]}/{item["source"]}'
                if source not in seen_sources:
                    raise Failure(f'Executable fixture is not published in scoped docs: {source}')
    if inclusions < 1:
        raise Failure('No canonical source inclusions found')
    check_exports(root, packages)
    print(f'Checked {len(documents)} current documentation/API surfaces, {inclusions} canonical '
          f'inclusions, {len(names)} workflows, {len(inventory["examples"])} sample guides, '
          'local links and public exports.', flush=True)
    return metadata, inventory


def export_directives(source):
    """Read directives without mistaking Dart comments or string data for code.

    Mask literals before matching directives so comment markers and semicolons
    inside URIs stay intact. Dart analysis remains responsible for syntax checks.
    """
    code = []
    strings = []
    position = 0
    string_start = re.compile("r?(\"\"\"|'''|\"|')")
    while position < len(source):
        if source.startswith('//', position):
            end = source.find('\n', position)
            position = len(source) if end == -1 else end
            code.append(' ')
        elif source.startswith('/*', position):
            position += 2
            depth = 1
            while position < len(source) and depth:
                if source.startswith('/*', position):
                    depth += 1
                    position += 2
                elif source.startswith('*/', position):
                    depth -= 1
                    position += 2
                else:
                    position += 1
            if depth:
                raise Failure('Unterminated Dart comment while scanning exports')
            code.append(' ')
        elif match := string_start.match(source, position):
            start = position
            raw = source[start] == 'r'
            quote = match[1]
            position = match.end()
            while position < len(source) and not source.startswith(quote, position):
                position += 2 if source[position] == '\\' and not raw else 1
            if position >= len(source):
                raise Failure('Unterminated Dart string while scanning exports')
            position += len(quote)
            code.append(f'\0{len(strings)}\0')
            strings.append(source[start:position])
        else:
            code.append(source[position])
            position += 1
    directives = re.findall(r'\bexport\s*(\0\d+\0[^;]*);', ''.join(code))
    return [' '.join(re.sub(r'\0(\d+)\0', lambda m: strings[int(m[1])], body).split())
            for body in directives]


def check_exports(root, packages):
    inventory = (root / 'docs/PUBLIC_API.md').read_text()
    listed = set(re.findall(r'^### `([^`]+)`', inventory, re.M))
    actual = set()
    for path in root.glob('packages/*/lib/*.dart'):
        label = f'{path.parent.parent.name}/{path.name}'
        actual.add(label)
        heading = f'### `{label}`'
        if heading not in inventory:
            raise Failure(f'New public entrypoint absent from API inventory: {label}')
        section = inventory.split(heading, 1)[1].split('\n### ', 1)[0]
        recorded = re.findall(r'^- `([^`]+)`', section, re.M)
        exports = export_directives(path.read_text())
        if recorded != exports:
            raise Failure(f'{label}: public exports differ from docs/PUBLIC_API.md')
    if listed != actual:
        raise Failure(f'API entrypoint inventory differs: {listed ^ actual}')
    matrix = (root / 'docs/CAPABILITIES.md').read_text()
    rows = set(re.findall(r'^\| (dddart\w*) \|', matrix, re.M))
    if rows != set(packages):
        raise Failure(f'Capability matrix differs from shared inventory: {rows ^ set(packages)}')


def sync(root=ROOT):
    for path in document_paths(root):
        text = path.read_text()
        def replace(match):
            source = safe_path(root, match[1])
            return (f'<!-- dddart-source: {match[1]} -->\n```{match[2]}\n'
                    f'{source.read_text().rstrip()}\n```\n<!-- /dddart-source -->')
        updated = INCLUSION.sub(replace, text)
        if updated != text:
            path.write_text(updated)
            print(f'Refreshed {path.relative_to(root)}')


def parse_command(line):
    args = shlex.split(line)
    additions = {}
    while args and re.fullmatch(r'[A-Z][A-Z0-9_]*=.*', args[0]):
        key, value = args.pop(0).split('=', 1)
        if not key.startswith('BOOKING_'):
            raise Failure(f'Unsupported documentation environment override: {key}')
        additions[key] = value
    if not args or args[0] not in ('dart', 'mkdir'):
        raise Failure(f'Unsupported documented command: {line}')
    if args[0] == 'mkdir' and args != ['mkdir', '-p', 'build']:
        raise Failure(f'Unsupported directory command: {line}')
    return additions, args


def environment(additions=None):
    # Do not inherit a hook's Git state or the user's demo configuration.
    result = {k: v for k, v in os.environ.items()
              if not k.startswith('GIT_') and not k.startswith('BOOKING_')}
    result.update(additions or {})
    result['CI'] = 'true'
    return result


def command(args, cwd, label, additions=None, timeout=180):
    print(f'{label}: {shlex.join(args)}', flush=True)
    try:
        result = subprocess.run(args, cwd=cwd, env=environment(additions),
                                text=True, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Failure(f'{label}: command {shlex.join(args)} failed: {error}') from error
    if result.returncode:
        raise Failure(f'{label}: command {shlex.join(args)} failed (exit {result.returncode})\n'
                      f'{result.stdout}\n{result.stderr}')
    return result.stdout


def stage(workflows, destination, root=ROOT):
    names = sorted({p for w in workflows for p in w['allowedLocalPackages']})
    command(['dart', str(root / 'tool/documentation/stage.dart'), str(destination), *names],
            root, 'local package staging', timeout=300)
    return {name: destination / 'packages' / name for name in names}


def require_service(workflow, inventory):
    kind = {'mongodb': 'mongo'}.get(workflow['service'], workflow['service'])
    if kind == 'none':
        return
    policies = inventory['testTagPolicies']
    for policy in policies:
        service = policy.get('service')
        if service and service['kind'] == kind:
            try:
                with socket.create_connection((service['host'], service['port']), timeout=3):
                    return
            except OSError as error:
                raise Failure(f'{workflow["name"]}: required {kind} service unavailable at '
                              f'{service["host"]}:{service["port"]}: {error}') from error
    raise Failure(f'{workflow["name"]}: no shared service policy for {kind}')


def run_workflow(workflow, staged=None, root=ROOT, javascript=True):
    name = workflow['name']
    base = root / 'docs/quickstarts' / name
    label = f'docs/quickstarts/{name} ({"local archives, NOT hosted proof" if staged else "pinned Git"})'
    with tempfile.TemporaryDirectory(prefix=f'dddart_docs_{name}_') as tmp:
        consumer = Path(tmp)
        for item in workflow['files']:
            target = safe_path(consumer, item['destination'])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(safe_path(base, item['source']), target)
        if staged is not None:
            manifest = consumer / 'pubspec.yaml'
            text = re.sub(r'^dependency_overrides:\n(?:[ \t].*\n|\n)*', '', manifest.read_text(), flags=re.M)
            text += 'dependency_overrides:\n'
            for package in workflow['allowedLocalPackages']:
                text += f'  {package}:\n    path: {json.dumps(str(staged[package]))}\n'
            manifest.write_text(text)
        expected = {r['path']: (base / r['stdoutFile']).read_text() for r in workflow['runs']}
        for script in workflow['commandsFiles']:
            for line in (base / script).read_text().splitlines():
                if not line.strip() or line.startswith('#'):
                    continue
                additions, args = parse_command(line)
                out = command(args, consumer, f'{label}/{script}', additions)
                if args[:2] == ['dart', 'run'] and args[2] in expected:
                    if out != expected[args[2]]:
                        raise Failure(f'{label}: {args[2]} expected stdout {expected[args[2]]!r}, got {out!r}')
        # Required outputs must be freshly produced in this empty consumer.
        for source in consumer.rglob('*.dart'):
            if '.dart_tool' in source.parts:
                continue
            for part in re.findall(r"^part ['\"]([^'\"]+\.g\.dart)['\"];", source.read_text(), re.M):
                if not (source.parent / part).is_file():
                    raise Failure(f'{label}: generation did not produce {part} for {source.name}')
        deps = json.loads(command(['dart', 'pub', 'deps', '--json'], consumer, label))
        local = {p['name'] for p in deps['packages'] if p['name'].startswith('dddart') and p['kind'] != 'root'}
        if local != set(workflow['allowedLocalPackages']):
            raise Failure(f'{label}: resolved DDDart closure differs: {local}')
        if staged is None:
            revision = read_json(root / 'docs/quickstarts/workflows.json')['revision']
            revisions = set(re.findall(r'resolved-ref: ["\']?([0-9a-f]{40})', (consumer / 'pubspec.lock').read_text()))
            if revisions != {revision}:
                raise Failure(f'{label}: lockfile did not resolve the documented revision: {revisions}')
        if javascript:
            for entrypoint in workflow.get('javascript', []):
                (consumer / 'build').mkdir(exist_ok=True)
                output = 'build/' + Path(entrypoint).stem + '.js'
                command(['dart', 'compile', 'js', entrypoint, '-o', output], consumer, label)
                out = command(['node', str(ROOT / 'tool/documentation/node_runner.cjs'), output], consumer, label)
                if out != expected[entrypoint]:
                    raise Failure(f'{label}: JavaScript output mismatch: {out!r}')
        print(f'PASS {label}; temporary application cleaned up.', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'sync', 'all', 'run'])
    parser.add_argument('name', nargs='?')
    parser.add_argument('--source', choices=['local', 'git'], default='local')
    parser.add_argument('--service-kind', choices=['all', 'none', 'mysql', 'mongo', 'dynamodb'], default='all')
    args = parser.parse_args()
    if args.action == 'sync':
        sync()
        return
    metadata, inventory = check()
    if args.action == 'check':
        return
    selected = [w for w in metadata['workflows'] if
                (args.action == 'all' or w['name'] == args.name) and
                (args.service_kind == 'all' or {'mongodb': 'mongo'}.get(w['service'], w['service']) == args.service_kind)]
    if not selected:
        raise Failure('No workflows selected; provide a valid name/service lane')
    for workflow in selected:
        require_service(workflow, inventory)
    with tempfile.TemporaryDirectory(prefix='dddart_documentation_archives_') as tmp:
        staged = stage(selected, Path(tmp)) if args.source == 'local' else None
        for workflow in selected:
            run_workflow(workflow, staged)


if __name__ == '__main__':
    try:
        main()
    except (Failure, KeyError, ValueError) as error:
        print(f'Documentation validation failed: {error}', file=sys.stderr)
        sys.exit(1)
