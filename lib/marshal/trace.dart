import 'package:flutter/foundation.dart';

/// Debug-only trace. The message is built inside an `assert`, so both the
/// closure and its string literals are dropped from release builds.
void gridNote(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}
