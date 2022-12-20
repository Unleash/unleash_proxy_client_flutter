import 'dart:math';

String generateSessionId() {
  return ((Random().nextDouble() * 1000000000).floor()).toString();
}