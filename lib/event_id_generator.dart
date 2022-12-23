import 'package:uuid/uuid.dart';

var uuid = const Uuid();

/// Generates UUID for impression events. Should be swapped with predictable values in tests
String generateEventId() {
  return uuid.v4();
}
