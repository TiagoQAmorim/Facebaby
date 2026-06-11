import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_summary.dart';
import 'health_calendar_events.dart';
import 'diaper_events.dart';
import 'feeding_events.dart';
import 'sleep_events.dart';
import 'measurement_units_prefs.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'facebaby.db';
  static const _dbVersion = 35;

  Database? _db;
  SharedPreferences? _prefs;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    if (kIsWeb) {
      // Web fallback: we do not use sqflite on web due to worker returning null in some environments.
      // Any method that needs persistence should use SharedPreferences-based storage instead.
      throw StateError('Database is not available on web fallback');
    }
    final created = await _open();
    _db = created;
    return created;
  }

  Future<Database> _open() async {
    final String path;
    if (kIsWeb) {
      // On web, getDatabasesPath() can be null. Using a simple file name works with sqflite_common_ffi_web.
      path = _dbName;
    } else {
      final dbDir = await getDatabasesPath();
      path = p.join(dbDir, _dbName);
    }

    if (!kIsWeb) {
      try {
        final f = File(path);
        debugPrint(
            'SQLite open path=$path exists=${f.existsSync()} bytes=${f.existsSync() ? f.lengthSync() : 0}');
      } catch (e) {
        debugPrint('SQLite open path=$path (stat failed: $e)');
      }
    }

    try {
      final db = await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: (db) async {
          // Enforce foreign keys so babies are tied to mothers.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          debugPrint('SQLite onCreate version=$version path=$path');
          await db.execute('''
CREATE TABLE mothers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT,
  birth_date TEXT,
  height_cm REAL,
  father_height_cm REAL,
  father_name TEXT,
  father_birth_date TEXT,
  father_photo_b64 TEXT,
  father_photo_url TEXT,
  register_father INTEGER,
  show_family_christian INTEGER NOT NULL DEFAULT 0,
  show_family_horoscope INTEGER NOT NULL DEFAULT 1,
  show_family_spiritist INTEGER NOT NULL DEFAULT 0,
  show_family_jewish INTEGER NOT NULL DEFAULT 0,
  photo_b64 TEXT,
  photo_url TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL
)
''');

          await db.execute('''
CREATE TABLE babies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mother_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  sex TEXT,
  birth_date TEXT,
  zodiac_sign TEXT,
  weight_kg REAL,
  height_cm REAL,
  birth_weight_kg REAL,
  birth_height_cm REAL,
  first_baby INTEGER,
  onboarding_concerns_json TEXT,
  onboarding_goals_json TEXT,
  photo_b64 TEXT,
  photo_url TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (mother_id) REFERENCES mothers(id) ON DELETE CASCADE
)
''');

          await db.execute(
              'CREATE INDEX idx_babies_mother_id ON babies(mother_id)');

          await db.execute('''
CREATE TABLE auth_tokens (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  access_token TEXT,
  refresh_token TEXT,
  expires_at TEXT,
  created_at TEXT NOT NULL
)
''');

          await db.execute('''
CREATE TABLE memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  emoji TEXT,
  happened_at TEXT,
  photo_path TEXT,
  day_key TEXT,
  photo_b64 TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  badge_id TEXT,
  memory_date TEXT,
  baby_age_at_moment TEXT,
  weight_at_moment REAL,
  height_at_moment REAL,
  mood_at_moment TEXT,
  mother_notes TEXT,
  is_favorite INTEGER DEFAULT 0,
  is_public INTEGER DEFAULT 0,
  public_enabled_at TEXT,
  public_disabled_at TEXT,
  eligible_weekly_photo INTEGER DEFAULT 0,
  weekly_photo_winner INTEGER DEFAULT 0,
  weekly_photo_week_id TEXT,
  show_baby_name_public INTEGER DEFAULT 1,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_memories_baby_id ON memories(baby_id)');
          await db.execute(
              'CREATE INDEX idx_memories_day_key ON memories(baby_id, day_key)');
          await db.execute(
              'CREATE INDEX idx_memories_badge ON memories(baby_id, badge_id)');

          await db.execute('''
CREATE TABLE memory_badge_tombstones (
  baby_id INTEGER NOT NULL,
  badge_id TEXT NOT NULL,
  baby_cloud_id TEXT,
  deleted_at TEXT NOT NULL,
  PRIMARY KEY (baby_id, badge_id),
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_memory_tombstones_cloud ON memory_badge_tombstones(baby_cloud_id, badge_id)');

          await db.execute('''
CREATE TABLE vaccines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  dose TEXT,
  applied_at TEXT,
  next_due_at TEXT,
  notes TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_vaccines_baby_id ON vaccines(baby_id)');
          await db.execute(
              'CREATE INDEX idx_vaccines_applied_at ON vaccines(applied_at)');

          await db.execute('''
CREATE TABLE consultations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  notes TEXT,
  phone TEXT,
  address TEXT,
  occurred_at TEXT NOT NULL,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_consultations_baby_occurred ON consultations(baby_id, occurred_at)');

          await db.execute('''
CREATE TABLE symptom_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  occurred_at TEXT NOT NULL,
  medication_note TEXT,
  fever INTEGER NOT NULL DEFAULT 0,
  temp_celsius REAL,
  crying INTEGER NOT NULL DEFAULT 0,
  pain INTEGER NOT NULL DEFAULT 0,
  colic INTEGER NOT NULL DEFAULT 0,
  reflux INTEGER NOT NULL DEFAULT 0,
  other_note TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_symptom_reports_baby_occurred ON symptom_reports(baby_id, occurred_at)');

          await db.execute('''
CREATE TABLE feedings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_sec INTEGER NOT NULL,
  side TEXT,
  type TEXT,
  quantity_ml REAL,
  note TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_feedings_baby_id ON feedings(baby_id)');
          await db.execute(
              'CREATE INDEX idx_feedings_started_at ON feedings(started_at)');

          await db.execute('''
CREATE TABLE diapers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  changed_at TEXT NOT NULL,
  kind TEXT NOT NULL, -- 'pee' | 'poo' | 'both'
  note TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db
              .execute('CREATE INDEX idx_diapers_baby_id ON diapers(baby_id)');
          await db.execute(
              'CREATE INDEX idx_diapers_changed_at ON diapers(changed_at)');

          await db.execute('''
CREATE TABLE growth_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  kind TEXT NOT NULL, -- 'weight' | 'height' | 'head'
  value REAL NOT NULL,
  measured_at TEXT NOT NULL,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_growth_records_baby_id ON growth_records(baby_id)');
          await db.execute(
              'CREATE INDEX idx_growth_records_kind_measured_at ON growth_records(kind, measured_at)');

          await db.execute('''
CREATE TABLE sleep_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_sec INTEGER NOT NULL,
  quality TEXT,
  note TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_sleep_records_baby_id ON sleep_records(baby_id)');
          await db.execute(
              'CREATE INDEX idx_sleep_records_started_at ON sleep_records(started_at)');

          await db.execute('''
CREATE TABLE daily_journals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  day_key TEXT NOT NULL,
  text TEXT,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (baby_id, day_key),
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_daily_journals_baby_day ON daily_journals(baby_id, day_key)');

          await db.execute('''
CREATE TABLE notification_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT,
  notif_id INTEGER,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  payload TEXT,
  kind TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  cloud_id TEXT,
  created_at TEXT NOT NULL
)
''');
          await db.execute(
              'CREATE INDEX idx_notification_log_occurred ON notification_log(occurred_at)');
          await db.execute(
              'CREATE INDEX idx_notification_log_uid_occurred ON notification_log(uid, occurred_at)');

          await db.execute('''
CREATE TABLE daily_summary_snapshots (
  baby_id INTEGER NOT NULL,
  day_key TEXT NOT NULL,
  feedings INTEGER NOT NULL,
  feeding_minutes_total INTEGER NOT NULL,
  diapers INTEGER NOT NULL,
  diaper_pee INTEGER NOT NULL,
  diaper_poo INTEGER NOT NULL,
  sleep_sessions INTEGER NOT NULL,
  sleep_total_sec INTEGER NOT NULL,
  weight_label TEXT NOT NULL,
  cloud_id TEXT,
  created_at TEXT NOT NULL,
  PRIMARY KEY (baby_id, day_key),
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          await db.execute(
              'CREATE INDEX idx_daily_summary_snapshots_day ON daily_summary_snapshots(day_key)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('SQLite onUpgrade $oldVersion->$newVersion path=$path');
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE babies ADD COLUMN zodiac_sign TEXT');

            await db.execute('''
CREATE TABLE IF NOT EXISTS auth_tokens (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  access_token TEXT,
  refresh_token TEXT,
  expires_at TEXT,
  created_at TEXT NOT NULL
)
''');

            await db.execute('''
CREATE TABLE IF NOT EXISTS memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  emoji TEXT,
  happened_at TEXT,
  photo_path TEXT,
  day_key TEXT,
  photo_b64 TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_memories_baby_id ON memories(baby_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_memories_day_key ON memories(baby_id, day_key)');

            await db.execute('''
CREATE TABLE IF NOT EXISTS vaccines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  dose TEXT,
  applied_at TEXT,
  next_due_at TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_vaccines_baby_id ON vaccines(baby_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_vaccines_applied_at ON vaccines(applied_at)');
          }

          if (oldVersion < 3) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS feedings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_sec INTEGER NOT NULL,
  side TEXT,
  type TEXT,
  quantity_ml REAL,
  note TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_feedings_baby_id ON feedings(baby_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_feedings_started_at ON feedings(started_at)');
          }

          if (oldVersion < 4) {
            await db.execute('ALTER TABLE mothers ADD COLUMN photo_b64 TEXT');
            await db.execute('ALTER TABLE babies ADD COLUMN sex TEXT');
            await db.execute('ALTER TABLE babies ADD COLUMN photo_b64 TEXT');
          }

          if (oldVersion < 5) {
            await db.execute('ALTER TABLE mothers ADD COLUMN birth_date TEXT');
            await db.execute('ALTER TABLE mothers ADD COLUMN height_cm REAL');
            await db.execute(
                'ALTER TABLE mothers ADD COLUMN father_height_cm REAL');
          }

          if (oldVersion < 6) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS growth_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  kind TEXT NOT NULL,
  value REAL NOT NULL,
  measured_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_growth_records_baby_id ON growth_records(baby_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_growth_records_kind_measured_at ON growth_records(kind, measured_at)');
          }

          if (oldVersion < 7) {
            // Daily photo mural fields (kept optional for backward compatibility).
            await db.execute('ALTER TABLE memories ADD COLUMN day_key TEXT');
            await db.execute('ALTER TABLE memories ADD COLUMN photo_b64 TEXT');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_memories_day_key ON memories(baby_id, day_key)');
          }

          if (oldVersion < 8) {
            // Badge-driven memories (album grid). We keep legacy columns for compatibility.
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {
                // ignore if already exists
              }
            }

            await tryAdd('ALTER TABLE memories ADD COLUMN badge_id TEXT');
            await tryAdd('ALTER TABLE memories ADD COLUMN memory_date TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN baby_age_at_moment TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN weight_at_moment REAL');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN height_at_moment REAL');
            await tryAdd('ALTER TABLE memories ADD COLUMN mood_at_moment TEXT');
            await tryAdd('ALTER TABLE memories ADD COLUMN mother_notes TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN is_favorite INTEGER DEFAULT 0');

            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_memories_badge ON memories(baby_id, badge_id)');
          }

          if (oldVersion < 9) {
            // Instalações que abriram com versão 8: onCreate não incluía colunas do álbum por badge —
            // só existiam via onUpgrade, que não corre em BD nova. Garantimos colunas aqui.
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd('ALTER TABLE memories ADD COLUMN badge_id TEXT');
            await tryAdd('ALTER TABLE memories ADD COLUMN memory_date TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN baby_age_at_moment TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN weight_at_moment REAL');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN height_at_moment REAL');
            await tryAdd('ALTER TABLE memories ADD COLUMN mood_at_moment TEXT');
            await tryAdd('ALTER TABLE memories ADD COLUMN mother_notes TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN is_favorite INTEGER DEFAULT 0');

            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_memories_badge ON memories(baby_id, badge_id)');
          }

          if (oldVersion < 11) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS sleep_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_sec INTEGER NOT NULL,
  quality TEXT,
  note TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_sleep_records_baby_id ON sleep_records(baby_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_sleep_records_started_at ON sleep_records(started_at)');
          }

          if (oldVersion < 12) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS daily_journals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  day_key TEXT NOT NULL,
  text TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (baby_id, day_key),
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_daily_journals_baby_day ON daily_journals(baby_id, day_key)');
          }

          if (oldVersion < 13) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS notification_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT,
  notif_id INTEGER,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  payload TEXT,
  kind TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_notification_log_occurred ON notification_log(occurred_at)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_notification_log_uid_occurred ON notification_log(uid, occurred_at)');
          }

          if (oldVersion < 14) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS daily_summary_snapshots (
  baby_id INTEGER NOT NULL,
  day_key TEXT NOT NULL,
  feedings INTEGER NOT NULL,
  feeding_minutes_total INTEGER NOT NULL,
  diapers INTEGER NOT NULL,
  diaper_pee INTEGER NOT NULL,
  diaper_poo INTEGER NOT NULL,
  sleep_sessions INTEGER NOT NULL,
  sleep_total_sec INTEGER NOT NULL,
  weight_label TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (baby_id, day_key),
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_daily_summary_snapshots_day ON daily_summary_snapshots(day_key)');
          }

          if (oldVersion < 15) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS consultations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  notes TEXT,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_consultations_baby_occurred ON consultations(baby_id, occurred_at)');
          }

          if (oldVersion < 16) {
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd('ALTER TABLE consultations ADD COLUMN phone TEXT');
            await tryAdd('ALTER TABLE consultations ADD COLUMN address TEXT');
          }

          if (oldVersion < 17) {
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd('ALTER TABLE mothers ADD COLUMN cloud_id TEXT');
            await tryAdd('ALTER TABLE babies ADD COLUMN cloud_id TEXT');
          }

          if (oldVersion < 18) {
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd('ALTER TABLE memories ADD COLUMN cloud_id TEXT');
            await tryAdd('ALTER TABLE vaccines ADD COLUMN cloud_id TEXT');
            await tryAdd('ALTER TABLE consultations ADD COLUMN cloud_id TEXT');
          }

          if (oldVersion < 19) {
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd('ALTER TABLE feedings ADD COLUMN cloud_id TEXT');
            await tryAdd('ALTER TABLE diapers ADD COLUMN cloud_id TEXT');
            await tryAdd('ALTER TABLE sleep_records ADD COLUMN cloud_id TEXT');
            await tryAdd('ALTER TABLE growth_records ADD COLUMN cloud_id TEXT');
            await tryAdd('ALTER TABLE daily_journals ADD COLUMN cloud_id TEXT');
            await tryAdd(
                'ALTER TABLE notification_log ADD COLUMN cloud_id TEXT');
            await tryAdd(
                'ALTER TABLE daily_summary_snapshots ADD COLUMN cloud_id TEXT');
          }

          if (oldVersion < 20) {
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd('ALTER TABLE notification_log ADD COLUMN uid TEXT');
            try {
              await db.execute(
                  'CREATE INDEX IF NOT EXISTS idx_notification_log_uid_occurred ON notification_log(uid, occurred_at)');
            } catch (_) {}
          }

          if (oldVersion < 22) {
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd('ALTER TABLE mothers ADD COLUMN photo_url TEXT');
            await tryAdd('ALTER TABLE babies ADD COLUMN photo_url TEXT');
          }

          if (oldVersion < 23) {
            Future<void> tryAdd(String sql) async {
              try {
                await db.execute(sql);
              } catch (_) {}
            }

            await tryAdd(
                'ALTER TABLE memories ADD COLUMN is_public INTEGER DEFAULT 0');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN public_enabled_at TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN public_disabled_at TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN eligible_weekly_photo INTEGER DEFAULT 0');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN weekly_photo_winner INTEGER DEFAULT 0');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN weekly_photo_week_id TEXT');
            await tryAdd(
                'ALTER TABLE memories ADD COLUMN show_baby_name_public INTEGER DEFAULT 1');
          }

          if (oldVersion < 24) {
            try {
              await db.execute(
                "UPDATE notification_log SET uid = 'anonymous' WHERE uid IS NULL OR TRIM(COALESCE(uid, '')) = ''",
              );
            } catch (e) {
              debugPrint('migration v24 notification_log uid: $e');
            }
          }

          if (oldVersion < 25) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS symptom_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  occurred_at TEXT NOT NULL,
  medication_note TEXT,
  fever INTEGER NOT NULL DEFAULT 0,
  temp_celsius REAL,
  crying INTEGER NOT NULL DEFAULT 0,
  pain INTEGER NOT NULL DEFAULT 0,
  colic INTEGER NOT NULL DEFAULT 0,
  reflux INTEGER NOT NULL DEFAULT 0,
  other_note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_symptom_reports_baby_occurred ON symptom_reports(baby_id, occurred_at)');
          }

          if (oldVersion < 26) {
            try {
              await db.execute(
                  'ALTER TABLE symptom_reports ADD COLUMN cloud_id TEXT');
            } catch (e) {
              debugPrint('migration v26 symptom_reports.cloud_id: $e');
            }
          }

          if (oldVersion < 27) {
            try {
              await db.execute(
                  'ALTER TABLE mothers ADD COLUMN father_birth_date TEXT');
            } catch (e) {
              debugPrint('migration v27 mothers.father_birth_date: $e');
            }
          }

          if (oldVersion < 28) {
            try {
              await db
                  .execute('ALTER TABLE mothers ADD COLUMN father_name TEXT');
            } catch (e) {
              debugPrint('migration v28 mothers.father_name: $e');
            }
          }

          if (oldVersion < 29) {
            Future<void> tryAdd(String sql, String label) async {
              try {
                await db.execute(sql);
              } catch (e) {
                debugPrint('migration v29 $label: $e');
              }
            }

            await tryAdd(
                'ALTER TABLE mothers ADD COLUMN register_father INTEGER',
                'mothers.register_father');
            await tryAdd('ALTER TABLE babies ADD COLUMN first_baby INTEGER',
                'babies.first_baby');
            await tryAdd(
                'ALTER TABLE babies ADD COLUMN onboarding_concerns_json TEXT',
                'babies.onboarding_concerns_json');
            await tryAdd(
                'ALTER TABLE babies ADD COLUMN onboarding_goals_json TEXT',
                'babies.onboarding_goals_json');
          }

          if (oldVersion < 30) {
            Future<void> tryAdd30(String sql, String label) async {
              try {
                await db.execute(sql);
              } catch (e) {
                debugPrint('migration v30 $label: $e');
              }
            }

            await tryAdd30(
                'ALTER TABLE mothers ADD COLUMN father_photo_b64 TEXT',
                'mothers.father_photo_b64');
            await tryAdd30(
                'ALTER TABLE mothers ADD COLUMN father_photo_url TEXT',
                'mothers.father_photo_url');
          }

          if (oldVersion < 31) {
            Future<void> tryAdd31(String sql, String label) async {
              try {
                await db.execute(sql);
              } catch (e) {
                debugPrint('migration v31 $label: $e');
              }
            }

            await tryAdd31(
              'ALTER TABLE mothers ADD COLUMN show_family_christian INTEGER NOT NULL DEFAULT 0',
              'mothers.show_family_christian',
            );
            await tryAdd31(
              'ALTER TABLE mothers ADD COLUMN show_family_horoscope INTEGER NOT NULL DEFAULT 1',
              'mothers.show_family_horoscope',
            );
          }

          if (oldVersion < 32) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS memory_badge_tombstones (
  baby_id INTEGER NOT NULL,
  badge_id TEXT NOT NULL,
  deleted_at TEXT NOT NULL,
  PRIMARY KEY (baby_id, badge_id),
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
          }

          if (oldVersion < 33) {
            try {
              await db.execute(
                  'ALTER TABLE memory_badge_tombstones ADD COLUMN baby_cloud_id TEXT');
            } catch (e) {
              debugPrint('migration v33 memory_badge_tombstones.baby_cloud_id: $e');
            }
            try {
              await db.execute(
                  'CREATE INDEX IF NOT EXISTS idx_memory_tombstones_cloud ON memory_badge_tombstones(baby_cloud_id, badge_id)');
            } catch (e) {
              debugPrint('migration v33 idx_memory_tombstones_cloud: $e');
            }
          }

          if (oldVersion < 34) {
            Future<void> tryAdd34(String sql, String label) async {
              try {
                await db.execute(sql);
              } catch (e) {
                debugPrint('migration v34 $label: $e');
              }
            }

            await tryAdd34(
              'ALTER TABLE mothers ADD COLUMN show_family_spiritist INTEGER NOT NULL DEFAULT 0',
              'mothers.show_family_spiritist',
            );
            await tryAdd34(
              'ALTER TABLE mothers ADD COLUMN show_family_jewish INTEGER NOT NULL DEFAULT 0',
              'mothers.show_family_jewish',
            );
          }

          if (oldVersion < 35) {
            Future<void> tryAdd35(String sql, String label) async {
              try {
                await db.execute(sql);
              } catch (e) {
                debugPrint('migration v35 $label: $e');
              }
            }

            await tryAdd35(
              'ALTER TABLE babies ADD COLUMN birth_weight_kg REAL',
              'babies.birth_weight_kg',
            );
            await tryAdd35(
              'ALTER TABLE babies ADD COLUMN birth_height_cm REAL',
              'babies.birth_height_cm',
            );
            await db.execute(
              'UPDATE babies SET birth_weight_kg = weight_kg WHERE birth_weight_kg IS NULL AND weight_kg IS NOT NULL',
            );
            await db.execute(
              'UPDATE babies SET birth_height_cm = height_cm WHERE birth_height_cm IS NULL AND height_cm IS NOT NULL',
            );
          }

          if (oldVersion < 10) {
            await db.execute('''
CREATE TABLE IF NOT EXISTS diapers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  baby_id INTEGER NOT NULL,
  changed_at TEXT NOT NULL,
  kind TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (baby_id) REFERENCES babies(id) ON DELETE CASCADE
)
''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_diapers_baby_id ON diapers(baby_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_diapers_changed_at ON diapers(changed_at)');
          }
        },
      );

      return db;
    } catch (e) {
      rethrow;
    }
  }

  static DateTime? _parseLocalDt(String? iso) {
    final s = iso?.trim();
    if (s == null || s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    if (d == null) return null;
    return d.isUtc ? d.toLocal() : d;
  }

  Future<SharedPreferences> _webPrefs() async {
    final existing = _prefs;
    if (existing != null) return existing;
    final created = await SharedPreferences.getInstance();
    _prefs = created;
    return created;
  }

  /// Serializes web read–modify–write so concurrent calls cannot drop the last write.
  Future<void> _webPersistTail = Future<void>.value();

  Future<T> _webSerialized<T>(Future<T> Function() op) async {
    final gate = Completer<void>();
    final prev = _webPersistTail;
    _webPersistTail = gate.future;
    await prev;
    try {
      return await op();
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }

  Future<int> _webNextId(SharedPreferences prefs, String key) async {
    final idKey = 'facebaby_web_next_id_$key';
    final next = (prefs.getInt(idKey) ?? 1);
    final ok = await prefs.setInt(idKey, next + 1);
    if (kIsWeb && !ok) {
      throw StateError(
          'Falha ao gravar contador de IDs (armazenamento cheio ou indisponível).');
    }
    return next;
  }

  List<Map<String, Object?>> _webReadList(SharedPreferences prefs, String key) {
    final raw = prefs.getString('facebaby_web_$key');
    if (raw == null || raw.trim().isEmpty) return <Map<String, Object?>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, Object?>>[];
      return decoded
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (e) {
      throw StateError('Invalid stored JSON for facebaby_web_$key: $e');
    }
  }

  Future<void> _webWriteList(SharedPreferences prefs, String key,
      List<Map<String, Object?>> list) async {
    final encoded = jsonEncode(list);
    if (kIsWeb) {
      // localStorage ~5 MB por origem; o JSON das memórias inclui base64 de todas as fotos.
      const memoriesJsonSoftLimit = 1900000;
      if (key == 'memories' && encoded.length > memoriesJsonSoftLimit) {
        throw StateError(
          'O mural no browser ficou demasiado grande para guardar. Apague fotos antigas nas memórias ou use imagens mais pequenas.',
        );
      }
    }
    final ok = await prefs.setString('facebaby_web_$key', encoded);
    if (!ok) {
      throw StateError(
        'Falha ao gravar facebaby_web_$key (armazenamento cheio ou indisponível). '
        'No site, limite fotos grandes no mural ou liberte espaço do navegador.',
      );
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }

  /// Apaga o cache local (SQLite) e preferências relacionadas ao perfil atual.
  /// O Firestore continua sendo a fonte de verdade.
  Future<void> wipeLocalCache() async {
    if (kIsWeb) return;
    debugPrint('wipeLocalCache() called.\n${StackTrace.current}');
    await close();
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, _dbName);
    await deleteDatabase(path);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('current_baby_id');
  }

  // ---------------- Cloud (Firestore) re-hydration helpers ----------------

  /// Lê o `cloud_id` de uma linha local antes de apagar (para permitir delete na nuvem).
  Future<String?> getRowCloudId({
    required String table,
    required int id,
    required int babyId,
  }) async {
    if (kIsWeb) return null;
    final db = await database;
    final rows = await db.query(
      table,
      columns: const ['cloud_id'],
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final cid = (rows.first['cloud_id'] as String?)?.trim();
    return (cid == null || cid.isEmpty) ? null : cid;
  }

  static DateTime? _parseCloudIso(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is! String) return null;
    final dt = DateTime.tryParse(v);
    if (dt == null) return null;
    // Cloud timestamps might come as UTC (with 'Z'). Keep everything in local time
    // for stable calendar-day queries and UI.
    return dt.isUtc ? dt.toLocal() : dt;
  }

  /// Eventos Firestore usam [`type`] = `'feeding'` como discriminador; o subtipo fica em [`feeding_type`].
  /// Se gravarmos `'feeding'` no SQLite, o “Resumo de hoje” e as queries ignoram estas linhas.
  static String? _feedingSubtypeFromCloudEvent(Map<String, dynamic> data) {
    final ft = _nonEmptyTrimmed(data['feeding_type']);
    if (ft != null) return ft;
    final t = _nonEmptyTrimmed(data['type']);
    if (t == null) return null;
    if (t.toLowerCase() == 'feeding') return null;
    return t;
  }

  static double? _parseCloudDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  static bool? _parseCloudBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'sim') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'nao' || s == 'não') {
        return false;
      }
    }
    return null;
  }

  static String? _stringListJson(dynamic v) {
    if (v is List) {
      return jsonEncode(v.map((e) => '$e').toList(growable: false));
    }
    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return jsonEncode(decoded.map((e) => '$e').toList(growable: false));
        }
      } catch (_) {}
    }
    return null;
  }

  static String? _encodeStringList(List<String>? values) {
    final clean = values
        ?.map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (clean == null || clean.isEmpty) return null;
    return jsonEncode(clean);
  }

  /// Só atualiza foto local quando o mapa cloud traz string **não vazia** —
  /// caso contrário preservamos SQLite (Firestore pode trazer `photo_url: null`/"" com [containsKey]==true na serialização antiga ou merge parcial).
  static String? _nonEmptyTrimmed(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static String? _firstNonEmptyPhotoField(
      Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      if (!data.containsKey(k)) continue;
      final s = _nonEmptyTrimmed(data[k]);
      if (s != null) return s;
    }
    return null;
  }

  /// Evita que um perfil Firestore incompleto (campos null/"") apague dados já gravados no SQLite.
  static String _mergeMotherNameFromCloud(
      Map<String, dynamic> data, Map<String, Object?>? existing) {
    final fromCloud =
        _nonEmptyTrimmed(data['name']) ?? _nonEmptyTrimmed(data['displayName']);
    if (fromCloud != null) return fromCloud;
    final prev = _nonEmptyTrimmed(existing?['name'] as String?);
    if (prev != null) return prev;
    return 'Mãe';
  }

  static String? _mergeMotherPhoneFromCloud(
      Map<String, dynamic> data, Map<String, Object?>? existing) {
    for (final k in ['phone', 'phoneNumber']) {
      if (!data.containsKey(k)) continue;
      final s = _nonEmptyTrimmed(data[k]);
      if (s != null) return s;
    }
    return _nonEmptyTrimmed(existing?['phone'] as String?);
  }

  static DateTime? _mergeMotherBirthFromCloud(
      Map<String, dynamic> data, Map<String, Object?>? existing) {
    final fromCloud =
        _parseCloudIso(data['birth_date']) ?? _parseCloudIso(data['birthDate']);
    if (fromCloud != null) return fromCloud;
    return _parseCloudIso(existing?['birth_date'] as String?);
  }

  static double? _mergeMotherDoubleFromCloud(
    Map<String, dynamic> data,
    List<String> keys,
    Map<String, Object?>? existing,
    String sqliteColumn,
  ) {
    for (final k in keys) {
      if (!data.containsKey(k)) continue;
      final v = data[k];
      final parsed = _parseCloudDouble(v);
      if (parsed != null) return parsed;
    }
    final prev = existing?[sqliteColumn];
    if (prev is num) return prev.toDouble();
    return null;
  }

  Future<int> upsertMotherFromCloud({
    required String cloudId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) {
      // Web fallback uses prefs; cloud hydration is out of scope there.
      return 0;
    }
    final db = await database;
    final rows = await db.query('mothers',
        columns: ['id'], where: 'cloud_id = ?', whereArgs: [cloudId], limit: 1);
    final createdAt = DateTime.now().toIso8601String();
    final mergedPhotoUrl = _firstNonEmptyPhotoField(
        Map<String, dynamic>.from(data), ['photo_url', 'photoUrl']);
    final mergedFatherPhotoUrl = _firstNonEmptyPhotoField(
        Map<String, dynamic>.from(data),
        ['father_photo_url', 'fatherPhotoUrl']);

    Map<String, Object?>? existingRow;
    if (rows.isNotEmpty) {
      final full = await db.query(
        'mothers',
        where: 'id = ?',
        whereArgs: [(rows.first['id'] as num).toInt()],
        limit: 1,
      );
      existingRow = full.isEmpty ? null : full.first;
    }

    final name = _mergeMotherNameFromCloud(data, existingRow);
    final phone = _mergeMotherPhoneFromCloud(data, existingRow);
    final birth = _mergeMotherBirthFromCloud(data, existingRow);
    final fatherName =
        ((data['father_name'] ?? data['fatherName']) as String?)?.trim() ??
            (existingRow?['father_name'] as String?)?.trim();
    final fatherBirth = _parseCloudIso(data['father_birth_date']) ??
        _parseCloudIso(data['fatherBirthDate']) ??
        _parseCloudIso(existingRow?['father_birth_date'] as String?);
    final registerFather = _parseCloudBool(
          data['register_father'] ?? data['registerFather'],
        ) ??
        _parseCloudBool(existingRow?['register_father']);
    final height = rows.isEmpty
        ? _parseCloudDouble(data['height_cm'] ?? data['heightCm'])
        : _mergeMotherDoubleFromCloud(
            Map<String, dynamic>.from(data),
            ['height_cm', 'heightCm'],
            existingRow,
            'height_cm',
          );
    final fatherHeight = rows.isEmpty
        ? _parseCloudDouble(data['father_height_cm'] ?? data['fatherHeightCm'])
        : _mergeMotherDoubleFromCloud(
            Map<String, dynamic>.from(data),
            ['father_height_cm', 'fatherHeightCm'],
            existingRow,
            'father_height_cm',
          );
    final showChristian = _parseCloudBool(
          data['show_family_christian'] ?? data['showFamilyChristian'],
        ) ??
        _parseCloudBool(existingRow?['show_family_christian']) ??
        false;
    final showHoroscope = _parseCloudBool(
          data['show_family_horoscope'] ?? data['showFamilyHoroscope'],
        ) ??
        _parseCloudBool(existingRow?['show_family_horoscope']) ??
        true;
    final showSpiritist = _parseCloudBool(
          data['show_family_spiritist'] ?? data['showFamilySpiritist'],
        ) ??
        _parseCloudBool(existingRow?['show_family_spiritist']) ??
        false;
    final showJewish = _parseCloudBool(
          data['show_family_jewish'] ?? data['showFamilyJewish'],
        ) ??
        _parseCloudBool(existingRow?['show_family_jewish']) ??
        false;

    if (rows.isEmpty) {
      final id = await db.insert('mothers', {
        'name': name,
        'phone': (phone == null || phone.isEmpty) ? null : phone,
        'birth_date': birth?.toIso8601String(),
        'height_cm': height,
        'father_name':
            (fatherName == null || fatherName.isEmpty) ? null : fatherName,
        'father_height_cm': fatherHeight,
        'father_birth_date': fatherBirth?.toIso8601String(),
        'register_father':
            registerFather == null ? null : (registerFather ? 1 : 0),
        'show_family_christian': showChristian ? 1 : 0,
        'show_family_horoscope': showHoroscope ? 1 : 0,
        'show_family_spiritist': showSpiritist ? 1 : 0,
        'show_family_jewish': showJewish ? 1 : 0,
        'photo_b64': null,
        'photo_url': mergedPhotoUrl,
        'father_photo_url': mergedFatherPhotoUrl,
        'cloud_id': cloudId,
        'created_at': createdAt,
      });
      return id;
    }
    final id = (rows.first['id'] as num).toInt();
    final patch = <String, Object?>{
      'name': name,
      'phone': (phone == null || phone.isEmpty) ? null : phone,
      'birth_date': birth?.toIso8601String(),
      'height_cm': height,
      'father_name':
          (fatherName == null || fatherName.isEmpty) ? null : fatherName,
      'father_height_cm': fatherHeight,
      'father_birth_date': fatherBirth?.toIso8601String(),
      'register_father':
          registerFather == null ? null : (registerFather ? 1 : 0),
      'show_family_christian': showChristian ? 1 : 0,
      'show_family_horoscope': showHoroscope ? 1 : 0,
      'show_family_spiritist': showSpiritist ? 1 : 0,
      'show_family_jewish': showJewish ? 1 : 0,
      'cloud_id': cloudId,
    };
    if (mergedPhotoUrl != null) patch['photo_url'] = mergedPhotoUrl;
    if (mergedFatherPhotoUrl != null) {
      patch['father_photo_url'] = mergedFatherPhotoUrl;
    }
    await db.update(
      'mothers',
      patch,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> upsertBabyFromCloud({
    required String cloudId,
    required int localMotherId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return 0;
    final db = await database;
    final rows = await db.query('babies',
        columns: ['id'], where: 'cloud_id = ?', whereArgs: [cloudId], limit: 1);
    final name = (data['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return 0;
    final sex = ((data['sex'] as String?) ?? 'F').trim().isEmpty
        ? 'F'
        : ((data['sex'] as String?) ?? 'F').trim();
    final birth = _parseCloudIso(data['birth_date']);
    final zodiac = (data['zodiac_sign'] as String?)?.trim();
    final weight = _parseCloudDouble(data['weight_kg']);
    final height = _parseCloudDouble(data['height_cm']);
    final birthWeight = _parseCloudDouble(
      data['birth_weight_kg'] ?? data['birthWeightKg'],
    );
    final birthHeight = _parseCloudDouble(
      data['birth_height_cm'] ?? data['birthHeightCm'],
    );
    final firstBaby = _parseCloudBool(data['first_baby'] ?? data['firstBaby']);
    final concernsJson = _stringListJson(
        data['onboarding_concerns'] ?? data['onboardingConcerns']);
    final goalsJson =
        _stringListJson(data['onboarding_goals'] ?? data['onboardingGoals']);
    final createdAt = DateTime.now().toIso8601String();
    final mergedBabyPhotoUrl = _firstNonEmptyPhotoField(
        Map<String, dynamic>.from(data), ['photo_url', 'photoUrl']);

    if (rows.isEmpty) {
      final id = await db.insert('babies', {
        'mother_id': localMotherId,
        'name': name,
        'sex': sex,
        'birth_date': birth?.toIso8601String(),
        'zodiac_sign': (zodiac == null || zodiac.isEmpty) ? null : zodiac,
        'weight_kg': weight,
        'height_cm': height,
        'birth_weight_kg': birthWeight ?? weight,
        'birth_height_cm': birthHeight ?? height,
        'first_baby': firstBaby == null ? null : (firstBaby ? 1 : 0),
        'onboarding_concerns_json': concernsJson,
        'onboarding_goals_json': goalsJson,
        'photo_b64': null,
        'photo_url': mergedBabyPhotoUrl,
        'cloud_id': cloudId,
        'created_at': createdAt,
      });
      return id;
    }
    final id = (rows.first['id'] as num).toInt();
    final patch = <String, Object?>{
      'mother_id': localMotherId,
      'name': name,
      'sex': sex,
      'birth_date': birth?.toIso8601String(),
      'zodiac_sign': (zodiac == null || zodiac.isEmpty) ? null : zodiac,
      'weight_kg': weight,
      'height_cm': height,
      'first_baby': firstBaby == null ? null : (firstBaby ? 1 : 0),
      'onboarding_concerns_json': concernsJson,
      'onboarding_goals_json': goalsJson,
      'cloud_id': cloudId,
    };
    if (birthWeight != null) patch['birth_weight_kg'] = birthWeight;
    if (birthHeight != null) patch['birth_height_cm'] = birthHeight;
    if (mergedBabyPhotoUrl != null) patch['photo_url'] = mergedBabyPhotoUrl;
    await db.update(
      'babies',
      patch,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<void> upsertConsultationFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final cid = (data['id'] as String?)?.trim();
    if (cid == null || cid.isEmpty) return;
    final title = (data['title'] as String?)?.trim() ?? '';
    final occurredAt = _parseCloudIso(data['occurred_at']);
    if (title.isEmpty || occurredAt == null) return;

    final db = await database;
    final rows = await db.query(
      'consultations',
      columns: ['id'],
      where: 'baby_id = ? AND cloud_id = ?',
      whereArgs: [localBabyId, cid],
      limit: 1,
    );
    final notes = (data['notes'] as String?)?.trim();
    final phone = (data['phone'] as String?)?.trim();
    final address = (data['address'] as String?)?.trim();
    final createdAt = DateTime.now().toIso8601String();

    if (rows.isEmpty) {
      await db.insert('consultations', {
        'baby_id': localBabyId,
        'title': title,
        'notes': (notes == null || notes.isEmpty) ? null : notes,
        'phone': (phone == null || phone.isEmpty) ? null : phone,
        'address': (address == null || address.isEmpty) ? null : address,
        'occurred_at': occurredAt.toIso8601String(),
        'cloud_id': cid,
        'created_at': createdAt,
      });
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'consultations',
      {
        'title': title,
        'notes': (notes == null || notes.isEmpty) ? null : notes,
        'phone': (phone == null || phone.isEmpty) ? null : phone,
        'address': (address == null || address.isEmpty) ? null : address,
        'occurred_at': occurredAt.toIso8601String(),
        'cloud_id': cid,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
  }

  Future<void> upsertVaccineFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final vid = (data['id'] as String?)?.trim();
    if (vid == null || vid.isEmpty) return;
    final name = (data['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return;
    final appliedAt = _parseCloudIso(data['applied_at']);
    final nextDueAt = _parseCloudIso(data['next_due_at']);

    final db = await database;
    final rows = await db.query(
      'vaccines',
      columns: ['id'],
      where: 'baby_id = ? AND cloud_id = ?',
      whereArgs: [localBabyId, vid],
      limit: 1,
    );
    final dose = (data['dose'] as String?)?.trim();
    final notes = (data['notes'] as String?)?.trim();
    final createdAt = DateTime.now().toIso8601String();

    if (rows.isEmpty) {
      await db.insert('vaccines', {
        'baby_id': localBabyId,
        'name': name,
        'dose': (dose == null || dose.isEmpty) ? null : dose,
        'applied_at': appliedAt?.toIso8601String(),
        'next_due_at': nextDueAt?.toIso8601String(),
        'notes': (notes == null || notes.isEmpty) ? null : notes,
        'cloud_id': vid,
        'created_at': createdAt,
      });
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'vaccines',
      {
        'name': name,
        'dose': (dose == null || dose.isEmpty) ? null : dose,
        'applied_at': appliedAt?.toIso8601String(),
        'next_due_at': nextDueAt?.toIso8601String(),
        'notes': (notes == null || notes.isEmpty) ? null : notes,
        'cloud_id': vid,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
  }

  Future<bool> isBabyMemoryBadgeTombstoned({
    required int babyId,
    required String badgeId,
    String? babyCloudId,
  }) async {
    final bid = badgeId.trim();
    if (bid.isEmpty) return false;
    final cloud = babyCloudId?.trim() ?? '';
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'memory_badge_tombstones');
        return list.any((r) {
          if ((r['badge_id'] as String?) != bid) return false;
          if ((r['baby_id'] as num?)?.toInt() == babyId) return true;
          if (cloud.isNotEmpty && (r['baby_cloud_id'] as String?) == cloud) {
            return true;
          }
          return false;
        });
      });
    }
    final db = await database;
    if (cloud.isNotEmpty) {
      final byCloud = await db.query(
        'memory_badge_tombstones',
        columns: const ['badge_id'],
        where: 'baby_cloud_id = ? AND badge_id = ?',
        whereArgs: [cloud, bid],
        limit: 1,
      );
      if (byCloud.isNotEmpty) return true;
    }
    final rows = await db.query(
      'memory_badge_tombstones',
      columns: const ['badge_id'],
      where: 'baby_id = ? AND badge_id = ?',
      whereArgs: [babyId, bid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> tombstoneBabyMemoryBadge({
    required int babyId,
    required String badgeId,
    String? babyCloudId,
  }) async {
    final bid = badgeId.trim();
    if (bid.isEmpty) return;
    var cloud = babyCloudId?.trim() ?? '';
    if (cloud.isEmpty && !kIsWeb) {
      final row = await getBabyById(babyId);
      cloud = (row?['cloud_id'] as String?)?.trim() ?? '';
    }
    final deletedAt = DateTime.now().toIso8601String();
    if (kIsWeb) {
      await _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'memory_badge_tombstones');
        list.removeWhere((r) {
          if ((r['badge_id'] as String?) != bid) return false;
          return (r['baby_id'] as num?)?.toInt() == babyId ||
              (cloud.isNotEmpty && (r['baby_cloud_id'] as String?) == cloud);
        });
        list.add({
          'baby_id': babyId,
          'badge_id': bid,
          if (cloud.isNotEmpty) 'baby_cloud_id': cloud,
          'deleted_at': deletedAt,
        });
        await _webWriteList(prefs, 'memory_badge_tombstones', list);
      });
      return;
    }
    final db = await database;
    await db.insert(
      'memory_badge_tombstones',
      {
        'baby_id': babyId,
        'badge_id': bid,
        'baby_cloud_id': cloud.isEmpty ? null : cloud,
        'deleted_at': deletedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Aplica exclusões guardadas na nuvem ao SQLite local (após login).
  Future<void> applyCloudMemoryDeletions({
    required int localBabyId,
    required String babyCloudId,
    required List<String> badgeIds,
  }) async {
    for (final raw in badgeIds) {
      final bid = raw.trim();
      if (bid.isEmpty) continue;
      await tombstoneBabyMemoryBadge(
        babyId: localBabyId,
        badgeId: bid,
        babyCloudId: babyCloudId,
      );
      await deleteBabyMemoryByBadge(
        babyId: localBabyId,
        badgeId: bid,
        skipTombstone: true,
      );
    }
  }

  Future<void> clearBabyMemoryBadgeTombstone({
    required int babyId,
    required String badgeId,
    String? babyCloudId,
  }) async {
    final bid = badgeId.trim();
    if (bid.isEmpty) return;
    var cloud = babyCloudId?.trim() ?? '';
    if (cloud.isEmpty && !kIsWeb) {
      final row = await getBabyById(babyId);
      cloud = (row?['cloud_id'] as String?)?.trim() ?? '';
    }
    if (kIsWeb) {
      await _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'memory_badge_tombstones');
        list.removeWhere((r) {
          if ((r['badge_id'] as String?) != bid) return false;
          return (r['baby_id'] as num?)?.toInt() == babyId ||
              (cloud.isNotEmpty && (r['baby_cloud_id'] as String?) == cloud);
        });
        await _webWriteList(prefs, 'memory_badge_tombstones', list);
      });
      return;
    }
    final db = await database;
    await db.delete(
      'memory_badge_tombstones',
      where: 'baby_id = ? AND badge_id = ?',
      whereArgs: [babyId, bid],
    );
    if (cloud.isNotEmpty) {
      await db.delete(
        'memory_badge_tombstones',
        where: 'baby_cloud_id = ? AND badge_id = ?',
        whereArgs: [cloud, bid],
      );
    }
  }

  Future<void> upsertBabyMemoryFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    if (data['deleted'] == true) {
      final babyRow = await getBabyById(localBabyId);
      final babyCloud = (babyRow?['cloud_id'] as String?)?.trim() ?? '';
      var badgeId = (data['badge_id'] as String?)?.trim() ?? '';
      final docId = (data['id'] as String?)?.trim() ?? '';
      if (badgeId.isEmpty &&
          babyCloud.isNotEmpty &&
          docId.startsWith('badge_${babyCloud}_')) {
        badgeId = docId.substring('badge_${babyCloud}_'.length);
      }
      if (badgeId.isNotEmpty) {
        await tombstoneBabyMemoryBadge(
            babyId: localBabyId, badgeId: badgeId);
        await deleteBabyMemoryByBadge(
            babyId: localBabyId, badgeId: badgeId);
      }
      return;
    }
    final babyRow = await getBabyById(localBabyId);
    final babyCloud = (babyRow?['cloud_id'] as String?)?.trim() ?? '';
    final docId = (data['id'] as String?)?.trim() ?? '';

    var badgeId = (data['badge_id'] as String?)?.trim() ?? '';
    if (badgeId.isEmpty &&
        babyCloud.isNotEmpty &&
        docId.startsWith('badge_${babyCloud}_')) {
      badgeId = docId.substring('badge_${babyCloud}_'.length);
    }
    if (badgeId.isEmpty && docId.isNotEmpty && !docId.startsWith('badge_')) {
      badgeId = docId;
    }
    if (badgeId.isEmpty) return;
    if (await isBabyMemoryBadgeTombstoned(
      babyId: localBabyId,
      badgeId: badgeId,
      babyCloudId: babyCloud.isEmpty ? null : babyCloud,
    )) {
      return;
    }
    final title = (data['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return;

    final desc = (data['description'] as String?)?.trim();
    final db = await database;
    final existingRows = await db.query(
      'memories',
      columns: const ['photo_b64', 'photo_path'],
      where: 'baby_id = ? AND badge_id = ?',
      whereArgs: [localBabyId, badgeId],
      limit: 1,
    );
    final localRow = existingRows.isEmpty ? null : existingRows.first;
    var localB64 = (localRow?['photo_b64'] as String?)?.trim();
    if (localB64 != null && localB64.isEmpty) localB64 = null;
    var localPath = (localRow?['photo_path'] as String?)?.trim();
    if (localPath != null && localPath.isEmpty) localPath = null;

    // Só aplicar fotos quando o documento remoto traz valores **úteis** (strings não vazias).
    // Chaves como `photo_url` com null/"" vindas do Firestore/merge não podem apagar a foto local —
    // isso despovoava todo o livro de memórias no próximo hydrate.
    final dataMap = Map<String, dynamic>.from(data);
    final remoteB64 = _nonEmptyTrimmed(dataMap['photo_b64']);
    final photoB64 = remoteB64 ?? localB64;
    final remotePathOrUrl = _firstNonEmptyPhotoField(
        dataMap, ['photo_url', 'photoUrl', 'photo_path']);
    final photoUrl = remotePathOrUrl ?? localPath;

    final memoryDate = _parseCloudIso(data['memory_date']) ?? DateTime.now();
    final babyAge = (data['baby_age_at_moment'] as String?)?.trim();
    final weight = _parseCloudDouble(data['weight_at_moment']);
    final height = _parseCloudDouble(data['height_at_moment']);
    final mood = (data['mood_at_moment'] as String?)?.trim();
    final motherNotes = (data['mother_notes'] as String?)?.trim();
    final fav =
        (data['is_favorite'] == true) ? true : (data['is_favorite'] == 1);
    final pub = (data['is_public'] == true) ? true : (data['is_public'] == 1);
    final pubEn = _parseCloudIso(data['public_enabled_at']);
    final pubDis = _parseCloudIso(data['public_disabled_at']);
    final eligRaw =
        data['eligible_weekly_photo'] ?? data['eligible_for_weekly_photo'];
    final elig = (eligRaw == true) ? true : (eligRaw == 1);
    final win = (data['weekly_photo_winner'] == true)
        ? true
        : (data['weekly_photo_winner'] == 1);
    final wwk = (data['weekly_photo_week_id'] as String?)?.trim();
    final showBaby = (data['show_baby_name_public'] == false)
        ? false
        : (data['show_baby_name_public'] != 0);
    final createdAt = _parseCloudIso(data['created_at']) ??
        _parseCloudIso(data['createdAt']);

    await upsertBabyMemory(
      babyId: localBabyId,
      badgeId: badgeId,
      fromCloudImport: true,
      preserveCreatedAt: createdAt,
      title: title,
      description: (desc == null || desc.isEmpty) ? null : desc,
      photoB64: (photoB64 == null || photoB64.isEmpty) ? null : photoB64,
      photoUrl: (photoUrl == null || photoUrl.isEmpty) ? null : photoUrl,
      memoryDate: memoryDate,
      babyAgeAtMoment: (babyAge == null || babyAge.isEmpty) ? null : babyAge,
      weightAtMoment: weight,
      heightAtMoment: height,
      moodAtMoment: (mood == null || mood.isEmpty) ? null : mood,
      motherNotes:
          (motherNotes == null || motherNotes.isEmpty) ? null : motherNotes,
      isFavorite: fav == true,
      isPublic: pub == true,
      publicEnabledAt: pubEn,
      publicDisabledAt: pubDis,
      eligibleForWeeklyPhoto: elig == true,
      weeklyPhotoWinner: win == true,
      weeklyPhotoWeekId: (wwk == null || wwk.isEmpty) ? null : wwk,
      showBabyFirstNameWhenPublic: showBaby,
    );
  }

  Future<void> upsertFeedingFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final cid = (data['id'] as String?)?.trim();
    if (cid == null || cid.isEmpty) return;
    final startedAt = _parseCloudIso(data['started_at']);
    final endedAt = _parseCloudIso(data['ended_at']);
    final duration = (data['duration_sec'] is num)
        ? (data['duration_sec'] as num).toInt()
        : int.tryParse('${data['duration_sec']}');
    if (startedAt == null || endedAt == null || duration == null) return;

    final db = await database;
    final rows = await db.query(
      'feedings',
      columns: ['id'],
      where: 'baby_id = ? AND cloud_id = ?',
      whereArgs: [localBabyId, cid],
      limit: 1,
    );
    final createdAt = DateTime.now().toIso8601String();
    final side = (data['side'] as String?)?.trim();
    final dataMap = Map<String, dynamic>.from(data);
    final typeRaw = _feedingSubtypeFromCloudEvent(dataMap);
    final type = (typeRaw == null || typeRaw.isEmpty) ? null : typeRaw;
    final note = (data['note'] as String?)?.trim();
    final qty = _parseCloudDouble(data['quantity_ml']);

    if (rows.isEmpty) {
      await db.insert('feedings', {
        'baby_id': localBabyId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_sec': duration,
        'side': (side == null || side.isEmpty) ? null : side,
        'type': (type == null || type.isEmpty) ? null : type,
        'quantity_ml': qty,
        'note': (note == null || note.isEmpty) ? null : note,
        'cloud_id': cid,
        'created_at': createdAt,
      });
      FeedingEvents.ping();
      HealthCalendarEvents.ping();
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'feedings',
      {
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_sec': duration,
        'side': (side == null || side.isEmpty) ? null : side,
        'type': (type == null || type.isEmpty) ? null : type,
        'quantity_ml': qty,
        'note': (note == null || note.isEmpty) ? null : note,
        'cloud_id': cid,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
    FeedingEvents.ping();
    HealthCalendarEvents.ping();
  }

  /// Linhas antigas vinham da nuvem com `type = 'feeding'` (discriminador do evento Firestore) em vez de `feeding_type`.
  /// Isso zera o “Resumo de hoje”; forçamos rehidratação para corrigir.
  Future<bool> feedingRowsHaveLegacyCloudSubtypeBug(
      {required int babyId}) async {
    if (kIsWeb) return false;
    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT COUNT(*) AS c FROM feedings
WHERE baby_id = ?
  AND LOWER(TRIM(COALESCE(type,''))) = 'feeding'
''',
      [babyId],
    );
    return ((rows.first['c'] as num?)?.toInt() ?? 0) > 0;
  }

  Future<void> upsertDiaperFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final cid = (data['id'] as String?)?.trim();
    if (cid == null || cid.isEmpty) return;
    final changedAt = _parseCloudIso(data['changed_at']);
    final kind = (data['kind'] as String?)?.trim();
    if (changedAt == null || kind == null || kind.isEmpty) return;
    final note = (data['note'] as String?)?.trim();
    final createdAt = DateTime.now().toIso8601String();

    final db = await database;
    final rows = await db.query(
      'diapers',
      columns: ['id'],
      where: 'baby_id = ? AND cloud_id = ?',
      whereArgs: [localBabyId, cid],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('diapers', {
        'baby_id': localBabyId,
        'changed_at': changedAt.toIso8601String(),
        'kind': kind,
        'note': (note == null || note.isEmpty) ? null : note,
        'cloud_id': cid,
        'created_at': createdAt,
      });
      DiaperEvents.ping();
      HealthCalendarEvents.ping();
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'diapers',
      {
        'changed_at': changedAt.toIso8601String(),
        'kind': kind,
        'note': (note == null || note.isEmpty) ? null : note,
        'cloud_id': cid,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
    DiaperEvents.ping();
    HealthCalendarEvents.ping();
  }

  Future<void> upsertSleepFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final cid = (data['id'] as String?)?.trim();
    if (cid == null || cid.isEmpty) return;
    final startedAt = _parseCloudIso(data['started_at']);
    final endedAt = _parseCloudIso(data['ended_at']);
    final duration = (data['duration_sec'] is num)
        ? (data['duration_sec'] as num).toInt()
        : int.tryParse('${data['duration_sec']}');
    if (startedAt == null || endedAt == null || duration == null) return;
    final quality = (data['quality'] as String?)?.trim();
    final note = (data['note'] as String?)?.trim();
    final createdAt = DateTime.now().toIso8601String();

    final db = await database;
    final rows = await db.query(
      'sleep_records',
      columns: ['id'],
      where: 'baby_id = ? AND cloud_id = ?',
      whereArgs: [localBabyId, cid],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('sleep_records', {
        'baby_id': localBabyId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_sec': duration,
        'quality': (quality == null || quality.isEmpty) ? null : quality,
        'note': (note == null || note.isEmpty) ? null : note,
        'cloud_id': cid,
        'created_at': createdAt,
      });
      SleepEvents.ping();
      HealthCalendarEvents.ping();
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'sleep_records',
      {
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_sec': duration,
        'quality': (quality == null || quality.isEmpty) ? null : quality,
        'note': (note == null || note.isEmpty) ? null : note,
        'cloud_id': cid,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
    SleepEvents.ping();
    HealthCalendarEvents.ping();
  }

  Future<void> upsertGrowthFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final cid = (data['id'] as String?)?.trim();
    if (cid == null || cid.isEmpty) return;
    final kind = (data['kind'] as String?)?.trim();
    final value = _parseCloudDouble(data['value']);
    final measuredAt = _parseCloudIso(data['measured_at']);
    if (kind == null || kind.isEmpty || value == null || measuredAt == null)
      return;
    final createdAt = DateTime.now().toIso8601String();

    final db = await database;
    final rows = await db.query(
      'growth_records',
      columns: ['id'],
      where: 'baby_id = ? AND cloud_id = ?',
      whereArgs: [localBabyId, cid],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('growth_records', {
        'baby_id': localBabyId,
        'kind': kind,
        'value': value,
        'measured_at': measuredAt.toIso8601String(),
        'cloud_id': cid,
        'created_at': createdAt,
      });
      HealthCalendarEvents.ping();
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'growth_records',
      {
        'kind': kind,
        'value': value,
        'measured_at': measuredAt.toIso8601String(),
        'cloud_id': cid,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
    HealthCalendarEvents.ping();
  }

  static bool _symptomBoolFromCloud(dynamic v) {
    if (v == true) return true;
    if (v == false) return false;
    if (v is num) return v != 0;
    return false;
  }

  Future<void> upsertSymptomReportFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final cid = (data['id'] as String?)?.trim();
    if (cid == null || cid.isEmpty) return;
    DateTime? occurredAt = _parseCloudIso(data['occurred_at']) ??
        _parseCloudIso(data['occurredAt']);
    final et = data['event_time'];
    if (occurredAt == null && et is Timestamp) {
      occurredAt = et.toDate();
    }
    if (occurredAt == null) return;
    final med = (data['medication_note'] ?? data['medicationNote']) as String?;
    final medTrim = med?.trim();
    final medicationNote =
        (medTrim == null || medTrim.isEmpty) ? null : medTrim;
    final fever = _symptomBoolFromCloud(data['fever']);
    final tempCelsius =
        _parseCloudDouble(data['temp_celsius'] ?? data['tempCelsius']);
    final crying = _symptomBoolFromCloud(data['crying'] ??
        data['unexplained_crying'] ??
        data['unexplainedCrying']);
    final pain = _symptomBoolFromCloud(data['pain']);
    final colic = _symptomBoolFromCloud(data['colic']);
    final reflux = _symptomBoolFromCloud(data['reflux']);
    final otherRaw = (data['other_note'] ?? data['otherNote']) as String?;
    final otherTrim = otherRaw?.trim();
    final otherNote =
        (otherTrim == null || otherTrim.isEmpty) ? null : otherTrim;
    final createdAt = DateTime.now().toIso8601String();

    final db = await database;
    final rows = await db.query(
      'symptom_reports',
      columns: ['id'],
      where: 'baby_id = ? AND cloud_id = ?',
      whereArgs: [localBabyId, cid],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('symptom_reports', {
        'baby_id': localBabyId,
        'occurred_at': occurredAt.toIso8601String(),
        'medication_note': medicationNote,
        'fever': fever ? 1 : 0,
        'temp_celsius': tempCelsius,
        'crying': crying ? 1 : 0,
        'pain': pain ? 1 : 0,
        'colic': colic ? 1 : 0,
        'reflux': reflux ? 1 : 0,
        'other_note': otherNote,
        'cloud_id': cid,
        'created_at': createdAt,
        'updated_at': createdAt,
      });
      HealthCalendarEvents.ping();
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'symptom_reports',
      {
        'occurred_at': occurredAt.toIso8601String(),
        'medication_note': medicationNote,
        'fever': fever ? 1 : 0,
        'temp_celsius': tempCelsius,
        'crying': crying ? 1 : 0,
        'pain': pain ? 1 : 0,
        'colic': colic ? 1 : 0,
        'reflux': reflux ? 1 : 0,
        'other_note': otherNote,
        'cloud_id': cid,
        'updated_at': createdAt,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
    HealthCalendarEvents.ping();
  }

  Future<int> setSymptomReportCloudId({
    required int id,
    required int babyId,
    required String cloudId,
  }) async {
    final cid = cloudId.trim();
    if (cid.isEmpty) return 0;
    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'symptom_reports');
          final idx = list.indexWhere((raw) {
            final m = Map<String, Object?>.from(raw as Map);
            return ((m['id'] as num?)?.toInt() == id) &&
                ((m['baby_id'] as num?)?.toInt() == babyId);
          });
          if (idx < 0) return 0;
          final prev = Map<String, Object?>.from(list[idx] as Map);
          list[idx] = {...prev, 'cloud_id': cid};
          await _webWriteList(prefs, 'symptom_reports', list);
          return 1;
        });
      }
      final db = await database;
      return await db.update(
        'symptom_reports',
        {'cloud_id': cid},
        where: 'id = ? AND baby_id = ?',
        whereArgs: [id, babyId],
      );
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<void> upsertDailyJournalFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final dayKey =
        (data['day_key'] as String?)?.trim() ?? (data['id'] as String?)?.trim();
    if (dayKey == null || dayKey.isEmpty) return;
    final text = (data['text'] as String?)?.trim();
    final db = await database;
    final rows = await db.query(
      'daily_journals',
      columns: ['id'],
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [localBabyId, dayKey],
      limit: 1,
    );
    final createdAt = DateTime.now().toIso8601String();
    if (rows.isEmpty) {
      await db.insert('daily_journals', {
        'baby_id': localBabyId,
        'day_key': dayKey,
        'text': (text == null || text.isEmpty) ? null : text,
        'cloud_id': dayKey,
        'created_at': createdAt,
        'updated_at': createdAt,
      });
      return;
    }
    final localId = (rows.first['id'] as num).toInt();
    await db.update(
      'daily_journals',
      {
        'text': (text == null || text.isEmpty) ? null : text,
        'cloud_id': dayKey,
        'updated_at': createdAt,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [localId, localBabyId],
    );
  }

  Future<void> upsertDailySummarySnapshotFromCloud({
    required int localBabyId,
    required Map<String, dynamic> data,
  }) async {
    if (kIsWeb) return;
    final dayKey =
        (data['day_key'] as String?)?.trim() ?? (data['id'] as String?)?.trim();
    if (dayKey == null || dayKey.isEmpty) return;
    final createdAt = DateTime.now().toIso8601String();

    int? asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');
    final feedings = asInt(data['feedings']);
    final feedingMin = asInt(data['feeding_minutes_total']);
    final diapers = asInt(data['diapers']);
    final diaperPee = asInt(data['diaper_pee']);
    final diaperPoo = asInt(data['diaper_poo']);
    final sleepSessions = asInt(data['sleep_sessions']);
    final sleepTotal = asInt(data['sleep_total_sec']);
    final weightLabel = (data['weight_label'] as String?)?.trim();
    if (feedings == null ||
        feedingMin == null ||
        diapers == null ||
        diaperPee == null ||
        diaperPoo == null ||
        sleepSessions == null ||
        sleepTotal == null ||
        weightLabel == null ||
        weightLabel.isEmpty) {
      return;
    }

    final db = await database;
    final existing = await db.query(
      'daily_summary_snapshots',
      columns: ['baby_id'],
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [localBabyId, dayKey],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('daily_summary_snapshots', {
        'baby_id': localBabyId,
        'day_key': dayKey,
        'feedings': feedings,
        'feeding_minutes_total': feedingMin,
        'diapers': diapers,
        'diaper_pee': diaperPee,
        'diaper_poo': diaperPoo,
        'sleep_sessions': sleepSessions,
        'sleep_total_sec': sleepTotal,
        'weight_label': weightLabel,
        'cloud_id': dayKey,
        'created_at': createdAt,
      });
      return;
    }
    await db.update(
      'daily_summary_snapshots',
      {
        'feedings': feedings,
        'feeding_minutes_total': feedingMin,
        'diapers': diapers,
        'diaper_pee': diaperPee,
        'diaper_poo': diaperPoo,
        'sleep_sessions': sleepSessions,
        'sleep_total_sec': sleepTotal,
        'weight_label': weightLabel,
        'cloud_id': dayKey,
      },
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [localBabyId, dayKey],
    );
  }

  /// Notificações mostradas ou agendadas (histórico na app). Web: no-op.
  Future<void> insertNotificationLog({
    int? notifId,
    required String uid,
    required String title,
    required String body,
    String? payload,
    required String kind,
    required DateTime occurredAt,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    final uidNorm = uid.trim().isEmpty ? 'anonymous' : uid.trim();
    await db.insert('notification_log', {
      'uid': uidNorm,
      'notif_id': notifId,
      'title': title,
      'body': body,
      'payload': payload,
      'kind': kind,
      'occurred_at': occurredAt.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Eventos registados há pouco tempo: [occurred_at] ou [created_at] ≥ [since].
  ///
  /// Isto alinha “últimos N dias registados na app” com o facto de alguns registos de
  /// agendamento guardarem um [occurred_at] lógico (ex.: deadline de sono) no passado
  /// mesmo quando foram escritos pela primeira vez já depois dessa data.
  Future<List<Map<String, Object?>>> listNotificationLogSince(
      {required String uid, required DateTime since}) async {
    if (kIsWeb) return const [];
    final db = await database;
    final sinceIso = since.toIso8601String();
    final uidNorm = uid.trim().isEmpty ? 'anonymous' : uid.trim();
    return db.query(
      'notification_log',
      where:
          "COALESCE(uid, 'anonymous') = ? AND (occurred_at >= ? OR created_at >= ?)",
      whereArgs: [uidNorm, sinceIso, sinceIso],
      orderBy: 'created_at DESC, occurred_at DESC',
    );
  }

  Future<void> deleteNotificationLogs(
      {required String uid, required List<int> ids}) async {
    if (kIsWeb) return;
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final uidNorm = uid.trim().isEmpty ? 'anonymous' : uid.trim();
    await db.delete(
      'notification_log',
      where: "COALESCE(uid, 'anonymous') = ? AND id IN ($placeholders)",
      whereArgs: [uidNorm, ...ids],
    );
  }

  Future<int> insertMother({
    required String name,
    String? phone,
    DateTime? birthDate,
    double? heightCm,
    String? fatherName,
    double? fatherHeightCm,
    DateTime? fatherBirthDate,
    bool? registerFather,
    String? photoB64,
    String? fatherPhotoB64,
    bool showFamilyChristian = false,
    bool showFamilyHoroscope = true,
    bool showFamilySpiritist = false,
    bool showFamilyJewish = false,
  }) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final mothers = _webReadList(prefs, 'mothers');
        final id = await _webNextId(prefs, 'mothers');
        final createdAt = DateTime.now().toIso8601String();
        final n = name.trim();
        final p = phone?.trim().isEmpty == true ? null : phone?.trim();
        final fn =
            fatherName?.trim().isEmpty == true ? null : fatherName?.trim();
        final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
        final fpb =
            fatherPhotoB64?.trim().isEmpty == true ? null : fatherPhotoB64?.trim();

        mothers.insert(0, {
          'id': id,
          'name': n,
          'phone': p,
          'birth_date': birthDate?.toIso8601String(),
          'height_cm': heightCm,
          'father_name': fn,
          'father_height_cm': fatherHeightCm,
          'father_birth_date': fatherBirthDate?.toIso8601String(),
          'father_photo_b64': fpb,
          'register_father':
              registerFather == null ? null : (registerFather ? 1 : 0),
          'show_family_christian': showFamilyChristian ? 1 : 0,
          'show_family_horoscope': showFamilyHoroscope ? 1 : 0,
          'show_family_spiritist': showFamilySpiritist ? 1 : 0,
          'show_family_jewish': showFamilyJewish ? 1 : 0,
          'photo_b64': pb,
          'cloud_id': null,
          'created_at': createdAt,
        });
        await _webWriteList(prefs, 'mothers', mothers);
        return id;
      });
    }

    final db = await database;
    // Using rawInsert for best compatibility across web/ffi implementations.
    final createdAt = DateTime.now().toIso8601String();
    final n = name.trim();
    final p = phone?.trim().isEmpty == true ? null : phone?.trim();
    final fn = fatherName?.trim().isEmpty == true ? null : fatherName?.trim();
    final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
    final fpb =
        fatherPhotoB64?.trim().isEmpty == true ? null : fatherPhotoB64?.trim();
    try {
      final res = await db.rawInsert(
        'INSERT INTO mothers(name, phone, birth_date, height_cm, father_name, father_height_cm, father_birth_date, father_photo_b64, register_father, show_family_christian, show_family_horoscope, show_family_spiritist, show_family_jewish, photo_b64, created_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          n,
          p,
          birthDate?.toIso8601String(),
          heightCm,
          fn,
          fatherHeightCm,
          fatherBirthDate?.toIso8601String(),
          fpb,
          registerFather == null ? null : (registerFather ? 1 : 0),
          showFamilyChristian ? 1 : 0,
          showFamilyHoroscope ? 1 : 0,
          showFamilySpiritist ? 1 : 0,
          showFamilyJewish ? 1 : 0,
          pb,
          createdAt
        ],
      );
      return res;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> listMothers() async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final mothers = _webReadList(prefs, 'mothers');
      return mothers;
    }
    final db = await database;
    return db.query(
      'mothers',
      columns: [
        'id',
        'name',
        'phone',
        'birth_date',
        'height_cm',
        'father_name',
        'father_height_cm',
        'father_birth_date',
        'father_photo_b64',
        'father_photo_url',
        'register_father',
        'photo_b64',
        'photo_url',
        'cloud_id',
        'created_at'
      ],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> insertBaby({
    required int motherId,
    required String name,
    String sex = 'F',
    DateTime? birthDate,
    String? zodiacSign,
    double? weightKg,
    double? heightCm,
    bool? firstBaby,
    List<String>? onboardingConcerns,
    List<String>? onboardingGoals,
    String? photoB64,
  }) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        final id = await _webNextId(prefs, 'babies');
        final createdAt = DateTime.now().toIso8601String();
        final n = name.trim();
        final z =
            zodiacSign?.trim().isEmpty == true ? null : zodiacSign?.trim();
        final sx = sex.trim().isEmpty ? 'F' : sex.trim();
        final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
        final concernsJson = _encodeStringList(onboardingConcerns);
        final goalsJson = _encodeStringList(onboardingGoals);
        babies.insert(0, {
          'id': id,
          'mother_id': motherId,
          'name': n,
          'sex': sx,
          'birth_date': birthDate?.toIso8601String(),
          'zodiac_sign': z,
          'weight_kg': weightKg,
          'height_cm': heightCm,
          'birth_weight_kg': weightKg,
          'birth_height_cm': heightCm,
          'first_baby': firstBaby == null ? null : (firstBaby ? 1 : 0),
          'onboarding_concerns_json': concernsJson,
          'onboarding_goals_json': goalsJson,
          'photo_b64': pb,
          'cloud_id': null,
          'created_at': createdAt,
        });
        await _webWriteList(prefs, 'babies', babies);
        return id;
      });
    }
    final db = await database;
    final createdAt = DateTime.now().toIso8601String();
    final n = name.trim();
    final z = zodiacSign?.trim().isEmpty == true ? null : zodiacSign?.trim();
    final sx = sex.trim().isEmpty ? 'F' : sex.trim();
    final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
    final concernsJson = _encodeStringList(onboardingConcerns);
    final goalsJson = _encodeStringList(onboardingGoals);
    return db.rawInsert(
      '''
INSERT INTO babies(
  mother_id, name, sex, birth_date, zodiac_sign, weight_kg, height_cm, birth_weight_kg, birth_height_cm, first_baby, onboarding_concerns_json, onboarding_goals_json, photo_b64, created_at
) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        motherId,
        n,
        sx,
        birthDate?.toIso8601String(),
        z,
        weightKg,
        heightCm,
        weightKg,
        heightCm,
        firstBaby == null ? null : (firstBaby ? 1 : 0),
        concernsJson,
        goalsJson,
        pb,
        createdAt,
      ],
    );
  }

  Future<int> deleteBaby({required int babyId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        final idx = babies
            .indexWhere((raw) => ((raw['id'] as num?)?.toInt() == babyId));
        if (idx < 0) return 0;
        babies.removeAt(idx);
        await _webWriteList(prefs, 'babies', babies);
        return 1;
      });
    }
    final db = await database;
    return db.delete('babies', where: 'id = ?', whereArgs: [babyId]);
  }

  Future<int> insertMotherWithBaby({
    required String motherName,
    String? motherPhone,
    required String babyName,
    DateTime? babyBirthDate,
    String? babyZodiacSign,
    double? babyWeightKg,
    double? babyHeightCm,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final motherId = await txn.insert('mothers', {
        'name': motherName.trim(),
        'phone':
            motherPhone?.trim().isEmpty == true ? null : motherPhone?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.insert('babies', {
        'mother_id': motherId,
        'name': babyName.trim(),
        'birth_date': babyBirthDate?.toIso8601String(),
        'zodiac_sign': babyZodiacSign?.trim().isEmpty == true
            ? null
            : babyZodiacSign?.trim(),
        'weight_kg': babyWeightKg,
        'height_cm': babyHeightCm,
        'created_at': DateTime.now().toIso8601String(),
      });

      return motherId;
    });
  }

  Future<List<Map<String, Object?>>> listBabies() async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      return _webReadList(prefs, 'babies');
    }
    final db = await database;
    return db.rawQuery('''
SELECT
  id,
  mother_id,
  name,
  sex,
  birth_date,
  zodiac_sign,
  weight_kg,
  height_cm,
  first_baby,
  onboarding_concerns_json,
  onboarding_goals_json,
  photo_b64,
  photo_url,
  cloud_id,
  created_at
FROM babies
ORDER BY created_at DESC
''');
  }

  /// Uma linha do bebê por id (fallback quando [listBabies] vem vazio por corrida).
  Future<Map<String, Object?>?> getBabyById(int babyId) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'babies');
      for (final raw in list) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['id'] as num?)?.toInt() == babyId) return m;
      }
      return null;
    }
    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT
  id,
  mother_id,
  name,
  sex,
  birth_date,
  zodiac_sign,
  weight_kg,
  height_cm,
  photo_b64,
  photo_url,
  cloud_id,
  created_at
FROM babies
WHERE id = ?
LIMIT 1
''',
      [babyId],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int?> getLocalBabyIdByCloudId(String cloudId) async {
    if (kIsWeb) return null;
    final cid = cloudId.trim();
    if (cid.isEmpty) return null;
    final db = await database;
    final rows = await db.query(
      'babies',
      columns: ['id'],
      where: 'cloud_id = ?',
      whereArgs: [cid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['id'] as num?)?.toInt();
  }

  Future<Map<String, Object?>?> getMotherById(int motherId) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final mothers = _webReadList(prefs, 'mothers');
      for (final m in mothers) {
        final id = (m['id'] as num?)?.toInt();
        if (id == motherId) return m;
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      'mothers',
      columns: [
        'id',
        'name',
        'phone',
        'birth_date',
        'height_cm',
        'father_name',
        'father_height_cm',
        'father_birth_date',
        'father_photo_b64',
        'father_photo_url',
        'register_father',
        'show_family_christian',
        'show_family_horoscope',
        'show_family_spiritist',
        'show_family_jewish',
        'photo_b64',
        'photo_url',
        'cloud_id',
        'created_at'
      ],
      where: 'id = ?',
      whereArgs: [motherId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Corrige só o FK quando a linha [mothers] ficou inconsistente após erro/migração.
  Future<void> patchBabyMotherId(
      {required int babyId, required int motherId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        for (var i = 0; i < babies.length; i++) {
          final b = Map<String, Object?>.from(babies[i] as Map);
          if ((b['id'] as num?)?.toInt() == babyId) {
            b['mother_id'] = motherId;
            babies[i] = b;
            break;
          }
        }
        await _webWriteList(prefs, 'babies', babies);
      });
    }
    final db = await database;
    await db.update(
      'babies',
      {'mother_id': motherId},
      where: 'id = ?',
      whereArgs: [babyId],
    );
  }

  Future<void> updateMotherPhoto(
      {required int motherId, String? photoB64}) async {
    final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final mothers = _webReadList(prefs, 'mothers');
        for (final m in mothers) {
          final id = (m['id'] as num?)?.toInt();
          if (id == motherId) {
            m['photo_b64'] = pb;
            m['photo_url'] = null;
            break;
          }
        }
        await _webWriteList(prefs, 'mothers', mothers);
      });
    }
    final db = await database;
    await db.update(
      'mothers',
      {'photo_b64': pb, 'photo_url': null},
      where: 'id = ?',
      whereArgs: [motherId],
    );
  }

  Future<void> updateBabyPhoto({required int babyId, String? photoB64}) async {
    final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        for (final b in babies) {
          final id = (b['id'] as num?)?.toInt();
          if (id == babyId) {
            b['photo_b64'] = pb;
            b['photo_url'] = null;
            break;
          }
        }
        await _webWriteList(prefs, 'babies', babies);
      });
    }
    final db = await database;
    await db.update(
      'babies',
      {'photo_b64': pb, 'photo_url': null},
      where: 'id = ?',
      whereArgs: [babyId],
    );
  }

  Future<void> persistFatherPhotoUrl(
      {required int motherId, required String photoUrl}) async {
    final u = photoUrl.trim();
    if (u.isEmpty) return;
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final mothers = _webReadList(prefs, 'mothers');
        for (final m in mothers) {
          final id = (m['id'] as num?)?.toInt();
          if (id == motherId) {
            m['father_photo_url'] = u;
            break;
          }
        }
        await _webWriteList(prefs, 'mothers', mothers);
      });
    }
    final db = await database;
    await db.update('mothers', {'father_photo_url': u, 'father_photo_b64': null},
        where: 'id = ?', whereArgs: [motherId]);
  }

  Future<void> persistMotherPhotoUrl(
      {required int motherId, required String photoUrl}) async {
    final u = photoUrl.trim();
    if (u.isEmpty) return;
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final mothers = _webReadList(prefs, 'mothers');
        for (final m in mothers) {
          final id = (m['id'] as num?)?.toInt();
          if (id == motherId) {
            m['photo_url'] = u;
            break;
          }
        }
        await _webWriteList(prefs, 'mothers', mothers);
      });
    }
    final db = await database;
    // Se temos URL (Storage), não precisamos manter base64 local.
    await db.update('mothers', {'photo_url': u, 'photo_b64': null},
        where: 'id = ?', whereArgs: [motherId]);
  }

  Future<void> persistBabyPhotoUrl(
      {required int babyId, required String photoUrl}) async {
    final u = photoUrl.trim();
    if (u.isEmpty) return;
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        for (final b in babies) {
          final id = (b['id'] as num?)?.toInt();
          if (id == babyId) {
            b['photo_url'] = u;
            break;
          }
        }
        await _webWriteList(prefs, 'babies', babies);
      });
    }
    final db = await database;
    // Se temos URL (Storage), não precisamos manter base64 local.
    await db.update('babies', {'photo_url': u, 'photo_b64': null},
        where: 'id = ?', whereArgs: [babyId]);
  }

  Future<void> updateBabySex({required int babyId, required String sex}) async {
    final sx = sex.trim().isEmpty ? 'F' : sex.trim();
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        for (final b in babies) {
          final id = (b['id'] as num?)?.toInt();
          if (id == babyId) {
            b['sex'] = sx;
            break;
          }
        }
        await _webWriteList(prefs, 'babies', babies);
      });
    }
    final db = await database;
    await db.update('babies', {'sex': sx},
        where: 'id = ?', whereArgs: [babyId]);
  }

  Future<void> updateMotherFamilyMessagePrefs({
    required int motherId,
    required bool showChristian,
    required bool showHoroscope,
    required bool showSpiritist,
    required bool showJewish,
  }) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final mothers = _webReadList(prefs, 'mothers');
        for (var i = 0; i < mothers.length; i++) {
          final m = Map<String, Object?>.from(mothers[i] as Map);
          if ((m['id'] as num?)?.toInt() == motherId) {
            m['show_family_christian'] = showChristian ? 1 : 0;
            m['show_family_horoscope'] = showHoroscope ? 1 : 0;
            m['show_family_spiritist'] = showSpiritist ? 1 : 0;
            m['show_family_jewish'] = showJewish ? 1 : 0;
            mothers[i] = m;
            break;
          }
        }
        await _webWriteList(prefs, 'mothers', mothers);
      });
    }
    final db = await database;
    await db.update(
      'mothers',
      {
        'show_family_christian': showChristian ? 1 : 0,
        'show_family_horoscope': showHoroscope ? 1 : 0,
        'show_family_spiritist': showSpiritist ? 1 : 0,
        'show_family_jewish': showJewish ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [motherId],
    );
  }

  Future<void> updateMother({
    required int motherId,
    required String name,
    String? phone,
    DateTime? birthDate,
    double? heightCm,
    String? fatherName,
    double? fatherHeightCm,
    DateTime? fatherBirthDate,
    bool? registerFather,
    String? photoB64,
    String? fatherPhotoB64,
    bool? showFamilyChristian,
    bool? showFamilyHoroscope,
    bool resetProfilePhotoUrl = false,
    bool resetFatherPhotoUrl = false,
  }) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError.value(name, 'name', 'Must be non-empty');
    final p = phone?.trim().isEmpty == true ? null : phone?.trim();
    final fn = fatherName?.trim().isEmpty == true ? null : fatherName?.trim();
    final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
    final fpb =
        fatherPhotoB64?.trim().isEmpty == true ? null : fatherPhotoB64?.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final mothers = _webReadList(prefs, 'mothers');
        for (var i = 0; i < mothers.length; i++) {
          final m = Map<String, Object?>.from(mothers[i] as Map);
          if ((m['id'] as num?)?.toInt() == motherId) {
            m['name'] = n;
            m['phone'] = p;
            m['birth_date'] = birthDate?.toIso8601String();
            m['height_cm'] = heightCm;
            m['father_name'] = fn;
            m['father_height_cm'] = fatherHeightCm;
            m['father_birth_date'] = fatherBirthDate?.toIso8601String();
            if (registerFather != null) {
              m['register_father'] = registerFather ? 1 : 0;
            }
            m['photo_b64'] = pb;
            m['father_photo_b64'] = fpb;
            if (showFamilyChristian != null) {
              m['show_family_christian'] = showFamilyChristian! ? 1 : 0;
            }
            if (showFamilyHoroscope != null) {
              m['show_family_horoscope'] = showFamilyHoroscope! ? 1 : 0;
            }
            if (resetProfilePhotoUrl) m['photo_url'] = null;
            if (resetFatherPhotoUrl) m['father_photo_url'] = null;
            mothers[i] = m;
            break;
          }
        }
        await _webWriteList(prefs, 'mothers', mothers);
      });
    }
    final db = await database;
    final patch = <String, Object?>{
      'name': n,
      'phone': p,
      'birth_date': birthDate?.toIso8601String(),
      'height_cm': heightCm,
      'father_name': fn,
      'father_height_cm': fatherHeightCm,
      'father_birth_date': fatherBirthDate?.toIso8601String(),
      'photo_b64': pb,
      'father_photo_b64': fpb,
    };
    if (registerFather != null) {
      patch['register_father'] = registerFather ? 1 : 0;
    }
    if (showFamilyChristian != null) {
      patch['show_family_christian'] = showFamilyChristian! ? 1 : 0;
    }
    if (showFamilyHoroscope != null) {
      patch['show_family_horoscope'] = showFamilyHoroscope! ? 1 : 0;
    }
    if (resetProfilePhotoUrl) patch['photo_url'] = null;
    if (resetFatherPhotoUrl) patch['father_photo_url'] = null;
    await db.update(
      'mothers',
      patch,
      where: 'id = ?',
      whereArgs: [motherId],
    );
  }

  Future<void> updateBaby({
    required int babyId,
    required int motherId,
    required String name,
    String sex = 'F',
    DateTime? birthDate,
    String? zodiacSign,
    double? weightKg,
    double? heightCm,
    double? birthWeightKg,
    double? birthHeightCm,
    bool touchBirthBaseline = true,
    String? photoB64,
    bool resetProfilePhotoUrl = false,
  }) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError.value(name, 'name', 'Must be non-empty');
    final z = zodiacSign?.trim().isEmpty == true ? null : zodiacSign?.trim();
    final sx = sex.trim().isEmpty ? 'F' : sex.trim();
    final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        for (var i = 0; i < babies.length; i++) {
          final b = Map<String, Object?>.from(babies[i] as Map);
          if ((b['id'] as num?)?.toInt() == babyId) {
            if ((b['mother_id'] as num?)?.toInt() != motherId) {
              throw StateError(
                  'Baby $babyId does not belong to mother $motherId');
            }
            b['name'] = n;
            b['sex'] = sx;
            b['birth_date'] = birthDate?.toIso8601String();
            b['zodiac_sign'] = z;
            b['weight_kg'] = weightKg;
            b['height_cm'] = heightCm;
            if (touchBirthBaseline) {
              b['birth_weight_kg'] = birthWeightKg ?? weightKg;
              b['birth_height_cm'] = birthHeightCm ?? heightCm;
            }
            b['photo_b64'] = pb;
            if (resetProfilePhotoUrl) b['photo_url'] = null;
            babies[i] = b;
            break;
          }
        }
        await _webWriteList(prefs, 'babies', babies);
      });
    }
    final db = await database;
    final patch = <String, Object?>{
      'name': n,
      'sex': sx,
      'birth_date': birthDate?.toIso8601String(),
      'zodiac_sign': z,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'photo_b64': pb,
    };
    if (touchBirthBaseline) {
      patch['birth_weight_kg'] = birthWeightKg ?? weightKg;
      patch['birth_height_cm'] = birthHeightCm ?? heightCm;
    }
    if (resetProfilePhotoUrl) patch['photo_url'] = null;
    final nRows = await db.update(
      'babies',
      patch,
      where: 'id = ? AND mother_id = ?',
      whereArgs: [babyId, motherId],
    );
    if (nRows == 0) throw StateError('Baby not found or wrong mother');
  }

  /// ID do documento Firestore associado (sincronização de perfil na nuvem).
  Future<void> setMotherCloudId(
      {required int motherId, required String cloudId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final mothers = _webReadList(prefs, 'mothers');
        for (var i = 0; i < mothers.length; i++) {
          final m = Map<String, Object?>.from(mothers[i] as Map);
          if ((m['id'] as num?)?.toInt() == motherId) {
            m['cloud_id'] = cloudId;
            mothers[i] = m;
            break;
          }
        }
        await _webWriteList(prefs, 'mothers', mothers);
      });
    }
    final db = await database;
    await db.update('mothers', {'cloud_id': cloudId},
        where: 'id = ?', whereArgs: [motherId]);
  }

  /// ID do documento Firestore associado (sincronização de perfil na nuvem).
  Future<void> setBabyCloudId(
      {required int babyId, required String cloudId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final babies = _webReadList(prefs, 'babies');
        for (var i = 0; i < babies.length; i++) {
          final b = Map<String, Object?>.from(babies[i] as Map);
          if ((b['id'] as num?)?.toInt() == babyId) {
            b['cloud_id'] = cloudId;
            babies[i] = b;
            break;
          }
        }
        await _webWriteList(prefs, 'babies', babies);
      });
    }
    final db = await database;
    await db.update('babies', {'cloud_id': cloudId},
        where: 'id = ?', whereArgs: [babyId]);
  }

  Future<List<Map<String, Object?>>> listMothersWithBabies() async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final mothers = _webReadList(prefs, 'mothers');
      final babies = _webReadList(prefs, 'babies');
      final out = <Map<String, Object?>>[];
      for (final m in mothers) {
        final mid = (m['id'] as num).toInt();
        final mb = babies
            .where((b) => (b['mother_id'] as num).toInt() == mid)
            .toList();
        if (mb.isEmpty) {
          out.add({
            'mother_id': mid,
            'mother_name': m['name'],
            'mother_phone': m['phone'],
            'mother_birth_date': m['birth_date'],
            'mother_height_cm': m['height_cm'],
            'mother_father_name': m['father_name'],
            'mother_father_height_cm': m['father_height_cm'],
            'mother_father_birth_date': m['father_birth_date'],
            'mother_created_at': m['created_at'],
            'baby_id': null,
            'baby_name': null,
            'baby_birth_date': null,
            'baby_zodiac_sign': null,
            'baby_weight_kg': null,
            'baby_height_cm': null,
            'baby_created_at': null,
          });
        } else {
          for (final b in mb) {
            out.add({
              'mother_id': mid,
              'mother_name': m['name'],
              'mother_phone': m['phone'],
              'mother_birth_date': m['birth_date'],
              'mother_height_cm': m['height_cm'],
              'mother_father_name': m['father_name'],
              'mother_father_height_cm': m['father_height_cm'],
              'mother_father_birth_date': m['father_birth_date'],
              'mother_created_at': m['created_at'],
              'baby_id': b['id'],
              'baby_name': b['name'],
              'baby_birth_date': b['birth_date'],
              'baby_zodiac_sign': b['zodiac_sign'],
              'baby_weight_kg': b['weight_kg'],
              'baby_height_cm': b['height_cm'],
              'baby_created_at': b['created_at'],
            });
          }
        }
      }
      return out;
    }
    final db = await database;
    return db.rawQuery('''
SELECT
  m.id AS mother_id,
  m.name AS mother_name,
  m.phone AS mother_phone,
  m.birth_date AS mother_birth_date,
  m.height_cm AS mother_height_cm,
  m.father_name AS mother_father_name,
  m.father_height_cm AS mother_father_height_cm,
  m.father_birth_date AS mother_father_birth_date,
  m.created_at AS mother_created_at,
  b.id AS baby_id,
  b.name AS baby_name,
  b.birth_date AS baby_birth_date,
  b.zodiac_sign AS baby_zodiac_sign,
  b.weight_kg AS baby_weight_kg,
  b.height_cm AS baby_height_cm,
  b.created_at AS baby_created_at
FROM mothers m
LEFT JOIN babies b ON b.mother_id = m.id
ORDER BY m.created_at DESC, b.created_at DESC
''');
  }

  Future<int> insertVaccine({
    required int babyId,
    required String name,
    String? dose,
    DateTime? appliedAt,
    DateTime? nextDueAt,
    String? notes,
  }) async {
    final nm = name.trim();
    if (nm.isEmpty)
      throw ArgumentError.value(name, 'name', 'Must be non-empty');
    final created = DateTime.now().toIso8601String();
    final d = dose?.trim().isEmpty == true ? null : dose?.trim();
    final n = notes?.trim().isEmpty == true ? null : notes?.trim();

    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'vaccines');
          final id = await _webNextId(prefs, 'vaccines');
          list.insert(0, {
            'id': id,
            'baby_id': babyId,
            'name': nm,
            'dose': d,
            'applied_at': appliedAt?.toIso8601String(),
            'next_due_at': nextDueAt?.toIso8601String(),
            'notes': n,
            'created_at': created,
          });
          await _webWriteList(prefs, 'vaccines', list);
          return id;
        });
      }

      final db = await database;
      return await db.insert('vaccines', {
        'baby_id': babyId,
        'name': nm,
        'dose': d,
        'applied_at': appliedAt?.toIso8601String(),
        'next_due_at': nextDueAt?.toIso8601String(),
        'notes': n,
        'created_at': created,
      });
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<List<Map<String, Object?>>> listVaccines({required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'vaccines');
      final filtered =
          list.where((r) => (r['baby_id'] as num?)?.toInt() == babyId).toList();
      filtered.sort((a, b) {
        final aa = a['applied_at'] as String? ?? '';
        final bb = b['applied_at'] as String? ?? '';
        final c = bb.compareTo(aa);
        if (c != 0) return c;
        final ac = a['created_at'] as String? ?? '';
        final bc = b['created_at'] as String? ?? '';
        return bc.compareTo(ac);
      });
      return filtered;
    }
    final db = await database;
    return db.query(
      'vaccines',
      where: 'baby_id = ?',
      whereArgs: [babyId],
      orderBy: 'applied_at DESC, created_at DESC',
    );
  }

  Future<int> updateVaccine({
    required int id,
    required int babyId,
    required String name,
    String? dose,
    DateTime? appliedAt,
    DateTime? nextDueAt,
    String? notes,
  }) async {
    final nm = name.trim();
    if (nm.isEmpty)
      throw ArgumentError.value(name, 'name', 'Must be non-empty');
    final d = dose?.trim().isEmpty == true ? null : dose?.trim();
    final n = notes?.trim().isEmpty == true ? null : notes?.trim();

    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'vaccines');
          final idx = list.indexWhere((raw) {
            final m = Map<String, Object?>.from(raw as Map);
            return ((m['id'] as num?)?.toInt() == id) &&
                ((m['baby_id'] as num?)?.toInt() == babyId);
          });
          if (idx < 0) return 0;
          final prev = Map<String, Object?>.from(list[idx] as Map);
          list[idx] = {
            ...prev,
            'name': nm,
            'dose': d,
            'applied_at': appliedAt?.toIso8601String(),
            'next_due_at': nextDueAt?.toIso8601String(),
            'notes': n,
          };
          await _webWriteList(prefs, 'vaccines', list);
          return 1;
        });
      }

      final db = await database;
      return await db.update(
        'vaccines',
        {
          'name': nm,
          'dose': d,
          'applied_at': appliedAt?.toIso8601String(),
          'next_due_at': nextDueAt?.toIso8601String(),
          'notes': n,
        },
        where: 'id = ? AND baby_id = ?',
        whereArgs: [id, babyId],
      );
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<int> deleteVaccine({required int id, required int babyId}) async {
    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'vaccines');
          final before = list.length;
          list.removeWhere((raw) {
            final m = Map<String, Object?>.from(raw as Map);
            return ((m['id'] as num?)?.toInt() == id) &&
                ((m['baby_id'] as num?)?.toInt() == babyId);
          });
          if (list.length == before) return 0;
          await _webWriteList(prefs, 'vaccines', list);
          return 1;
        });
      }
      final db = await database;
      return await db.delete(
        'vaccines',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [id, babyId],
      );
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  /// Vacinas com data de aplicação neste dia civil (timezone local do [calendarDay]).
  Future<List<Map<String, Object?>>> listVaccinesOnCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final out = <Map<String, Object?>>[];
      for (final raw in _webReadList(prefs, 'vaccines')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final ap = DateTime.tryParse(m['applied_at'] as String? ?? '');
        if (ap == null || ap.isBefore(start) || !ap.isBefore(end)) continue;
        out.add(m);
      }
      out.sort((a, b) {
        final aa = DateTime.tryParse(a['applied_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bb = DateTime.tryParse(b['applied_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final c = aa.compareTo(bb);
        if (c != 0) return c;
        final ac = a['created_at'] as String? ?? '';
        final bc = b['created_at'] as String? ?? '';
        return ac.compareTo(bc);
      });
      return out;
    }

    final db = await database;
    return db.query(
      'vaccines',
      where:
          'baby_id = ? AND applied_at IS NOT NULL AND applied_at >= ? AND applied_at < ?',
      whereArgs: [babyId, startIso, endIso],
      orderBy: 'applied_at ASC, created_at ASC',
    );
  }

  Future<Map<String, Object?>?> getVaccineRowById(int id) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      for (final raw in _webReadList(prefs, 'vaccines')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['id'] as num?)?.toInt() == id) return m;
      }
      return null;
    }
    final db = await database;
    final rows =
        await db.query('vaccines', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Vacinas com **próxima dose** (`next_due_at`) neste dia civil.
  Future<List<Map<String, Object?>>> listVaccinesDueOnCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final out = <Map<String, Object?>>[];
      for (final raw in _webReadList(prefs, 'vaccines')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final due = DateTime.tryParse(m['next_due_at'] as String? ?? '');
        if (due == null || due.isBefore(start) || !due.isBefore(end)) continue;
        out.add(m);
      }
      out.sort((a, b) {
        final aa = DateTime.tryParse(a['next_due_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bb = DateTime.tryParse(b['next_due_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final c = aa.compareTo(bb);
        if (c != 0) return c;
        final ac = a['created_at'] as String? ?? '';
        final bc = b['created_at'] as String? ?? '';
        return ac.compareTo(bc);
      });
      return out;
    }

    final db = await database;
    return db.query(
      'vaccines',
      where:
          'baby_id = ? AND next_due_at IS NOT NULL AND next_due_at >= ? AND next_due_at < ?',
      whereArgs: [babyId, startIso, endIso],
      orderBy: 'next_due_at ASC, created_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> listConsultationsOnCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final out = <Map<String, Object?>>[];
      for (final raw in _webReadList(prefs, 'consultations')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final oc = DateTime.tryParse(m['occurred_at'] as String? ?? '');
        if (oc == null || oc.isBefore(start) || !oc.isBefore(end)) continue;
        out.add(m);
      }
      out.sort((a, b) {
        final aa = DateTime.tryParse(a['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bb = DateTime.tryParse(b['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final c = aa.compareTo(bb);
        if (c != 0) return c;
        final ac = a['created_at'] as String? ?? '';
        final bc = b['created_at'] as String? ?? '';
        return ac.compareTo(bc);
      });
      return out;
    }

    final db = await database;
    return db.query(
      'consultations',
      where: 'baby_id = ? AND occurred_at >= ? AND occurred_at < ?',
      whereArgs: [babyId, startIso, endIso],
      orderBy: 'occurred_at ASC, created_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> listConsultations(
      {required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final filtered = _webReadList(prefs, 'consultations')
          .where((r) => (r['baby_id'] as num?)?.toInt() == babyId)
          .toList();
      filtered.sort((a, b) {
        final aa = DateTime.tryParse(a['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bb = DateTime.tryParse(b['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final c = bb.compareTo(aa);
        if (c != 0) return c;
        final ac = a['created_at'] as String? ?? '';
        final bc = b['created_at'] as String? ?? '';
        return bc.compareTo(ac);
      });
      return filtered;
    }
    final db = await database;
    return db.query(
      'consultations',
      where: 'baby_id = ?',
      whereArgs: [babyId],
      orderBy: 'occurred_at DESC, created_at DESC',
    );
  }

  /// Próxima consulta futura (por `occurred_at`), ou `null`.
  Future<Map<String, Object?>?> nextUpcomingConsultation(
      {required int babyId}) async {
    final nowIso = DateTime.now().toIso8601String();
    if (kIsWeb) {
      final prefs = await _webPrefs();
      Map<String, Object?>? best;
      DateTime? bestAt;
      for (final raw in _webReadList(prefs, 'consultations')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final oc = DateTime.tryParse(m['occurred_at'] as String? ?? '');
        if (oc == null || !oc.isAfter(DateTime.now())) continue;
        if (bestAt == null || oc.isBefore(bestAt)) {
          bestAt = oc;
          best = m;
        }
      }
      return best;
    }
    final db = await database;
    final rows = await db.query(
      'consultations',
      where: 'baby_id = ? AND occurred_at >= ?',
      whereArgs: [babyId, nowIso],
      orderBy: 'occurred_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> getConsultation(
      {required int id, required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      for (final raw in _webReadList(prefs, 'consultations')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['id'] as num?)?.toInt() == id &&
            (m['baby_id'] as num?)?.toInt() == babyId) {
          return m;
        }
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      'consultations',
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertConsultation({
    required int babyId,
    required String title,
    required DateTime occurredAt,
    String? notes,
    String? phone,
    String? address,
  }) async {
    final t = title.trim();
    if (t.isEmpty)
      throw ArgumentError.value(title, 'title', 'Must be non-empty');
    final n = notes?.trim().isEmpty == true ? null : notes?.trim();
    final ph = phone?.trim().isEmpty == true ? null : phone?.trim();
    final addr = address?.trim().isEmpty == true ? null : address?.trim();
    final created = DateTime.now().toIso8601String();

    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'consultations');
          final id = await _webNextId(prefs, 'consultations');
          list.insert(0, {
            'id': id,
            'baby_id': babyId,
            'title': t,
            'notes': n,
            'phone': ph,
            'address': addr,
            'occurred_at': occurredAt.toIso8601String(),
            'created_at': created,
          });
          await _webWriteList(prefs, 'consultations', list);
          return id;
        });
      }

      final db = await database;
      return await db.insert('consultations', {
        'baby_id': babyId,
        'title': t,
        'notes': n,
        'phone': ph,
        'address': addr,
        'occurred_at': occurredAt.toIso8601String(),
        'created_at': created,
      });
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<int> updateConsultation({
    required int id,
    required int babyId,
    required String title,
    required DateTime occurredAt,
    String? notes,
    String? phone,
    String? address,
  }) async {
    final t = title.trim();
    if (t.isEmpty)
      throw ArgumentError.value(title, 'title', 'Must be non-empty');
    final n = notes?.trim().isEmpty == true ? null : notes?.trim();
    final ph = phone?.trim().isEmpty == true ? null : phone?.trim();
    final addr = address?.trim().isEmpty == true ? null : address?.trim();

    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'consultations');
          final idx = list.indexWhere((raw) {
            final m = Map<String, Object?>.from(raw as Map);
            return ((m['id'] as num?)?.toInt() == id) &&
                ((m['baby_id'] as num?)?.toInt() == babyId);
          });
          if (idx < 0) return 0;
          final prev = Map<String, Object?>.from(list[idx] as Map);
          list[idx] = {
            ...prev,
            'title': t,
            'notes': n,
            'phone': ph,
            'address': addr,
            'occurred_at': occurredAt.toIso8601String(),
          };
          await _webWriteList(prefs, 'consultations', list);
          return 1;
        });
      }

      final db = await database;
      return await db.update(
        'consultations',
        {
          'title': t,
          'notes': n,
          'phone': ph,
          'address': addr,
          'occurred_at': occurredAt.toIso8601String(),
        },
        where: 'id = ? AND baby_id = ?',
        whereArgs: [id, babyId],
      );
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<int> deleteConsultation({required int id, required int babyId}) async {
    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'consultations');
          final before = list.length;
          list.removeWhere((raw) {
            final m = Map<String, Object?>.from(raw as Map);
            return ((m['id'] as num?)?.toInt() == id) &&
                ((m['baby_id'] as num?)?.toInt() == babyId);
          });
          if (list.length == before) return 0;
          await _webWriteList(prefs, 'consultations', list);
          return 1;
        });
      }
      final db = await database;
      return await db.delete(
        'consultations',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [id, babyId],
      );
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<List<Map<String, Object?>>> listSymptomReports(
      {required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final filtered = _webReadList(prefs, 'symptom_reports')
          .where((r) => (r['baby_id'] as num?)?.toInt() == babyId)
          .toList();
      filtered.sort((a, b) {
        final aa = DateTime.tryParse(a['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bb = DateTime.tryParse(b['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final c = bb.compareTo(aa);
        if (c != 0) return c;
        final ac = (a['id'] as num?)?.toInt() ?? 0;
        final bc = (b['id'] as num?)?.toInt() ?? 0;
        return bc.compareTo(ac);
      });
      return filtered;
    }
    final db = await database;
    return db.query(
      'symptom_reports',
      where: 'baby_id = ?',
      whereArgs: [babyId],
      orderBy: 'occurred_at DESC, id DESC',
    );
  }

  /// [periodEndInclusive] — último dia civil incluído; comparação por instante (`occurred_at`).
  Future<List<Map<String, Object?>>> listSymptomReportsInPeriod({
    required int babyId,
    required DateTime periodStart,
    required DateTime periodEndInclusive,
  }) async {
    final start =
        DateTime(periodStart.year, periodStart.month, periodStart.day);
    final endDay = DateTime(periodEndInclusive.year, periodEndInclusive.month,
        periodEndInclusive.day);
    final periodEndExclusive = endDay.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = periodEndExclusive.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final out = <Map<String, Object?>>[];
      for (final raw in _webReadList(prefs, 'symptom_reports')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final oc = DateTime.tryParse(m['occurred_at'] as String? ?? '');
        if (oc == null ||
            oc.isBefore(start) ||
            !oc.isBefore(periodEndExclusive)) continue;
        out.add(m);
      }
      out.sort((a, b) {
        final aa = DateTime.tryParse(a['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bb = DateTime.tryParse(b['occurred_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final c = aa.compareTo(bb);
        if (c != 0) return c;
        final ac = (a['id'] as num?)?.toInt() ?? 0;
        final bc = (b['id'] as num?)?.toInt() ?? 0;
        return ac.compareTo(bc);
      });
      return out;
    }

    final db = await database;
    return db.query(
      'symptom_reports',
      where: 'baby_id = ? AND occurred_at >= ? AND occurred_at < ?',
      whereArgs: [babyId, startIso, endIso],
      orderBy: 'occurred_at ASC, id ASC',
    );
  }

  Future<Map<String, Object?>?> getSymptomReport(
      {required int id, required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      for (final raw in _webReadList(prefs, 'symptom_reports')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['id'] as num?)?.toInt() == id &&
            (m['baby_id'] as num?)?.toInt() == babyId) {
          return m;
        }
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      'symptom_reports',
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertSymptomReport({
    required int babyId,
    required DateTime occurredAt,
    String? medicationNote,
    required bool fever,
    double? tempCelsius,
    required bool crying,
    required bool pain,
    required bool colic,
    required bool reflux,
    String? otherNote,
  }) async {
    final med =
        medicationNote?.trim().isEmpty == true ? null : medicationNote?.trim();
    final other = otherNote?.trim().isEmpty == true ? null : otherNote?.trim();
    final now = DateTime.now().toIso8601String();

    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'symptom_reports');
          final id = await _webNextId(prefs, 'symptom_reports');
          list.insert(0, {
            'id': id,
            'baby_id': babyId,
            'occurred_at': occurredAt.toIso8601String(),
            'medication_note': med,
            'fever': fever ? 1 : 0,
            'temp_celsius': tempCelsius,
            'crying': crying ? 1 : 0,
            'pain': pain ? 1 : 0,
            'colic': colic ? 1 : 0,
            'reflux': reflux ? 1 : 0,
            'other_note': other,
            'cloud_id': null,
            'created_at': now,
            'updated_at': now,
          });
          await _webWriteList(prefs, 'symptom_reports', list);
          return id;
        });
      }

      final db = await database;
      return await db.insert('symptom_reports', {
        'baby_id': babyId,
        'occurred_at': occurredAt.toIso8601String(),
        'medication_note': med,
        'fever': fever ? 1 : 0,
        'temp_celsius': tempCelsius,
        'crying': crying ? 1 : 0,
        'pain': pain ? 1 : 0,
        'colic': colic ? 1 : 0,
        'reflux': reflux ? 1 : 0,
        'other_note': other,
        'created_at': now,
        'updated_at': now,
      });
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<int> updateSymptomReport({
    required int id,
    required int babyId,
    required DateTime occurredAt,
    String? medicationNote,
    required bool fever,
    double? tempCelsius,
    required bool crying,
    required bool pain,
    required bool colic,
    required bool reflux,
    String? otherNote,
  }) async {
    final med =
        medicationNote?.trim().isEmpty == true ? null : medicationNote?.trim();
    final other = otherNote?.trim().isEmpty == true ? null : otherNote?.trim();
    final now = DateTime.now().toIso8601String();

    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'symptom_reports');
          final idx = list.indexWhere((raw) {
            final m = Map<String, Object?>.from(raw as Map);
            return ((m['id'] as num?)?.toInt() == id) &&
                ((m['baby_id'] as num?)?.toInt() == babyId);
          });
          if (idx < 0) return 0;
          final prev = Map<String, Object?>.from(list[idx] as Map);
          list[idx] = {
            ...prev,
            'occurred_at': occurredAt.toIso8601String(),
            'medication_note': med,
            'fever': fever ? 1 : 0,
            'temp_celsius': tempCelsius,
            'crying': crying ? 1 : 0,
            'pain': pain ? 1 : 0,
            'colic': colic ? 1 : 0,
            'reflux': reflux ? 1 : 0,
            'other_note': other,
            'updated_at': now,
          };
          await _webWriteList(prefs, 'symptom_reports', list);
          return 1;
        });
      }

      final db = await database;
      return await db.update(
        'symptom_reports',
        {
          'occurred_at': occurredAt.toIso8601String(),
          'medication_note': med,
          'fever': fever ? 1 : 0,
          'temp_celsius': tempCelsius,
          'crying': crying ? 1 : 0,
          'pain': pain ? 1 : 0,
          'colic': colic ? 1 : 0,
          'reflux': reflux ? 1 : 0,
          'other_note': other,
          'updated_at': now,
        },
        where: 'id = ? AND baby_id = ?',
        whereArgs: [id, babyId],
      );
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<int> deleteSymptomReport(
      {required int id, required int babyId}) async {
    try {
      if (kIsWeb) {
        return await _webSerialized(() async {
          final prefs = await _webPrefs();
          final list = _webReadList(prefs, 'symptom_reports');
          final before = list.length;
          list.removeWhere((raw) {
            final m = Map<String, Object?>.from(raw as Map);
            return ((m['id'] as num?)?.toInt() == id) &&
                ((m['baby_id'] as num?)?.toInt() == babyId);
          });
          if (list.length == before) return 0;
          await _webWriteList(prefs, 'symptom_reports', list);
          return 1;
        });
      }
      final db = await database;
      return await db.delete(
        'symptom_reports',
        where: 'id = ? AND baby_id = ?',
        whereArgs: [id, babyId],
      );
    } finally {
      HealthCalendarEvents.ping();
    }
  }

  Future<int> insertFeeding({
    required int babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    int? durationSec,
    String? side,
    String? type,
    double? quantityMl,
    String? note,
  }) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final feedings = _webReadList(prefs, 'feedings');
        final id = await _webNextId(prefs, 'feedings');
        final dur = durationSec ?? endedAt.difference(startedAt).inSeconds;
        feedings.insert(0, {
          'id': id,
          'baby_id': babyId,
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt.toIso8601String(),
          'duration_sec': dur < 0 ? 0 : dur,
          'side': side?.trim().isEmpty == true ? null : side?.trim(),
          'type': type?.trim().isEmpty == true ? null : type?.trim(),
          'quantity_ml': quantityMl,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
        await _webWriteList(prefs, 'feedings', feedings);
        FeedingEvents.ping();
        return id;
      });
    }
    final db = await database;
    final dur = durationSec ?? endedAt.difference(startedAt).inSeconds;
    final out = await db.insert('feedings', {
      'baby_id': babyId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_sec': dur < 0 ? 0 : dur,
      'side': side?.trim().isEmpty == true ? null : side?.trim(),
      'type': type?.trim().isEmpty == true ? null : type?.trim(),
      'quantity_ml': quantityMl,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    FeedingEvents.ping();
    return out;
  }

  static bool _rowIsBreastOrBottleForLatest(Map<String, Object?> row) {
    final rawType = ((row['type'] as String?) ?? '').trim();
    final t = rawType.toLowerCase();
    if (t == 'solidos') return false;
    if (rawType.isNotEmpty && t != 'peito' && t != 'mamadeira') return false;
    return true;
  }

  /// Último registro ao **peito** ou **mamadeira** pelo horário de término [ended_at] (ignora **sólidos**).
  ///
  /// Ordena sempre por **fim**, não pela lista truncada por `started_at`: assim, ao **excluir** o último registro,
  /// o “último” volta corretamente ao anterior (evita janela de N linhas errada).
  Future<DateTime?> latestBreastOrBottleFeedingEndedAt(
      {required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final feedings = _webReadList(prefs, 'feedings');
      DateTime? best;
      for (final row in feedings) {
        final m = Map<String, Object?>.from(row as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        if (!_rowIsBreastOrBottleForLatest(m)) continue;
        final endIso = m['ended_at'] as String?;
        if (endIso == null || endIso.trim().isEmpty) continue;
        final end = DateTime.tryParse(endIso);
        if (end == null) continue;
        if (best == null || end.isAfter(best)) best = end;
      }
      return best;
    }

    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT ended_at FROM feedings
      WHERE baby_id = ?
        AND TRIM(COALESCE(type, '')) != 'solidos'
        AND (
          TRIM(COALESCE(type, '')) = ''
          OR LOWER(TRIM(type)) = 'peito'
          OR LOWER(TRIM(type)) = 'mamadeira'
        )
      ORDER BY ended_at DESC
      LIMIT 1
      ''',
      [babyId],
    );
    if (rows.isEmpty) return null;
    final iso = rows.first['ended_at'] as String?;
    if (iso == null || iso.trim().isEmpty) return null;
    return _parseLocalDt(iso);
  }

  static String _formatSleepTotalSeconds(int totalSec) {
    if (totalSec <= 0) return '0m';
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m';
  }

  static String _formatWeightLabel(double kg) {
    String comma(String s) => s.replaceAll('.', ',');
    switch (MeasurementUnitsPrefs.weight.value) {
      case WeightUnit.kg:
        return '${comma(kg.toStringAsFixed(3))} kg';
      case WeightUnit.lb:
        final lb = kg * 2.2046226218;
        return '${comma(lb.toStringAsFixed(1))} lb';
      case WeightUnit.st:
        final st = (kg * 2.2046226218) / 14.0;
        return '${comma(st.toStringAsFixed(1))} st';
    }
  }

  /// Contagens do dia (calendário local) para o cartão «Resumo» na home.
  Future<DailySummary> dailySummaryForCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    Future<String> weightLabelForCalendarDay() async {
      Future<String> fallbackBirthWeightLabel() async {
        try {
          final baby = await getBabyById(babyId);
          final birth = (baby?['birth_weight_kg'] as num?)?.toDouble();
          final kg = (birth != null && birth > 0)
              ? birth
              : (baby?['weight_kg'] as num?)?.toDouble();
          if (kg != null && kg > 0) return _formatWeightLabel(kg);
        } catch (_) {}
        return '—';
      }

      if (kIsWeb) {
        final prefs = await _webPrefs();
        DateTime? bestT;
        double? bestV;
        for (final raw in _webReadList(prefs, 'growth_records')) {
          final m = Map<String, Object?>.from(raw as Map);
          if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
          if ((m['kind'] as String?)?.trim() != 'weight') continue;
          final mt = DateTime.tryParse(m['measured_at'] as String? ?? '');
          if (mt == null || mt.isBefore(start) || !mt.isBefore(end)) continue;
          final v = (m['value'] as num?)?.toDouble();
          if (v == null || v <= 0) continue;
          if (bestT == null || mt.isAfter(bestT)) {
            bestT = mt;
            bestV = v;
          }
        }
        if (bestV != null) return _formatWeightLabel(bestV);
        // Sem peso registado no dia: mostrar o último peso conhecido até o fim do dia.
        DateTime? bestAnyT;
        double? bestAnyV;
        for (final raw in _webReadList(prefs, 'growth_records')) {
          final m = Map<String, Object?>.from(raw as Map);
          if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
          if ((m['kind'] as String?)?.trim() != 'weight') continue;
          final mt = DateTime.tryParse(m['measured_at'] as String? ?? '');
          if (mt == null || !mt.isBefore(end)) continue;
          final v = (m['value'] as num?)?.toDouble();
          if (v == null || v <= 0) continue;
          if (bestAnyT == null || mt.isAfter(bestAnyT)) {
            bestAnyT = mt;
            bestAnyV = v;
          }
        }
        if (bestAnyV != null) return _formatWeightLabel(bestAnyV);
        return fallbackBirthWeightLabel();
      }
      final db = await database;
      final rows = await db.query(
        'growth_records',
        columns: ['value'],
        where:
            'baby_id = ? AND kind = ? AND measured_at >= ? AND measured_at < ?',
        whereArgs: [babyId, 'weight', startIso, endIso],
        orderBy: 'measured_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        // Sem peso registado no dia: mostrar o último peso conhecido até o fim do dia.
        final anyRows = await db.query(
          'growth_records',
          columns: ['value'],
          where: 'baby_id = ? AND kind = ? AND measured_at < ?',
          whereArgs: [babyId, 'weight', endIso],
          orderBy: 'measured_at DESC',
          limit: 1,
        );
        if (anyRows.isNotEmpty) {
          final anyV = (anyRows.first['value'] as num?)?.toDouble();
          if (anyV != null && anyV > 0) return _formatWeightLabel(anyV);
        }
        return fallbackBirthWeightLabel();
      }
      final v = (rows.first['value'] as num?)?.toDouble();
      if (v == null || v <= 0) return fallbackBirthWeightLabel();
      return _formatWeightLabel(v);
    }

    if (kIsWeb) {
      final prefs = await _webPrefs();
      var feedCount = 0;
      var feedDurationSec = 0;
      for (final raw in _webReadList(prefs, 'feedings')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        if (!_rowIsBreastOrBottleForLatest(m)) continue;
        final endAt = DateTime.tryParse(m['ended_at'] as String? ?? '');
        if (endAt == null || endAt.isBefore(start) || !endAt.isBefore(end))
          continue;
        feedCount++;
        feedDurationSec += (m['duration_sec'] as num?)?.toInt() ?? 0;
      }
      final feedingMin =
          feedDurationSec <= 0 ? 0 : ((feedDurationSec + 30) ~/ 60);

      var diaperCount = 0;
      var diaperPee = 0;
      var diaperPoo = 0;
      for (final raw in _webReadList(prefs, 'diapers')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final ch = DateTime.tryParse(m['changed_at'] as String? ?? '');
        if (ch == null || ch.isBefore(start) || !ch.isBefore(end)) continue;
        diaperCount++;
        final k = (m['kind'] as String?)?.trim().toLowerCase() ?? '';
        if (k == 'pee' || k == 'both') diaperPee++;
        if (k == 'poo' || k == 'both') diaperPoo++;
      }

      var sleepSec = 0;
      var sleepSessions = 0;
      for (final raw in _webReadList(prefs, 'sleep_records')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final endAt = DateTime.tryParse(m['ended_at'] as String? ?? '');
        if (endAt == null || endAt.isBefore(start) || !endAt.isBefore(end))
          continue;
        sleepSessions++;
        sleepSec += (m['duration_sec'] as num?)?.toInt() ?? 0;
      }
      final sleepStr = _formatSleepTotalSeconds(sleepSec);
      final wStr = await weightLabelForCalendarDay();
      return DailySummary(
        feedings: feedCount,
        feedingMinutesTotal: feedingMin,
        sleep: sleepStr,
        sleepSessions: sleepSessions,
        diapers: diaperCount,
        diaperPee: diaperPee,
        diaperPoo: diaperPoo,
        weight: wStr,
        sleepTotalSeconds: sleepSec,
      );
    }

    final db = await database;
    final feedRows = await db.rawQuery(
      '''
SELECT COUNT(*) AS c, IFNULL(SUM(duration_sec), 0) AS dur FROM feedings
WHERE baby_id = ?
  AND ended_at >= ? AND ended_at < ?
  AND LOWER(TRIM(COALESCE(type, ''))) != 'solidos'
  AND (
    TRIM(COALESCE(type, '')) = ''
    OR LOWER(TRIM(type)) = 'peito'
    OR LOWER(TRIM(type)) = 'mamadeira'
  )
''',
      [babyId, startIso, endIso],
    );
    final feedCount = (feedRows.first['c'] as num?)?.toInt() ?? 0;
    final feedDurRaw = feedRows.first['dur'];
    final feedDurSec = feedDurRaw == null ? 0 : (feedDurRaw as num).toInt();
    final feedingMin = feedDurSec <= 0 ? 0 : ((feedDurSec + 30) ~/ 60);

    final diaperRows = await db.rawQuery(
      '''
SELECT
  COUNT(*) AS c,
  SUM(CASE WHEN LOWER(TRIM(kind)) IN ('pee', 'both') THEN 1 ELSE 0 END) AS pee,
  SUM(CASE WHEN LOWER(TRIM(kind)) IN ('poo', 'both') THEN 1 ELSE 0 END) AS poo
FROM diapers
WHERE baby_id = ? AND changed_at >= ? AND changed_at < ?
''',
      [babyId, startIso, endIso],
    );
    final diaperCount = (diaperRows.first['c'] as num?)?.toInt() ?? 0;
    final diaperPee = (diaperRows.first['pee'] as num?)?.toInt() ?? 0;
    final diaperPoo = (diaperRows.first['poo'] as num?)?.toInt() ?? 0;

    final sleepRows = await db.rawQuery(
      '''
SELECT COUNT(*) AS n, IFNULL(SUM(duration_sec), 0) AS t FROM sleep_records
WHERE baby_id = ?
  AND ended_at IS NOT NULL AND TRIM(ended_at) != ''
  AND ended_at >= ? AND ended_at < ?
''',
      [babyId, startIso, endIso],
    );
    final sleepSessions = (sleepRows.first['n'] as num?)?.toInt() ?? 0;
    final sumRaw = sleepRows.first['t'];
    final sleepSec = sumRaw == null ? 0 : (sumRaw as num).toInt();
    final sleepStr = _formatSleepTotalSeconds(sleepSec);
    final wStr = await weightLabelForCalendarDay();

    return DailySummary(
      feedings: feedCount,
      feedingMinutesTotal: feedingMin,
      sleep: sleepStr,
      sleepSessions: sleepSessions,
      diapers: diaperCount,
      diaperPee: diaperPee,
      diaperPoo: diaperPoo,
      weight: wStr,
      sleepTotalSeconds: sleepSec,
    );
  }

  /// Chave estável `yyyy-mm-dd` para snapshots do resumo diário.
  static String calendarDayKey(DateTime calendarDay) {
    return '${calendarDay.year}-${calendarDay.month.toString().padLeft(2, '0')}-${calendarDay.day.toString().padLeft(2, '0')}';
  }

  Future<DailySummary?> getDailySummarySnapshot({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    if (kIsWeb) return null;
    final db = await database;
    final key = calendarDayKey(calendarDay);
    final rows = await db.query(
      'daily_summary_snapshots',
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [babyId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final sleepSec = (r['sleep_total_sec'] as num?)?.toInt() ?? 0;
    return DailySummary(
      feedings: (r['feedings'] as num?)?.toInt() ?? 0,
      feedingMinutesTotal: (r['feeding_minutes_total'] as num?)?.toInt() ?? 0,
      sleep: _formatSleepTotalSeconds(sleepSec),
      sleepSessions: (r['sleep_sessions'] as num?)?.toInt() ?? 0,
      diapers: (r['diapers'] as num?)?.toInt() ?? 0,
      diaperPee: (r['diaper_pee'] as num?)?.toInt() ?? 0,
      diaperPoo: (r['diaper_poo'] as num?)?.toInt() ?? 0,
      weight: (r['weight_label'] as String?) ?? '—',
      sleepTotalSeconds: sleepSec,
    );
  }

  Future<void> upsertDailySummarySnapshot({
    required int babyId,
    required DateTime calendarDay,
    required DailySummary summary,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    final key = calendarDayKey(calendarDay);
    await db.insert(
      'daily_summary_snapshots',
      {
        'baby_id': babyId,
        'day_key': key,
        'feedings': summary.feedings,
        'feeding_minutes_total': summary.feedingMinutesTotal,
        'diapers': summary.diapers,
        'diaper_pee': summary.diaperPee,
        'diaper_poo': summary.diaperPoo,
        'sleep_sessions': summary.sleepSessions,
        'sleep_total_sec': summary.sleepTotalSeconds,
        'weight_label': summary.weight,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Grava o resumo de **ontem** uma vez (dia civil já encerrado), para histórico estável.
  Future<void> ensureYesterdayDailySummarySnapshot(
      {required int babyId}) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final existing =
        await getDailySummarySnapshot(babyId: babyId, calendarDay: yesterday);
    if (existing != null) return;
    final s = await dailySummaryForCalendarDay(
        babyId: babyId, calendarDay: yesterday);
    await upsertDailySummarySnapshot(
        babyId: babyId, calendarDay: yesterday, summary: s);
  }

  /// Resumo para a Home: dias passados preferem snapshot gravado; hoje é sempre em tempo real.
  Future<DailySummary> dailySummaryForHomePicker({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final day = DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!day.isBefore(today)) {
      return dailySummaryForCalendarDay(babyId: babyId, calendarDay: day);
    }
    if (kIsWeb) {
      return dailySummaryForCalendarDay(babyId: babyId, calendarDay: day);
    }
    final snap =
        await getDailySummarySnapshot(babyId: babyId, calendarDay: day);
    bool looksEmpty(DailySummary s) {
      final w = s.weight.trim();
      final weightEmpty = w.isEmpty || w == '—' || w.toLowerCase() == 'null';
      return s.feedings == 0 &&
          s.feedingMinutesTotal == 0 &&
          s.diapers == 0 &&
          s.sleepTotalSeconds == 0 &&
          weightEmpty;
    }

    // Se o snapshot existe mas está vazio, ele pode ter sido gravado cedo demais
    // (ex.: logo após reinstalar, antes da hidratação do Firestore preencher eventos).
    // Nesse caso, recalculamos e substituímos para não "travar" o dia como zerado.
    if (snap != null && !looksEmpty(snap)) return snap;

    final computed =
        await dailySummaryForCalendarDay(babyId: babyId, calendarDay: day);
    if (snap == null || looksEmpty(snap) || !looksEmpty(computed)) {
      await upsertDailySummarySnapshot(
          babyId: babyId, calendarDay: day, summary: computed);
    }
    return computed;
  }

  Future<DateTime?> latestBreastOrBottleFeedingEndedOnCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      DateTime? best;
      for (final raw in _webReadList(prefs, 'feedings')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        if (!_rowIsBreastOrBottleForLatest(m)) continue;
        final endAt = DateTime.tryParse(m['ended_at'] as String? ?? '');
        if (endAt == null || endAt.isBefore(start) || !endAt.isBefore(end))
          continue;
        if (best == null || endAt.isAfter(best)) best = endAt;
      }
      return best;
    }

    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT ended_at FROM feedings
WHERE baby_id = ?
  AND ended_at >= ? AND ended_at < ?
  AND LOWER(TRIM(COALESCE(type, ''))) != 'solidos'
  AND (
    TRIM(COALESCE(type, '')) = ''
    OR LOWER(TRIM(type)) = 'peito'
    OR LOWER(TRIM(type)) = 'mamadeira'
  )
ORDER BY ended_at DESC
LIMIT 1
''',
      [babyId, startIso, endIso],
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['ended_at'] as String? ?? '');
  }

  Future<DateTime?> latestDiaperChangedAtOnCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      DateTime? best;
      for (final raw in _webReadList(prefs, 'diapers')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final ch = DateTime.tryParse(m['changed_at'] as String? ?? '');
        if (ch == null || ch.isBefore(start) || !ch.isBefore(end)) continue;
        if (best == null || ch.isAfter(best)) best = ch;
      }
      return best;
    }

    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT changed_at FROM diapers
WHERE baby_id = ? AND changed_at >= ? AND changed_at < ?
ORDER BY changed_at DESC
LIMIT 1
''',
      [babyId, startIso, endIso],
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['changed_at'] as String? ?? '');
  }

  Future<DateTime?> latestCompletedSleepEndOnCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      DateTime? best;
      for (final raw in _webReadList(prefs, 'sleep_records')) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final endAt = DateTime.tryParse(m['ended_at'] as String? ?? '');
        if (endAt == null || endAt.isBefore(start) || !endAt.isBefore(end))
          continue;
        if (best == null || endAt.isAfter(best)) best = endAt;
      }
      return best;
    }

    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT ended_at FROM sleep_records
WHERE baby_id = ?
  AND ended_at IS NOT NULL AND TRIM(ended_at) != ''
  AND ended_at >= ? AND ended_at < ?
ORDER BY ended_at DESC
LIMIT 1
''',
      [babyId, startIso, endIso],
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['ended_at'] as String? ?? '');
  }

  Future<List<Map<String, Object?>>> listFeedings({
    required int babyId,
    int limit = 50,
    DateTime? startedSince,
  }) async {
    bool sinceOk(DateTime dt) =>
        startedSince == null ? true : !dt.isBefore(startedSince);

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final feedings = _webReadList(prefs, 'feedings');
      final list = feedings
          .where((f) => (f['baby_id'] as num?)?.toInt() == babyId)
          .where((f) {
            final iso = f['started_at'] as String?;
            final dt = DateTime.tryParse(iso ?? '');
            return dt != null && sinceOk(dt);
          })
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();
      list.sort((a, b) {
        final as = (a['started_at'] as String?) ?? '';
        final bs = (b['started_at'] as String?) ?? '';
        return bs.compareTo(as);
      });
      return list.take(limit).toList();
    }
    final db = await database;
    final whereParts = <String>['baby_id = ?'];
    final whereArgs = <Object>[babyId];
    if (startedSince != null) {
      whereParts.add('started_at >= ?');
      whereArgs.add(startedSince.toIso8601String());
    }
    return db.query(
      'feedings',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }

  Future<int> updateFeeding({
    required int id,
    required int babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    int? durationSec,
    String? side,
    String? type,
    double? quantityMl,
    String? note,
  }) async {
    final dur = durationSec ?? endedAt.difference(startedAt).inSeconds;
    final trimmedSide = side?.trim().isEmpty == true ? null : side?.trim();
    final trimmedType = type?.trim().isEmpty == true ? null : type?.trim();
    final trimmedNote = note?.trim().isEmpty == true ? null : note?.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final feedings = _webReadList(prefs, 'feedings');
        final idx =
            feedings.indexWhere((f) => (f['id'] as num?)?.toInt() == id);
        if (idx < 0) return 0;
        final existing = Map<String, Object?>.from(feedings[idx] as Map);
        if ((existing['baby_id'] as num?)?.toInt() != babyId) return 0;
        feedings[idx] = {
          ...existing,
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt.toIso8601String(),
          'duration_sec': dur < 0 ? 0 : dur,
          'side': trimmedSide,
          'type': trimmedType,
          'quantity_ml': quantityMl,
          'note': trimmedNote,
        };
        await _webWriteList(prefs, 'feedings', feedings);
        FeedingEvents.ping();
        return 1;
      });
    }

    final db = await database;
    final n = await db.update(
      'feedings',
      {
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_sec': dur < 0 ? 0 : dur,
        'side': trimmedSide,
        'type': trimmedType,
        'quantity_ml': quantityMl,
        'note': trimmedNote,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
    if (n > 0) FeedingEvents.ping();
    return n;
  }

  Future<int> deleteFeeding({required int id, required int babyId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final feedings = _webReadList(prefs, 'feedings');
        final before = feedings.length;
        feedings.removeWhere((f) {
          final m = Map<String, Object?>.from(f as Map);
          return ((m['id'] as num?)?.toInt() == id) &&
              ((m['baby_id'] as num?)?.toInt() == babyId);
        });
        if (feedings.length == before) return 0;
        await _webWriteList(prefs, 'feedings', feedings);
        FeedingEvents.ping();
        return 1;
      });
    }

    final db = await database;
    final n = await db.delete(
      'feedings',
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
    if (n > 0) FeedingEvents.ping();
    return n;
  }

  Future<int> insertDiaperChange({
    required int babyId,
    required DateTime changedAt,
    required String kind, // 'pee' | 'poo' | 'both'
    String? note,
  }) async {
    final k = kind.trim().toLowerCase();
    if (k != 'pee' && k != 'poo' && k != 'both') {
      throw ArgumentError.value(kind, 'kind', 'Expected pee|poo|both');
    }

    final trimmedNote = note?.trim().isEmpty == true ? null : note?.trim();
    final createdAt = DateTime.now().toIso8601String();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'diapers');
        final id = await _webNextId(prefs, 'diapers');
        list.insert(0, {
          'id': id,
          'baby_id': babyId,
          'changed_at': changedAt.toIso8601String(),
          'kind': k,
          'note': trimmedNote,
          'created_at': createdAt,
        });
        await _webWriteList(prefs, 'diapers', list);
        DiaperEvents.ping();
        return id;
      });
    }

    final db = await database;
    final out = await db.insert('diapers', {
      'baby_id': babyId,
      'changed_at': changedAt.toIso8601String(),
      'kind': k,
      'note': trimmedNote,
      'created_at': createdAt,
    });
    DiaperEvents.ping();
    return out;
  }

  Future<DateTime?> latestDiaperChangedAt({required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'diapers');
      DateTime? best;
      for (final row in list) {
        final m = Map<String, Object?>.from(row as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final raw = (m['changed_at'] as String?) ?? '';
        final dt = DateTime.tryParse(raw);
        if (dt == null) continue;
        if (best == null || dt.isAfter(best)) best = dt;
      }
      return best;
    }

    final db = await database;
    final rows = await db.query(
      'diapers',
      columns: const ['changed_at'],
      where: 'baby_id = ?',
      whereArgs: [babyId],
      orderBy: 'changed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['changed_at'] as String?;
    return _parseLocalDt(raw);
  }

  /// Último registo que inclui xixi (`pee` ou `both`).
  Future<DateTime?> latestDiaperPeeRelatedAt({required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'diapers');
      DateTime? best;
      for (final row in list) {
        final m = Map<String, Object?>.from(row as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final kind = (m['kind'] as String?)?.trim().toLowerCase() ?? '';
        if (kind != 'pee' && kind != 'both') continue;
        final raw = (m['changed_at'] as String?) ?? '';
        final dt = DateTime.tryParse(raw);
        if (dt == null) continue;
        if (best == null || dt.isAfter(best)) best = dt;
      }
      return best;
    }
    final db = await database;
    final rows = await db.query(
      'diapers',
      columns: const ['changed_at'],
      where: 'baby_id = ? AND (kind = ? OR kind = ?)',
      whereArgs: [babyId, 'pee', 'both'],
      orderBy: 'changed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['changed_at'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Último registo que inclui cocô (`poo` ou `both`).
  Future<DateTime?> latestDiaperPooRelatedAt({required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'diapers');
      DateTime? best;
      for (final row in list) {
        final m = Map<String, Object?>.from(row as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final kind = (m['kind'] as String?)?.trim().toLowerCase() ?? '';
        if (kind != 'poo' && kind != 'both') continue;
        final raw = (m['changed_at'] as String?) ?? '';
        final dt = DateTime.tryParse(raw);
        if (dt == null) continue;
        if (best == null || dt.isAfter(best)) best = dt;
      }
      return best;
    }
    final db = await database;
    final rows = await db.query(
      'diapers',
      columns: const ['changed_at'],
      where: 'baby_id = ? AND (kind = ? OR kind = ?)',
      whereArgs: [babyId, 'poo', 'both'],
      orderBy: 'changed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['changed_at'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<List<Map<String, Object?>>> listDiapers(
      {required int babyId, int limit = 100}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'diapers');
      final filtered =
          list.where((r) => (r['baby_id'] as num?)?.toInt() == babyId).toList();
      filtered.sort((a, b) {
        final am = a['changed_at'] as String? ?? '';
        final bm = b['changed_at'] as String? ?? '';
        return bm.compareTo(am);
      });
      return filtered.take(limit).toList();
    }
    final db = await database;
    return db.query(
      'diapers',
      where: 'baby_id = ?',
      whereArgs: [babyId],
      orderBy: 'changed_at DESC',
      limit: limit,
    );
  }

  Future<int> updateDiaper({
    required int id,
    required int babyId,
    required DateTime changedAt,
    required String kind,
    String? note,
  }) async {
    final k = kind.trim().toLowerCase();
    if (k != 'pee' && k != 'poo' && k != 'both') {
      throw ArgumentError.value(kind, 'kind', 'Expected pee|poo|both');
    }
    final trimmedNote = note?.trim().isEmpty == true ? null : note?.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'diapers');
        final idx = list.indexWhere((raw) {
          final m = Map<String, Object?>.from(raw as Map);
          return ((m['id'] as num?)?.toInt() == id) &&
              ((m['baby_id'] as num?)?.toInt() == babyId);
        });
        if (idx < 0) return 0;
        final prev = Map<String, Object?>.from(list[idx] as Map);
        list[idx] = {
          ...prev,
          'changed_at': changedAt.toIso8601String(),
          'kind': k,
          'note': trimmedNote,
        };
        await _webWriteList(prefs, 'diapers', list);
        DiaperEvents.ping();
        return 1;
      });
    }

    final db = await database;
    final n = await db.update(
      'diapers',
      {
        'changed_at': changedAt.toIso8601String(),
        'kind': k,
        'note': trimmedNote,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
    if (n > 0) DiaperEvents.ping();
    return n;
  }

  Future<int> deleteDiaper({required int id, required int babyId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'diapers');
        final before = list.length;
        list.removeWhere((raw) {
          final m = Map<String, Object?>.from(raw as Map);
          return ((m['id'] as num?)?.toInt() == id) &&
              ((m['baby_id'] as num?)?.toInt() == babyId);
        });
        if (list.length == before) return 0;
        await _webWriteList(prefs, 'diapers', list);
        DiaperEvents.ping();
        return 1;
      });
    }
    final db = await database;
    final n = await db.delete(
      'diapers',
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
    if (n > 0) DiaperEvents.ping();
    return n;
  }

  Future<int> insertGrowthRecord({
    required int babyId,
    required String kind, // 'weight' | 'height' | 'head'
    required double value,
    DateTime? measuredAt,
  }) async {
    final k = kind.trim().toLowerCase();
    if (k != 'weight' && k != 'height' && k != 'head') {
      throw ArgumentError.value(kind, 'kind', 'Expected weight|height|head');
    }
    final measured = (measuredAt ?? DateTime.now()).toIso8601String();
    final created = DateTime.now().toIso8601String();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'growth_records');
        final id = await _webNextId(prefs, 'growth_records');
        list.insert(0, {
          'id': id,
          'baby_id': babyId,
          'kind': k,
          'value': value,
          'measured_at': measured,
          'created_at': created,
        });
        await _webWriteList(prefs, 'growth_records', list);
        return id;
      });
    }

    final db = await database;
    return db.insert('growth_records', {
      'baby_id': babyId,
      'kind': k,
      'value': value,
      'measured_at': measured,
      'created_at': created,
    });
  }

  Future<List<Map<String, Object?>>> listGrowthRecords({
    required int babyId,
    required String kind, // 'weight' | 'height' | 'head'
    int limit = 120,
  }) async {
    final k = kind.trim().toLowerCase();
    if (k != 'weight' && k != 'height' && k != 'head') {
      throw ArgumentError.value(kind, 'kind', 'Expected weight|height|head');
    }

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'growth_records');
      final filtered = list.where((r) {
        return (r['baby_id'] as num?)?.toInt() == babyId &&
            (r['kind'] as String?) == k;
      }).toList();
      filtered.sort((a, b) {
        final am = a['measured_at'] as String?;
        final bm = b['measured_at'] as String?;
        return (bm ?? '').compareTo(am ?? '');
      });
      return filtered.take(limit).toList();
    }

    final db = await database;
    return db.query(
      'growth_records',
      where: 'baby_id = ? AND kind = ?',
      whereArgs: [babyId, k],
      orderBy: 'measured_at DESC, created_at DESC',
      limit: limit,
    );
  }

  Future<int> deleteGrowthRecord({required int id, required int babyId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'growth_records');
        final before = list.length;
        list.removeWhere((raw) {
          final m = Map<String, Object?>.from(raw as Map);
          return ((m['id'] as num?)?.toInt() == id) &&
              ((m['baby_id'] as num?)?.toInt() == babyId);
        });
        if (list.length == before) return 0;
        await _webWriteList(prefs, 'growth_records', list);
        return 1;
      });
    }
    final db = await database;
    return db.delete(
      'growth_records',
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
  }

  Future<int> updateGrowthRecord({
    required int id,
    required int babyId,
    required double value,
    required DateTime measuredAt,
  }) async {
    if (value <= 0)
      throw ArgumentError.value(value, 'value', 'Must be positive');
    final iso = measuredAt.toIso8601String();
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'growth_records');
        final idx = list.indexWhere((raw) {
          final m = Map<String, Object?>.from(raw as Map);
          return ((m['id'] as num?)?.toInt() == id) &&
              ((m['baby_id'] as num?)?.toInt() == babyId);
        });
        if (idx < 0) return 0;
        final prev = Map<String, Object?>.from(list[idx] as Map);
        list[idx] = {
          ...prev,
          'value': value,
          'measured_at': iso,
        };
        await _webWriteList(prefs, 'growth_records', list);
        return 1;
      });
    }
    final db = await database;
    return db.update(
      'growth_records',
      {'value': value, 'measured_at': iso},
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
  }

  Future<int> insertSleepRecord({
    required int babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSec,
    String? quality,
    String? note,
  }) async {
    if (durationSec < 1)
      throw ArgumentError.value(durationSec, 'durationSec', 'Must be positive');
    final created = DateTime.now().toIso8601String();
    final q =
        (quality == null || quality.trim().isEmpty) ? 'good' : quality.trim();
    final n = (note == null || note.trim().isEmpty) ? null : note.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'sleep_records');
        final id = await _webNextId(prefs, 'sleep_records');
        list.insert(0, {
          'id': id,
          'baby_id': babyId,
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt.toIso8601String(),
          'duration_sec': durationSec,
          'quality': q,
          'note': n,
          'created_at': created,
        });
        await _webWriteList(prefs, 'sleep_records', list);
        SleepEvents.ping();
        return id;
      });
    }

    final db = await database;
    final id = await db.insert(
      'sleep_records',
      {
        'baby_id': babyId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_sec': durationSec,
        'quality': q,
        'note': n,
        'created_at': created,
      },
    );
    SleepEvents.ping();
    return id;
  }

  Future<List<Map<String, Object?>>> listSleepRecords({
    required int babyId,
    int limit = 50,
  }) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'sleep_records');
      final filtered =
          list.where((r) => (r['baby_id'] as num?)?.toInt() == babyId).toList();
      filtered.sort((a, b) {
        final am = a['ended_at'] as String? ?? '';
        final bm = b['ended_at'] as String? ?? '';
        return bm.compareTo(am);
      });
      return filtered.take(limit).toList();
    }
    final db = await database;
    return db.query(
      'sleep_records',
      where: 'baby_id = ?',
      whereArgs: [babyId],
      orderBy: 'ended_at DESC',
      limit: limit,
    );
  }

  /// Sonos com `ended_at` dentro do dia civil local (para relatórios / gráficos).
  Future<List<Map<String, Object?>>> listSleepRecordsForCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'sleep_records');
      final out = <Map<String, Object?>>[];
      for (final raw in list) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final endAt = DateTime.tryParse(m['ended_at'] as String? ?? '');
        if (endAt == null || endAt.isBefore(start) || !endAt.isBefore(end))
          continue;
        out.add(m);
      }
      out.sort((a, b) {
        final as = a['started_at'] as String? ?? '';
        final bs = b['started_at'] as String? ?? '';
        return as.compareTo(bs);
      });
      return out;
    }
    final db = await database;
    return db.query(
      'sleep_records',
      where:
          'baby_id = ? AND ended_at >= ? AND ended_at < ? AND ended_at IS NOT NULL AND TRIM(ended_at) != ?',
      whereArgs: [babyId, startIso, endIso, ''],
      orderBy: 'started_at ASC',
    );
  }

  /// Mamadas peito/mamadeira do dia civil local (mesmo critério do resumo diário).
  Future<List<Map<String, Object?>>> listBreastBottleFeedingsForCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final feedings = _webReadList(prefs, 'feedings');
      final out = <Map<String, Object?>>[];
      for (final raw in feedings) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        if (!_rowIsBreastOrBottleForLatest(m)) continue;
        final endAt = DateTime.tryParse(m['ended_at'] as String? ?? '');
        if (endAt == null || endAt.isBefore(start) || !endAt.isBefore(end))
          continue;
        out.add(m);
      }
      out.sort((a, b) {
        final ae = a['ended_at'] as String? ?? '';
        final be = b['ended_at'] as String? ?? '';
        return ae.compareTo(be);
      });
      return out;
    }
    final db = await database;
    return db.rawQuery(
      '''
SELECT * FROM feedings
WHERE baby_id = ?
  AND ended_at >= ? AND ended_at < ?
  AND LOWER(TRIM(COALESCE(type, ''))) != 'solidos'
  AND (
    TRIM(COALESCE(type, '')) = ''
    OR LOWER(TRIM(type)) = 'peito'
    OR LOWER(TRIM(type)) = 'mamadeira'
  )
ORDER BY ended_at ASC
''',
      [babyId, startIso, endIso],
    );
  }

  Future<List<Map<String, Object?>>> listDiapersForCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'diapers');
      final out = <Map<String, Object?>>[];
      for (final raw in list) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final ch = DateTime.tryParse(m['changed_at'] as String? ?? '');
        if (ch == null || ch.isBefore(start) || !ch.isBefore(end)) continue;
        out.add(m);
      }
      out.sort((a, b) {
        final ac = a['changed_at'] as String? ?? '';
        final bc = b['changed_at'] as String? ?? '';
        return ac.compareTo(bc);
      });
      return out;
    }
    final db = await database;
    return db.query(
      'diapers',
      where: 'baby_id = ? AND changed_at >= ? AND changed_at < ?',
      whereArgs: [babyId, startIso, endIso],
      orderBy: 'changed_at ASC',
    );
  }

  /// Humores registados em memórias do dia (`day_key` ou intervalo de `memory_date`).
  Future<List<String>> listMemoryMoodsForCalendarDay({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final key = _dayKey(calendarDay);
    final start =
        DateTime(calendarDay.year, calendarDay.month, calendarDay.day);
    final end = start.add(const Duration(days: 1));
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final memories = _webReadList(prefs, 'memories');
      final out = <String>[];
      for (final raw in memories) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final dk = (m['day_key'] as String?)?.trim();
        final memDt = DateTime.tryParse(m['memory_date'] as String? ?? '');
        final inDay = dk == key ||
            (memDt != null && !memDt.isBefore(start) && memDt.isBefore(end));
        if (!inDay) continue;
        final mood = (m['mood_at_moment'] as String?)?.trim();
        if (mood == null || mood.isEmpty) continue;
        out.add(mood);
      }
      return out;
    }
    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT mood_at_moment FROM memories
WHERE baby_id = ?
  AND mood_at_moment IS NOT NULL AND TRIM(mood_at_moment) != ''
  AND (
    day_key = ?
    OR (memory_date >= ? AND memory_date < ?)
  )
''',
      [babyId, key, startIso, endIso],
    );
    final out = <String>[];
    for (final r in rows) {
      final m = (r['mood_at_moment'] as String?)?.trim();
      if (m != null && m.isNotEmpty) out.add(m);
    }
    return out;
  }

  /// Data/hora do último sono **terminado** (`ended_at` válido). Usado na home para a barra de vigília.
  Future<DateTime?> latestCompletedSleepEnd({required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'sleep_records');
      final filtered =
          list.where((r) => (r['baby_id'] as num?)?.toInt() == babyId).toList();
      filtered.sort((a, b) {
        final am = a['ended_at'] as String? ?? '';
        final bm = b['ended_at'] as String? ?? '';
        return bm.compareTo(am);
      });
      for (final r in filtered) {
        final e = DateTime.tryParse(r['ended_at'] as String? ?? '');
        if (e != null) return e;
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      'sleep_records',
      columns: ['ended_at'],
      where: 'baby_id = ? AND ended_at IS NOT NULL AND TRIM(ended_at) != ?',
      whereArgs: [babyId, ''],
      orderBy: 'ended_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _parseLocalDt(rows.first['ended_at'] as String?);
  }

  Future<int> updateSleepRecord({
    required int id,
    required int babyId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSec,
    String? quality,
    String? note,
  }) async {
    if (durationSec < 1)
      throw ArgumentError.value(durationSec, 'durationSec', 'Must be positive');
    final q =
        (quality == null || quality.trim().isEmpty) ? 'good' : quality.trim();
    final n = (note == null || note.trim().isEmpty) ? null : note.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'sleep_records');
        final idx = list.indexWhere((raw) {
          final m = Map<String, Object?>.from(raw as Map);
          return ((m['id'] as num?)?.toInt() == id) &&
              ((m['baby_id'] as num?)?.toInt() == babyId);
        });
        if (idx < 0) return 0;
        final prev = Map<String, Object?>.from(list[idx] as Map);
        list[idx] = {
          ...prev,
          'started_at': startedAt.toIso8601String(),
          'ended_at': endedAt.toIso8601String(),
          'duration_sec': durationSec,
          'quality': q,
          'note': n,
        };
        await _webWriteList(prefs, 'sleep_records', list);
        SleepEvents.ping();
        return 1;
      });
    }

    final db = await database;
    final out = await db.update(
      'sleep_records',
      {
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_sec': durationSec,
        'quality': q,
        'note': n,
      },
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
    if (out > 0) SleepEvents.ping();
    return out;
  }

  Future<int> deleteSleepRecord({required int id, required int babyId}) async {
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'sleep_records');
        final before = list.length;
        list.removeWhere((raw) {
          final m = Map<String, Object?>.from(raw as Map);
          return ((m['id'] as num?)?.toInt() == id) &&
              ((m['baby_id'] as num?)?.toInt() == babyId);
        });
        if (list.length == before) return 0;
        await _webWriteList(prefs, 'sleep_records', list);
        SleepEvents.ping();
        return 1;
      });
    }
    final db = await database;
    final n = await db.delete(
      'sleep_records',
      where: 'id = ? AND baby_id = ?',
      whereArgs: [id, babyId],
    );
    if (n > 0) SleepEvents.ping();
    return n;
  }

  String _dayKey(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<String?> getDailyJournalText({
    required int babyId,
    required DateTime calendarDay,
  }) async {
    final key = _dayKey(calendarDay);
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final list = _webReadList(prefs, 'daily_journals');
      for (final raw in list) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() == babyId &&
            (m['day_key'] as String?) == key) {
          return (m['text'] as String?)?.trim();
        }
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      'daily_journals',
      columns: const ['text'],
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [babyId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['text'] as String?)?.trim();
  }

  Future<void> upsertDailyJournalText({
    required int babyId,
    required DateTime calendarDay,
    required String? text,
  }) async {
    final key = _dayKey(calendarDay);
    final nowIso = DateTime.now().toIso8601String();
    final t = text?.trim();
    final stored = (t == null || t.isEmpty) ? null : t;

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final list = _webReadList(prefs, 'daily_journals');
        for (final row in list) {
          final m = Map<String, Object?>.from(row as Map);
          if ((m['baby_id'] as num?)?.toInt() == babyId &&
              (m['day_key'] as String?) == key) {
            m['text'] = stored;
            m['updated_at'] = nowIso;
            await _webWriteList(prefs, 'daily_journals', list);
            return;
          }
        }
        final id = await _webNextId(prefs, 'daily_journals');
        list.insert(0, {
          'id': id,
          'baby_id': babyId,
          'day_key': key,
          'text': stored,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        await _webWriteList(prefs, 'daily_journals', list);
      });
    }

    final db = await database;
    final existing = await db.query(
      'daily_journals',
      columns: const ['id'],
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [babyId, key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = (existing.first['id'] as num).toInt();
      await db.update(
        'daily_journals',
        {'text': stored, 'updated_at': nowIso},
        where: 'id = ?',
        whereArgs: [id],
      );
      return;
    }
    await db.insert('daily_journals', {
      'baby_id': babyId,
      'day_key': key,
      'text': stored,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
  }

  /// Memórias com `memory_date` em \[startInclusive, endExclusive).
  Future<List<Map<String, Object?>>> listMemoriesInDateRange({
    required int babyId,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final startIso = startInclusive.toIso8601String();
    final endIso = endExclusive.toIso8601String();

    if (kIsWeb) {
      final prefs = await _webPrefs();
      final memories = _webReadList(prefs, 'memories');
      final out = <Map<String, Object?>>[];
      for (final raw in memories) {
        final m = Map<String, Object?>.from(raw as Map);
        if ((m['baby_id'] as num?)?.toInt() != babyId) continue;
        final md = DateTime.tryParse(m['memory_date'] as String? ?? '');
        if (md == null ||
            md.isBefore(startInclusive) ||
            !md.isBefore(endExclusive)) continue;
        out.add(m);
      }
      out.sort((a, b) {
        final am = a['memory_date'] as String? ?? '';
        final bm = b['memory_date'] as String? ?? '';
        return am.compareTo(bm);
      });
      return out;
    }
    final db = await database;
    return db.query(
      'memories',
      where: 'baby_id = ? AND memory_date >= ? AND memory_date < ?',
      whereArgs: [babyId, startIso, endIso],
      orderBy: 'memory_date ASC',
    );
  }

  Future<Map<String, Object?>?> getDailyMemory(
      {required int babyId, DateTime? day}) async {
    final key = _dayKey(day ?? DateTime.now());
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final memories = _webReadList(prefs, 'memories');
      for (final m in memories) {
        if ((m['baby_id'] as num?)?.toInt() == babyId &&
            (m['day_key'] as String?) == key) {
          return m;
        }
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      'memories',
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [babyId, key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> upsertDailyMemoryPhoto({
    required int babyId,
    required String photoB64,
    DateTime? day,
  }) async {
    final key = _dayKey(day ?? DateTime.now());
    final created = DateTime.now().toIso8601String();
    final pb = photoB64.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final memories = _webReadList(prefs, 'memories');
        for (final m in memories) {
          if ((m['baby_id'] as num?)?.toInt() == babyId &&
              (m['day_key'] as String?) == key) {
            m['photo_b64'] = pb;
            m['title'] = m['title'] ?? 'Foto do dia';
            m['emoji'] = m['emoji'] ?? '📸';
            m['happened_at'] =
                m['happened_at'] ?? (day ?? DateTime.now()).toIso8601String();
            await _webWriteList(prefs, 'memories', memories);
            return (m['id'] as num?)?.toInt() ?? 0;
          }
        }
        final id = await _webNextId(prefs, 'memories');
        memories.insert(0, {
          'id': id,
          'baby_id': babyId,
          'title': 'Foto do dia',
          'description': null,
          'emoji': '📸',
          'happened_at': (day ?? DateTime.now()).toIso8601String(),
          'photo_path': null,
          'day_key': key,
          'photo_b64': pb,
          'created_at': created,
        });
        await _webWriteList(prefs, 'memories', memories);
        return id;
      });
    }

    final db = await database;
    final existing = await db.query(
      'memories',
      columns: ['id'],
      where: 'baby_id = ? AND day_key = ?',
      whereArgs: [babyId, key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = (existing.first['id'] as num).toInt();
      await db.update(
        'memories',
        {'photo_b64': pb},
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    return db.insert('memories', {
      'baby_id': babyId,
      'title': 'Foto do dia',
      'description': null,
      'emoji': '📸',
      'happened_at': (day ?? DateTime.now()).toIso8601String(),
      'photo_path': null,
      'day_key': key,
      'photo_b64': pb,
      'created_at': created,
    });
  }

  Future<List<Map<String, Object?>>> listDailyMemories(
      {required int babyId, int limit = 60}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final memories = _webReadList(prefs, 'memories');
      final filtered = memories
          .where((m) => (m['baby_id'] as num?)?.toInt() == babyId)
          .toList();
      filtered.sort((a, b) {
        final ad = (a['day_key'] as String?) ?? '';
        final bd = (b['day_key'] as String?) ?? '';
        return bd.compareTo(ad);
      });
      return filtered.take(limit).toList();
    }
    final db = await database;
    return db.query(
      'memories',
      where:
          'baby_id = ? AND (photo_b64 IS NOT NULL OR photo_path IS NOT NULL)',
      whereArgs: [babyId],
      orderBy: 'day_key DESC, created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> listBabyMemories(
      {required int babyId}) async {
    if (kIsWeb) {
      final prefs = await _webPrefs();
      final memories = _webReadList(prefs, 'memories');
      final filtered = memories
          .where((m) =>
              (m['baby_id'] as num?)?.toInt() == babyId &&
              (m['badge_id'] as String?) != null)
          .toList();
      filtered.sort((a, b) {
        final ao = (a['created_at'] as String?) ?? '';
        final bo = (b['created_at'] as String?) ?? '';
        return bo.compareTo(ao);
      });
      return filtered;
    }
    final db = await database;
    return db.query(
      'memories',
      where: 'baby_id = ? AND badge_id IS NOT NULL',
      whereArgs: [babyId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> upsertBabyMemory({
    required int babyId,
    required String badgeId,
    required String title,
    required String? photoB64,
    String? photoUrl,
    required String? description,
    required DateTime memoryDate,
    String? babyAgeAtMoment,
    double? weightAtMoment,
    double? heightAtMoment,
    String? moodAtMoment,
    String? motherNotes,
    bool isFavorite = false,
    bool isPublic = false,
    DateTime? publicEnabledAt,
    DateTime? publicDisabledAt,
    bool eligibleForWeeklyPhoto = false,
    bool weeklyPhotoWinner = false,
    String? weeklyPhotoWeekId,
    bool showBabyFirstNameWhenPublic = true,
    bool fromCloudImport = false,
    DateTime? preserveCreatedAt,
  }) async {
    if (!fromCloudImport) {
      await clearBabyMemoryBadgeTombstone(babyId: babyId, badgeId: badgeId);
    }
    final created = (preserveCreatedAt ?? DateTime.now()).toIso8601String();
    final pb = photoB64?.trim().isEmpty == true ? null : photoB64?.trim();
    final purl = photoUrl?.trim().isEmpty == true ? null : photoUrl?.trim();
    final desc =
        description?.trim().isEmpty == true ? null : description?.trim();
    final age = babyAgeAtMoment?.trim().isEmpty == true
        ? null
        : babyAgeAtMoment?.trim();
    final mood =
        moodAtMoment?.trim().isEmpty == true ? null : moodAtMoment?.trim();
    final notes =
        motherNotes?.trim().isEmpty == true ? null : motherNotes?.trim();
    final memDt = memoryDate.toIso8601String();
    final pubEn = publicEnabledAt?.toIso8601String();
    final pubDis = publicDisabledAt?.toIso8601String();
    final wwk = weeklyPhotoWeekId?.trim().isEmpty == true
        ? null
        : weeklyPhotoWeekId?.trim();

    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final memories = _webReadList(prefs, 'memories');
        for (final m in memories) {
          if ((m['baby_id'] as num?)?.toInt() == babyId &&
              (m['badge_id'] as String?) == badgeId) {
            m['title'] = title;
            m['description'] = desc;
            m['photo_b64'] = pb;
            m['photo_path'] = purl;
            m['badge_id'] = badgeId;
            m['memory_date'] = memDt;
            m['baby_age_at_moment'] = age;
            m['weight_at_moment'] = weightAtMoment;
            m['height_at_moment'] = heightAtMoment;
            m['mood_at_moment'] = mood;
            m['mother_notes'] = notes;
            m['is_favorite'] = isFavorite ? 1 : 0;
            m['is_public'] = isPublic ? 1 : 0;
            m['public_enabled_at'] = pubEn;
            m['public_disabled_at'] = pubDis;
            m['eligible_weekly_photo'] = eligibleForWeeklyPhoto ? 1 : 0;
            m['weekly_photo_winner'] = weeklyPhotoWinner ? 1 : 0;
            m['weekly_photo_week_id'] = wwk;
            m['show_baby_name_public'] = showBabyFirstNameWhenPublic ? 1 : 0;
            await _webWriteList(prefs, 'memories', memories);
            return (m['id'] as num?)?.toInt() ?? 0;
          }
        }
        final id = await _webNextId(prefs, 'memories');
        memories.insert(0, {
          'id': id,
          'baby_id': babyId,
          'badge_id': badgeId,
          'title': title,
          'description': desc,
          'photo_b64': pb,
          'photo_path': purl,
          'memory_date': memDt,
          'baby_age_at_moment': age,
          'weight_at_moment': weightAtMoment,
          'height_at_moment': heightAtMoment,
          'mood_at_moment': mood,
          'mother_notes': notes,
          'is_favorite': isFavorite ? 1 : 0,
          'is_public': isPublic ? 1 : 0,
          'public_enabled_at': pubEn,
          'public_disabled_at': pubDis,
          'eligible_weekly_photo': eligibleForWeeklyPhoto ? 1 : 0,
          'weekly_photo_winner': weeklyPhotoWinner ? 1 : 0,
          'weekly_photo_week_id': wwk,
          'show_baby_name_public': showBabyFirstNameWhenPublic ? 1 : 0,
          'created_at': created,
        });
        await _webWriteList(prefs, 'memories', memories);
        return id;
      });
    }

    final db = await database;
    final existing = await db.query(
      'memories',
      columns: ['id'],
      where: 'baby_id = ? AND badge_id = ?',
      whereArgs: [babyId, badgeId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = (existing.first['id'] as num).toInt();
      await db.update(
        'memories',
        {
          'title': title,
          'description': desc,
          'photo_b64': pb,
          'photo_path': purl,
          'badge_id': badgeId,
          'memory_date': memDt,
          'baby_age_at_moment': age,
          'weight_at_moment': weightAtMoment,
          'height_at_moment': heightAtMoment,
          'mood_at_moment': mood,
          'mother_notes': notes,
          'is_favorite': isFavorite ? 1 : 0,
          'is_public': isPublic ? 1 : 0,
          'public_enabled_at': pubEn,
          'public_disabled_at': pubDis,
          'eligible_weekly_photo': eligibleForWeeklyPhoto ? 1 : 0,
          'weekly_photo_winner': weeklyPhotoWinner ? 1 : 0,
          'weekly_photo_week_id': wwk,
          'show_baby_name_public': showBabyFirstNameWhenPublic ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    return db.insert('memories', {
      'baby_id': babyId,
      'badge_id': badgeId,
      'title': title,
      'description': desc,
      'photo_b64': pb,
      'photo_path': purl,
      'memory_date': memDt,
      'baby_age_at_moment': age,
      'weight_at_moment': weightAtMoment,
      'height_at_moment': heightAtMoment,
      'mood_at_moment': mood,
      'mother_notes': notes,
      'is_favorite': isFavorite ? 1 : 0,
      'is_public': isPublic ? 1 : 0,
      'public_enabled_at': pubEn,
      'public_disabled_at': pubDis,
      'eligible_weekly_photo': eligibleForWeeklyPhoto ? 1 : 0,
      'weekly_photo_winner': weeklyPhotoWinner ? 1 : 0,
      'weekly_photo_week_id': wwk,
      'show_baby_name_public': showBabyFirstNameWhenPublic ? 1 : 0,
      'created_at': created,
    });
  }

  /// Remove memória de um selo; o badge volta a ficar livre na grelha.
  Future<int> deleteBabyMemoryByBadge({
    required int babyId,
    required String badgeId,
    bool skipTombstone = false,
  }) async {
    if (!skipTombstone) {
      await tombstoneBabyMemoryBadge(babyId: babyId, badgeId: badgeId);
    }
    if (kIsWeb) {
      return _webSerialized(() async {
        final prefs = await _webPrefs();
        final memories = _webReadList(prefs, 'memories');
        final before = memories.length;
        memories.removeWhere((m) =>
            (m['baby_id'] as num?)?.toInt() == babyId &&
            (m['badge_id'] as String?) == badgeId);
        if (memories.length < before) {
          await _webWriteList(prefs, 'memories', memories);
          return before - memories.length;
        }
        return 0;
      });
    }
    final db = await database;
    return db.delete(
      'memories',
      where: 'baby_id = ? AND badge_id = ?',
      whereArgs: [babyId, badgeId],
    );
  }
}
