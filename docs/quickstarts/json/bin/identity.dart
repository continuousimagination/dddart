import 'dart:convert';

import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';

class IssueId extends Identity {
  const IssueId(this.repository, this.number);
  final String repository;
  final int number;

  @override
  List<Object?> get props => [repository, number];
}

class IssueIdCodec implements IdentityCodec<IssueId> {
  const IssueIdCodec();

  @override
  Object toJson(IssueId identity) => {
        'repository': identity.repository,
        'number': identity.number,
      };

  @override
  IssueId fromJson(Object? value) {
    if (value is! Map ||
        value['repository'] is! String ||
        value['number'] is! int) {
      throw const FormatException('Expected repository and integer number');
    }
    return IssueId(value['repository'] as String, value['number'] as int);
  }

  @override
  String toKey(IssueId identity) =>
      jsonEncode([identity.repository, identity.number]);

  @override
  IssueId fromKey(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List ||
        decoded.length != 2 ||
        decoded[0] is! String ||
        decoded[1] is! int) {
      throw const FormatException('Expected canonical issue key');
    }
    return IssueId(decoded[0] as String, decoded[1] as int);
  }
}

void main() {
  final codecs = IdentityCodecRegistry()
    ..register<IssueId>('issue.v1', const IssueIdCodec());
  const id = IssueId('team/booking', 12);
  final key = codecs.toKey(id);
  print(codecs.fromKey<IssueId>(key) == id); // true
  print(codecs.toTaggedJson(id)['type']); // issue.v1
}
