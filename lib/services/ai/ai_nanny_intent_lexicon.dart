/// Palavras e frases para detecção de intenção de registro (PT-BR, ES, EN, IT, FR, DE).
abstract final class AiNannyIntentLexicon {
  static bool containsAny(String low, Iterable<String> phrases) =>
      phrases.any(low.contains);

  // —— Alimentação ——
  static const feedingCues = [
    // PT-BR
    'mamar', 'mamou', 'mamei', 'mamada', 'mamadeira', 'amament',
    'peito', 'alimentei', 'alimentação', 'alimentacao', 'dei leite',
    'dar mamar', 'dei mamar', 'deu mamar', 'acabei de dar mamar',
    // EN
    'breastfed', 'breastfeed', 'nursed', 'nursing', 'bottle feed',
    'bottle-feed', 'fed the baby', 'just fed', 'feeding time',
    'had a feed', 'fed ', 'feed ', 'breast', 'lactancia', 'lactó',
    'allaitement', 'stillen', 'allattamento', 'mamó', 'mamo',
    'tomó el pecho', 'tomó pecho', 'amamantó', 'amamanto',
    'allattato', 'allattamento', 'poppata', 'poppe',
    'allaité', 'allaitement', 'tétée',
    'gestillt', 'stillen', 'an der brust',
    ' ml', 'ml ',
  ];

  static const bottleSubtypeCues = [
    'mamadeira', 'bottle', 'biberón', 'biberon', 'biberòn',
    'flasche', ' ml', 'ml ',
  ];

  static const solidsSubtypeCues = [
    'solido', 'sólido', 'solidos', 'sólidos', 'papinha',
    'solid food', 'purée', 'puree', 'comida sólida',
    'alimentación sólida', 'pappa', 'brei',
  ];

  static const breastLeftCues = [
    'esquerd', 'left breast', 'left side', 'lado esquerdo',
    'lado izquierdo', 'seno sinistro', 'linke brust', 'gauche',
    ' côté gauche', ' lato sinistro', 'linke brust', 'linken brust',
  ];

  static const breastRightCues = [
    'direit', 'right breast', 'right side', 'lado direito',
    'lado derecho', 'seno destro', 'rechte brust', 'droite',
    ' côté droit', ' lato destro',
  ];

  static const breastBothCues = [
    'dos dois', 'dois lados', 'ambos os peitos', 'both breasts', 'both sides',
    'beide brüste', 'beide seiten', 'les deux seins', 'entrambi i lati',
    'ambos lados', 'deux côtés',
  ];

  // —— Fralda ——
  static const diaperCues = [
    // PT-BR
    'fralda', 'trocou', 'troquei', 'trocar a fralda', 'troca de fralda',
  ];

  static const diaperChangeCues = [
    ...diaperCues,
    // EN
    'diaper', 'nappy', 'changed the diaper', 'diaper change',
    'changed diaper', 'wet diaper', 'dirty diaper',
    // ES
    'pañal', 'panal', 'cambié el pañal', 'cambie el panal',
    'cambió el pañal', 'cambio de pañal',
    // FR
    'couche', 'changé la couche', 'change de couche',
    // DE
    'windel', 'windel gewechselt', 'windeln gewechselt',
    // IT
    'pannolino', 'cambiato il pannolino', 'cambio pannolino',
  ];

  static const peeCues = [
    // PT-BR
    'xixi', 'xix', 'pipi', 'mijou', 'mijo', 'mijar', 'urinou',
    'fez xixi', 'fez pipi', 'fazer xixi', 'fazendo xixi',
    // EN
    ' pee', 'peed', 'urine', 'urinated', 'wet pee', 'wee ',
    'had a wee', 'made pee',
    // ES
    'pipí', 'pipi', 'orina', 'orinó', 'orino', 'hizo pipí', 'hizo pipi',
    'mojó', 'mojo',
    // FR
    'pipi', 'urine', 'a fait pipi', 'fait pipi',
    // DE
    'urin', 'gepinkelt', 'pipi gemacht', 'nass gemacht',
    // IT
    'pipì', 'pipi', 'urina', 'ha fatto pipì', 'fatto pipì',
  ];

  static const pooCues = [
    // PT-BR
    'cocô', 'coco', 'cagar', 'cagou', 'cagando', 'fezes', 'fez cocô', 'fez coco',
    // EN
    'poop', 'poo', 'bowel movement', 'dirty diaper', 'had a poop',
    'pooped',
    // ES
    'caca', 'caca', 'popó', 'popo', 'heces', 'hizo caca', 'hizo popó',
    // FR
    'caca', 'selles', 'popo', 'a fait caca',
    // DE
    'kaka', 'stuhl', 'kot', 'stuhlgang', 'stuhl gemacht',
    // IT
    'cacca', 'popò', 'feci', 'ha fatto la cacca',
  ];

  static const diaperBothCues = [
    'ambos', 'os dois', 'as duas', 'pee and poop', 'pipi y caca',
    'pipí y caca', 'les deux', 'beides', 'entrambi',
  ];

  // —— Sono ——
  static const sleepCues = [
    // PT-BR
    'dormiu', 'dormir', 'dormindo', 'sono', 'soneca', 'soninho',
    'foi dormir', 'hora de dormir', 'colocou para dormir',
    'coloquei para dormir', 'acordou', 'despertou', 'acabou de acordar',
    'nanar', 'ninar',
    // EN
    'slept', 'sleeping', 'asleep', 'went to sleep', 'put to sleep',
    'nap time', ' nap', 'napped', 'woke up', 'wake up', 'awake',
    'bedtime',
    // ES
    'durmió', 'durmio', 'durmiendo', 'sueño', 'sueno', 'siesta',
    'despertó', 'desperto', 'hora de dormir', 'se durmió',
    // FR
    'dormi', 'dort', 'sommeil', 'sieste', 'réveillé', 'reveille',
    'endormi', 'coucher',
    // DE
    'geschlafen', 'schlaf', 'schlafen', 'nickerchen', 'eingeschlafen',
    'aufgewacht', 'wach geworden',
    // IT
    'dormito', 'dormire', 'sonno', 'pisolino', 'svegliato', 'addormentato',
  ];

  static const sleepStartCues = [
    'foi dormir', 'vai dormir', 'colocou para dormir', 'coloquei para dormir',
    'hora de dormir', 'went to sleep', 'put to sleep', 'falling asleep',
    'se durmió', 'se endorm', 'eingeschlafen', 'si è addormentato',
    'iniciar sono', 'iniciou o sono', 'dormindo agora', 'bedtime',
  ];

  static const sleepWakeCues = [
    'acordou', 'despertou', 'acabou de acordar', 'levantou', 'levantou agora',
    'woke up', 'wake up', 'just woke', 'despertó', 'desperto', 'réveillé',
    'aufgewacht', 'svegliato', 'terminou o sono', 'encerrou o sono',
  ];

  static bool textImpliesWake(String low) =>
      containsAny(low, sleepWakeCues);

  static const sleepCompleteCues = [
    'dormiu', 'soneca', 'soninho', 'slept', 'nap', 'napped', 'siesta',
    'durmió', 'dormi', 'geschlafen', 'dormito',
  ];

  // —— Crescimento / saúde rotina ——
  static const weightCues = [
    'pesou', 'peso', ' kg', 'quilo', 'gramas', 'weighed', 'weight',
    'pesó', 'peso', 'gewogen', 'gewicht', 'pesato', 'kilogram', 'kilogramm',
  ];

  static const weightGainCues = [
    'ganhou', 'gained', 'gain ', 'ganó', 'guadagnato', 'gagné', 'zugenommen',
    'aufgenommen', 'increased by',
    // PT-BR informal / variações
    'engordou', 'engordar', 'engordando', 'aumentou', 'aumentou de peso',
    'subiu de peso',
    'ganhou peso', 'ganhou de peso', 'mais pesad', 'mais gord',
  ];

  static const heightCues = [
    'altura', ' cresceu', 'crescimento', ' cm', 'height', 'tall',
    'estatura', 'taille', 'größe', 'altezza', 'centimeter', 'centimetre',
  ];

  static const heightGainCues = [
    'cresceu', 'grew', 'creció', 'cresciuto', 'grandi', 'gewachsen', 'wuchs',
  ];

  static const scheduleCues = [
    'agendar', 'agenda', 'marcar', 'schedule', 'book', 'programar',
    'prenotare', 'planifier', 'vereinbaren', 'termin',
  ];

  static const takenCues = [
    'tomou', 'tomada', 'aplicou', 'took', 'got the', 'received',
    'recibió', 'recibio', 'ha ricevuto', 'a reçu', 'a recu', 'bekam',
    'ha fatto', 'fatta',
  ];

  static const todayCues = [
    'hoje', 'today', 'hoy', 'oggi', "aujourd'hui", 'aujourdhui', 'heute',
  ];

  static const tomorrowCues = [
    'amanhã', 'amanha', 'tomorrow', 'mañana', 'manana', 'domani', 'demain', 'morgen',
  ];

  static const formulaCues = [
    'fórmula', 'formula', 'formule', 'formel', 'formula ',
  ];

  static const expressedMilkCues = [
    'ordenha', 'expressed', 'leche materna extraida', 'lait tiré',
  ];

  static const temperatureCues = [
    'febre', 'temperatura', '°c', 'graus', 'fever', 'temperature',
    'fiebre', 'fièvre', 'fieber', 'febbre',
  ];

  static const medicineCues = [
    'remédio', 'remedio', 'medicamento', 'dei dipirona', 'dei paracetamol',
    'dei ibuprofeno', 'tomou remédio', 'tomou remedio', 'dei o remédio',
    'medicine', 'medication', 'gave medicine', 'tylenol', 'motrin',
    'ibuprofen', 'acetaminophen', 'medicina', 'medicamento',
    'médicament', 'medikament', 'farmaco', 'medicina',
  ];

  static const bathCues = [
    'banho', 'tomou banho', 'bath', 'bathed', 'baño', 'bañó',
    'bain', 'bad', 'bagno', 'fatto il bagno',
  ];

  static const memoryCues = [
    'marco', 'primeiro', 'conquista', 'memória', 'memoria', 'foto do',
    'milestone', 'first time', 'memory', 'hito', 'primera vez',
    'étape', 'souvenir', 'meilenstein', 'erinnerung', 'traguardo',
  ];

  static const consultationCues = [
    'consulta', 'pediatra', 'appointment', 'doctor visit', 'visita médica',
    'médecin', 'arzt', 'medico', 'pediatra', 'cardiolog', 'pediatrician',
    'kindesarzt', 'pediatra', 'rendez-vous',
  ];

  static const symptomCues = [
    'chorando', 'crying', 'llorando', 'pleure', 'weint',
    'pianto', 'cólica', 'colic', 'kolik', 'colique', 'reflux',
    'vomit', 'vómito', 'diarr', 'tosse', 'cough', 'coriza', 'runny nose',
  ];

  static const vaccineCues = ['vacin', 'vaccin', 'impfung', 'vaccino'];

  // —— Conversa (não registrar) ——
  static const greetingOnlyPhrases = [
    'oi', 'olá', 'ola', 'bom dia', 'boa tarde', 'boa noite',
    'hi', 'hello', 'hey', 'good morning', 'good evening',
    'hola', 'buenos días', 'buenas tardes', 'buenas noches',
    'bonjour', 'bonsoir', 'salut',
    'hallo', 'guten morgen', 'guten tag',
    'ciao', 'buongiorno', 'buonasera',
  ];

  static const declineRegistrationCues = [
    'não quero registrar', 'nao quero registrar', 'não precisa registrar',
    "don't register", 'no registrar', 'no quiero registrar',
    'ne pas enregistrer', 'nicht speichern', 'non registrare',
    'deixa assim', 'cancela o registro', 'esquece o registro',
  ];

  /// Pedido explícito para gravar o que já foi entendido (ex.: após "ganhou 150g").
  static const confirmSaveCues = [
    'registra isso',
    'registra isto',
    'registrar isso',
    'salva isso',
    'salvar isso',
    'pode registrar',
    'pode salvar',
    'confirma',
    'confirmar',
    'grava isso',
    'gravar isso',
    'anota isso',
    'anotar isso',
    'save it',
    'register it',
    'confirm it',
    'guardalo',
    'regístralo',
    'registralo',
  ];

  /// União para [RoutineRecordInterpreter.transcriptHasRoutineCue].
  static List<String> get allRoutineCues => [
        ...feedingCues,
        ...diaperCues,
        ...peeCues,
        ...pooCues,
        ...sleepCues,
        ...weightCues,
        ...weightGainCues,
        ...heightCues,
        ...heightGainCues,
        ...temperatureCues,
        ...medicineCues,
        ...bathCues,
        ...consultationCues,
        ...vaccineCues,
        'fed ', 'feed ', 'diaper', 'pañal', 'windel', 'pannolino',
        'chorando', 'crying', 'llorando',
      ];

  static bool hasFeedingCue(String low) => containsAny(low, feedingCues);

  /// Mamada para registrar — não "parece com fome" sem ação.
  static bool hasExplicitFeedingIntent(String low) {
    if (containsAny(low, [
      'mamou', 'mamei', 'mamada', 'mamar', 'amament',
      'nursed', 'breastfed', 'fed the baby', 'just fed', 'deu mamar',
      'mamadeira', 'tomou leite', ' ml', 'ml ',
    ])) {
      return true;
    }
    return hasFeedingCue(low) &&
        !RegExp(r'\b(com fome|parece.*fome|hungry|hambre)\b').hasMatch(low);
  }

  static bool hasDiaperCue(String low) =>
      containsAny(low, diaperCues) ||
      containsAny(low, peeCues) ||
      containsAny(low, pooCues);

  static bool hasPeeCue(String low) => containsAny(low, peeCues);

  static bool hasPooCue(String low) => containsAny(low, pooCues);

  static bool indicatesDiaperChange(String low) =>
      containsAny(low, diaperChangeCues);

  static bool hasSleepCue(String low) => containsAny(low, sleepCues);

  static bool hasTemperatureCue(String low) => containsAny(low, temperatureCues);

  static bool hasMedicineCue(String low) => containsAny(low, medicineCues);

  static bool hasBathCue(String low) => containsAny(low, bathCues);

  static bool hasMemoryCue(String low) => containsAny(low, memoryCues);

  static bool isGreetingOnly(String low) {
    if (low.length > 48) return false;
    return greetingOnlyPhrases.any((g) => low == g || low.startsWith('$g '));
  }

  static bool isBottleSubtype(String low) => containsAny(low, bottleSubtypeCues);

  static bool isSolidsSubtype(String low) => containsAny(low, solidsSubtypeCues);

  static String? resolveDiaperKind(String transcript) {
    final low = transcript.toLowerCase();
    final hasPee = hasPeeCue(low);
    final hasPoo = hasPooCue(low);
    final hasBoth = containsAny(low, diaperBothCues) ||
        (low.contains('dois') && (hasPee || hasPoo)) ||
        (low.contains('two') && (hasPee || hasPoo));
    if (hasBoth || (hasPee && hasPoo)) return 'both';
    if (hasPoo) return 'poo';
    if (hasPee) return 'pee';
    return null;
  }

  static String? parseBreastSide(String low) {
    if (containsAny(low, breastLeftCues) || low == 'e' || low == 'l') {
      return 'E';
    }
    if (containsAny(low, breastRightCues) || low == 'd' || low == 'r') {
      return 'D';
    }
    return null;
  }

  /// "Registra isso", "salva", etc. — após rascunho de crescimento pendente.
  static bool wantsConfirmSave(String transcript) {
    final low = transcript.trim().toLowerCase();
    if (low.isEmpty) return false;
    if (containsAny(low, confirmSaveCues)) return true;
    if (RegExp(
      r'\b(pode|podem)\s+(registrar|registar|salvar|gravar|anotar)\b',
    ).hasMatch(low)) {
      return true;
    }
    if (RegExp(r'\b(registra|registrar|salva|salvar|grava|gravar|anota|anotar)\b')
        .hasMatch(low)) {
      return low.contains('isso') ||
          low.contains('isto') ||
          low.contains('aí') ||
          low.contains('ai') ||
          low.contains('peso') ||
          low.contains('crescimento') ||
          low.contains('vacin') ||
          low.contains('remédio') ||
          low.contains('remedio') ||
          low.contains('medicamento') ||
          low.contains('consulta') ||
          low.contains('então') ||
          low.contains('entao');
    }
    return false;
  }

  static bool confirmsAffirmative(String transcript) {
    final low = transcript.trim().toLowerCase();
    if (low.isEmpty) return false;
    if (RegExp(
      r'^(sim|s|ok|confirmo|yes|yep|yeah|ja|oui|si|sí|sì)\b',
    ).hasMatch(low)) {
      return true;
    }
    if (RegExp(r'\b(sim|yes|ja|oui|sí|si|sì)\b').hasMatch(low)) return true;
    if (low.contains('pode ser') ||
        low.contains('confirmo') ||
        low.contains('of course') ||
        low.contains('sure')) {
      return true;
    }
    if (low.contains('agora') ||
        low.contains('now') ||
        low.contains('ahora') ||
        low.contains('jetzt') ||
        indicatesDiaperChange(low)) {
      return true;
    }
    return false;
  }
}
