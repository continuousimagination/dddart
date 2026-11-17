import 'package:dddart/dddart.dart';

class Note extends AggregateRoot<UuidValue> {
  Note({required this.title, UuidValue? id})
      : super(id: id ?? UuidValue.generate());

  final String title;
}

Future<String> readTitle(
  Repository<Note, UuidValue> notes,
  UuidValue id,
) async {
  final note = await notes.getById(id);
  return note.title;
}

Future<void> main() async {
  final Repository<Note, UuidValue> notes =
      InMemoryRepository<Note, UuidValue>();
  final note = Note(title: 'Ship the first version');

  await notes.save(note);
  print(await readTitle(notes, note.id));
  await notes.deleteById(note.id);
}
