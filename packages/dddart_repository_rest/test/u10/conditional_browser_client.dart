/// Executable real-browser contract client, compiled by the isolated driver.
library;

import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:dddart_shared_model_fixture/versioned_model.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'conditional_binding.dart';

const _base = String.fromEnvironment('SSG_BROWSER_BASE');

class _CountingClient extends http.BaseClient {
  _CountingClient(this.inner);
  final BrowserClient inner;
  int puts = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.method == 'PUT') puts++;
    return inner.send(request);
  }
}

void _require(bool value, String label) {
  if (!value) throw StateError(label);
}

Future<void> main() async {
  final raw = BrowserClient();
  final counted = _CountingClient(raw);
  final results = <String, Object?>{};
  var current = 'setup';
  var sequence = 1;
  VersionedRecord record({
    UuidValue? id,
    int revision = 0,
    String text = 'initial',
  }) => VersionedRecord(
    id:
        id ??
        UuidValue.fromString(
          '00000000-0000-4000-8000-${(sequence++).toString().padLeft(12, '0')}',
        ),
    text: text,
    tags: ['synthetic'],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    revision: Revision(revision),
  );
  ConditionalProbeRestRepository repository(String scenario) =>
      ConditionalProbeRestRepository(
        RestConnection(baseUrl: '$_base/$scenario', httpClient: counted),
      );
  Future<Map<String, dynamic>> stats(String scenario) async =>
      jsonDecode((await raw.get(Uri.parse('$_base/stats/$scenario'))).body)
          as Map<String, dynamic>;
  Future<WriteOutcomeUnknownException> uncertain(
    Future<Object?> operation,
  ) async {
    try {
      await operation;
      throw StateError('Unexpected acknowledgment');
    } on WriteOutcomeUnknownException catch (error) {
      return error;
    }
  }

  try {
    for (final cross in [false, true]) {
      for (final status in [301, 302, 303, 307, 308]) {
        current = 'redirect_${cross ? 'cross' : 'same'}_$status';
        final value = record();
        final before = counted.puts;
        await uncertain(
          repository(
            current,
          ).save(value, precondition: const WritePrecondition.absent()),
        );
        _require(counted.puts == before + 1, 'redirect app dispatch');
      }
      current = 'get_redirect_${cross ? 'cross' : 'same'}_302';
      try {
        await repository(current).getById(record().id);
        throw StateError('Unexpected redirect success');
      } on RepositoryException {
        /* The redirect is a normal failed read. */
      }
    }
    _require(
      (await stats('targets'))['targets'] == 0,
      'redirect target received request',
    );
    results['redirectCases'] = 12;

    for (final scenario in ['replay421', 'lost', 'denied421']) {
      current = scenario;
      final value = record();
      final repo = repository(scenario);
      await raw.get(Uri.parse('$_base/$scenario/warm'));
      final before = counted.puts;
      final error = await uncertain(
        repo.save(value, precondition: const WritePrecondition.absent()),
      );
      _require(counted.puts == before + 1, 'application replay');
      _require(
        error.observedFailure ==
            (scenario == 'denied421'
                ? RepositoryExceptionType.unauthorized
                : RepositoryExceptionType.constraint),
        'final status classification',
      );
      _require(
        error.accessUnavailable == (scenario == 'denied421'),
        'access classification',
      );
      final seen = await stats(scenario);
      _require(
        seen['puts'] == 2 && seen['mutations'] == 1 && seen['gets'] == 0,
        'wire replay accounting',
      );
      if (scenario == 'lost') {
        _require(
          seen['reused'] == true,
          'lost response used warmed connection',
        );
      }
      if (!error.accessUnavailable) {
        final observed = await repo.getById(value.id);
        _require(
          observed.revision == Revision(1),
          'observed committed first copy',
        );
      }
      results[scenario] = {
        'appPuts': 1,
        'wirePuts': seen['puts'],
        'mutations': seen['mutations'],
        'accessUnavailable': error.accessUnavailable,
      };
    }

    current = 'race';
    final first = repository(current);
    final second = repository(current);
    final original = record();
    Future<Object> outcome(Future<VersionedRecord> operation) async {
      try {
        return await operation;
      } on WriteOutcomeUnknownException catch (error) {
        return error;
      }
    }

    final creates = await Future.wait([
      outcome(
        first.save(original, precondition: const WritePrecondition.absent()),
      ),
      outcome(
        second.save(
          record(id: original.id, text: 'other'),
          precondition: const WritePrecondition.absent(),
        ),
      ),
    ]);
    _require(
      creates.whereType<VersionedRecord>().length == 1 &&
          creates.whereType<WriteOutcomeUnknownException>().length == 1,
      'create race',
    );
    final updates = await Future.wait([
      outcome(
        first.save(
          record(id: original.id, revision: 1, text: 'A'),
          precondition: WritePrecondition.atRevision(Revision(1)),
        ),
      ),
      outcome(
        second.save(
          record(id: original.id, revision: 1, text: 'B'),
          precondition: WritePrecondition.atRevision(Revision(1)),
        ),
      ),
    ]);
    final winner = updates.whereType<VersionedRecord>().single;
    _require(
      updates.whereType<WriteOutcomeUnknownException>().length == 1 &&
          winner.revision == Revision(2),
      'update race',
    );
    _require(
      (await first.getById(original.id)).text == winner.text,
      'winner observed',
    );
    final newer = await second.save(
      record(id: original.id, revision: 2, text: 'newer'),
      precondition: WritePrecondition.atRevision(Revision(2)),
    );
    await uncertain(
      first.save(
        record(id: original.id, revision: 1, text: 'stale'),
        precondition: WritePrecondition.atRevision(Revision(1)),
      ),
    );
    final observed = await first.getById(original.id);
    _require(
      observed.revision == newer.revision && observed.text == newer.text,
      'stale overwrite',
    );
    await second.deleteById(
      original.id,
      precondition: WritePrecondition.atRevision(Revision(3)),
    );
    try {
      await first.getById(original.id);
      throw StateError('Retired root visible');
    } on RepositoryException catch (error) {
      _require(
        error.type == RepositoryExceptionType.notFound,
        'retired read classification',
      );
    }
    await uncertain(
      first.save(original, precondition: const WritePrecondition.absent()),
    );
    final raced = await stats(current);
    _require(raced['mutations'] == 4, 'race mutation count');
    results['race'] = {
      'wirePuts': raced['puts'],
      'mutations': raced['mutations'],
    };
    results['pass'] = true;
  } catch (error) {
    results['pass'] = false;
    results['case'] = current;
    results['errorType'] = error.runtimeType.toString();
  }
  await raw.post(Uri.parse('$_base/report'), body: jsonEncode(results));
  raw.close();
}
