import 'package:uuid/uuid.dart';

var uuid = const Uuid();

String generateEventId() {
  return uuid.v4();
}
