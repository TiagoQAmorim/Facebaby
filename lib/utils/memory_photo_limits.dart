import 'package:flutter/foundation.dart' show kIsWeb;

/// Tamanho máximo ao escolher foto para memórias / mural do dia.
/// No **web** os dados vivem em `SharedPreferences` (localStorage), com cota baixa
/// por origem; fotos muito grandes somadas ao resto da app estouram quota e podem
/// impedir novas gravações ou deixar o armazenamento instável.
int memoryPhotoPickMaxBytes() => kIsWeb ? 420 * 1024 : (2 * 1024 * 1024);
