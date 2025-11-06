import 'package:test/test.dart';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import 'test_models.dart';

void main() {
  group('Complex Object Graph Serialization', () {
    group('AggregateRoot with multiple nested entities and values', () {
      test('serializes complex AggregateRoot with nested structures', () {
        final homeAddress = TestAddress(
          street: '123 Home St',
          city: 'Home City',
          zipCode: '12345',
        );
        final workAddress = TestAddress(
          street: '456 Work Ave',
          city: 'Work City',
          zipCode: '67890',
        );
        final contactInfo = TestContactInfo(
          email: 'complex@example.com',
          phone: '+1-555-0123',
          address: homeAddress,
        );

        final complexUser = TestComplexUser(
          name: 'Complex User',
          contactInfo: contactInfo,
          addresses: [homeAddress, workAddress],
          tags: {'developer', 'tester', 'reviewer'},
          metadata: {
            'department': 'Engineering',
            'level': 'Senior',
            'active': true,
            'score': 95.5,
          },
        );

        final serializer = TestComplexUserJsonSerializer();
        final json = serializer.toJson(complexUser);

        // Verify top-level fields
        expect(json['name'], equals('Complex User'));
        expect(json['id'], isA<String>());
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());

        // Verify nested contact info
        expect(json['contactInfo'], isA<Map<String, dynamic>>());
        final contactJson = json['contactInfo'] as Map<String, dynamic>;
        expect(contactJson['email'], equals('complex@example.com'));
        expect(contactJson['phone'], equals('+1-555-0123'));
        expect(contactJson['address'], isA<Map<String, dynamic>>());

        // Verify nested address within contact info
        final nestedAddressJson = contactJson['address'] as Map<String, dynamic>;
        expect(nestedAddressJson['street'], equals('123 Home St'));
        expect(nestedAddressJson['city'], equals('Home City'));
        expect(nestedAddressJson['zipCode'], equals('12345'));

        // Verify addresses list
        expect(json['addresses'], isA<List>());
        final addressesList = json['addresses'] as List;
        expect(addressesList, hasLength(2));
        expect(addressesList[0]['street'], equals('123 Home St'));
        expect(addressesList[1]['street'], equals('456 Work Ave'));

        // Verify tags set
        expect(json['tags'], isA<List>());
        final tagsList = json['tags'] as List;
        expect(tagsList, hasLength(3));
        expect(tagsList, containsAll(['developer', 'tester', 'reviewer']));

        // Verify metadata map
        expect(json['metadata'], isA<Map<String, dynamic>>());
        final metadataMap = json['metadata'] as Map<String, dynamic>;
        expect(metadataMap['department'], equals('Engineering'));
        expect(metadataMap['level'], equals('Senior'));
        expect(metadataMap['active'], equals(true));
        expect(metadataMap['score'], equals(95.5));
      });

      test('deserializes complex AggregateRoot with nested structures', () {
        final json = {
          'name': 'Deserialized Complex User',
          'contactInfo': {
            'email': 'deserialized@example.com',
            'phone': '+1-555-9876',
            'address': {
              'street': '789 Deserial St',
              'city': 'Deserial City',
              'zipCode': '54321',
            },
          },
          'addresses': [
            {
              'street': '111 First St',
              'city': 'First City',
              'zipCode': '11111',
            },
            {
              'street': '222 Second St',
              'city': 'Second City',
              'zipCode': '22222',
            },
          ],
          'tags': ['admin', 'manager'],
          'metadata': {
            'department': 'Operations',
            'level': 'Lead',
            'active': false,
            'score': 88.0,
          },
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final serializer = TestComplexUserJsonSerializer();
        final complexUser = serializer.fromJson(json);

        expect(complexUser.name, equals('Deserialized Complex User'));
        expect(complexUser.contactInfo.email, equals('deserialized@example.com'));
        expect(complexUser.contactInfo.phone, equals('+1-555-9876'));
        expect(complexUser.contactInfo.address.street, equals('789 Deserial St'));
        
        expect(complexUser.addresses, hasLength(2));
        expect(complexUser.addresses[0].street, equals('111 First St'));
        expect(complexUser.addresses[1].street, equals('222 Second St'));
        
        expect(complexUser.tags, hasLength(2));
        expect(complexUser.tags, containsAll(['admin', 'manager']));
        
        expect(complexUser.metadata['department'], equals('Operations'));
        expect(complexUser.metadata['level'], equals('Lead'));
        expect(complexUser.metadata['active'], equals(false));
        expect(complexUser.metadata['score'], equals(88.0));
      });

      test('round-trip complex object maintains complete structure', () {
        final address1 = TestAddress(
          street: 'Round Trip St 1',
          city: 'RT City 1',
          zipCode: '11111',
        );
        final address2 = TestAddress(
          street: 'Round Trip St 2',
          city: 'RT City 2',
          zipCode: '22222',
        );
        final contactInfo = TestContactInfo(
          email: 'roundtrip@example.com',
          phone: '+1-555-1111',
          address: address1,
        );

        final original = TestComplexUser(
          name: 'Round Trip User',
          contactInfo: contactInfo,
          addresses: [address1, address2],
          tags: {'tag1', 'tag2', 'tag3'},
          metadata: {
            'key1': 'value1',
            'key2': 42,
            'key3': true,
            'key4': [1, 2, 3],
          },
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440001'),
          createdAt: DateTime.parse('2024-01-01T10:00:00.000Z'),
          updatedAt: DateTime.parse('2024-01-01T10:15:00.000Z'),
        );

        final serializer = TestComplexUserJsonSerializer();
        final json = serializer.toJson(original);
        final deserialized = serializer.fromJson(json);

        expect(deserialized, equals(original));
        expect(deserialized.contactInfo, equals(original.contactInfo));
        expect(deserialized.addresses, equals(original.addresses));
        expect(deserialized.tags, equals(original.tags));
        expect(deserialized.metadata, equals(original.metadata));
      });
    });

    group('Collections of entities and values', () {
      test('serializes AggregateRoot with collections of different types', () {
        final user1 = TestUser(name: 'User 1', email: 'user1@example.com');
        final user2 = TestUser(name: 'User 2', email: 'user2@example.com');
        
        final milestone1 = TestValueWithSpecialTypes(
          id: UuidValue.generate(),
          timestamp: DateTime.parse('2024-01-01T00:00:00.000Z'),
          name: 'Milestone 1',
        );
        final milestone2 = TestValueWithSpecialTypes(
          id: UuidValue.generate(),
          timestamp: DateTime.parse('2024-02-01T00:00:00.000Z'),
          name: 'Milestone 2',
        );

        final homeOffice = TestAddress(
          street: '123 Home Office',
          city: 'Remote City',
          zipCode: '00000',
        );
        final mainOffice = TestAddress(
          street: '456 Main Office',
          city: 'HQ City',
          zipCode: '11111',
        );

        final project = TestProject(
          title: 'Test Project',
          description: 'A project for testing collections',
          collaborators: [user1, user2],
          milestones: {milestone1, milestone2},
          settings: {
            'home_office': homeOffice,
            'main_office': mainOffice,
          },
        );

        final serializer = TestProjectJsonSerializer();
        final json = serializer.toJson(project);

        expect(json['title'], equals('Test Project'));
        expect(json['description'], equals('A project for testing collections'));

        // Verify collaborators list
        expect(json['collaborators'], isA<List>());
        final collaboratorsList = json['collaborators'] as List;
        expect(collaboratorsList, hasLength(2));
        expect(collaboratorsList[0]['name'], equals('User 1'));
        expect(collaboratorsList[1]['name'], equals('User 2'));

        // Verify milestones set
        expect(json['milestones'], isA<List>());
        final milestonesList = json['milestones'] as List;
        expect(milestonesList, hasLength(2));

        // Verify settings map
        expect(json['settings'], isA<Map<String, dynamic>>());
        final settingsMap = json['settings'] as Map<String, dynamic>;
        expect(settingsMap['home_office'], isA<Map<String, dynamic>>());
        expect(settingsMap['main_office'], isA<Map<String, dynamic>>());
      });

      test('deserializes collections maintaining proper types', () {
        final json = {
          'title': 'Deserialized Project',
          'description': 'Testing deserialization of collections',
          'collaborators': [
            {
              'name': 'Collaborator 1',
              'email': 'collab1@example.com',
              'id': '550e8400-e29b-41d4-a716-446655440010',
              'createdAt': '2024-01-01T08:00:00.000Z',
              'updatedAt': '2024-01-01T08:00:00.000Z',
            },
            {
              'name': 'Collaborator 2',
              'email': 'collab2@example.com',
              'id': '550e8400-e29b-41d4-a716-446655440011',
              'createdAt': '2024-01-01T09:00:00.000Z',
              'updatedAt': '2024-01-01T09:00:00.000Z',
            },
          ],
          'milestones': [
            {
              'id': '550e8400-e29b-41d4-a716-446655440020',
              'timestamp': '2024-03-01T00:00:00.000Z',
              'name': 'Deserialized Milestone 1',
            },
            {
              'id': '550e8400-e29b-41d4-a716-446655440021',
              'timestamp': '2024-04-01T00:00:00.000Z',
              'name': 'Deserialized Milestone 2',
            },
          ],
          'settings': {
            'primary': {
              'street': 'Primary Street',
              'city': 'Primary City',
              'zipCode': 'PRIMARY',
            },
            'secondary': {
              'street': 'Secondary Street',
              'city': 'Secondary City',
              'zipCode': 'SECONDARY',
            },
          },
          'id': '550e8400-e29b-41d4-a716-446655440030',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        final serializer = TestProjectJsonSerializer();
        final project = serializer.fromJson(json);

        expect(project.collaborators, hasLength(2));
        expect(project.collaborators[0].name, equals('Collaborator 1'));
        expect(project.collaborators[1].name, equals('Collaborator 2'));

        expect(project.milestones, hasLength(2));
        final milestonesList = project.milestones.toList();
        expect(milestonesList.any((m) => m.name == 'Deserialized Milestone 1'), isTrue);
        expect(milestonesList.any((m) => m.name == 'Deserialized Milestone 2'), isTrue);

        expect(project.settings, hasLength(2));
        expect(project.settings['primary']?.street, equals('Primary Street'));
        expect(project.settings['secondary']?.street, equals('Secondary Street'));
      });
    });

    group('Deeply nested object structures', () {
      test('serializes deeply nested Value objects', () {
        final deepChild = TestNestedValue(
          level: 3,
          data: 'Deep Level 3',
          child: null,
        );
        final midChild = TestNestedValue(
          level: 2,
          data: 'Mid Level 2',
          child: deepChild,
        );
        final topLevel = TestNestedValue(
          level: 1,
          data: 'Top Level 1',
          child: midChild,
        );

        final serializer = TestNestedValueJsonSerializer();
        final json = serializer.toJson(topLevel);

        expect(json['level'], equals(1));
        expect(json['data'], equals('Top Level 1'));
        expect(json['child'], isA<Map<String, dynamic>>());

        final midJson = json['child'] as Map<String, dynamic>;
        expect(midJson['level'], equals(2));
        expect(midJson['data'], equals('Mid Level 2'));
        expect(midJson['child'], isA<Map<String, dynamic>>());

        final deepJson = midJson['child'] as Map<String, dynamic>;
        expect(deepJson['level'], equals(3));
        expect(deepJson['data'], equals('Deep Level 3'));
        expect(deepJson['child'], isNull);
      });

      test('deserializes deeply nested structures correctly', () {
        final json = {
          'level': 1,
          'data': 'Deserialized Level 1',
          'child': {
            'level': 2,
            'data': 'Deserialized Level 2',
            'child': {
              'level': 3,
              'data': 'Deserialized Level 3',
              'child': null,
            },
          },
        };

        final serializer = TestNestedValueJsonSerializer();
        final nested = serializer.fromJson(json);

        expect(nested.level, equals(1));
        expect(nested.data, equals('Deserialized Level 1'));
        expect(nested.child, isNotNull);
        expect(nested.child!.level, equals(2));
        expect(nested.child!.data, equals('Deserialized Level 2'));
        expect(nested.child!.child, isNotNull);
        expect(nested.child!.child!.level, equals(3));
        expect(nested.child!.child!.data, equals('Deserialized Level 3'));
        expect(nested.child!.child!.child, isNull);
      });

      test('round-trip deeply nested structures maintain integrity', () {
        final original = TestNestedValue(
          level: 1,
          data: 'Round Trip Level 1',
          child: TestNestedValue(
            level: 2,
            data: 'Round Trip Level 2',
            child: TestNestedValue(
              level: 3,
              data: 'Round Trip Level 3',
              child: null,
            ),
          ),
        );

        final serializer = TestNestedValueJsonSerializer();
        final json = serializer.toJson(original);
        final deserialized = serializer.fromJson(json);

        expect(deserialized, equals(original));
        expect(deserialized.child, equals(original.child));
        expect(deserialized.child?.child, equals(original.child?.child));
      });
    });

    group('Performance with large object graphs', () {
      test('handles serialization of large collections efficiently', () {
        final addresses = List.generate(100, (i) => 
          TestAddress(
            street: 'Street $i',
            city: 'City $i',
            zipCode: 'Zip$i',
          ));
        
        final tags = Set<String>.from(List.generate(50, (i) => 'tag$i'));
        
        final metadata = Map.fromEntries(
          List.generate(200, (i) => MapEntry('key$i', 'value$i')));

        final contactInfo = TestContactInfo(
          email: 'performance@example.com',
          phone: '+1-555-PERF',
          address: addresses.first,
        );

        final largeUser = TestComplexUser(
          name: 'Performance Test User',
          contactInfo: contactInfo,
          addresses: addresses,
          tags: tags,
          metadata: metadata,
        );

        // Measure serialization performance
        final stopwatch = Stopwatch()..start();
        final serializer = TestComplexUserJsonSerializer();
        final json = serializer.toJson(largeUser);
        stopwatch.stop();

        // Verify the serialization completed and produced expected structure
        expect(json['addresses'], hasLength(100));
        expect(json['tags'], hasLength(50));
        expect(json['metadata'], hasLength(200));
        
        // Performance should be reasonable (less than 100ms for this size)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('handles deserialization of large collections efficiently', () {
        final json = {
          'name': 'Large Deserialization Test',
          'contactInfo': {
            'email': 'large@example.com',
            'phone': '+1-555-LARGE',
            'address': {
              'street': 'Large Street',
              'city': 'Large City',
              'zipCode': 'LARGE',
            },
          },
          'addresses': List.generate(100, (i) => {
            'street': 'Street $i',
            'city': 'City $i',
            'zipCode': 'Zip$i',
          }),
          'tags': List.generate(50, (i) => 'tag$i'),
          'metadata': Map.fromEntries(
            List.generate(200, (i) => MapEntry('key$i', 'value$i'))),
          'id': '550e8400-e29b-41d4-a716-446655440099',
          'createdAt': '2024-01-01T12:00:00.000Z',
          'updatedAt': '2024-01-01T12:30:00.000Z',
        };

        // Measure deserialization performance
        final stopwatch = Stopwatch()..start();
        final serializer = TestComplexUserJsonSerializer();
        final largeUser = serializer.fromJson(json);
        stopwatch.stop();

        // Verify the deserialization completed correctly
        expect(largeUser.addresses, hasLength(100));
        expect(largeUser.tags, hasLength(50));
        expect(largeUser.metadata, hasLength(200));
        
        // Performance should be reasonable (less than 100ms for this size)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}