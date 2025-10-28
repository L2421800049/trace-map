import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:minio/minio.dart';

import '../models/object_store_config.dart';

class ObjectStoreService {
  const ObjectStoreService();

  Minio _createClient(ObjectStoreConfig config) {
    final trimmed = config.endpoint.trim();
    String host;
    int? port;
    if (trimmed.contains('://')) {
      final uri = Uri.parse(trimmed);
      host = uri.host;
      port = uri.hasPort ? uri.port : null;
    } else {
      final parts = trimmed.split(':');
      host = parts.first;
      if (parts.length > 1) {
        port = int.tryParse(parts.last);
      }
    }
    port ??= config.useSsl ? 443 : 80;
    return Minio(
      endPoint: host,
      port: port,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
      useSSL: config.useSsl,
    );
  }

  Future<void> uploadDatabaseFile({
    required ObjectStoreConfig config,
    required String filePath,
    String objectName = 'backups/device_track.sqlite',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Database file not found at $filePath');
    }
    final stat = await file.stat();
    final client = _createClient(config);
    final stream = file.openRead().map(Uint8List.fromList);
    await client.putObject(
      config.bucket,
      objectName,
      stream,
      size: stat.size,
    );
  }

  Future<void> ensureBucket({
    required ObjectStoreConfig config,
  }) async {
    final client = _createClient(config);
    final exists = await client.bucketExists(config.bucket);
    if (!exists) {
      await client.makeBucket(config.bucket);
    }
  }

  Future<void> uploadJsonContent({
    required ObjectStoreConfig config,
    required String objectName,
    required String content,
  }) async {
    final client = _createClient(config);
    final bytes = Uint8List.fromList(utf8.encode(content));
    await client.putObject(
      config.bucket,
      objectName,
      Stream.value(bytes),
      size: bytes.length,
    );
  }

  Future<List<String>> listBackups({
    required ObjectStoreConfig config,
    String prefix = 'backups/',
  }) async {
    final client = _createClient(config);
    final result = await client.listAllObjects(
      config.bucket,
      prefix: prefix,
      recursive: true,
    );
    final keys = <String>[];
    for (final object in result.objects) {
      final key = object.key;
      if (key != null && key.isNotEmpty) {
        keys.add(key);
      }
    }
    keys.sort((a, b) => b.compareTo(a));
    return keys;
  }

  Future<void> downloadObject({
    required ObjectStoreConfig config,
    required String objectName,
    required String destinationPath,
  }) async {
    final client = _createClient(config);
    final stream = await client.getObject(config.bucket, objectName);
    final file = File(destinationPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    final sink = file.openWrite();
    try {
      await stream.pipe(sink);
    } finally {
      await sink.close();
    }
  }

  Future<void> deleteObject({
    required ObjectStoreConfig config,
    required String objectName,
  }) async {
    final client = _createClient(config);
    await client.removeObject(config.bucket, objectName);
  }

  Future<void> enforceBackupRetention({
    required ObjectStoreConfig config,
    int maxBackups = 7,
    String prefix = 'backups/',
  }) async {
    if (maxBackups <= 0) {
      return;
    }
    final backups = await listBackups(config: config, prefix: prefix);
    final filtered = backups
        .where(
          (key) => !key.endsWith('_latest.sqlite') && key.startsWith(prefix),
        )
        .toList();
    if (filtered.length <= maxBackups) {
      return;
    }
    filtered.sort(); // ascending
    final toDelete = filtered.take(filtered.length - maxBackups);
    for (final key in toDelete) {
      await deleteObject(config: config, objectName: key);
    }
  }
}
