//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PublicSystemInfo {
  /// Returns a new [PublicSystemInfo] instance.
  PublicSystemInfo({
    this.serverName,
    this.version,
    this.id,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? serverName;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? version;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicSystemInfo &&
          other.serverName == serverName &&
          other.version == version &&
          other.id == id;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (serverName == null ? 0 : serverName!.hashCode) +
      (version == null ? 0 : version!.hashCode) +
      (id == null ? 0 : id!.hashCode);

  @override
  String toString() =>
      'PublicSystemInfo[serverName=$serverName, version=$version, id=$id]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.serverName != null) {
      json[r'ServerName'] = this.serverName;
    } else {
      json[r'ServerName'] = null;
    }
    if (this.version != null) {
      json[r'Version'] = this.version;
    } else {
      json[r'Version'] = null;
    }
    if (this.id != null) {
      json[r'Id'] = this.id;
    } else {
      json[r'Id'] = null;
    }
    return json;
  }

  /// Returns a new [PublicSystemInfo] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PublicSystemInfo? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "PublicSystemInfo[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "PublicSystemInfo[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PublicSystemInfo(
        serverName: mapValueOfType<String>(json, r'ServerName'),
        version: mapValueOfType<String>(json, r'Version'),
        id: mapValueOfType<String>(json, r'Id'),
      );
    }
    return null;
  }

  static List<PublicSystemInfo> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <PublicSystemInfo>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PublicSystemInfo.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PublicSystemInfo> mapFromJson(dynamic json) {
    final map = <String, PublicSystemInfo>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PublicSystemInfo.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PublicSystemInfo-objects as value to a dart map
  static Map<String, List<PublicSystemInfo>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<PublicSystemInfo>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PublicSystemInfo.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
