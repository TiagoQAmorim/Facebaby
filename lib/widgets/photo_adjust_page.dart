import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Ajuste de foto em tela cheia: pinça/arrastar; recorte quadrado centralizado.
class PhotoAdjustPage extends StatefulWidget {
  final Uint8List imageBytes;

  const PhotoAdjustPage({super.key, required this.imageBytes});

  @override
  State<PhotoAdjustPage> createState() => _PhotoAdjustPageState();
}

class _PhotoAdjustPageState extends State<PhotoAdjustPage> {
  final _controller = CropController();
  var _busy = false;
  late Uint8List _imageBytes;

  static const _maxScale = 48.0;
  static const _minScale = 0.04;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.imageBytes;
  }

  void _rotate(int angle) {
    if (_busy) return;
    final decoded = img.decodeImage(_imageBytes);
    if (decoded == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível rotacionar a foto.')),
      );
      return;
    }
    final rotated = img.copyRotate(decoded, angle: angle);
    final bytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
    setState(() => _imageBytes = bytes);
    _controller.image = bytes;
  }

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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Crop(
            image: _imageBytes,
            controller: _controller,
            interactive: true,
            fixCropRect: true,
            withCircleUi: false,
            aspectRatio: 1,
            maskColor: Colors.black.withAlpha(175),
            baseColor: Colors.black,
            initialRectBuilder:
                InitialRectBuilder.withBuilder(_initialCropSquare),
            onCropped: _onCropped,
            willUpdateScale: (next) => next >= _minScale && next <= _maxScale,
            scrollZoomSensitivity: 0.28,
            radius: 4,
            overlayBuilder: (context, rect) {
              return CustomPaint(
                painter: _CropGridPainter(),
                child: const SizedBox.expand(),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Ajustar foto',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    'Use dois dedos para ampliar bem a foto e um dedo para centralizar. '
                    'Se precisar, rotacione a imagem antes de salvar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _rotate(-90),
                          icon: const Icon(Icons.rotate_left_rounded),
                          label: const Text('Girar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withAlpha(180),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _rotate(90),
                          icon: const Icon(Icons.rotate_right_rounded),
                          label: const Text('Girar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withAlpha(180),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() => _busy = true);
                            _controller.crop();
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : const Text(
                            'Usar esta foto',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quadrado de recorte grande e centralizado (~94% do lado menor da tela).
Rect _initialCropSquare(ViewportBasedRect viewport, ImageBasedRect _) {
  final w = viewport.width;
  final h = viewport.height;
  const inset = 12.0;
  final maxSide = math.min(w, h) - inset * 2;
  final side = maxSide.clamp(200.0, math.min(w, h)).toDouble();
  final left = (w - side) / 2;
  final top = (h - side) / 2;
  return Rect.fromLTWH(left, top, side, side);
}

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(55)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final fx = size.width * i / 3;
      final fy = size.height * i / 3;
      canvas.drawLine(Offset(fx, 0), Offset(fx, size.height), paint);
      canvas.drawLine(Offset(0, fy), Offset(size.width, fy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
