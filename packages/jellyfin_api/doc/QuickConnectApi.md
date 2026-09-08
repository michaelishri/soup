# jellyfin_api.api.QuickConnectApi

## Load the API package
```dart
import 'package:jellyfin_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getQuickConnectEnabled**](QuickConnectApi.md#getquickconnectenabled) | **GET** /QuickConnect/Enabled |
[**getQuickConnectState**](QuickConnectApi.md#getquickconnectstate) | **GET** /QuickConnect/Connect |
[**initiateQuickConnect**](QuickConnectApi.md#initiatequickconnect) | **POST** /QuickConnect/Initiate |


# **getQuickConnectEnabled**
> bool getQuickConnectEnabled()



### Example
```dart
import 'package:jellyfin_api/api.dart';

final api_instance = QuickConnectApi();

try {
    final result = api_instance.getQuickConnectEnabled();
    print(result);
} catch (e) {
    print('Exception when calling QuickConnectApi->getQuickConnectEnabled: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**bool**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getQuickConnectState**
> QuickConnectResult getQuickConnectState(secret)



### Example
```dart
import 'package:jellyfin_api/api.dart';

final api_instance = QuickConnectApi();
final secret = secret_example; // String |

try {
    final result = api_instance.getQuickConnectState(secret);
    print(result);
} catch (e) {
    print('Exception when calling QuickConnectApi->getQuickConnectState: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **secret** | **String**|  |

### Return type

[**QuickConnectResult**](QuickConnectResult.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **initiateQuickConnect**
> QuickConnectResult initiateQuickConnect()



### Example
```dart
import 'package:jellyfin_api/api.dart';

final api_instance = QuickConnectApi();

try {
    final result = api_instance.initiateQuickConnect();
    print(result);
} catch (e) {
    print('Exception when calling QuickConnectApi->initiateQuickConnect: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**QuickConnectResult**](QuickConnectResult.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
