import 'dart:io';

import 'package:facebaby_flutter/services/app_database.dart';
import 'package:facebaby_flutter/utils/growth_baseline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('growth_persist_test_');
    dbPath = p.join(tempDir.path, 'test.db');
    AppDatabase.instance.setTestDatabasePath(dbPath);
    await AppDatabase.instance.database;
  });

  tearDown(() async {
    await AppDatabase.instance.disposeForTest();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<int> createBaby({
    required double birthWeightKg,
    required double birthHeightCm,
    required DateTime birthDate,
  }) async {
    final motherId = await AppDatabase.instance.insertMother(name: 'Test Mother');
    return AppDatabase.instance.insertBaby(
      motherId: motherId,
      name: 'Baby Test',
      birthDate: birthDate,
      weightKg: birthWeightKg,
      heightCm: birthHeightCm,
    );
  }

  test('adding weight keeps birth baseline and creates distinct records', () async {
    final birthDate = DateTime(2026, 4, 1);
    final babyId = await createBaby(
      birthWeightKg: 6.40,
      birthHeightCm: 50.0,
      birthDate: birthDate,
    );

    final measuredAt = DateTime(2026, 6, 12, 10, 0);
    final newId = await AppDatabase.instance.insertGrowthRecord(
      babyId: babyId,
      kind: 'weight',
      value: 5.60,
      measuredAt: measuredAt,
    );
    await AppDatabase.instance.patchBabyCurrentMeasurements(
      babyId: babyId,
      weightKg: 5.60,
    );

    final baby = await AppDatabase.instance.getBabyById(babyId);
    expect(GrowthBaseline.birthWeightKgStored(baby), closeTo(6.40, 0.001));
    expect((baby?['weight_kg'] as num?)?.toDouble(), closeTo(5.60, 0.001));

    final rows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'weight',
    );
    expect(rows.length, 1);
    expect((rows.first['id'] as num?)?.toInt(), newId);
    expect((rows.first['value'] as num?)?.toDouble(), closeTo(5.60, 0.001));

    final latest = GrowthBaseline.maxValueByMeasuredAtForTest(rows);
    expect(latest, closeTo(5.60, 0.001));
    expect(latest, isNot(closeTo(6.40, 0.001)));
  });

  test('adding height keeps birth baseline and creates distinct records', () async {
    final babyId = await createBaby(
      birthWeightKg: 3.5,
      birthHeightCm: 52.0,
      birthDate: DateTime(2026, 4, 1),
    );

    final newId = await AppDatabase.instance.insertGrowthRecord(
      babyId: babyId,
      kind: 'height',
      value: 58.0,
      measuredAt: DateTime(2026, 6, 12),
    );
    await AppDatabase.instance.patchBabyCurrentMeasurements(
      babyId: babyId,
      heightCm: 58.0,
    );

    final baby = await AppDatabase.instance.getBabyById(babyId);
    expect(GrowthBaseline.birthHeightCmStored(baby), closeTo(52.0, 0.001));
    expect((baby?['height_cm'] as num?)?.toDouble(), closeTo(58.0, 0.001));

    final rows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'height',
    );
    expect(rows.length, 1);
    expect((rows.first['id'] as num?)?.toInt(), newId);
    expect((rows.first['value'] as num?)?.toDouble(), closeTo(58.0, 0.001));
  });

  test('two weight records have different ids and birth stays after second insert', () async {
    final babyId = await createBaby(
      birthWeightKg: 6.40,
      birthHeightCm: 50.0,
      birthDate: DateTime(2026, 4, 1),
    );

    final id1 = await AppDatabase.instance.insertGrowthRecord(
      babyId: babyId,
      kind: 'weight',
      value: 5.80,
      measuredAt: DateTime(2026, 5, 1),
    );
    await AppDatabase.instance.patchBabyCurrentMeasurements(
      babyId: babyId,
      weightKg: 5.80,
    );

    final id2 = await AppDatabase.instance.insertGrowthRecord(
      babyId: babyId,
      kind: 'weight',
      value: 5.60,
      measuredAt: DateTime(2026, 6, 12),
    );
    await AppDatabase.instance.patchBabyCurrentMeasurements(
      babyId: babyId,
      weightKg: 5.60,
    );

    expect(id1, isNot(equals(id2)));

    final baby = await AppDatabase.instance.getBabyById(babyId);
    expect(GrowthBaseline.birthWeightKgStored(baby), closeTo(6.40, 0.001));

    final rows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'weight',
    );
    expect(rows.length, 2);
    final ids = rows.map((r) => (r['id'] as num).toInt()).toSet();
    expect(ids, containsAll([id1, id2]));

    final latest = GrowthBaseline.maxValueByMeasuredAtForTest(rows);
    expect(latest, closeTo(5.60, 0.001));
  });

  test('cloud profile sync does not overwrite local birth baseline', () async {
    final babyId = await createBaby(
      birthWeightKg: 6.40,
      birthHeightCm: 50.0,
      birthDate: DateTime(2026, 4, 1),
    );
    await AppDatabase.instance.setBabyCloudId(
      babyId: babyId,
      cloudId: 'cloud-baby-1',
    );

    await AppDatabase.instance.upsertBabyFromCloud(
      cloudId: 'cloud-baby-1',
      localMotherId:
          ((await AppDatabase.instance.getBabyById(babyId))!['mother_id'] as num)
              .toInt(),
      data: {
        'name': 'Baby Test',
        'sex': 'F',
        'birth_date': DateTime(2026, 4, 1).toIso8601String(),
        'weight_kg': 5.60,
        'height_cm': 55.0,
      },
    );

    final baby = await AppDatabase.instance.getBabyById(babyId);
    expect(GrowthBaseline.birthWeightKgStored(baby), closeTo(6.40, 0.001));
    expect(GrowthBaseline.birthHeightCmStored(baby), closeTo(50.0, 0.001));
    expect((baby?['weight_kg'] as num?)?.toDouble(), closeTo(5.60, 0.001));
  });

  test('listBabies exposes birth baseline columns for growth cards', () async {
    await createBaby(
      birthWeightKg: 6.40,
      birthHeightCm: 50.0,
      birthDate: DateTime(2026, 4, 1),
    );

    final babies = await AppDatabase.instance.listBabies();
    expect(babies, isNotEmpty);
    final row = babies.first;
    expect((row['birth_weight_kg'] as num?)?.toDouble(), closeTo(6.40, 0.001));
    expect((row['birth_height_cm'] as num?)?.toDouble(), closeTo(50.0, 0.001));
  });

  test('cloud growth upsert inserts new record without touching birth baseline', () async {
    final babyId = await createBaby(
      birthWeightKg: 6.40,
      birthHeightCm: 50.0,
      birthDate: DateTime(2026, 4, 1),
    );

    await AppDatabase.instance.upsertGrowthFromCloud(
      localBabyId: babyId,
      data: {
        'id': 'cloud-growth-1',
        'kind': 'weight',
        'value': 5.60,
        'measured_at': DateTime(2026, 6, 12).toIso8601String(),
      },
    );

    final baby = await AppDatabase.instance.getBabyById(babyId);
    expect(GrowthBaseline.birthWeightKgStored(baby), closeTo(6.40, 0.001));

    final rows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'weight',
    );
    expect(rows.length, 1);
    expect(rows.first['cloud_id'], 'cloud-growth-1');
    expect((rows.first['value'] as num?)?.toDouble(), closeTo(5.60, 0.001));
  });
}
