import 'dart:convert';
import 'package:dddart/dddart.dart';
import 'package:dddart_serialization/dddart_serialization.dart';
import '../models/user.dart';
import '../models/address.dart';
import '../models/profile.dart';

/// JSON serializer for User aggregate root
/// 
/// Implements JsonSerializer to provide toJson and fromJson methods
/// for serializing User aggregates to/from JSON format
class UserSerializer implements Serializer<User> {
  @override
  String serialize(User user, [dynamic config]) {
    return jsonEncode(toJson(user, config));
  }

  @override
  User deserialize(String data, [dynamic config]) {
    final json = jsonDecode(data);
    return fromJson(json, config);
  }

  /// Converts a User to a JSON map
  Map<String, dynamic> toJson(User user, [dynamic config]) {
    return {
      'id': user.id.toString(),
      'firstName': user.firstName,
      'lastName': user.lastName,
      'email': user.email,
      'address': _addressToJson(user.address),
      if (user.profile != null) 'profile': _profileToJson(user.profile!),
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt.toIso8601String(),
    };
  }

  /// Converts a JSON map to a User
  User fromJson(dynamic json, [dynamic config]) {
    return User(
      id: UuidValue.fromString(json['id']),
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      address: _addressFromJson(json['address']),
      profile: json['profile'] != null ? _profileFromJson(json['profile']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  /// Converts an Address to a JSON map
  Map<String, dynamic> _addressToJson(Address address) {
    return {
      'street': address.street,
      'city': address.city,
      'state': address.state,
      'zipCode': address.zipCode,
      'country': address.country,
    };
  }

  /// Converts a JSON map to an Address
  Address _addressFromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zipCode'],
      country: json['country'],
    );
  }

  /// Converts a Profile to a JSON map
  Map<String, dynamic> _profileToJson(Profile profile) {
    return {
      'id': profile.id.toString(),
      'bio': profile.bio,
      'avatarUrl': profile.avatarUrl,
      'phoneNumber': profile.phoneNumber,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': profile.updatedAt.toIso8601String(),
    };
  }

  /// Converts a JSON map to a Profile
  Profile _profileFromJson(Map<String, dynamic> json) {
    return Profile(
      id: UuidValue.fromString(json['id']),
      bio: json['bio'],
      avatarUrl: json['avatarUrl'],
      phoneNumber: json['phoneNumber'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
