## 1.9.6

* Fix: stop metrics timer on client stop

## 1.9.5

* Fix: add variant data to impression event

## 1.9.4

* Fix: Drop x- prefix from unleash headers

## 1.9.3

* Chore: Sync x-unleash-sdk version scheme with other SDKs

## 1.9.2

* Fix: Skip initial toggles fetch when using updateContext or setContextFields

## 1.9.1

* Chore: Upgrade event_emitter version

## 1.9.0

* Feat: Unique SDK tracking
* Refactor: renamed eventIdGenerator to idGenerator but this API is used only for tests

## 1.8.0

* Feat: experimental support for skip fetch toggles on start

## 1.7.0

* Feat: manual control over updateToggles and sendMetrics


## 1.6.0

* Feat: save network calls when context fields don't change

## 1.5.3

* Fix: payload stringify in bootstrap

## 1.5.2

* Chore: update dependency range on shared_preferences and uuid

## 1.5.1

* Fix: handle parsing errors from storage

## 1.5.0

* Feat: ability to set multiple context fields at once without providing full context
* Chore: shared_preferences and uuid dependencies update (non-breaking changes)

## 1.4.0

* Feat: appName and environment are automatically send to backend and reported in impression events 
* Fix: type signature for UnleashContext properties

## 1.3.0

* Feat: HTTP dependency update. Since it's an important update (env support) it's a feat (major version update) and not chore. 

## 1.2.2

* Fix: encoding of custom properties

## 1.2.1

* Fix: handle empty ToggleConfig values

## 1.2.0

* Feat: variant metrics support

## 1.1.0

* Feat: added variant payload

## 1.0.3

* Fix set client state before emitting event

## 1.0.2

* Fix updateContext called before start

## 1.0.1

* Fix pubspec.yaml version 

## 1.0.0

* First official release

## 0.0.3

* Added examples

## 0.0.2

* Added support for impression events

## 0.0.1

* Initial implementation of the Flutter client
