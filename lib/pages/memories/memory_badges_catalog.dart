import 'package:flutter/material.dart';
import '../../models/memory_badge.dart';

class MemoryBadgesCatalog {
  /// Pastéis com matizes bem separados (vermelho, laranja, azul…), rotacionando na grelha.
  static const _pastels = <Color>[
    Color(0xFFFFD6D6), // vermelho
    Color(0xFFFFE0C2), // laranja
    Color(0xFFFFF0B8), // amarelo
    Color(0xFFC9F0CD), // verde
    Color(0xFFB8EBE8), // turquesa / ciano
    Color(0xFFC6E2FF), // azul
    Color(0xFFD2DCFF), // anil
    Color(0xFFE5D4FF), // violeta
    Color(0xFFFFD6EC), // rosa / magenta claro
    Color(0xFFFFECE0), // pêssego
  ];

  /// Poucos destaques fixos (cores fortes e distintas).
  static const _fixedPastels = <String, Color>{
    'arrived_home': Color(0xFFFFD0D0),
    'first_smile': Color(0xFFFFF4B0),
  };

  static Color pastelFor(String id, int sortIndex) {
    return _fixedPastels[id] ?? _pastels[sortIndex % _pastels.length];
  }

  /// Resolve badge metadata by stable id (for localized titles via [S.memoryBadgeTitle]).
  static MemoryBadge? findBadgeById(String id) {
    for (final b in all()) {
      if (b.id == id) return b;
    }
    return null;
  }

  static List<MemoryBadge> all() {
    final out = <MemoryBadge>[];
    var sort = 0;

    void addMoment(String id, String title, IconData icon) {
      out.add(
        MemoryBadge(
          id: id,
          title: title,
          category: 'moment',
          iconName: id,
          icon: icon,
          defaultColor: pastelFor(id, sort),
          sortOrder: sort++,
        ),
      );
    }

    // BADGES DE MOMENTOS IMPORTANTES (50)
    addMoment('arrived_home', 'Cheguei em casa', Icons.home_rounded);
    addMoment('first_smile', 'Primeiro sorriso', Icons.sentiment_satisfied_alt_rounded);
    addMoment('first_feeding', 'Primeira Amamentação', Icons.local_drink_rounded);
    addMoment('sleeping', 'Dormindo', Icons.nightlight_round);
    addMoment('bath_time', 'Hora do banho', Icons.bathtub_rounded);
    addMoment('going_out', 'Indo passear', Icons.directions_walk_rounded);
    addMoment('first_laugh', 'Primeira risada', Icons.mood_rounded);
    addMoment('found_hands', 'Achei minhas mãos', Icons.waving_hand_rounded);
    addMoment('lifted_head', 'Levantei a cabeça', Icons.child_care_rounded);
    addMoment('at_park', 'No parque', Icons.park_rounded);
    addMoment('first_hug', 'Primeiro abraço', Icons.favorite_rounded);
    addMoment('first_foods', 'Primeiros alimentos', Icons.restaurant_rounded);
    addMoment('first_bath', 'Primeiro banho', Icons.shower_rounded);
    addMoment('crib_sleep', 'Primeiro soninho no berço', Icons.crib_rounded);
    addMoment('first_diaper_change', 'Primeira troca de fralda', Icons.baby_changing_station_rounded);
    addMoment('first_burp', 'Primeiro arroto', Icons.air_rounded);
    addMoment('first_mom_cuddle', 'Primeiro colo da mamãe', Icons.woman_rounded);
    addMoment('first_dad_cuddle', 'Primeiro colo do papai', Icons.man_rounded);
    addMoment('first_pediatrician', 'Primeira visita ao pediatra', Icons.medical_services_rounded);
    addMoment('first_vaccine', 'Primeira vacina', Icons.vaccines_rounded);
    addMoment('first_car_ride', 'Primeiro passeio de carro', Icons.directions_car_rounded);
    addMoment('first_stroller_ride', 'Primeiro passeio de carrinho', Icons.stroller_rounded);
    addMoment('favorite_toy', 'Primeiro brinquedo favorito', Icons.toys_rounded);
    addMoment('first_night_home', 'Primeira noite em casa', Icons.bed_rounded);
    addMoment('first_giggle', 'Primeira gargalhada', Icons.emoji_emotions_rounded);
    addMoment('sun_bath', 'Primeiro banho de sol', Icons.wb_sunny_rounded);
    addMoment('first_christmas', 'Primeiro Natal', Icons.celebration_rounded);
    addMoment('first_new_year', 'Primeiro Ano Novo', Icons.auto_awesome_rounded);
    addMoment('first_mothers_day', 'Primeiro Dia das Mães', Icons.favorite_border_rounded);
    addMoment('first_fathers_day', 'Primeiro Dia dos Pais', Icons.family_restroom_rounded);
    addMoment('first_tooth', 'Primeiro dente', Icons.medical_information_rounded);
    addMoment('first_puree', 'Primeira papinha', Icons.soup_kitchen_rounded);
    addMoment('sat_alone', 'Sentou sozinha', Icons.airline_seat_recline_normal_rounded);
    addMoment('crawled', 'Engatinhou', Icons.child_friendly_rounded);
    addMoment('stood_up', 'Ficou em pé', Icons.accessibility_new_rounded);
    addMoment('first_steps', 'Primeiros passos', Icons.directions_walk_rounded);
    addMoment('first_word', 'Primeira palavra', Icons.chat_bubble_rounded);
    addMoment('favorite_song', 'Primeira música favorita', Icons.music_note_rounded);
    addMoment('first_trip', 'Primeira viagem', Icons.luggage_rounded);
    addMoment('family_birthday', 'Primeiro aniversário em família', Icons.cake_rounded);
    addMoment('first_beach', 'Primeira praia', Icons.beach_access_rounded);
    addMoment('first_pool', 'Primeira piscina', Icons.pool_rounded);
    addMoment('first_haircut', 'Primeiro corte de cabelo', Icons.content_cut_rounded);
    addMoment('first_shoes', 'Primeiro sapatinho', Icons.hiking_rounded);
    addMoment('special_outfit', 'Roupinha especial', Icons.checkroom_rounded);
    addMoment('first_friend', 'Primeiro amigo', Icons.diversity_1_rounded);
    addMoment('first_party', 'Primeira festa', Icons.celebration_rounded);
    addMoment('first_cartoon', 'Primeiro desenho', Icons.smart_display_rounded);
    addMoment('first_book', 'Primeiro livro', Icons.menu_book_rounded);
    addMoment('special_free', 'Momento especial livre', Icons.auto_awesome_rounded);

    // MESVERSÁRIOS (1..23)
    for (var m = 1; m <= 23; m++) {
      final id = 'month_$m';
      out.add(
        MemoryBadge(
          id: id,
          title: '$m mês${m == 1 ? '' : 'es'}',
          category: 'monthly',
          iconName: id,
          icon: null,
          defaultColor: pastelFor(id, sort),
          sortOrder: sort++,
          isMonthlyBadge: true,
          monthNumber: m,
        ),
      );
    }

    // ANIVERSÁRIOS (1 e 2 anos)
    for (var y = 1; y <= 2; y++) {
      final id = 'birthday_$y';
      out.add(
        MemoryBadge(
          id: id,
          title: '$y ano${y == 1 ? '' : 's'}',
          category: 'birthday',
          iconName: id,
          icon: Icons.cake_rounded,
          defaultColor: pastelFor(id, sort),
          sortOrder: sort++,
          yearNumber: y,
        ),
      );
    }

    return out;
  }
}

