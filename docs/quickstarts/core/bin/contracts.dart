import 'package:dddart/dddart.dart';

class Reservation extends AggregateRoot<UuidValue> {
  Reservation({required this.guest}) : super(id: UuidValue.generate());
  final String guest;
  bool _confirmed = false;
  bool get confirmed => _confirmed;

  void confirm() {
    if (_confirmed) throw StateError('Already confirmed');
    _confirmed = true;
    touch();
  }
}

class ConfirmReservation {
  ConfirmReservation(this.reservations);
  final Repository<Reservation, UuidValue> reservations;

  Future<void> call(UuidValue id) async {
    final reservation = await reservations.getById(id);
    reservation.confirm();
    await reservations.save(reservation);
  }
}

Future<void> main() async {
  final repository = InMemoryRepository<Reservation, UuidValue>();
  final reservation = Reservation(guest: 'Sam');
  await repository.save(reservation);

  final confirm = ConfirmReservation(repository);
  await confirm(reservation.id);

  print((await repository.getById(reservation.id)).confirmed); // true
}
