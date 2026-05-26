// Traduções ES/FR/DE/IT — IA Babá, histórico, horóscopo familiar e curvas de crescimento.
// ignore_for_file: lines_longer_than_80_chars

const Set<String> kAiFamilyGrowthExtraKeys = {
  'growthCurveSectionTitle',
  'growthCurveSectionTitleWeight',
  'growthCurveDisclaimer',
  'growthCurveLegendMin',
  'growthCurveLegendAvg',
  'growthCurveLegendMax',
  'growthCurveLegendBaby',
  'growthCurveAxisMonths',
  'growthCurveReferenceGirls',
  'growthCurveReferenceBoys',
  'growthCurveSexHint',
  'aiNannyNavLabel',
  'aiNannyPhase1Hint',
  'aiNannyTitle',
  'aiNannySubtitle',
  'aiNannyWelcomeMessage',
  'aiNannyMockReply',
  'aiNannyInputHint',
  'aiNannyThinking',
  'aiNannyDisclaimer',
  'aiNannyPremiumTitle',
  'aiNannyPremiumBody',
  'aiNannyPremiumCta',
  'aiNannyBenefitSmart',
  'aiNannyBenefitPersonal',
  'aiNannyBenefitAlerts',
  'aiNannyBenefitRoutines',
  'aiNannyBenefitContent',
  'aiNannyBenefitAudioSoon',
  'aiNannyAskBelow',
  'aiNannyNoBaby',
  'aiNannyRemainingToday',
  'aiNannyDailyLimitMessage',
  'aiNannyCallFailed',
  'aiNannyProfileButton',
  'aiNannySignInRequired',
  'aiVoiceRecording',
  'aiVoiceProcessing',
  'aiVoiceUnderstood',
  'aiVoiceConfirmTitle',
  'aiVoiceConfirm',
  'aiVoiceMicDenied',
  'aiVoiceMicWebUnavailable',
  'aiVoiceSavedOk',
  'aiVoiceSleepStarted',
  'aiVoiceSleepEnded',
  'aiVoiceRecordFailed',
  'aiVoiceNotARegisterTitle',
  'aiVoiceRegisterHint',
  'aiVoiceHoldMicHint',
  'aiVoiceReleaseHint',
  'aiVoiceTapMicHint',
  'aiVoiceTapStopHint',
  'aiVoiceRecordingHint',
  'aiVoiceListenReply',
  'aiTtsPreparing',
  'aiTtsPause',
  'aiTtsResume',
  'aiTtsRetry',
  'aiVoiceAskAiInstead',
  'aiVoiceHealthFieldsHint',
  'aiVoiceHealthTempLabel',
  'aiVoiceHealthVaccineNameLabel',
  'aiVoiceHealthVaccineDoseLabel',
  'aiVoiceHealthVaccineNameRequired',
  'aiBabyHistoryTitle',
  'aiBabyHistorySubtitle',
  'aiBabyHistoryFieldLabel',
  'aiBabyHistoryPlaceholder',
  'aiBabyHistoryDisclaimer',
  'aiBabyHistorySave',
  'aiBabyHistoryClear',
  'aiBabyHistorySaved',
  'aiBabyHistoryCleared',
  'aiBabyHistoryClearConfirmTitle',
  'aiBabyHistoryClearConfirmBody',
  'aiBabyHistoryLinkSubtitle',
  'aiBabyHistoryCharCount',
  'settingsAiBabyHistory',
  'familyTabTree',
  'familyTabHoroscope',
  'familyTabAiHistory',
  'familyHoroscopeDate',
  'familyHoroscopeGenerateToday',
  'familyHoroscopeRefresh',
  'familyHoroscopeMother',
  'familyHoroscopeFather',
  'familyHoroscopeBaby',
  'familyHoroscopeFamilyEnergy',
  'familyHoroscopeDailyAdvice',
  'familyHoroscopeDisclaimer',
  'familyHoroscopeRegisterFather',
  'familyHoroscopePremiumTitle',
  'familyHoroscopePremiumBody',
  'familyHoroscopeErrorGeneric',
  'familyHoroscopeErrorNotFound',
  'familyHoroscopeErrorUnauthenticated',
  'familyHoroscopeErrorPermission',
  'familyHoroscopeErrorPrecondition',
  'familyHoroscopeErrorExhausted',
};

/// Mapas por idioma (apenas chaves em [kAiFamilyGrowthExtraKeys]).
const Map<String, Map<String, String>> kAiFamilyGrowthLocaleExtras = {
  'es': _es,
  'fr': _fr,
  'de': _de,
  'it': _it,
};

String? aiFamilyGrowthLocaleExtra(String langName, String key) {
  if (!kAiFamilyGrowthExtraKeys.contains(key)) return null;
  return kAiFamilyGrowthLocaleExtras[langName]?[key];
}

const Map<String, String> _es = {
  'growthCurveSectionTitle': 'Curva de crecimiento (altura)',
  'growthCurveSectionTitleWeight': 'Curva de crecimiento (peso)',
  'growthCurveDisclaimer':
      'Esta información es orientativa y no sustituye una evaluación médica.',
  'growthCurveLegendMin': 'Mínimo saludable',
  'growthCurveLegendAvg': 'Media saludable',
  'growthCurveLegendMax': 'Máximo saludable',
  'growthCurveLegendBaby': 'Evolución del bebé',
  'growthCurveAxisMonths': 'meses',
  'growthCurveReferenceGirls': 'Referencia — niñas (0–4 años)',
  'growthCurveReferenceBoys': 'Referencia — niños (0–4 años)',
  'growthCurveSexHint':
      'Indica el sexo del bebé en el perfil para la curva correcta. Mostrando referencia para niñas.',
  'aiNannyNavLabel': 'IA Niñera',
  'aiNannyPhase1Hint':
      'El chat llegará en la próxima fase. El acceso directo ya está en el menú.',
  'aiNannyTitle': 'IA Niñera 24h contigo',
  'aiNannySubtitle':
      'Respuestas inteligentes y orientación personalizada para la rutina de tu bebé.',
  'aiNannyWelcomeMessage':
      '¡Hola! Soy la IA Niñera de FaceBaby ❤️ Pregunta sobre rutina, sueño o alimentación — con cariño y sin alarmismo.',
  'aiNannyMockReply':
      'Entendido ❤️ En la próxima fase responderé con los registros reales de tu bebé.',
  'aiNannyInputHint': 'Escribe tu pregunta…',
  'aiNannyThinking': 'La IA Niñera está pensando con cariño…',
  'aiNannyDisclaimer':
      'Contenido informativo. No sustituye atención médica.',
  'aiNannyPremiumTitle': 'IA Niñera 24h contigo',
  'aiNannyPremiumBody':
      'Función Premium: chat inteligente con contexto del bebé, hasta 50 mensajes al día.',
  'aiNannyPremiumCta': 'Desbloquear Premium',
  'aiNannyBenefitSmart': 'Respuestas inteligentes',
  'aiNannyBenefitPersonal': 'Orientación personalizada',
  'aiNannyBenefitAlerts': 'Alertas predictivas (próximamente)',
  'aiNannyBenefitRoutines': 'Rutinas personalizadas',
  'aiNannyBenefitContent': 'Contenidos generados por IA',
  'aiNannyBenefitAudioSoon': 'Próximamente: respuestas por voz',
  'aiNannyAskBelow': 'Haz tu primera pregunta abajo.',
  'aiNannyNoBaby': 'Registra un bebé para personalizar las respuestas.',
  'aiNannyRemainingToday': 'Mensajes restantes hoy: {n}',
  'aiNannyDailyLimitMessage':
      'Alcanzaste el límite diario de la IA Niñera. Vuelve mañana.',
  'aiNannyCallFailed':
      'No pude responder ahora. Inténtalo de nuevo en unos momentos.',
  'aiNannyProfileButton': 'Perfil de IA',
  'aiNannySignInRequired': 'Inicia sesión para usar la IA Niñera.',
  'aiVoiceRecording': 'Grabando… {s}s (máx. 20)',
  'aiVoiceProcessing': 'Transcribiendo e interpretando…',
  'aiVoiceUnderstood': 'Entendido: {text}',
  'aiVoiceConfirmTitle': '¿Registrar esto?',
  'aiVoiceConfirm': 'Confirmar',
  'aiVoiceMicDenied':
      'Se necesita acceso al micrófono. Actívalo en los ajustes del dispositivo.',
  'aiVoiceMicWebUnavailable':
      'El registro por voz está disponible en las apps de Android e iOS.',
  'aiVoiceSavedOk': 'Registro guardado correctamente.',
  'aiVoiceSleepStarted':
      'Sueño iniciado — revisa la pantalla Sueño o di «despertó» cuando acabe.',
  'aiVoiceSleepEnded': 'Sueño registrado correctamente.',
  'aiVoiceRecordFailed': 'No pude procesar el audio. Inténtalo de nuevo.',
  'aiVoiceNotARegisterTitle': 'Parece una pregunta, no un registro.',
  'aiVoiceRegisterHint':
      'Para registrar por voz, di por ejemplo: «durmió 1 hora», «pesó 3,5 kg» o «mamó 120 ml». Para dudas, habla con normalidad — la IA Niñera responde en el chat.',
  'aiVoiceHoldMicHint': 'Mantén pulsado el micrófono para hablar con la IA Niñera.',
  'aiVoiceReleaseHint': 'Suelta para enviar…',
  'aiVoiceTapMicHint': 'Toca el micrófono para grabar',
  'aiVoiceTapStopHint': 'Toca otra vez para enviar el audio',
  'aiVoiceRecordingHint': 'Grabando… toca ■ para enviar',
  'aiVoiceListenReply': 'Escuchar respuesta',
  'aiTtsPreparing': 'Preparando audio...',
  'aiTtsPause': 'Pausar',
  'aiTtsResume': 'Continuar',
  'aiTtsRetry': 'Reintentar',
  'aiVoiceAskAiInstead': 'Preguntar a la IA Niñera',
  'aiVoiceHealthFieldsHint':
      'Completa los campos y pulsa Confirmar para guardar en Salud.',
  'aiVoiceHealthTempLabel': 'Temperatura (°C)',
  'aiVoiceHealthVaccineNameLabel': 'Nombre de la vacuna',
  'aiVoiceHealthVaccineDoseLabel': 'Dosis (opcional)',
  'aiVoiceHealthVaccineNameRequired': 'Indica el nombre de la vacuna.',
  'aiBabyHistoryTitle': 'Historial del bebé',
  'aiBabyHistorySubtitle':
      'Cuenta rasgos importantes del bebé y la rutina para que la IA Niñera personalice las respuestas.',
  'aiBabyHistoryFieldLabel': 'Historial importante para la IA',
  'aiBabyHistoryPlaceholder':
      'Ej.: prematuro, reflujo, lactancia, despierta mucho de noche, fórmula, alergias u orientación pediátrica.',
  'aiBabyHistoryDisclaimer':
      'Ayuda a la IA a responder mejor, pero no sustituye consejo médico.',
  'aiBabyHistorySave': 'Guardar historial',
  'aiBabyHistoryClear': 'Borrar historial',
  'aiBabyHistorySaved': 'Historial guardado',
  'aiBabyHistoryCleared': 'Historial eliminado',
  'aiBabyHistoryClearConfirmTitle': '¿Borrar historial?',
  'aiBabyHistoryClearConfirmBody':
      'La IA Niñera dejará de usar esta información hasta que la completes de nuevo.',
  'aiBabyHistoryLinkSubtitle': 'Personaliza las respuestas de la IA Niñera',
  'aiBabyHistoryCharCount': '{current} / {max} caracteres',
  'settingsAiBabyHistory': 'Historial del bebé para la IA Niñera',
  'familyTabTree': 'Familia',
  'familyTabHoroscope': 'Horóscopo',
  'familyTabAiHistory': 'Historial',
  'familyHoroscopeDate': 'Horóscopo del {date}',
  'familyHoroscopeGenerateToday': 'Generar horóscopo de hoy',
  'familyHoroscopeRefresh': 'Actualizar horóscopo',
  'familyHoroscopeMother': 'Horóscopo de mamá',
  'familyHoroscopeFather': 'Horóscopo de papá',
  'familyHoroscopeBaby': 'Horóscopo del bebé',
  'familyHoroscopeFamilyEnergy': 'Energía familiar hoy',
  'familyHoroscopeDailyAdvice': 'Consejo del día para la familia',
  'familyHoroscopeDisclaimer':
      'Contenido generado por IA para reflexión y entretenimiento familiar. No sustituye orientación profesional.',
  'familyHoroscopeRegisterFather':
      'Registra a papá para incluir su horóscopo en la lectura familiar.',
  'familyHoroscopePremiumTitle': 'Horóscopo familiar con IA',
  'familyHoroscopePremiumBody':
      'Desbloquea lecturas diarias afectuosas para mamá, papá y bebé según los signos.',
  'familyHoroscopeErrorGeneric': 'No fue posible generar el horóscopo ahora. Inténtalo de nuevo.',
  'familyHoroscopeErrorNotFound':
      'Servicio de horóscopo no disponible. Actualiza la app e inténtalo de nuevo.',
  'familyHoroscopeErrorUnauthenticated': 'Inicia sesión para generar el horóscopo.',
  'familyHoroscopeErrorPermission':
      'Horóscopo familiar completo disponible en el plan Premium.',
  'familyHoroscopeErrorPrecondition':
      'Registra las fechas de nacimiento en Familia para generar el horóscopo.',
  'familyHoroscopeErrorExhausted':
      'Límite temporal alcanzado. Inténtalo más tarde.',
};

const Map<String, String> _fr = {
  'growthCurveSectionTitle': 'Courbe de croissance (taille)',
  'growthCurveSectionTitleWeight': 'Courbe de croissance (poids)',
  'growthCurveDisclaimer':
      'Ces informations sont indicatives et ne remplacent pas un avis médical.',
  'growthCurveLegendMin': 'Minimum sain',
  'growthCurveLegendAvg': 'Moyenne saine',
  'growthCurveLegendMax': 'Maximum sain',
  'growthCurveLegendBaby': 'Évolution du bébé',
  'growthCurveAxisMonths': 'mois',
  'growthCurveReferenceGirls': 'Référence — filles (0–4 ans)',
  'growthCurveReferenceBoys': 'Référence — garçons (0–4 ans)',
  'growthCurveSexHint':
      'Indiquez le sexe du bébé dans le profil pour la bonne courbe. Référence filles affichée.',
  'aiNannyNavLabel': 'IA Nounou',
  'aiNannyPhase1Hint':
      'Le chat arrive dans la prochaine phase. Le raccourci est déjà dans le menu.',
  'aiNannyTitle': 'IA Nounou 24h/24 avec vous',
  'aiNannySubtitle':
      'Réponses intelligentes et conseils personnalisés pour la routine de votre bébé.',
  'aiNannyWelcomeMessage':
      'Bonjour ! Je suis l’IA Nounou de FaceBaby ❤️ Posez vos questions sur la routine, le sommeil ou l’alimentation — avec douceur.',
  'aiNannyMockReply':
      'Compris ❤️ Dans la prochaine phase, je répondrai avec les vrais enregistrements de votre bébé.',
  'aiNannyInputHint': 'Saisissez votre question…',
  'aiNannyThinking': 'L’IA Nounou réfléchit avec attention…',
  'aiNannyDisclaimer':
      'Contenu informatif uniquement. Ne remplace pas un avis médical.',
  'aiNannyPremiumTitle': 'IA Nounou 24h/24 avec vous',
  'aiNannyPremiumBody':
      'Fonction Premium : chat intelligent avec le contexte du bébé, jusqu’à 50 messages par jour.',
  'aiNannyPremiumCta': 'Débloquer Premium',
  'aiNannyBenefitSmart': 'Réponses intelligentes',
  'aiNannyBenefitPersonal': 'Conseils personnalisés',
  'aiNannyBenefitAlerts': 'Alertes prédictives (bientôt)',
  'aiNannyBenefitRoutines': 'Routines personnalisées',
  'aiNannyBenefitContent': 'Contenus générés par IA',
  'aiNannyBenefitAudioSoon': 'Bientôt : réponses vocales',
  'aiNannyAskBelow': 'Posez votre première question ci-dessous.',
  'aiNannyNoBaby': 'Ajoutez un bébé pour personnaliser les réponses.',
  'aiNannyRemainingToday': 'Messages restants aujourd’hui : {n}',
  'aiNannyDailyLimitMessage':
      'Vous avez atteint la limite quotidienne de l’IA Nounou. Revenez demain.',
  'aiNannyCallFailed':
      'Impossible de répondre pour le moment. Réessayez dans un instant.',
  'aiNannyProfileButton': 'Profil IA',
  'aiNannySignInRequired': 'Connectez-vous pour utiliser l’IA Nounou.',
  'aiVoiceRecording': 'Enregistrement… {s}s (max. 20)',
  'aiVoiceProcessing': 'Transcription et analyse…',
  'aiVoiceUnderstood': 'Compris : {text}',
  'aiVoiceConfirmTitle': 'Enregistrer cela ?',
  'aiVoiceConfirm': 'Confirmer',
  'aiVoiceMicDenied':
      'L’accès au micro est nécessaire. Activez-le dans les réglages de l’appareil.',
  'aiVoiceMicWebUnavailable':
      'L’enregistrement vocal est disponible sur les apps Android et iOS.',
  'aiVoiceSavedOk': 'Enregistrement sauvegardé.',
  'aiVoiceSleepStarted':
      'Sommeil démarré — écran Sommeil ou dites « s’est réveillé » à la fin.',
  'aiVoiceSleepEnded': 'Sommeil enregistré.',
  'aiVoiceRecordFailed': 'Impossible de traiter l’audio. Réessayez.',
  'aiVoiceNotARegisterTitle': 'Cela ressemble à une question, pas à un enregistrement.',
  'aiVoiceRegisterHint':
      'Pour enregistrer à la voix, dites par ex. « a dormi 1 h », « pèse 3,5 kg » ou « 120 ml ». Pour une question, parlez — l’IA Nounou répond dans le chat.',
  'aiVoiceHoldMicHint': 'Maintenez le micro pour parler à l’IA Nounou.',
  'aiVoiceReleaseHint': 'Relâchez pour envoyer…',
  'aiVoiceTapMicHint': 'Appuyez sur le micro pour enregistrer',
  'aiVoiceTapStopHint': 'Appuyez à nouveau pour envoyer l’audio',
  'aiVoiceRecordingHint': 'Enregistrement… appuyez sur ■ pour envoyer',
  'aiVoiceListenReply': 'Écouter la réponse',
  'aiTtsPreparing': 'Préparation de l\'audio...',
  'aiTtsPause': 'Pause',
  'aiTtsResume': 'Reprendre',
  'aiTtsRetry': 'Réessayer',
  'aiVoiceAskAiInstead': 'Demander à l’IA Nounou',
  'aiVoiceHealthFieldsHint':
      'Remplissez les champs puis Confirmer pour enregistrer dans Santé.',
  'aiVoiceHealthTempLabel': 'Température (°C)',
  'aiVoiceHealthVaccineNameLabel': 'Nom du vaccin',
  'aiVoiceHealthVaccineDoseLabel': 'Dose (facultatif)',
  'aiVoiceHealthVaccineNameRequired': 'Indiquez le nom du vaccin.',
  'aiBabyHistoryTitle': 'Historique du bébé',
  'aiBabyHistorySubtitle':
      'Partagez les traits importants du bébé et de la routine pour personnaliser l’IA Nounou.',
  'aiBabyHistoryFieldLabel': 'Historique important pour l’IA',
  'aiBabyHistoryPlaceholder':
      'Ex. : prématuré, reflux, allaitement, réveils nocturnes, lait artificiel, allergies, suivi pédiatrique.',
  'aiBabyHistoryDisclaimer':
      'Aide l’IA à mieux répondre sans remplacer un avis médical.',
  'aiBabyHistorySave': 'Enregistrer l’historique',
  'aiBabyHistoryClear': 'Effacer l’historique',
  'aiBabyHistorySaved': 'Historique enregistré',
  'aiBabyHistoryCleared': 'Historique effacé',
  'aiBabyHistoryClearConfirmTitle': 'Effacer l’historique ?',
  'aiBabyHistoryClearConfirmBody':
      'L’IA Nounou n’utilisera plus ces informations tant que vous ne les aurez pas ressaisies.',
  'aiBabyHistoryLinkSubtitle': 'Personnalisez les réponses de l’IA Nounou',
  'aiBabyHistoryCharCount': '{current} / {max} caractères',
  'settingsAiBabyHistory': 'Historique du bébé pour l’IA Nounou',
  'familyTabTree': 'Famille',
  'familyTabHoroscope': 'Horoscope',
  'familyTabAiHistory': 'Historique',
  'familyHoroscopeDate': 'Horoscope du {date}',
  'familyHoroscopeGenerateToday': 'Générer l’horoscope du jour',
  'familyHoroscopeRefresh': 'Actualiser l’horoscope',
  'familyHoroscopeMother': 'Horoscope de maman',
  'familyHoroscopeFather': 'Horoscope de papa',
  'familyHoroscopeBaby': 'Horoscope du bébé',
  'familyHoroscopeFamilyEnergy': 'Énergie familiale aujourd’hui',
  'familyHoroscopeDailyAdvice': 'Conseil du jour pour la famille',
  'familyHoroscopeDisclaimer':
      'Contenu IA pour réflexion et divertissement familial. Ne remplace pas un avis professionnel.',
  'familyHoroscopeRegisterFather':
      'Ajoutez papa pour inclure son horoscope dans la lecture familiale.',
  'familyHoroscopePremiumTitle': 'Horoscope familial IA',
  'familyHoroscopePremiumBody':
      'Débloquez des lectures quotidiennes pour maman, papa et bébé selon les signes.',
  'familyHoroscopeErrorGeneric':
      'Impossible de générer l’horoscope maintenant. Réessayez.',
  'familyHoroscopeErrorNotFound':
      'Service d’horoscope indisponible. Mettez l’app à jour et réessayez.',
  'familyHoroscopeErrorUnauthenticated': 'Connectez-vous pour générer l’horoscope.',
  'familyHoroscopeErrorPermission':
      'Horoscope familial complet disponible avec Premium.',
  'familyHoroscopeErrorPrecondition':
      'Enregistrez les dates de naissance dans Famille pour générer l’horoscope.',
  'familyHoroscopeErrorExhausted':
      'Limite temporaire atteinte. Réessayez plus tard.',
};

const Map<String, String> _de = {
  'growthCurveSectionTitle': 'Wachstumskurve (Größe)',
  'growthCurveSectionTitleWeight': 'Wachstumskurve (Gewicht)',
  'growthCurveDisclaimer':
      'Diese Angaben dienen nur zur Orientierung und ersetzen keine ärztliche Bewertung.',
  'growthCurveLegendMin': 'Gesundes Minimum',
  'growthCurveLegendAvg': 'Gesunder Durchschnitt',
  'growthCurveLegendMax': 'Gesundes Maximum',
  'growthCurveLegendBaby': 'Entwicklung des Babys',
  'growthCurveAxisMonths': 'Monate',
  'growthCurveReferenceGirls': 'Referenz — Mädchen (0–4 Jahre)',
  'growthCurveReferenceBoys': 'Referenz — Jungen (0–4 Jahre)',
  'growthCurveSexHint':
      'Tragen Sie das Geschlecht des Babys im Profil ein für die richtige Kurve. Referenz für Mädchen.',
  'aiNannyNavLabel': 'KI-Babysitterin',
  'aiNannyPhase1Hint':
      'Der Chat kommt in der nächsten Phase. Die Verknüpfung ist schon im Menü.',
  'aiNannyTitle': 'KI-Babysitterin 24/7 für Sie',
  'aiNannySubtitle':
      'Intelligente Antworten und persönliche Tipps für die Routine Ihres Babys.',
  'aiNannyWelcomeMessage':
      'Hallo! Ich bin FaceBabys KI-Babysitterin ❤️ Fragen Sie zu Routine, Schlaf oder Ernährung — einfühlsam und ohne Panik.',
  'aiNannyMockReply':
      'Verstanden ❤️ In der nächsten Phase antworte ich mit echten Einträgen Ihres Babys.',
  'aiNannyInputHint': 'Frage eingeben…',
  'aiNannyThinking': 'Die KI-Babysitterin denkt nach…',
  'aiNannyDisclaimer':
      'Nur zur Information. Ersetzt keine medizinische Beratung.',
  'aiNannyPremiumTitle': 'KI-Babysitterin 24/7 für Sie',
  'aiNannyPremiumBody':
      'Premium: intelligenter Chat mit Baby-Kontext, bis zu 50 Nachrichten pro Tag.',
  'aiNannyPremiumCta': 'Premium freischalten',
  'aiNannyBenefitSmart': 'Intelligente Antworten',
  'aiNannyBenefitPersonal': 'Persönliche Tipps',
  'aiNannyBenefitAlerts': 'Vorhersage-Hinweise (demnächst)',
  'aiNannyBenefitRoutines': 'Persönliche Routinen',
  'aiNannyBenefitContent': 'KI-generierte Inhalte',
  'aiNannyBenefitAudioSoon': 'Demnächst: Sprachantworten',
  'aiNannyAskBelow': 'Stellen Sie unten Ihre erste Frage.',
  'aiNannyNoBaby': 'Legen Sie ein Baby an, um Antworten zu personalisieren.',
  'aiNannyRemainingToday': 'Nachrichten heute übrig: {n}',
  'aiNannyDailyLimitMessage':
      'Tageslimit der KI-Babysitterin erreicht. Kommen Sie morgen wieder.',
  'aiNannyCallFailed':
      'Antwort gerade nicht möglich. Bitte gleich erneut versuchen.',
  'aiNannyProfileButton': 'KI-Profil',
  'aiNannySignInRequired': 'Melden Sie sich an, um die KI-Babysitterin zu nutzen.',
  'aiVoiceRecording': 'Aufnahme… {s}s (max. 20)',
  'aiVoiceProcessing': 'Transkribieren und auswerten…',
  'aiVoiceUnderstood': 'Verstanden: {text}',
  'aiVoiceConfirmTitle': 'Das speichern?',
  'aiVoiceConfirm': 'Bestätigen',
  'aiVoiceMicDenied':
      'Mikrofonzugriff nötig. Bitte in den Geräteeinstellungen aktivieren.',
  'aiVoiceMicWebUnavailable':
      'Spracheingabe ist in den Android- und iOS-Apps verfügbar.',
  'aiVoiceSavedOk': 'Eintrag gespeichert.',
  'aiVoiceSleepStarted':
      'Schlaf gestartet — Schlaf-Bildschirm oder „ist aufgewacht“ sagen.',
  'aiVoiceSleepEnded': 'Schlaf gespeichert.',
  'aiVoiceRecordFailed': 'Audio konnte nicht verarbeitet werden. Erneut versuchen.',
  'aiVoiceNotARegisterTitle': 'Das klingt wie eine Frage, kein Eintrag.',
  'aiVoiceRegisterHint':
      'Zum Speichern per Sprache z. B. „1 Stunde geschlafen“, „3,5 kg“ oder „120 ml“. Bei Fragen spricht die KI-Babysitterin im Chat.',
  'aiVoiceHoldMicHint': 'Mikrofon gedrückt halten, um mit der KI zu sprechen.',
  'aiVoiceReleaseHint': 'Loslassen zum Senden…',
  'aiVoiceTapMicHint': 'Mikrofon tippen zum Aufnehmen',
  'aiVoiceTapStopHint': 'Erneut tippen, um Audio zu senden',
  'aiVoiceRecordingHint': 'Aufnahme… ■ tippen zum Senden',
  'aiVoiceListenReply': 'Antwort anhören',
  'aiTtsPreparing': 'Audio wird vorbereitet...',
  'aiTtsPause': 'Pause',
  'aiTtsResume': 'Fortsetzen',
  'aiTtsRetry': 'Erneut versuchen',
  'aiVoiceAskAiInstead': 'KI-Babysitterin fragen',
  'aiVoiceHealthFieldsHint':
      'Felder ausfüllen und Bestätigen, um unter Gesundheit zu speichern.',
  'aiVoiceHealthTempLabel': 'Temperatur (°C)',
  'aiVoiceHealthVaccineNameLabel': 'Impfstoffname',
  'aiVoiceHealthVaccineDoseLabel': 'Dosis (optional)',
  'aiVoiceHealthVaccineNameRequired': 'Bitte Impfstoffname angeben.',
  'aiBabyHistoryTitle': 'Baby-Verlauf',
  'aiBabyHistorySubtitle':
      'Wichtige Merkmale und Routine teilen, damit die KI-Babysitterin personalisiert antwortet.',
  'aiBabyHistoryFieldLabel': 'Wichtiger Verlauf für die KI',
  'aiBabyHistoryPlaceholder':
      'z. B. Frühgeburt, Reflux, Stillen, häufiges Aufwachen, Milchnahrung, Allergien, pädiatrische Hinweise.',
  'aiBabyHistoryDisclaimer':
      'Hilft der KI bei besseren Antworten — kein Ersatz für medizinischen Rat.',
  'aiBabyHistorySave': 'Verlauf speichern',
  'aiBabyHistoryClear': 'Verlauf löschen',
  'aiBabyHistorySaved': 'Verlauf gespeichert',
  'aiBabyHistoryCleared': 'Verlauf gelöscht',
  'aiBabyHistoryClearConfirmTitle': 'Verlauf löschen?',
  'aiBabyHistoryClearConfirmBody':
      'Die KI-Babysitterin nutzt diese Infos erst wieder, wenn Sie sie neu ausfüllen.',
  'aiBabyHistoryLinkSubtitle': 'Antworten der KI-Babysitterin personalisieren',
  'aiBabyHistoryCharCount': '{current} / {max} Zeichen',
  'settingsAiBabyHistory': 'Baby-Verlauf für die KI-Babysitterin',
  'familyTabTree': 'Familie',
  'familyTabHoroscope': 'Horoskop',
  'familyTabAiHistory': 'Verlauf',
  'familyHoroscopeDate': 'Horoskop vom {date}',
  'familyHoroscopeGenerateToday': 'Horoskop für heute erstellen',
  'familyHoroscopeRefresh': 'Horoskop aktualisieren',
  'familyHoroscopeMother': 'Horoskop der Mama',
  'familyHoroscopeFather': 'Horoskop des Papas',
  'familyHoroscopeBaby': 'Horoskop des Babys',
  'familyHoroscopeFamilyEnergy': 'Familienenergie heute',
  'familyHoroscopeDailyAdvice': 'Tipp des Tages für die Familie',
  'familyHoroscopeDisclaimer':
      'KI-Inhalt zur Familienreflexion und Unterhaltung. Ersetzt keine professionelle Beratung.',
  'familyHoroscopeRegisterFather':
      'Papa erfassen, um sein Horoskop in die Familienlesung einzubeziehen.',
  'familyHoroscopePremiumTitle': 'Familien-Horoskop mit KI',
  'familyHoroscopePremiumBody':
      'Tägliche liebevolle Lesungen für Mama, Papa und Baby nach den Sternzeichen.',
  'familyHoroscopeErrorGeneric':
      'Horoskop konnte jetzt nicht erstellt werden. Bitte erneut versuchen.',
  'familyHoroscopeErrorNotFound':
      'Horoskop-Dienst nicht verfügbar. App aktualisieren und erneut versuchen.',
  'familyHoroscopeErrorUnauthenticated': 'Anmelden, um das Horoskop zu erstellen.',
  'familyHoroscopeErrorPermission':
      'Vollständiges Familien-Horoskop mit Premium verfügbar.',
  'familyHoroscopeErrorPrecondition':
      'Geburtsdaten unter Familie eintragen, um das Horoskop zu erstellen.',
  'familyHoroscopeErrorExhausted':
      'Vorübergehendes Limit erreicht. Später erneut versuchen.',
};

const Map<String, String> _it = {
  'growthCurveSectionTitle': 'Curva di crescita (altezza)',
  'growthCurveSectionTitleWeight': 'Curva di crescita (peso)',
  'growthCurveDisclaimer':
      'Queste informazioni sono indicative e non sostituiscono una valutazione medica.',
  'growthCurveLegendMin': 'Minimo salutare',
  'growthCurveLegendAvg': 'Media salutare',
  'growthCurveLegendMax': 'Massimo salutare',
  'growthCurveLegendBaby': 'Evoluzione del bambino',
  'growthCurveAxisMonths': 'mesi',
  'growthCurveReferenceGirls': 'Riferimento — bambine (0–4 anni)',
  'growthCurveReferenceBoys': 'Riferimento — bambini (0–4 anni)',
  'growthCurveSexHint':
      'Indica il sesso del bambino nel profilo per la curva corretta. Riferimento per bambine.',
  'aiNannyNavLabel': 'IA Tata',
  'aiNannyPhase1Hint':
      'La chat arriverà nella prossima fase. Il collegamento è già nel menu.',
  'aiNannyTitle': 'IA Tata 24h con te',
  'aiNannySubtitle':
      'Risposte intelligenti e consigli personalizzati per la routine del tuo bambino.',
  'aiNannyWelcomeMessage':
      'Ciao! Sono l’IA Tata di FaceBaby ❤️ Chiedi su routine, sonno o alimentazione — con dolcezza.',
  'aiNannyMockReply':
      'Capito ❤️ Nella prossima fase risponderò con i registri reali del bambino.',
  'aiNannyInputHint': 'Scrivi la tua domanda…',
  'aiNannyThinking': 'L’IA Tata sta pensando con cura…',
  'aiNannyDisclaimer':
      'Solo a scopo informativo. Non sostituisce un parere medico.',
  'aiNannyPremiumTitle': 'IA Tata 24h con te',
  'aiNannyPremiumBody':
      'Funzione Premium: chat intelligente con contesto del bambino, fino a 50 messaggi al giorno.',
  'aiNannyPremiumCta': 'Sblocca Premium',
  'aiNannyBenefitSmart': 'Risposte intelligenti',
  'aiNannyBenefitPersonal': 'Consigli personalizzati',
  'aiNannyBenefitAlerts': 'Avvisi predittivi (in arrivo)',
  'aiNannyBenefitRoutines': 'Routine personalizzate',
  'aiNannyBenefitContent': 'Contenuti generati dall’IA',
  'aiNannyBenefitAudioSoon': 'Presto: risposte vocali',
  'aiNannyAskBelow': 'Fai la prima domanda qui sotto.',
  'aiNannyNoBaby': 'Registra un bambino per personalizzare le risposte.',
  'aiNannyRemainingToday': 'Messaggi rimasti oggi: {n}',
  'aiNannyDailyLimitMessage':
      'Hai raggiunto il limite giornaliero dell’IA Tata. Torna domani.',
  'aiNannyCallFailed':
      'Non ho potuto rispondere ora. Riprova tra poco.',
  'aiNannyProfileButton': 'Profilo IA',
  'aiNannySignInRequired': 'Accedi per usare l’IA Tata.',
  'aiVoiceRecording': 'Registrazione… {s}s (max 20)',
  'aiVoiceProcessing': 'Trascrizione e interpretazione…',
  'aiVoiceUnderstood': 'Capito: {text}',
  'aiVoiceConfirmTitle': 'Registrare questo?',
  'aiVoiceConfirm': 'Conferma',
  'aiVoiceMicDenied':
      'Serve l’accesso al microfono. Attivalo nelle impostazioni del dispositivo.',
  'aiVoiceMicWebUnavailable':
      'La registrazione vocale è disponibile sulle app Android e iOS.',
  'aiVoiceSavedOk': 'Registro salvato.',
  'aiVoiceSleepStarted':
      'Sonno avviato — schermata Sonno o di’ «è sveglio» quando finisce.',
  'aiVoiceSleepEnded': 'Sonno registrato.',
  'aiVoiceRecordFailed': 'Impossibile elaborare l’audio. Riprova.',
  'aiVoiceNotARegisterTitle': 'Sembra una domanda, non un registro.',
  'aiVoiceRegisterHint':
      'Per registrare a voce, ad es. «ha dormito 1 ora», «pesa 3,5 kg» o «120 ml». Per domande, parla — l’IA Tata risponde in chat.',
  'aiVoiceHoldMicHint': 'Tieni premuto il microfono per parlare con l’IA Tata.',
  'aiVoiceReleaseHint': 'Rilascia per inviare…',
  'aiVoiceTapMicHint': 'Tocca il microfono per registrare',
  'aiVoiceTapStopHint': 'Tocca di nuovo per inviare l’audio',
  'aiVoiceRecordingHint': 'Registrazione… tocca ■ per inviare',
  'aiVoiceListenReply': 'Ascolta risposta',
  'aiTtsPreparing': 'Preparazione audio...',
  'aiTtsPause': 'Pausa',
  'aiTtsResume': 'Riprendi',
  'aiTtsRetry': 'Riprova',
  'aiVoiceAskAiInstead': 'Chiedi all’IA Tata',
  'aiVoiceHealthFieldsHint':
      'Compila i campi e tocca Conferma per salvare in Salute.',
  'aiVoiceHealthTempLabel': 'Temperatura (°C)',
  'aiVoiceHealthVaccineNameLabel': 'Nome vaccino',
  'aiVoiceHealthVaccineDoseLabel': 'Dose (opzionale)',
  'aiVoiceHealthVaccineNameRequired': 'Inserisci il nome del vaccino.',
  'aiBabyHistoryTitle': 'Storico del bambino',
  'aiBabyHistorySubtitle':
      'Racconta tratti importanti del bambino e della routine per personalizzare l’IA Tata.',
  'aiBabyHistoryFieldLabel': 'Storico importante per l’IA',
  'aiBabyHistoryPlaceholder':
      'Es.: prematurità, reflusso, allattamento, risvegli notturni, latte artificiale, allergie, indicazioni pediatriche.',
  'aiBabyHistoryDisclaimer':
      'Aiuta l’IA a rispondere meglio ma non sostituisce un parere medico.',
  'aiBabyHistorySave': 'Salva storico',
  'aiBabyHistoryClear': 'Cancella storico',
  'aiBabyHistorySaved': 'Storico salvato',
  'aiBabyHistoryCleared': 'Storico cancellato',
  'aiBabyHistoryClearConfirmTitle': 'Cancellare lo storico?',
  'aiBabyHistoryClearConfirmBody':
      'L’IA Tata non userà più queste informazioni finché non le compili di nuovo.',
  'aiBabyHistoryLinkSubtitle': 'Personalizza le risposte dell’IA Tata',
  'aiBabyHistoryCharCount': '{current} / {max} caratteri',
  'settingsAiBabyHistory': 'Storico del bambino per l’IA Tata',
  'familyTabTree': 'Famiglia',
  'familyTabHoroscope': 'Oroscopo',
  'familyTabAiHistory': 'Storico',
  'familyHoroscopeDate': 'Oroscopo del {date}',
  'familyHoroscopeGenerateToday': 'Genera oroscopo di oggi',
  'familyHoroscopeRefresh': 'Aggiorna oroscopo',
  'familyHoroscopeMother': 'Oroscopo della mamma',
  'familyHoroscopeFather': 'Oroscopo del papà',
  'familyHoroscopeBaby': 'Oroscopo del bambino',
  'familyHoroscopeFamilyEnergy': 'Energia familiare oggi',
  'familyHoroscopeDailyAdvice': 'Consiglio del giorno per la famiglia',
  'familyHoroscopeDisclaimer':
      'Contenuto IA per riflessione e intrattenimento familiare. Non sostituisce un parere professionale.',
  'familyHoroscopeRegisterFather':
      'Registra il papà per includere il suo oroscopo nella lettura familiare.',
  'familyHoroscopePremiumTitle': 'Oroscopo familiare con IA',
  'familyHoroscopePremiumBody':
      'Sblocca letture quotidiane per mamma, papà e bambino in base ai segni.',
  'familyHoroscopeErrorGeneric':
      'Impossibile generare l’oroscopo ora. Riprova.',
  'familyHoroscopeErrorNotFound':
      'Servizio oroscopo non disponibile. Aggiorna l’app e riprova.',
  'familyHoroscopeErrorUnauthenticated': 'Accedi per generare l’oroscopo.',
  'familyHoroscopeErrorPermission':
      'Oroscopo familiare completo disponibile con Premium.',
  'familyHoroscopeErrorPrecondition':
      'Registra le date di nascita in Famiglia per generare l’oroscopo.',
  'familyHoroscopeErrorExhausted':
      'Limite temporaneo raggiunto. Riprova più tardi.',
};
