/// Qualidade do PDF do livro de memórias.
enum MemoryAlbumPdfQuality {
  /// Menor tamanho — ideal para partilhar (WhatsApp, e-mail).
  share,

  /// Maior resolução — ideal para impressão.
  print,
}

extension MemoryAlbumPdfQualitySettings on MemoryAlbumPdfQuality {
  int get maxImageWidth => switch (this) {
        MemoryAlbumPdfQuality.share => 960,
        MemoryAlbumPdfQuality.print => 1800,
      };

  int get jpegQuality => switch (this) {
        MemoryAlbumPdfQuality.share => 72,
        MemoryAlbumPdfQuality.print => 88,
      };

  String get fileSuffix => switch (this) {
        MemoryAlbumPdfQuality.share => 'share',
        MemoryAlbumPdfQuality.print => 'print',
      };
}
