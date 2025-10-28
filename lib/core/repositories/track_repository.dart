import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/location_sample.dart';
import '../models/map_log_entry.dart';
import '../models/track_record.dart';

class TrackRepository {
  TrackRepository._(this._dbPath);

  late Database _db;
  final String _dbPath;

  static Future<TrackRepository> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'device_track.sqlite');
    final repository = TrackRepository._(dbPath);
    await repository._openDatabase();
    return repository;
  }

  Future<void> _openDatabase() async {
    _db = await openDatabase(
      _dbPath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE samples(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            altitude REAL,
            altitude_accuracy REAL,
            speed REAL,
            speed_accuracy REAL,
            heading REAL,
            heading_accuracy REAL,
            is_mocked INTEGER NOT NULL,
            floor INTEGER
          )
        ''');
        await database.execute('''
          CREATE TABLE map_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            message TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE track_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            start_name TEXT NOT NULL,
            end_name TEXT NOT NULL,
            start_lat REAL NOT NULL,
            start_lng REAL NOT NULL,
            end_lat REAL NOT NULL,
            end_lng REAL NOT NULL,
            points_json TEXT NOT NULL
          )
        ''');
      },
      onOpen: (database) async {
        await database.execute('''
          CREATE TABLE IF NOT EXISTS map_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            message TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE IF NOT EXISTS settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE IF NOT EXISTS track_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            start_name TEXT NOT NULL,
            end_name TEXT NOT NULL,
            start_lat REAL NOT NULL,
            start_lng REAL NOT NULL,
            end_lat REAL NOT NULL,
            end_lng REAL NOT NULL,
            points_json TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertSample(LocationSample sample) async {
    await _db.insert(
      'samples',
      sample.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocationSample>> fetchSamples() async {
    final rows = await _db.query('samples', orderBy: 'timestamp ASC');
    return rows.map(LocationSample.fromMap).toList();
  }

  Future<void> deleteOlderThan(DateTime cutoff) async {
    await _db.delete(
      'samples',
      where: 'timestamp < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete('samples');
  }

  Future<void> close() => _db.close();

  Future<void> insertMapLog(MapLogEntry entry) async {
    await _db.insert('map_logs', entry.toMap());
  }

  Future<List<MapLogEntry>> fetchMapLogs() async {
    final rows = await _db.query('map_logs', orderBy: 'timestamp DESC');
    return rows.map((row) => MapLogEntry.fromMap(row)).toList();
  }

  Future<void> clearMapLogs() async {
    await _db.delete('map_logs');
  }

  Future<void> upsertSetting(String key, String value) async {
    await _db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> readSetting(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  Future<void> deleteSetting(String key) async {
    await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<int> insertTrackRecord(TrackRecord record) async {
    return _db.insert(
      'track_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TrackRecord>> fetchTrackRecords() async {
    final rows = await _db.query('track_records', orderBy: 'start_time DESC');
    return rows.map((row) => TrackRecord.fromMap(row)).toList();
  }

  Future<void> deleteTrackRecord(int id) async {
    await _db.delete('track_records', where: 'id = ?', whereArgs: [id]);
  }

  String get databasePath => _dbPath;

  Future<void> replaceWith(String sourcePath) async {
    await _db.close();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Backup file not found at $sourcePath');
    }
    final destinationFile = File(_dbPath);
    if (!await destinationFile.parent.exists()) {
      await destinationFile.parent.create(recursive: true);
    }
    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }
    await sourceFile.copy(destinationFile.path);
    await _openDatabase();
  }
}
