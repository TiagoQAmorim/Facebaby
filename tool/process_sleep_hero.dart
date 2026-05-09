// Processa assets/sleep/baby_sleep.png: upscale + remove fundo escuro ligado à borda (BFS).
// Uso: dart run tool/process_sleep_hero.dart
import 'dart:io';

import 'package:image/image.dart' as img;

/// Largura alvo (~3× típico asset mobile); mantém proporção.
const int _targetMinWidth = 1200;

bool _isDarkBg(int r, int g, int b, int a) {
  if (a < 200) return false;
  // Fundo preto / cinza muito escuro (evita comer roxo do desenho: threshold moderado).
  return r < 48 && g < 48 && b < 48;
}

void main() {
  final root = Directory.current.path;
  final input = File('$root/assets/sleep/baby_sleep.png');
  if (!input.existsSync()) {
    stderr.writeln('Missing ${input.path}');
    exit(1);
  }

  final bytes = input.readAsBytesSync();
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    stderr.writeln('Could not decode PNG');
    exit(1);
  }

  var im = _ensureRgba(decoded);

  // Upscale antes do recorte para bordas mais suaves.
  if (im.width < _targetMinWidth) {
    const nw = _targetMinWidth;
    final nh = (im.height * (nw / im.width)).round();
    im = img.copyResize(im, width: nw, height: nh, interpolation: img.Interpolation.cubic);
  }

  final w = im.width;
  final h = im.height;

  final isBg = List.generate(h, (_) => List<bool>.filled(w, false));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      isBg[y][x] = _isDarkBg(p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt());
    }
  }

  final vis = List.generate(h, (_) => List<bool>.filled(w, false));
  final q = <List<int>>[];

  void push(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h || vis[y][x]) return;
    if (!isBg[y][x]) return;
    vis[y][x] = true;
    q.add([x, y]);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }

  var qi = 0;
  while (qi < q.length) {
    final c = q[qi++];
    final x = c[0], y = c[1];
    im.setPixelRgba(x, y, 0, 0, 0, 0);
    const dirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];
    for (final d in dirs) {
      final nx = x + d[0], ny = y + d[1];
      if (nx >= 0 && ny >= 0 && nx < w && ny < h && !vis[ny][nx] && isBg[ny][nx]) {
        vis[ny][nx] = true;
        q.add([nx, ny]);
      }
    }
  }

  final outBytes = img.encodePng(im, level: 6);
  final backup = File('$root/assets/sleep/baby_sleep.original.png');
  if (!backup.existsSync()) {
    backup.writeAsBytesSync(bytes);
  }
  input.writeAsBytesSync(outBytes);
  stdout.writeln('Wrote ${input.path} (${im.width}×${im.height}, RGBA)');
}

img.Image _ensureRgba(img.Image src) {
  if (src.numChannels >= 4) return src;
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
    }
  }
  return out;
}
