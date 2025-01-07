import 'package:uuid/uuid.dart';

var uuid = const Uuid();

/// Generates UUID for impression events. Should be swapped with predictable values in tests
String generateId() {
  return uuid.v4();
}
