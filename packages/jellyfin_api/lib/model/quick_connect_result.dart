//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class QuickConnectResult {
  /// Returns a new [QuickConnectResult] instance.
  QuickConnectResult({
    this.authenticated,
    this.secret,
    this.code,
    this.dateAdded,
    this.deviceId,
    this.deviceName,
    this.appName,
    this.appVersion,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? authenticated;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? secret;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? code;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? dateAdded;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? deviceId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? deviceName;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? appName;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? appVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickConnectResult &&
          other.authenticated == authenticated &&
          other.secret == secret &&
          other.code == code &&
          other.dateAdded == dateAdded &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.appName == appName &&
          other.appVersion == appVersion;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (authenticated == null ? 0 : authenticated!.hashCode) +
      (secret == null ? 0 : secret!.hashCode) +
      (code == null ? 0 : code!.hashCode) +
      (dateAdded == null ? 0 : dateAdded!.hashCode) +
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (deviceName == null ? 0 : deviceName!.hashCode) +
      (appName == null ? 0 : appName!.hashCode) +
      (appVersion == null ? 0 : appVersion!.hashCode);

  @override
  String toString() =>
      'QuickConnectResult[authenticated=$authenticated, secret=$secret, code=$code, dateAdded=$dateAdded, deviceId=$deviceId, deviceName=$deviceName, appName=$appName, appVersion=$appVersion]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.authenticated != null) {
      json[r'Authenticated'] = this.authenticated;
    } else {
      json[r'Authenticated'] = null;
    }
    if (this.secret != null) {
      json[r'Secret'] = this.secret;
    } else {
      json[r'Secret'] = null;
    }
    if (this.code != null) {
      json[r'Code'] = this.code;
    } else {
      json[r'Code'] = null;
    }
    if (this.dateAdded != null) {
      json[r'DateAdded'] = this.dateAdded!.toUtc().toIso8601String();
    } else {
      json[r'DateAdded'] = null;
    }
    if (this.deviceId != null) {
      json[r'DeviceId'] = this.deviceId;
    } else {
      json[r'DeviceId'] = null;
    }
    if (this.deviceName != null) {
      json[r'DeviceName'] = this.deviceName;
    } else {
      json[r'DeviceName'] = null;
    }
    if (this.appName != null) {
      json[r'AppName'] = this.appName;
    } else {
      json[r'AppName'] = null;
    }
    if (this.appVersion != null) {
      json[r'AppVersion'] = this.appVersion;
    } else {
      json[r'AppVersion'] = null;
    }
    return json;
  }

  /// Returns a new [QuickConnectResult] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static QuickConnectResult? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "QuickConnectResult[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "QuickConnectResult[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return QuickConnectResult(
        authenticated: mapValueOfType<bool>(json, r'Authenticated'),
        secret: mapValueOfType<String>(json, r'Secret'),
        code: mapValueOfType<String>(json, r'Code'),
        dateAdded: mapDateTime(json, r'DateAdded', r''),
        deviceId: mapValueOfType<String>(json, r'DeviceId'),
        deviceName: mapValueOfType<String>(json, r'DeviceName'),
        appName: mapValueOfType<String>(json, r'AppName'),
        appVersion: mapValueOfType<String>(json, r'AppVersion'),
      );
    }
    return null;
  }

  static List<QuickConnectResult> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <QuickConnectResult>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = QuickConnectResult.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, QuickConnectResult> mapFromJson(dynamic json) {
    final map = <String, QuickConnectResult>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = QuickConnectResult.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of QuickConnectResult-objects as value to a dart map
  static Map<String, List<QuickConnectResult>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<QuickConnectResult>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = QuickConnectResult.listFromJson(
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
