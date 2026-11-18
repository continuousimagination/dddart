import 'package:dddart/dddart.dart';

class SeatCount extends Value {
  factory SeatCount({required int value}) {
    if (value < 1) {
      throw ArgumentError.value(
          value, 'value', 'At least one seat is required');
    }
    return SeatCount._(value);
  }

  const SeatCount._(this.value);
  final int value;

  @override
  List<Object?> get props => [value];
}

class ReservationConfirmed extends DomainEvent<UuidValue, UuidValue> {
  ReservationConfirmed({
    required super.aggregateId,
    required this.guestName,
    UuidValue? eventId,
    super.occurredAt,
    super.context,
  }) : super(eventId: eventId ?? UuidValue.generate());

  final String guestName;
}

class Reservation extends AggregateRoot<UuidValue> {
  Reservation({
    required this.guestName,
    required this.seats,
    bool confirmed = false,
    UuidValue? id,
    super.createdAt,
    super.updatedAt,
  })  : _confirmed = confirmed,
        super(id: id ?? UuidValue.generate());

  final String guestName;
  final SeatCount seats;
  bool _confirmed;
  bool get confirmed => _confirmed;

  void confirm() {
    if (_confirmed) throw StateError('This reservation is already confirmed');
    _confirmed = true;
    touch();
    raiseEvent(ReservationConfirmed(
      aggregateId: id,
      guestName: guestName,
    ));
  }
}

Future<void> main() async {
  final Repository<Reservation, UuidValue> reservations =
      InMemoryRepository<Reservation, UuidValue>();
  final reservation = Reservation(
    guestName: 'Sam',
    seats: SeatCount(value: 2),
  );

  reservation.confirm();
  await reservations.save(reservation);

  final loaded = await reservations.getById(reservation.id);
  print('${loaded.guestName}: ${loaded.seats.value} seats, '
      'confirmed: ${loaded.confirmed}');
  print(loaded.getUncommittedEvents().single.runtimeType);
}
