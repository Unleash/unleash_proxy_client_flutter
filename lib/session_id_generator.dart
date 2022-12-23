import 'dart:math';

/// User session id generator used for consistent toggle delivery. It is stored in local storage.
/// For testing purposed it's swapped with predictable values.
String generateSessionId() {
  return ((Random().nextDouble() * 1000000000).floor()).toString();
}
