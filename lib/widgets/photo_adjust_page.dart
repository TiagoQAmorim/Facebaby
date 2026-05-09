import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Ajuste de foto: pinça + arrastar; recorte quadrado (não redondo).
class PhotoAdjustPage extends StatefulWidget {
  final Uint8List imageBytes;

  const PhotoAdjustPage({super.key, required this.imageBytes});

  @override
  State<PhotoAdjustPage> createState() => _PhotoAdjustPageState();
}

class _PhotoAdjustPageState extends State<PhotoAdjustPage> {
  final _controller = CropController();
  var _busy = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure(:final cause):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível aplicar o recorte: $cause')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('Ajustar foto'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pinch, size: 20, color: Colors.black.withAlpha(150)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use dois dedos para ampliar ou reduzir e um dedo para mover a foto. '
                      'O quadrado mostra o que será salvo.',
                      style: TextStyle(color: Colors.black.withAlpha(150), fontSize: 12.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Crop(
                  image: widget.imageBytes,
                  controller: _controller,
                  interactive: true,
                  fixCropRect: true,
                  withCircleUi: false,
                  aspectRatio: 1,
                  maskColor: Colors.black.withAlpha(140),
                  baseColor: Colors.black,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(size: 0.85, aspectRatio: 1),
                  onCropped: _onCropped,
                  willUpdateScale: (next) => next >= 0.08 && next <= 14,
                  scrollZoomSensitivity: 0.14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _busy = true);
                        _controller.crop();
                      },
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Usar esta foto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
