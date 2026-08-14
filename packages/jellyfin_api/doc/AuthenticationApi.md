# jellyfin_api.api.AuthenticationApi

## Load the API package
```dart
import 'package:jellyfin_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authenticateUserByName**](AuthenticationApi.md#authenticateuserbyname) | **POST** /Users/AuthenticateByName |


# **authenticateUserByName**
> AuthenticationResult authenticateUserByName(authenticateUserByName)



### Example
```dart
import 'package:jellyfin_api/api.dart';

final api_instance = AuthenticationApi();
final authenticateUserByName = AuthenticateUserByName(); // AuthenticateUserByName |

try {
    final result = api_instance.authenticateUserByName(authenticateUserByName);
    print(result);
} catch (e) {
    print('Exception when calling AuthenticationApi->authenticateUserByName: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authenticateUserByName** | [**AuthenticateUserByName**](AuthenticateUserByName.md)|  |

### Return type

[**AuthenticationResult**](AuthenticationResult.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
