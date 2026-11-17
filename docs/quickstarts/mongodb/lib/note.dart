import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_json/dddart_json.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'package:dddart_repository_mongodb/dddart_repository_mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart';

part 'note.g.dart';

@Serializable()
@GenerateMongoRepository(collectionName: 'quickstart_notes')
class Note extends AggregateRoot<UuidValue> {
  Note({required this.text, UuidValue? id, super.createdAt, super.updatedAt})
      : super(id: id ?? UuidValue.generate());
  final String text;
}
