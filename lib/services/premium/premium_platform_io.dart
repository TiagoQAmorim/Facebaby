import 'dart:io' show Platform;

bool premiumStoreSupported() => Platform.isAndroid || Platform.isIOS;
