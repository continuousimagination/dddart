// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_models.dart';

// **************************************************************************
// SerializableGenerator
// **************************************************************************

class TestUserJsonSerializer implements JsonSerializer<TestUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestUser instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
    };
    return json;
  }

  @override
  TestUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestUser from null JSON',
        expectedType: 'TestUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    try {
      return TestUser(
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestUser: $e',
        expectedType: 'TestUser',
      );
    }
  }

  @override
  String serialize(TestUser object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestUser',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestUser instance, [
    SerializationConfig? config,
  ]) {
    return TestUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestUser decode(dynamic json, [SerializationConfig? config]) {
    return TestUserJsonSerializer().fromJson(json, config);
  }
}

class TestAddressJsonSerializer implements JsonSerializer<TestAddress> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestAddressJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestAddress instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('city', effectiveConfig.fieldRename):
          instance.city,
      SerializationUtils.applyFieldRename(
        'street',
        effectiveConfig.fieldRename,
      ): instance.street,
      SerializationUtils.applyFieldRename(
        'zipCode',
        effectiveConfig.fieldRename,
      ): instance.zipCode,
    };
    return json;
  }

  @override
  TestAddress fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestAddress from null JSON',
        expectedType: 'TestAddress',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestAddress',
      );
    }
    try {
      return TestAddress(
        city:
            json[SerializationUtils.applyFieldRename(
                  'city',
                  effectiveConfig.fieldRename,
                )]
                as String,
        street:
            json[SerializationUtils.applyFieldRename(
                  'street',
                  effectiveConfig.fieldRename,
                )]
                as String,
        zipCode:
            json[SerializationUtils.applyFieldRename(
                  'zipCode',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestAddress: $e',
        expectedType: 'TestAddress',
      );
    }
  }

  @override
  String serialize(TestAddress object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestAddress deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestAddress',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestAddress instance, [
    SerializationConfig? config,
  ]) {
    return TestAddressJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestAddress decode(dynamic json, [SerializationConfig? config]) {
    return TestAddressJsonSerializer().fromJson(json, config);
  }
}

class TestUserWithAddressJsonSerializer
    implements JsonSerializer<TestUserWithAddress> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestUserWithAddressJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestUserWithAddress instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'address',
        effectiveConfig.fieldRename,
      ): TestAddressJsonSerializer().toJson(
        instance.address,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
    };
    return json;
  }

  @override
  TestUserWithAddress fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestUserWithAddress from null JSON',
        expectedType: 'TestUserWithAddress',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestUserWithAddress',
      );
    }
    try {
      return TestUserWithAddress(
        address: TestAddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'address',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestUserWithAddress: $e',
        expectedType: 'TestUserWithAddress',
      );
    }
  }

  @override
  String serialize(TestUserWithAddress object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestUserWithAddress deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestUserWithAddress',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestUserWithAddress instance, [
    SerializationConfig? config,
  ]) {
    return TestUserWithAddressJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestUserWithAddress decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return TestUserWithAddressJsonSerializer().fromJson(json, config);
  }
}

class TestUserSnakeCaseJsonSerializer
    implements JsonSerializer<TestUserSnakeCase> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestUserSnakeCaseJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestUserSnakeCase instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'emailAddress',
        effectiveConfig.fieldRename,
      ): instance.emailAddress,
      SerializationUtils.applyFieldRename(
        'firstName',
        effectiveConfig.fieldRename,
      ): instance.firstName,
      SerializationUtils.applyFieldRename(
        'lastName',
        effectiveConfig.fieldRename,
      ): instance.lastName,
    };
    return json;
  }

  @override
  TestUserSnakeCase fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestUserSnakeCase from null JSON',
        expectedType: 'TestUserSnakeCase',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestUserSnakeCase',
      );
    }
    try {
      return TestUserSnakeCase(
        emailAddress:
            json[SerializationUtils.applyFieldRename(
                  'emailAddress',
                  effectiveConfig.fieldRename,
                )]
                as String,
        firstName:
            json[SerializationUtils.applyFieldRename(
                  'firstName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        lastName:
            json[SerializationUtils.applyFieldRename(
                  'lastName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestUserSnakeCase: $e',
        expectedType: 'TestUserSnakeCase',
      );
    }
  }

  @override
  String serialize(TestUserSnakeCase object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestUserSnakeCase deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestUserSnakeCase',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestUserSnakeCase instance, [
    SerializationConfig? config,
  ]) {
    return TestUserSnakeCaseJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestUserSnakeCase decode(dynamic json, [SerializationConfig? config]) {
    return TestUserSnakeCaseJsonSerializer().fromJson(json, config);
  }
}

class TestUserKebabCaseJsonSerializer
    implements JsonSerializer<TestUserKebabCase> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestUserKebabCaseJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestUserKebabCase instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'emailAddress',
        effectiveConfig.fieldRename,
      ): instance.emailAddress,
      SerializationUtils.applyFieldRename(
        'firstName',
        effectiveConfig.fieldRename,
      ): instance.firstName,
      SerializationUtils.applyFieldRename(
        'lastName',
        effectiveConfig.fieldRename,
      ): instance.lastName,
    };
    return json;
  }

  @override
  TestUserKebabCase fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestUserKebabCase from null JSON',
        expectedType: 'TestUserKebabCase',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestUserKebabCase',
      );
    }
    try {
      return TestUserKebabCase(
        emailAddress:
            json[SerializationUtils.applyFieldRename(
                  'emailAddress',
                  effectiveConfig.fieldRename,
                )]
                as String,
        firstName:
            json[SerializationUtils.applyFieldRename(
                  'firstName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        lastName:
            json[SerializationUtils.applyFieldRename(
                  'lastName',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestUserKebabCase: $e',
        expectedType: 'TestUserKebabCase',
      );
    }
  }

  @override
  String serialize(TestUserKebabCase object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestUserKebabCase deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestUserKebabCase',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestUserKebabCase instance, [
    SerializationConfig? config,
  ]) {
    return TestUserKebabCaseJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestUserKebabCase decode(dynamic json, [SerializationConfig? config]) {
    return TestUserKebabCaseJsonSerializer().fromJson(json, config);
  }
}

class TestValueWithSpecialTypesJsonSerializer
    implements JsonSerializer<TestValueWithSpecialTypes> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestValueWithSpecialTypesJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestValueWithSpecialTypes instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename(
        'timestamp',
        effectiveConfig.fieldRename,
      ): instance.timestamp
          .toIso8601String(),
    };
    return json;
  }

  @override
  TestValueWithSpecialTypes fromJson(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestValueWithSpecialTypes from null JSON',
        expectedType: 'TestValueWithSpecialTypes',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestValueWithSpecialTypes',
      );
    }
    try {
      return TestValueWithSpecialTypes(
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        timestamp: DateTime.parse(
          json[SerializationUtils.applyFieldRename(
                'timestamp',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestValueWithSpecialTypes: $e',
        expectedType: 'TestValueWithSpecialTypes',
      );
    }
  }

  @override
  String serialize(TestValueWithSpecialTypes object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestValueWithSpecialTypes deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestValueWithSpecialTypes',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestValueWithSpecialTypes instance, [
    SerializationConfig? config,
  ]) {
    return TestValueWithSpecialTypesJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestValueWithSpecialTypes decode(
    dynamic json, [
    SerializationConfig? config,
  ]) {
    return TestValueWithSpecialTypesJsonSerializer().fromJson(json, config);
  }
}

class TestContactInfoJsonSerializer implements JsonSerializer<TestContactInfo> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestContactInfoJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestContactInfo instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename(
        'address',
        effectiveConfig.fieldRename,
      ): TestAddressJsonSerializer().toJson(
        instance.address,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename('email', effectiveConfig.fieldRename):
          instance.email,
      SerializationUtils.applyFieldRename('phone', effectiveConfig.fieldRename):
          instance.phone,
    };
    return json;
  }

  @override
  TestContactInfo fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestContactInfo from null JSON',
        expectedType: 'TestContactInfo',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestContactInfo',
      );
    }
    try {
      return TestContactInfo(
        address: TestAddressJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'address',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        email:
            json[SerializationUtils.applyFieldRename(
                  'email',
                  effectiveConfig.fieldRename,
                )]
                as String,
        phone:
            json[SerializationUtils.applyFieldRename(
                  'phone',
                  effectiveConfig.fieldRename,
                )]
                as String,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestContactInfo: $e',
        expectedType: 'TestContactInfo',
      );
    }
  }

  @override
  String serialize(TestContactInfo object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestContactInfo deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestContactInfo',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestContactInfo instance, [
    SerializationConfig? config,
  ]) {
    return TestContactInfoJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestContactInfo decode(dynamic json, [SerializationConfig? config]) {
    return TestContactInfoJsonSerializer().fromJson(json, config);
  }
}

class TestComplexUserJsonSerializer implements JsonSerializer<TestComplexUser> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestComplexUserJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestComplexUser instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'addresses',
        effectiveConfig.fieldRename,
      ): instance.addresses
          .map(
            (item) => TestAddressJsonSerializer().toJson(item, effectiveConfig),
          )
          .toList(),
      SerializationUtils.applyFieldRename(
        'contactInfo',
        effectiveConfig.fieldRename,
      ): TestContactInfoJsonSerializer().toJson(
        instance.contactInfo,
        effectiveConfig,
      ),
      SerializationUtils.applyFieldRename(
        'metadata',
        effectiveConfig.fieldRename,
      ): instance.metadata,
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('tags', effectiveConfig.fieldRename):
          instance.tags.toList(),
    };
    return json;
  }

  @override
  TestComplexUser fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestComplexUser from null JSON',
        expectedType: 'TestComplexUser',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestComplexUser',
      );
    }
    try {
      return TestComplexUser(
        addresses:
            (json[SerializationUtils.applyFieldRename(
                      'addresses',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => TestAddressJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
                .toList(),
        contactInfo: TestContactInfoJsonSerializer().fromJson(
          json[SerializationUtils.applyFieldRename(
                'contactInfo',
                effectiveConfig.fieldRename,
              )]
              as Map<String, dynamic>,
          effectiveConfig,
        ),
        metadata: Map<String, dynamic>.from(
          json[SerializationUtils.applyFieldRename(
                'metadata',
                effectiveConfig.fieldRename,
              )]
              as Map,
        ).map((key, value) => MapEntry(key, value as dynamic)),
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        tags:
            (json[SerializationUtils.applyFieldRename(
                      'tags',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map((item) => item as String)
                .toSet(),
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestComplexUser: $e',
        expectedType: 'TestComplexUser',
      );
    }
  }

  @override
  String serialize(TestComplexUser object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestComplexUser deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestComplexUser',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestComplexUser instance, [
    SerializationConfig? config,
  ]) {
    return TestComplexUserJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestComplexUser decode(dynamic json, [SerializationConfig? config]) {
    return TestComplexUserJsonSerializer().fromJson(json, config);
  }
}

class TestProjectJsonSerializer implements JsonSerializer<TestProject> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestProjectJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestProject instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'collaborators',
        effectiveConfig.fieldRename,
      ): instance.collaborators
          .map((item) => TestUserJsonSerializer().toJson(item, effectiveConfig))
          .toList(),
      SerializationUtils.applyFieldRename(
        'description',
        effectiveConfig.fieldRename,
      ): instance.description,
      SerializationUtils.applyFieldRename(
        'milestones',
        effectiveConfig.fieldRename,
      ): instance.milestones
          .map(
            (item) => TestValueWithSpecialTypesJsonSerializer().toJson(
              item,
              effectiveConfig,
            ),
          )
          .toList(),
      SerializationUtils.applyFieldRename(
        'settings',
        effectiveConfig.fieldRename,
      ): instance.settings.map(
        (key, value) => MapEntry(
          key,
          TestAddressJsonSerializer().toJson(value, effectiveConfig),
        ),
      ),
      SerializationUtils.applyFieldRename('title', effectiveConfig.fieldRename):
          instance.title,
    };
    return json;
  }

  @override
  TestProject fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestProject from null JSON',
        expectedType: 'TestProject',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestProject',
      );
    }
    try {
      return TestProject(
        collaborators:
            (json[SerializationUtils.applyFieldRename(
                      'collaborators',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => TestUserJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
                .toList(),
        description:
            json[SerializationUtils.applyFieldRename(
                  'description',
                  effectiveConfig.fieldRename,
                )]
                as String,
        milestones:
            (json[SerializationUtils.applyFieldRename(
                      'milestones',
                      effectiveConfig.fieldRename,
                    )]
                    as List)
                .map(
                  (item) => TestValueWithSpecialTypesJsonSerializer().fromJson(
                    item as Map<String, dynamic>,
                    effectiveConfig,
                  ),
                )
                .toSet(),
        settings:
            Map<String, dynamic>.from(
              json[SerializationUtils.applyFieldRename(
                    'settings',
                    effectiveConfig.fieldRename,
                  )]
                  as Map,
            ).map(
              (key, value) => MapEntry(
                key,
                TestAddressJsonSerializer().fromJson(
                  value as Map<String, dynamic>,
                  effectiveConfig,
                ),
              ),
            ),
        title:
            json[SerializationUtils.applyFieldRename(
                  'title',
                  effectiveConfig.fieldRename,
                )]
                as String,
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestProject: $e',
        expectedType: 'TestProject',
      );
    }
  }

  @override
  String serialize(TestProject object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestProject deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestProject',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestProject instance, [
    SerializationConfig? config,
  ]) {
    return TestProjectJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestProject decode(dynamic json, [SerializationConfig? config]) {
    return TestProjectJsonSerializer().fromJson(json, config);
  }
}

class TestNestedValueJsonSerializer implements JsonSerializer<TestNestedValue> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestNestedValueJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestNestedValue instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      if (instance.child != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'child',
          effectiveConfig.fieldRename,
        ): instance.child != null
            ? TestNestedValueJsonSerializer().toJson(
                instance.child!,
                effectiveConfig,
              )
            : null,
      SerializationUtils.applyFieldRename('data', effectiveConfig.fieldRename):
          instance.data,
      SerializationUtils.applyFieldRename('level', effectiveConfig.fieldRename):
          instance.level,
    };
    return json;
  }

  @override
  TestNestedValue fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestNestedValue from null JSON',
        expectedType: 'TestNestedValue',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestNestedValue',
      );
    }
    try {
      return TestNestedValue(
        child:
            json[SerializationUtils.applyFieldRename(
                  'child',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? TestNestedValueJsonSerializer().fromJson(
                json[SerializationUtils.applyFieldRename(
                      'child',
                      effectiveConfig.fieldRename,
                    )]
                    as Map<String, dynamic>,
                effectiveConfig,
              )
            : null,
        data:
            json[SerializationUtils.applyFieldRename(
                  'data',
                  effectiveConfig.fieldRename,
                )]
                as String,
        level:
            json[SerializationUtils.applyFieldRename(
                  'level',
                  effectiveConfig.fieldRename,
                )]
                as int,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestNestedValue: $e',
        expectedType: 'TestNestedValue',
      );
    }
  }

  @override
  String serialize(TestNestedValue object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestNestedValue deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestNestedValue',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestNestedValue instance, [
    SerializationConfig? config,
  ]) {
    return TestNestedValueJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestNestedValue decode(dynamic json, [SerializationConfig? config]) {
    return TestNestedValueJsonSerializer().fromJson(json, config);
  }
}

class TestGameJsonSerializer implements JsonSerializer<TestGame> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestGameJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestGame instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('id', effectiveConfig.fieldRename):
          instance.id.toString(),
      SerializationUtils.applyFieldRename(
        'createdAt',
        effectiveConfig.fieldRename,
      ): instance.createdAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename(
        'updatedAt',
        effectiveConfig.fieldRename,
      ): instance.updatedAt
          .toIso8601String(),
      SerializationUtils.applyFieldRename('state', effectiveConfig.fieldRename):
          instance.state.name,
    };
    return json;
  }

  @override
  TestGame fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestGame from null JSON',
        expectedType: 'TestGame',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestGame',
      );
    }
    try {
      return TestGame(
        state: GameState.values.byName(
          json[SerializationUtils.applyFieldRename(
                'state',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        id: UuidValue.fromString(
          json[SerializationUtils.applyFieldRename(
                'id',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        createdAt:
            json[SerializationUtils.applyFieldRename(
                  'createdAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'createdAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
        updatedAt:
            json[SerializationUtils.applyFieldRename(
                  'updatedAt',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? DateTime.parse(
                json[SerializationUtils.applyFieldRename(
                      'updatedAt',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestGame: $e',
        expectedType: 'TestGame',
      );
    }
  }

  @override
  String serialize(TestGame object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestGame deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestGame',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestGame instance, [
    SerializationConfig? config,
  ]) {
    return TestGameJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestGame decode(dynamic json, [SerializationConfig? config]) {
    return TestGameJsonSerializer().fromJson(json, config);
  }
}

class TestPlayerJsonSerializer implements JsonSerializer<TestPlayer> {
  /// Default configuration for this serializer.
  final SerializationConfig _defaultConfig;

  /// Creates a serializer with the specified default configuration.
  TestPlayerJsonSerializer([SerializationConfig? defaultConfig])
    : _defaultConfig = defaultConfig ?? const SerializationConfig();

  @override
  Map<String, dynamic> toJson(
    TestPlayer instance, [
    SerializationConfig? config,
  ]) {
    final effectiveConfig = config ?? _defaultConfig;
    final json = <String, dynamic>{
      SerializationUtils.applyFieldRename('name', effectiveConfig.fieldRename):
          instance.name,
      SerializationUtils.applyFieldRename('role', effectiveConfig.fieldRename):
          instance.role.name,
      if (instance.status != null || effectiveConfig.includeNullFields)
        SerializationUtils.applyFieldRename(
          'status',
          effectiveConfig.fieldRename,
        ): instance.status?.name,
    };
    return json;
  }

  @override
  TestPlayer fromJson(dynamic json, [SerializationConfig? config]) {
    final effectiveConfig = config ?? _defaultConfig;
    if (json == null) {
      throw DeserializationException(
        'Cannot deserialize TestPlayer from null JSON',
        expectedType: 'TestPlayer',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected Map<String, dynamic> but got ${json.runtimeType}',
        expectedType: 'TestPlayer',
      );
    }
    try {
      return TestPlayer(
        name:
            json[SerializationUtils.applyFieldRename(
                  'name',
                  effectiveConfig.fieldRename,
                )]
                as String,
        role: PlayerRole.values.byName(
          json[SerializationUtils.applyFieldRename(
                'role',
                effectiveConfig.fieldRename,
              )]
              as String,
        ),
        status:
            json[SerializationUtils.applyFieldRename(
                  'status',
                  effectiveConfig.fieldRename,
                )] !=
                null
            ? PlayerStatus.values.byName(
                json[SerializationUtils.applyFieldRename(
                      'status',
                      effectiveConfig.fieldRename,
                    )]
                    as String,
              )
            : null,
      );
    } catch (e, stackTrace) {
      throw DeserializationException(
        'Failed to deserialize TestPlayer: $e',
        expectedType: 'TestPlayer',
      );
    }
  }

  @override
  String serialize(TestPlayer object, [dynamic config]) {
    return jsonEncode(toJson(object, config as SerializationConfig?));
  }

  @override
  TestPlayer deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw DeserializationException(
        'Expected JSON object but got ${json.runtimeType}',
        expectedType: 'TestPlayer',
      );
    }
    return fromJson(json, config as SerializationConfig?);
  }

  /// Convenience method for static access with default configuration
  static Map<String, dynamic> encode(
    TestPlayer instance, [
    SerializationConfig? config,
  ]) {
    return TestPlayerJsonSerializer().toJson(instance, config);
  }

  /// Convenience method for static access with default configuration
  static TestPlayer decode(dynamic json, [SerializationConfig? config]) {
    return TestPlayerJsonSerializer().fromJson(json, config);
  }
}
