import 'package:uuid/uuid.dart';

var uuid = const Uuid();

/// Generates UUID for impression events and unique connection id. Should be swapped with predictable values in tests
String generateId() {
  return uuid.v4();
}
