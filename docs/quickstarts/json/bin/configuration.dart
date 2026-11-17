import 'package:dddart_serialization/dddart_serialization.dart';

import '../lib/reservation.dart';

void main() {
  const apiFormat = SerializationConfig(
    fieldRename: FieldRename.snake,
    includeNullFields: true,
  );
  final serializer = ReservationJsonSerializer(apiFormat);
  final reservation = Reservation(
    guestName: 'Sam',
    seats: SeatCount(value: 2),
  );

  final wire = serializer.toJson(reservation);
  print(wire['guest_name']); // Sam
  print(wire.containsKey('note')); // true
  final restored = serializer.fromJson(wire);
  print(restored.guestName); // Sam

  // This call uses the framework settings instead of apiFormat.
  final ordinary = serializer.toJson(reservation, const SerializationConfig());
  print(ordinary['guestName']); // Sam
}
