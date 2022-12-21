# Unleash Proxy Client for Flutter (Dart)

This is a tiny Unleash Client SDK you can use together with the
[Unleash Proxy](https://docs.getunleash.io/sdks/unleash-proxy).
This makes it super simple to use Unleash from any Flutter app.

## How to use the client as a module

**Step 1: Unleash Proxy**

Before you can use this Unleash SDK you need set up a Unleash Proxy instance. [Read more about the Unleash Proxy](https://docs.getunleash.io/sdks/unleash-proxy).


**Step 2: Install**

```
flutter pub add unleash_proxy_client_flutter
```

**Step 3: Initialize the SDK**

You need to have a Unleash-hosted instance, and the proxy need to be enabled. In addition you will need a proxy-specific `clientKey` in order to connect  to the Unleash-hosted Proxy.

```dart
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';

var unleash = UnleashClient(
    url: 'https://app.unleash-hosted.com/demo/api/proxy',
    clientKey: 'proxy-123',
    appName: 'my-app');
```

**Step 4: Listen for when the client is ready**

You shouldn't start working with the client immediately. It's recommended to wait for `ready` or `initialized` event:

```dart
unleash.on('ready', (dynamic _) {
    if (unleash.isEnabled('proxy.demo')) {
      print('proxy.demo is enabled');
    } else {
      print('proxy.demo is disabled');
    }
});
```

The difference between the events is [explained below](#available-events).

**Step 5: Start polling the Unleash Proxy**

```dart
// Used to set the context fields, shared with the Unleash Proxy. This 
// method will replace the entire (mutable part) of the Unleash Context.
unleash.updateContext(UnleashContext(userId: '1233'));

// Used to update a single field on the Unleash Context.
unleash.setContextField('userId', '4141');

// Send the initial fetch towards the Unleash Proxy and starts the background polling
unleash.start();
```

**Step 6: Get toggle variant**

```dart
var variant = unleash.getVariant('proxy.demo');
if(variant.name == 'blue') {
 // something with variant blue...
}
```

### Available options

The Unleash SDK takes the following options:

| option            | required | default | description                                                                                                                                      |
|-------------------|----------|---------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| url               | yes | n/a | The Unleash Proxy URL to connect to. E.g.: `https://examples.com/proxy`                                                                         |
| clientKey         | yes | n/a | The Unleash Proxy Secret to be used                                                                                                             | 
| appName           | yes | n/a | The name of the application using this SDK. Will be used as part of the metrics sent to Unleash Proxy. Will also be part of the Unleash Context. | 
| refreshInterval   | no | 30 | How often, in seconds, the SDK should check for updated toggle configuration. If set to 0 will disable checking for updates                 |
| disableRefresh    | no | false | If set to true, the client will not check for updated toggle configuration                                                                |
| storageProvider   | no | `InMemoryStorageProvider` | Allows you to inject a custom storeProvider                                                                              |
| bootstrap         | no | `[]` | Allows you to bootstrap the cached feature toggle configuration.                                                                               | 
| bootstrapOverride | no| `true` | Should the bootstrap automatically override cached data in the local-storage. Will only be used if bootstrap is not an empty array.     | 

### Listen for updates via the events_emitter

The client is also an event emitter. This means that your code can subscribe to updates from the client.
This is a neat way to update your app when toggle state updates.

```dart
unleash.on('update', (dynamic _) {
    var myToggle = unleash.isEnabled('proxy.demo');
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
var unleash = UnleashClient(
    url: 'https://app.unleash-hosted.com/demo/api/proxy',
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
If `bootstrapOverride` is `true` (by default), any local cached data will be overridden with the bootstrap specified.   
If `bootstrapOverride` is `false` any local cached data will not be overridden unless the local cache is empty.
