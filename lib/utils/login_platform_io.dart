import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

bool get isIOSDevice {
  if (kIsWeb) return false;
  return Platform.isIOS;
}

bool get isAndroidDevice {
  if (kIsWeb) return false;
  return Platform.isAndroid;
}
