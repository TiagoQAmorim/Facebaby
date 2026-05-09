import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../widgets/photo_adjust_page.dart';
import 'file_picker_bytes.dart';
import 'photo_b64.dart';

img.Image _resizeToMaxSide(img.Image src, int side) {
  if (src.width <= side && src.height <= side) return src;
  return src.width >= src.height ? img.copyResize(src, width: side) : img.copyResize(src, height: side);
}

Uint8List _compressToFit(Uint8List raw, int maxBytes) {
  if (raw.lengthInBytes <= maxBytes) return raw;
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;
  for (final side in [1600, 1280, 1024, 800, 640, 520]) {
    final work = _resizeToMaxSide(decoded, side);
    for (var q = 90; q >= 40; q -= 10) {
      final out = Uint8List.fromList(img.encodeJpg(work, quality: q));
      if (out.lengthInBytes <= maxBytes) return out;
    }
  }
  final tiny = _resizeToMaxSide(decoded, 480);
  return Uint8List.fromList(img.encodeJpg(tiny, quality: 38));
}

Future<Uint8List?> _pickFromFilePicker() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (res == null || res.files.isEmpty) return null;
  final pf = res.files.first;
  final Uint8List? picked = await readPlatformFileBytes(pf);
  if (picked == null || picked.isEmpty) return null;
  return Uint8List.fromList(picked);
}

Future<Uint8List?> _pickFromImagePicker(ImageSource source) async {
  final picker = ImagePicker();
  final x = await picker.pickImage(source: source);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (bytes.isEmpty) return null;
  return Uint8List.fromList(bytes);
}

Future<ImageSource?> _askSource(BuildContext context) async {
  if (kIsWeb) return ImageSource.gallery;
  final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  if (!isMobile) return ImageSource.gallery;

  return showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Câmera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeria'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 6),
          ],
        ),
      );
    },
  );
}

/// Picks an image, then opens the adjust/crop screen (pan, zoom, recorte quadrado).
/// Set [allowAdjust] to `false` only for rare cases (tests); default is on for the whole app.
Future<String?> pickImageAsB64({
  required BuildContext context,
  int? maxBytes,
  bool allowAdjust = true,
}) async {
  Uint8List? raw;
  final source = await _askSource(context);
  if (source == null) return null;

  final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  if (!kIsWeb && isMobile) {
    raw = await _pickFromImagePicker(source);
  } else {
    raw = await _pickFromFilePicker();
  }
  if (raw == null || raw.isEmpty) return null;

  final limit = maxBytes;
  if (limit != null && raw.lengthInBytes > limit) {
    raw = _compressToFit(raw, limit);
    if (raw.lengthInBytes > limit) {
      return null;
    }
  }

  if (allowAdjust && context.mounted) {
    final edited = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => PhotoAdjustPage(imageBytes: raw!),
      ),
    );
    if (edited == null) {
      return null;
    }
    raw = edited;
  }

  if (limit != null && raw.lengthInBytes > limit) {
    raw = _compressToFit(raw, limit);
    if (raw.lengthInBytes > limit) {
      return null;
    }
  }

  return encodePhotoB64(raw);
}
