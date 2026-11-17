#!/usr/bin/env python3
"""Fault-inject real documentation consumers; no live services or credentials."""
import contextlib
import io
from pathlib import Path
import shutil
import socket
import tempfile
import unittest

import validate as gate


class ExportScanning(unittest.TestCase):
    def test_export_prose_and_commented_directives_are_ignored(self):
        source = """/// Keep internal types out of this export namespace.
library;
// export 'line_comment.dart';
/* export 'block_comment.dart';
   /* Nested Dart comments are allowed. */
   export 'still_commented.dart'; */
export 'public.dart';
"""
        self.assertEqual(gate.export_directives(source), ["'public.dart'"])

    def test_literals_do_not_create_directives_or_comments(self):
        source = """const example = '''
export 'example.dart';
''';
const rawExample = r"export 'raw_example.dart'; //";
const escaped = 'It\\'s not an export';
export 'https://example.com/public.dart';
"""
        self.assertEqual(gate.export_directives(source), ["'https://example.com/public.dart'"])

    def test_multiline_conditional_and_filtered_exports_keep_their_contract(self):
        source = """export /* public API */ 'base.dart'
  if (dart.library.io) 'native.dart'
  show First, Second;
export 'other.dart' // internal implementation
  hide Internal;
"""
        self.assertEqual(gate.export_directives(source), [
            "'base.dart' if (dart.library.io) 'native.dart' show First, Second",
            "'other.dart' hide Internal",
        ])


class DocumentationFailures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.metadata, cls.inventory = gate.check()
        cls.json = next(w for w in cls.metadata['workflows'] if w['name'] == 'json')
        cls.archive_temp = tempfile.TemporaryDirectory(prefix='dddart_doc_fault_archives_')
        cls.addClassCleanup(cls.archive_temp.cleanup)
        cls.staged = gate.stage([cls.json], Path(cls.archive_temp.name))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dddart_doc_fault_sources_')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for source in gate.repository_files(gate.ROOT):
            target = self.root / source.relative_to(gate.ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)

    def change(self, path, before, after):
        target = self.root / path
        text = target.read_text()
        self.assertIn(before, text, path)
        target.write_text(text.replace(before, after, 1))

    def sync(self):
        with contextlib.redirect_stdout(io.StringIO()):
            gate.sync(self.root)

    def test_new_primary_snippet_requires_checked_source(self):
        path = self.root / 'README.md'
        path.write_text(path.read_text() + '\n```dart\nvoid unclassified() {}\n```\n')
        with self.assertRaisesRegex(gate.Failure, 'README.md#dart-.*unchecked'):
            gate.check(self.root)

    def test_new_standalone_guide_requires_inventory_review(self):
        (self.root / 'docs/NEW_GUIDE.md').write_text('# New guide\n')
        with self.assertRaisesRegex(gate.Failure, 'surface inventory.*NEW_GUIDE'):
            gate.check(self.root)

    def test_standalone_guide_snippets_are_checked(self):
        path = self.root / 'packages/dddart/GETTING_STARTED.md'
        path.write_text(path.read_text() + '\n```dart\nMissingType sample;\n```\n')
        with self.assertRaisesRegex(gate.Failure, 'GETTING_STARTED.md.*unchecked'):
            gate.check(self.root)

    def test_deep_api_comment_snippets_are_checked(self):
        path = self.root / 'packages/dddart/lib/src/entity.dart'
        path.write_text(path.read_text() + '\n/// ```dart\n/// MissingType sample;\n/// ```\n')
        with self.assertRaisesRegex(gate.Failure, 'entity.dart.*unchecked'):
            gate.check(self.root)

    def test_broken_relative_link_is_rejected(self):
        path = self.root / 'packages/dddart/GETTING_STARTED.md'
        path.write_text(path.read_text() + '\n[Missing](missing.md)\n')
        with self.assertRaisesRegex(gate.Failure, 'GETTING_STARTED.md: broken local link'):
            gate.check(self.root)

    def test_broken_repository_url_anchor_is_rejected(self):
        path = self.root / 'README.md'
        path.write_text(path.read_text() + '\n[Missing](https://github.com/continuousimagination/dddart/blob/main/docs/README.md#gone)\n')
        with self.assertRaisesRegex(gate.Failure, 'broken local anchor'):
            gate.check(self.root)

    def test_changed_sample_coverage_cannot_keep_old_readme(self):
        self.change('tool/validation/inventory.json',
                    'Finite detached revision-read', 'Changed detached revision-read')
        with self.assertRaisesRegex(gate.Failure, 'sample coverage table differs'):
            gate.check(self.root)

    def test_historical_exemption_requires_visible_notice(self):
        self.change('packages/dddart/CHANGELOG.md', gate.HISTORICAL_NOTICE, 'Removed notice')
        with self.assertRaisesRegex(gate.Failure, 'historical document lacks'):
            gate.check(self.root)

    def test_homepage_cannot_reintroduce_unchecked_code(self):
        self.change('website/src/pages/index.astro', 'code: modelExample', 'code: `MissingType value;`')
        with self.assertRaisesRegex(gate.Failure, 'Homepage Dart code'):
            gate.check(self.root)

    def test_tilde_and_long_fences_cannot_bypass_source_checks(self):
        path = self.root / 'README.md'
        original = path.read_text()
        for fence in ('~~~', '````'):
            path.write_text(original + f'\n{fence}Dart\nMissingType value;\n{fence}\n')
            with self.assertRaisesRegex(gate.Failure, 'unchecked Dart snippet'):
                gate.check(self.root)

    def test_stale_published_code_fails_with_its_document_path(self):
        self.change('README.md', "guestName: 'Sam'", "guestName: 'Stale'")
        with self.assertRaisesRegex(gate.Failure, 'README.md: stale inclusion'):
            gate.check(self.root)

    def test_stale_documented_command_is_not_silently_ignored(self):
        self.change('README.md', 'dart pub get', 'dart pub missing')
        with self.assertRaisesRegex(gate.Failure, 'README.md: stale inclusion'):
            gate.check(self.root)

    def test_public_export_change_requires_inventory_review(self):
        path = self.root / 'packages/dddart_json/lib/dddart_json.dart'
        path.write_text(path.read_text() + "\nexport 'src/unreviewed.dart';\n")
        with self.assertRaisesRegex(gate.Failure, 'public exports differ'):
            gate.check(self.root)

    def test_comment_only_export_mentions_do_not_change_inventory(self):
        path = self.root / 'packages/dddart_repository_sql/lib/generator.dart'
        path.write_text(path.read_text() + "\n// export 'not_public.dart';\n"
                        "/* export 'also_not_public.dart'; */\n")
        with contextlib.redirect_stdout(io.StringIO()):
            gate.check(self.root)

    def test_missing_builder_dependency_fails_before_execution(self):
        self.change('docs/quickstarts/json/pubspec.yaml.txt', '  build_runner: ^2.4.0\n', '')
        self.sync()
        with self.assertRaisesRegex(gate.Failure, 'pubspec must declare build_runner'):
            gate.check(self.root)

    def test_compile_only_example_cannot_silently_lose_compilation(self):
        self.change('docs/quickstarts/slack_server/commands.sh',
                    'dart compile kernel bin/main.dart -o build/server.dill\n', '')
        self.sync()
        with self.assertRaisesRegex(gate.Failure, 'slack_server: compile commands'):
            gate.check(self.root)

    def test_missing_required_service_fails_instead_of_skipping(self):
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        inventory = {'testTagPolicies': [{'service': {'kind': 'mysql', 'host': '127.0.0.1', 'port': port}}]}
        with self.assertRaisesRegex(gate.Failure, 'required mysql service unavailable'):
            gate.require_service({'name': 'mysql', 'service': 'mysql'}, inventory)

    def test_broken_import_fails_real_generation_or_analysis(self):
        self.change('docs/quickstarts/json/lib/reservation.dart',
                    'package:dddart/dddart.dart', 'package:missing_domain/missing.dart')
        with self.assertRaisesRegex(gate.Failure, 'docs/quickstarts/json.*command') as caught:
            gate.run_workflow(self.json, self.staged, self.root, javascript=False)
        self.assertIn('lib/reservation.dart', str(caught.exception))

    def test_broken_constructor_fails_real_analysis(self):
        self.change('docs/quickstarts/json/bin/main.dart', 'SeatCount(value: 2)', 'SeatCount(seats: 2)')
        with self.assertRaisesRegex(gate.Failure, 'command dart analyze') as caught:
            gate.run_workflow(self.json, self.staged, self.root, javascript=False)
        self.assertIn('seats', str(caught.exception))
        self.assertIn('bin/main.dart', str(caught.exception))

    def test_wrong_part_directive_fails_with_fresh_outputs(self):
        self.change('docs/quickstarts/json/lib/reservation.dart',
                    "part 'reservation.g.dart';", "part 'missing.g.dart';")
        with self.assertRaises(gate.Failure) as caught:
            gate.run_workflow(self.json, self.staged, self.root, javascript=False)
        self.assertIn('missing.g.dart', str(caught.exception))
        self.assertIn('command', str(caught.exception))

    def test_wrong_runtime_result_fails_after_successful_compilation(self):
        self.change('docs/quickstarts/json/expected/main.txt', 'Sam\n', 'Incorrect\n')
        with self.assertRaisesRegex(gate.Failure, 'bin/main.dart expected stdout'):
            gate.run_workflow(self.json, self.staged, self.root, javascript=False)


if __name__ == '__main__':
    unittest.main(verbosity=2)
