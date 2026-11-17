import '../lib/reservation.dart';

void main() {
  final serializer = ReservationJsonSerializer();
  final original = Reservation(
    guestName: 'Sam',
    seats: SeatCount(value: 2),
  );

  final json = serializer.toJson(original);
  final text = serializer.serialize(original);
  final restored = serializer.deserialize(text);

  print(json['guestName']); // Sam
  print(restored.id == original.id); // true
  print(restored.seats == original.seats); // true
}
