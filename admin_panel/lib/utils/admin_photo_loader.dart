import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Campos de foto em documentos Firestore (`public_memories`, spotlight).
String adminHttpsPhotoUrl(Map<String, dynamic> d) {
  const keys = [
    'photoUrl',
    'photo_url',
    'winner_photo_url',
    'winnerPhotoUrl',
    'downloadUrl',
    'download_url',
  ];
  for (final k in keys) {
    final u = (d[k] as String?)?.trim();
    if (u != null && u.toLowerCase().startsWith('https://')) return u;
  }
  final path = (d['photoPath'] as String?)?.trim() ?? (d['photo_path'] as String?)?.trim();
  if (path != null && path.toLowerCase().startsWith('https://')) return path;
  return '';
}

/// Compatível com [photoFromMap] existente.
String photoFromMap(Map<String, dynamic> d) => adminHttpsPhotoUrl(d);

String? _rowUserId(Map<String, dynamic> d) {
  final u = (d['userId'] as String?)?.trim() ?? (d['owner_uid'] as String?)?.trim();
  return (u == null || u.isEmpty) ? null : u;
}

String? _rowBabyId(Map<String, dynamic> d) {
  final b = (d['babyId'] as String?)?.trim() ?? (d['baby_id'] as String?)?.trim();
  return (b == null || b.isEmpty) ? null : b;
}

String? _rowBadgeId(Map<String, dynamic> d) {
  final b = (d['badgeId'] as String?)?.trim() ?? (d['badge_id'] as String?)?.trim();
  return (b == null || b.isEmpty) ? null : b;
}

String? _rowPhotoB64(Map<String, dynamic> d) {
  final b = (d['photoB64'] as String?)?.trim() ?? (d['photo_b64'] as String?)?.trim();
  return (b == null || b.isEmpty) ? null : b;
}

/// `public_memories` doc id: `{ownerUid}_{babyCloudId}_{badgeId}`.
({String? babyId, String? badgeId}) idsFromPublicMemoryDocId({
  required String docId,
  required String userId,
  String? knownBabyId,
}) {
  final prefix = '${userId.trim()}_';
  if (userId.isEmpty || !docId.startsWith(prefix)) {
    return (babyId: null, badgeId: null);
  }
  final rest = docId.substring(prefix.length);
  if (rest.isEmpty) return (babyId: null, badgeId: null);

  final baby = knownBabyId?.trim();
  if (baby != null && baby.isNotEmpty && rest.startsWith('${baby}_')) {
    return (babyId: baby, badgeId: rest.substring(baby.length + 1));
  }

  final firstUnderscore = rest.indexOf('_');
  if (firstUnderscore <= 0 || firstUnderscore >= rest.length - 1) {
    return (babyId: null, badgeId: null);
  }
  return (
    babyId: rest.substring(0, firstUnderscore),
    badgeId: rest.substring(firstUnderscore + 1),
  );
}

String? _storagePathFromDownloadUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final marker = '/o/';
    final idx = uri.path.indexOf(marker);
    if (idx < 0) return null;
    final encoded = uri.path.substring(idx + marker.length);
    return Uri.decodeComponent(encoded);
  } catch (_) {
    return null;
  }
}

final FirebaseFunctions _adminFunctions =
    FirebaseFunctions.instanceFor(region: 'southamerica-east1');

Future<Uint8List?> _loadViaCallable({String? url, String? storagePath}) async {
  if ((url == null || url.isEmpty) && (storagePath == null || storagePath.isEmpty)) {
    return null;
  }
  try {
    final result = await _adminFunctions.httpsCallable('adminGetPhotoBytes').call(
      {
        if (url != null && url.isNotEmpty) 'url': url,
        if (storagePath != null && storagePath.isNotEmpty) 'storagePath': storagePath,
      },
    );
    final data = result.data as Map<dynamic, dynamic>?;
    if (data == null) return null;
    final b64 = (data['bytes'] as String?)?.trim();
    if (b64 == null || b64.isEmpty) return null;
    return Uint8List.fromList(base64Decode(b64));
  } catch (e, st) {
    debugPrint('AdminPhoto: adminGetPhotoBytes callable failed: $e\n$st');
    return null;
  }
}

Future<Uint8List?> _loadViaHttp(String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      debugPrint('AdminPhoto: http ${res.statusCode} for $url');
      return null;
    }
    return res.bodyBytes;
  } catch (e) {
    debugPrint('AdminPhoto: http get failed ($url): $e');
    return null;
  }
}

Future<Uint8List?> _loadFromStoragePath(String path) async {
  try {
    final bytes = await FirebaseStorage.instance.ref(path).getData(12 * 1024 * 1024);
    if (bytes != null && bytes.isNotEmpty) return bytes;
  } catch (e) {
    debugPrint('AdminPhoto: ref($path) getData failed: $e');
  }
  return _loadViaCallable(storagePath: path);
}

Future<Uint8List?> _loadFromHttpsUrl(String url) async {
  final objectPath = _storagePathFromDownloadUrl(url);
  if (objectPath != null && objectPath.isNotEmpty) {
    final fromPath = await _loadFromStoragePath(objectPath);
    if (fromPath != null) return fromPath;
  }

  try {
    final bytes = await FirebaseStorage.instance.refFromURL(url).getData(12 * 1024 * 1024);
    if (bytes != null && bytes.isNotEmpty) return bytes;
  } catch (e) {
    debugPrint('AdminPhoto: refFromURL getData failed ($url): $e');
  }

  final fromCallable = await _loadViaCallable(url: url);
  if (fromCallable != null) return fromCallable;

  return _loadViaHttp(url);
}

/// Carrega bytes da foto para o painel admin.
Future<Uint8List?> loadAdminPhotoBytes({
  Map<String, dynamic>? data,
  String? httpsUrl,
  String? userId,
  String? babyId,
  String? badgeId,
  String? photoB64,
  String? publicMemoryDocId,
}) async {
  final d = data ?? const <String, dynamic>{};
  final b64 = photoB64 ?? _rowPhotoB64(d);
  if (b64 != null) {
    try {
      return Uint8List.fromList(base64Decode(b64));
    } catch (e) {
      debugPrint('AdminPhoto: base64 decode failed: $e');
    }
  }

  var uid = userId ?? _rowUserId(d);
  var bid = babyId ?? _rowBabyId(d);
  var badge = badgeId ?? _rowBadgeId(d);

  final docId = (publicMemoryDocId ?? (d['memoryId'] as String?) ?? '').trim();
  if (uid != null && docId.isNotEmpty && (bid == null || badge == null)) {
    final parsed = idsFromPublicMemoryDocId(
      docId: docId,
      userId: uid,
      knownBabyId: bid,
    );
    bid ??= parsed.babyId;
    badge ??= parsed.badgeId;
  }

  final url = (httpsUrl ?? adminHttpsPhotoUrl(d)).trim();
  if (url.isNotEmpty) {
    final loaded = await _loadFromHttpsUrl(url);
    if (loaded != null) return loaded;
  }

  if (uid == null || bid == null || badge == null) return null;

  final storage = FirebaseStorage.instance;
  const exts = ['jpg', 'jpeg', 'png', 'webp'];
  for (final ext in exts) {
    for (final path in [
      'users/$uid/babies/$bid/memories/$badge.$ext',
      'users/$uid/babies/$bid/memories/${badge}_v1.$ext',
    ]) {
      final bytes = await _loadFromStoragePath(path);
      if (bytes != null) return bytes;
    }
  }

  try {
    final list = await storage.ref('users/$uid/babies/$bid/memories').listAll();
    for (final item in list.items) {
      if (!item.name.startsWith(badge)) continue;
      final bytes = await _loadFromStoragePath(item.fullPath);
      if (bytes != null) return bytes;
    }
  } catch (e) {
    debugPrint('AdminPhoto: listAll failed users/$uid/babies/$bid/memories: $e');
  }

  return null;
}
