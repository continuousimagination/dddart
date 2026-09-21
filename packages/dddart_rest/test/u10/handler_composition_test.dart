/// HTTP routing can be composed without opening a listening socket.
library;

import 'package:dddart_rest/dddart_rest.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('buildHandler dispatches routes without starting server', () async {
    final server = HttpServer(port: 0)
      ..addRoute('GET', '/probe', (Request request) => Response.ok('yes'));
    final handler = server.buildHandler();
    expect(
      await (await handler(
        Request('GET', Uri.parse('https://example.invalid/probe')),
      )).readAsString(),
      'yes',
    );
    await expectLater(server.stop(), throwsStateError);
  });
  test('handler uses the same route and CORS policy', () async {
    final server = HttpServer(port: 0)
      ..allowOrigins(['https://client.invalid'])
      ..addRoute('GET', '/probe', (Request request) => Response.ok('yes'));
    final response = await server.buildHandler()(
      Request(
        'GET',
        Uri.parse('https://example.invalid/probe'),
        headers: {'origin': 'https://client.invalid'},
      ),
    );
    expect(response.statusCode, 200);
    expect(
      response.headers['access-control-allow-origin'],
      'https://client.invalid',
    );
  });
  test('unknown routes and unsupported methods do not dispatch', () async {
    var calls = 0;
    final server = HttpServer(port: 0)
      ..addRoute('GET', '/probe', (Request request) {
        calls++;
        return Response.ok('yes');
      });
    expect(
      (await server.buildHandler()(
        Request('POST', Uri.parse('https://example.invalid/probe')),
      )).statusCode,
      isNot(200),
    );
    expect(calls, 0);
    final invalid = HttpServer(port: 0)
      ..addRoute('BROKEN', '/probe', (Request r) => Response.ok('no'));
    expect(invalid.buildHandler, throwsArgumentError);
  });
}
