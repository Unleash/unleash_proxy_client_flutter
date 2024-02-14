# Unleash Proxy Client for Flutter (Dart)

This is a tiny Unleash Client SDK you can use together with the [Unleash Frontend API](https://docs.getunleash.io/reference/front-end-api#using-the-unleash-front-end-api) or the 
[Unleash Proxy](https://docs.getunleash.io/sdks/unleash-proxy) or the [Unleash Edge](https://docs.getunleash.io/reference/unleash-edge).
This makes it super simple to use Unleash from any Flutter app.

## How to use the client as a module

### Step 1: Installation

```
flutter pub add unleash_proxy_client_flutter
```

### Step 2: Initialize the SDK

---

💡 **TIP**: As a client-side SDK, this SDK requires you to connect to either an Unleash proxy or to the Unleash front-end API. Refer to the [connection options section](#connection-options) for more information.

---

Configure the client according to your needs. The following example provides only the required options. Refer to [the section on available options](#available-options) for the full list.


```dart
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';

final unleash = UnleashClient(
    url: Uri.parse('https://<your-unleash-instance>/api/frontend'),
    clientKey: '<your-client-side-token>',
    appName: 'my-app');
```

#### Connection options

To connect this SDK to your Unleash instance's [front-end API](https://docs.getunleash.io/reference/front-end-api), use the URL to your Unleash instance's front-end API (`<unleash-url>/api/frontend`) as the `url` parameter. For the `clientKey` parameter, use a `FRONTEND` token generated from your Unleash instance. Refer to the [_how to create API tokens_](https://docs.getunleash.io/how-to/how-to-create-api-tokens) guide for the necessary steps.

To connect this SDK to the [Unleash proxy](https://docs.getunleash.io/reference/unleash-proxy), use the proxy's URL and a [proxy client key](https://docs.getunleash.io/reference/api-tokens-and-client-keys#proxy-client-keys). The [_configuration_ section of the Unleash proxy docs](https://docs.getunleash.io/reference/unleash-proxy#configuration) contains more info on how to configure client keys for your proxy.


### Step 3: Let the client synchronize

You should wait for the client's `ready` or `initialized` events before you start working with it. Before it's ready, the client might not report the correct state for your features.


```dart
unleash.on('ready', (_) {
    if (unleash.isEnabled('proxy.demo')) {
      print('proxy.demo is enabled');
    } else {
      print('proxy.demo is disabled');
    }
});
```

The difference between the events is [explained below](#available-events).

### Step 4: Check feature toggle states

Once the client is ready, you can start checking features in your application. Use the `isEnabled` method to check the state of any feature you want:

```dart
unleash.isEnabled('proxy.demo');
```

You can use the `getVariant` method to get the variant of an **enabled feature that has variants**. If the feature is disabled or if it has no variants, then you will get back the [**disabled variant**](https://docs.getunleash.io/reference/feature-toggle-variants#the-disabled-variant)

```dart
final variant = unleash.getVariant('proxy.demo');

if (variant.name == 'blue') {
 // something with variant blue...
}
```

You can also access the payload associated with the variant:

```dart
final variant = unleash.getVariant('proxy.demo');
final payload = variant.payload;

if (payload != null) {
  // do something with the payload
  // print(payload "${payload.type} ${payload.value}");
}
```

#### Updating the Unleash context

The [Unleash context](https://docs.getunleash.io/reference/unleash-context) is used to evaluate features against attributes of a the current user. To update and configure the Unleash context in this SDK, use the `updateContext` and `setContextField` methods.

The context you set in your app will be passed along to the Unleash proxy or the front-end API as query parameters for feature evaluation.

The `updateContext` method will replace the entire
(mutable part) of the Unleash context with the data that you pass in.

The `setContextField` method only acts on the property that you choose. It does not affect any other properties of the Unleash context.

```dart
// Used to set the context fields, shared with the Unleash Proxy. This 
// method will replace the entire (mutable part) of the Unleash Context.
unleash.updateContext(UnleashContext(userId: '1233'));

// Used to update a single field on the Unleash Context.
unleash.setContextField('userId', '4141');

// Used to update multiple context fields on the Unleash Context.
unleash.setContextFields({'userId': '4141'});
```

### Available options

The Unleash SDK takes the following options:

| option            | required | default                   | description                                                                                                                                      |
|-------------------|----------|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| url               | yes | n/a                       | The Unleash Proxy URL to connect to. E.g.: `https://examples.com/proxy`                                                                         |
| clientKey         | yes | n/a                       | The Unleash Proxy Secret to be used                                                                                                             | 
| appName           | yes | n/a                       | The name of the application using this SDK. Will be used as part of the metrics sent to Unleash Proxy. Will also be part of the Unleash Context. | 
| refreshInterval   | no | 30                        | How often, in seconds, the SDK should check for updated toggle configuration. If set to 0 will disable checking for updates                 |
| disableRefresh    | no | false                     | If set to true, the client will not check for updated toggle configuration                                                                |
| metricsInterval   | no | 30                        | How often, in seconds, the SDK should send usage metrics back to Unleash Proxy                                                              | 
| disableMetrics    | no | false                     | Set this option to `true` if you want to disable usage metrics
| storageProvider   | no | `SharedPreferencesStorageProvider` | Allows you to inject a custom storeProvider                                                                              |
| bootstrap         | no | `[]`                      | Allows you to bootstrap the cached feature toggle configuration.                                                                               | 
| bootstrapOverride | no| `true`                    | Should the bootstrap automatically override cached data in the local-storage. Will only be used if bootstrap is not an empty array.     |
| headerName        | no| `Authorization`           | Provides possiblity to specify custom header that is passed to Unleash / Unleash Proxy with the `clientKey` |
| customHeaders     | no| `{}`                      | Additional headers to use when making HTTP requests to the Unleash proxy. In case of name collisions with the default headers, the `customHeaders` value will be used. |
| impressionDataAll | no| `false` | Allows you to trigger "impression" events for **all** `getToggle` and `getVariant` invocations. This is particularly useful for "disabled" feature toggles that are not visible to frontend SDKs. |
| fetcher           | no | `http.get`                         | Allows you to define your own **fetcher**. Can be used to add certificate pinning or additional http behavior. |
| poster            | no | `http.post`                        | Allows you to define your own **poster**. Can be used to add certificate pinning or additional http behavior.  |
### Listen for updates via the events_emitter

The client is also an event emitter. This means that your code can subscribe to updates from the client.
This is a neat way to update your app when toggle state updates.

```dart
unleash.on('update', (_) {
    final myToggle = unleash.isEnabled('proxy.demo');
    //do something useful
});
```

#### Available events:

- **error** - emitted when an error occurs on init, or when fetch function fails, or when fetch receives a non-ok response object. The error object is sent as payload.
- **initialized** - emitted after the SDK has read local cached data in the storageProvider.
- **ready** - emitted after the SDK has successfully started and performed the initial fetch towards the Unleash Proxy.
- **update** - emitted every time the Unleash Proxy return a new feature toggle configuration. The SDK will emit this event as part of the initial fetch from the SDK.

> PS! Please remember that you should always register your event listeners before your call `unleash.start()`. If you register them after you have started the SDK you risk loosing important events.

### SessionId - Important note!

You may provide a custom session id via the "context". If you do not provide a sessionId this SDK will create a random session id, which will also be stored in the provided storage. By always having a consistent sessionId available ensures that even "anonymous" users will get a consistent experience when feature toggles is evaluated, in combination with a gradual (percentage based) rollout.

### Stop the SDK
You can stop the Unleash client by calling the `stop` method. Once the client has been stopped, it will no longer check for updates or send metrics to the server.

A stopped client _can_ be restarted.

```dart
unleash.stop();
```

## Bootstrap
Now it is possible to bootstrap the SDK with your own feature toggle configuration when you don't want to make an API call.

This is also useful if you require the toggles to be in a certain state immediately after initializing the SDK.

### How to use it ?
Add a `bootstrap` attribute when create a new `UnleashClient`.  
There's also a `bootstrapOverride` attribute which is by default is `true`.

```dart
final unleash = UnleashClient(
    url: Uri.parse('https://app.unleash-hosted.com/demo/api/proxy'),
    clientKey: 'proxy-123',
    appName: 'my-app',
    bootstrapOverride: false,
    bootstrap: {
    'demoApp.step4': ToggleConfig(
        enabled: true,
        impressionData: false,
        variant: Variant(enabled: true, name: 'blue'))
});
```
**NOTES: ⚠️**

* If `bootstrapOverride` is `true` (by default), any local cached data will be overridden with the bootstrap specified.   
* If `bootstrapOverride` is `false` any local cached data will not be overridden unless the local cache is empty.

## Useful commands development

* `flutter test`
* `dart format lib test`
* `flutter analyze lib test`
* `dart pub publish`
