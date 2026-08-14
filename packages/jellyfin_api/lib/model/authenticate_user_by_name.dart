//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthenticateUserByName {
  /// Returns a new [AuthenticateUserByName] instance.
  AuthenticateUserByName({
    required this.username,
    required this.pw,
  });

  String username;

  String pw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticateUserByName &&
          other.username == username &&
          other.pw == pw;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (username.hashCode) + (pw.hashCode);

  @override
  String toString() => 'AuthenticateUserByName[username=$username, pw=$pw]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'Username'] = this.username;
    json[r'Pw'] = this.pw;
    return json;
  }

  /// Returns a new [AuthenticateUserByName] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AuthenticateUserByName? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AuthenticateUserByName[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AuthenticateUserByName[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AuthenticateUserByName(
        username: mapValueOfType<String>(json, r'Username')!,
        pw: mapValueOfType<String>(json, r'Pw')!,
      );
    }
    return null;
  }

  static List<AuthenticateUserByName> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AuthenticateUserByName>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AuthenticateUserByName.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AuthenticateUserByName> mapFromJson(dynamic json) {
    final map = <String, AuthenticateUserByName>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AuthenticateUserByName.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AuthenticateUserByName-objects as value to a dart map
  static Map<String, List<AuthenticateUserByName>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AuthenticateUserByName>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AuthenticateUserByName.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'Username',
    'Pw',
  };
}
