/// REST repository connection must remain usable through its public web barrel.
library;

import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_repository_rest/dddart_repository_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'binding.dart';
import 'shared_model.dart';

void main() {
  test('public connection dispatches unchanged URI on VM/web', () async {
    final connection = RestConnection(
      baseUrl: 'https://example.invalid/',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/probe');
        return http.Response('ok', 200);
      }),
    );
    expect(
      (await connection.client.get(
        Uri.parse('${connection.baseUrl}probe'),
      )).body,
      'ok',
    );
    connection.dispose();
  });
  final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
  final now = DateTime.utc(2026, 9, 21);
  RemoteRecord record() =>
      RemoteRecord(id: id, createdAt: now, updatedAt: now, text: 'synthetic');
  test(
    'external prefixed model uses its shared serializer for read and void save',
    () async {
      var sends = 0;
      final connection = RestConnection(
        baseUrl: 'https://example.invalid/',
        httpClient: MockClient((request) async {
          sends++;
          expect(request.url.path, '/records/${id.uuid}');
          if (request.method == 'PUT') {
            expect((jsonDecode(request.body) as Map)['text'], 'synthetic');
            return http.Response('', 204);
          }
          return http.Response(
            RemoteRecordJsonSerializer().serialize(record()),
            200,
          );
        }),
      );
      final Repository<RemoteRecord> repo = ProbeRestRepository(connection);
      await repo.save(record());
      expect((await repo.getById(id)).text, 'synthetic');
      expect(sends, 2);
      connection.dispose();
    },
  );
  test(
    'provider response details never become public errors or repeat a write',
    () async {
      const marker = 'restricted-response-detail';
      var sends = 0;
      final connection = RestConnection(
        baseUrl: 'https://example.invalid/',
        httpClient: MockClient((request) async {
          sends++;
          return http.Response(jsonEncode({'detail': marker}), 503);
        }),
      );
      try {
        await ProbeRestRepository(connection).save(record());
        fail('Expected repository failure');
      } on RepositoryException catch (error) {
        expect(error.type, RepositoryExceptionType.connection);
        expect(error.toString(), isNot(contains(marker)));
      }
      expect(sends, 1);
      connection.dispose();
    },
  );
  test(
    'raw transport failures stay uncertain without leaking values or replay',
    () async {
      const marker = 'restricted-network-value';
      var sends = 0;
      final connection = RestConnection(
        baseUrl: 'https://example.invalid/',
        httpClient: MockClient((request) async {
          sends++;
          throw http.ClientException(marker);
        }),
      );
      try {
        await ProbeRestRepository(connection).save(record());
        fail('Expected repository failure');
      } on RepositoryException catch (error) {
        expect(error.type, RepositoryExceptionType.unknown);
        expect(error.toString(), isNot(contains(marker)));
      }
      expect(sends, 1);
      connection.dispose();
    },
  );
  test('authoritative validation status retains a typed rejection', () async {
    for (final status in [400, 412, 422]) {
      final connection = RestConnection(
        baseUrl: 'https://example.invalid/',
        httpClient: MockClient(
          (request) async =>
              http.Response('restricted-validation-value', status),
        ),
      );
      await expectLater(
        ProbeRestRepository(connection).save(record()),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.type,
            'type',
            RepositoryExceptionType.constraint,
          ),
        ),
      );
      connection.dispose();
    }
  });
}
