import 'dart:convert';

import 'package:dddart_events_distributed/src/event_bus_server.dart';
import 'package:dddart_events_distributed/src/event_repository.dart';
import 'package:dddart_events_distributed/src/stored_event.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

/// HTTP endpoints for event distribution.
///
/// Provides GET and POST endpoints for retrieving and submitting events
/// via HTTP. Supports optional authorization filtering to control which
/// events are delivered to specific clients.
class EventHttpEndpoints<T extends StoredEvent> {
  /// Creates HTTP endpoints for event distribution.
  ///
  /// [eventRepository] is used to query and store events.
  /// [authorizationFilter] is an optional function that determines whether
  /// a specific event should be delivered to a specific client based on
  /// the event data and HTTP request context.
  EventHttpEndpoints({
    required this.eventRepository,
    this.authorizationFilter,
  });

  /// Repository for querying and storing events.
  final EventRepository<T> eventRepository;

  /// Optional authorization filter function.
  ///
  /// If provided, this function is called for each event before including
  /// it in the response. Return true to include the event, false to exclude.
  final bool Function(T event, Request request)? authorizationFilter;

  /// Logger for HTTP operations.
  final Logger _logger = Logger('dddart.events.http');

  /// Handles GET /events?since=<ISO8601 timestamp> requests.
  ///
  /// Queries the event repository for all events since the provided timestamp
  /// and returns them as a JSON array. Applies authorization filtering if
  /// configured.
  ///
  /// Returns:
  /// - 200 OK with JSON array of events
  /// - 400 Bad Request if 'since' parameter is missing or invalid
  /// - 500 Internal Server Error if query fails
  Future<Response> handleGetEvents(Request request) async {
    try {
      // Parse timestamp parameter
      final sinceParam = request.url.queryParameters['since'];
      if (sinceParam == null) {
        _logger.warning('GET /events: missing "since" parameter');
        return Response(
          400,
          body: jsonEncode({
            'error': 'Missing required parameter: since',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      DateTime since;
      try {
        since = DateTime.parse(sinceParam);
      } catch (e) {
        _logger.warning('GET /events: invalid timestamp format: $sinceParam');
        return Response(
          400,
          body: jsonEncode({
            'error': 'Invalid timestamp format. Expected ISO 8601.',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Query events from repository
      final events = await eventRepository.findSince(since);

      // Apply authorization filter if configured
      final authorizedEvents = authorizationFilter != null
          ? events.where((event) {
              try {
                return authorizationFilter!(event, request);
              } catch (e, stackTrace) {
                _logger.severe(
                  'Authorization filter error for event ${event.id}',
                  e,
                  stackTrace,
                );
                return false; // Exclude event on filter error
              }
            }).toList()
          : events;

      _logger.info(
        'GET /events: returned ${authorizedEvents.length} events '
        '(since: $since, total: ${events.length})',
      );

      // Return as JSON array
      return Response.ok(
        jsonEncode(authorizedEvents.map((e) => e.toJson()).toList()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('GET /events failed', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handles POST /events requests.
  ///
  /// Accepts a JSON body containing a StoredEvent, saves it to the repository,
  /// and returns the event ID and timestamp.
  ///
  /// Returns:
  /// - 201 Created with event ID and timestamp
  /// - 400 Bad Request if JSON is invalid or deserialization fails
  /// - 500 Internal Server Error if save fails
  Future<Response> handlePostEvent(
    Request request,
    EventBusServer<T>? server,
  ) async {
    try {
      // Read and parse request body
      final body = await request.readAsString();

      Map<String, dynamic> eventJson;
      try {
        eventJson = jsonDecode(body) as Map<String, dynamic>;
      } catch (e) {
        _logger.warning('POST /events: invalid JSON body');
        return Response(
          400,
          body: jsonEncode({
            'error': 'Invalid JSON format',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Deserialize StoredEvent
      T stored;
      try {
        stored = StoredEvent.fromJson(eventJson) as T;
      } catch (e) {
        _logger.warning('POST /events: deserialization failed', e);
        return Response(
          400,
          body: jsonEncode({
            'error': 'Invalid event data',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Save to repository
      await eventRepository.save(stored);

      _logger.info(
        'POST /events: stored event ${stored.eventType} (${stored.id})',
      );

      // Return 201 Created with event details
      return Response(
        201,
        body: jsonEncode({
          'id': stored.id.toString(),
          'createdAt': stored.createdAt.toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('POST /events failed', e, stackTrace);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
