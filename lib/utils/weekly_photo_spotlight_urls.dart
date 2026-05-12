/// URLs de imagem que não devem aparecer no banner “Foto da Semana” (seeds / demos).
abstract final class WeeklyPhotoSpotlightUrls {
  WeeklyPhotoSpotlightUrls._();

  /// `true` se [url] for claramente placeholder ou serviço de demo — não é foto real de utilizador.
  static bool looksLikeDemoOrPlaceholder(String url) {
    final u = url.toLowerCase().trim();
    if (u.isEmpty) return true;

    // Serviços típicos de placeholder / stock em seeds e tutoriais.
    const blockedFragments = <String>[
      'picsum.photos',
      'placehold.co',
      'placeholder',
      'via.placeholder',
      'dummyimage.com',
      'example.com',
      'example.org',
      'lorempixel',
      'loremflickr',
      'thispersondoesnotexist',
      'fakeimg.pl',
      'placekitten',
      'baconmockup',
      'images.unsplash.com',
      'unsplash.com',
      'pexels.com',
      'pixabay.com',
      'freepik.com',
      'stock.adobe.com',
      'shutterstock.com',
    ];
    for (final f in blockedFragments) {
      if (u.contains(f)) return true;
    }

    // Caminhos comuns em buckets de desenvolvimento / marketing.
    const pathHints = <String>[
      '/demo/',
      '/demonstracao/',
      '/demonstração/',
      '/sample/',
      '/seed/',
      '/mock/',
      'spotlight_demo',
      'weekly_photo_demo',
      'foto_semana_demo',
    ];
    for (final h in pathHints) {
      if (u.contains(h)) return true;
    }

    return false;
  }
}
