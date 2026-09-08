//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AuthenticationApi {
  AuthenticationApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Performs an HTTP 'POST /Users/AuthenticateByName' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [AuthenticateUserByName] authenticateUserByName (required):
  Future<Response> authenticateUserByNameWithHttpInfo(
    AuthenticateUserByName authenticateUserByName,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/Users/AuthenticateByName';

    // ignore: prefer_final_locals
    Object? postBody = authenticateUserByName;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Parameters:
  ///
  /// * [AuthenticateUserByName] authenticateUserByName (required):
  Future<AuthenticationResult?> authenticateUserByName(
    AuthenticateUserByName authenticateUserByName,
  ) async {
    final response = await authenticateUserByNameWithHttpInfo(
      authenticateUserByName,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'AuthenticationResult',
      ) as AuthenticationResult;
    }
    return null;
  }

  /// Performs an HTTP 'POST /Users/AuthenticateWithQuickConnect' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [QuickConnectDto] quickConnectDto (required):
  Future<Response> authenticateWithQuickConnectWithHttpInfo(
    QuickConnectDto quickConnectDto,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/Users/AuthenticateWithQuickConnect';

    // ignore: prefer_final_locals
    Object? postBody = quickConnectDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Parameters:
  ///
  /// * [QuickConnectDto] quickConnectDto (required):
  Future<AuthenticationResult?> authenticateWithQuickConnect(
    QuickConnectDto quickConnectDto,
  ) async {
    final response = await authenticateWithQuickConnectWithHttpInfo(
      quickConnectDto,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'AuthenticationResult',
      ) as AuthenticationResult;
    }
    return null;
  }
}
