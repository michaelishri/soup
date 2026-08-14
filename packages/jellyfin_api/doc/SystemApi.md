# jellyfin_api.api.SystemApi

## Load the API package
```dart
import 'package:jellyfin_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getPublicSystemInfo**](SystemApi.md#getpublicsysteminfo) | **GET** /System/Info/Public |


# **getPublicSystemInfo**
> PublicSystemInfo getPublicSystemInfo()



### Example
```dart
import 'package:jellyfin_api/api.dart';

final api_instance = SystemApi();

try {
    final result = api_instance.getPublicSystemInfo();
    print(result);
} catch (e) {
    print('Exception when calling SystemApi->getPublicSystemInfo: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**PublicSystemInfo**](PublicSystemInfo.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
