import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/location_sample.dart';

class TrackRepository {
  TrackRepository._(this._db);

  final Database _db;

  static Future<TrackRepository> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'device_track.sqlite');
    final db = await openDatabase(
      dbPath,
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
      },
    );
    return TrackRepository._(db);
  }

  Future<void> insertSample(LocationSample sample) async {
    await _db.insert(
      'samples',
      sample.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocationSample>> fetchSamples() async {
    final rows = await _db.query(
      'samples',
      orderBy: 'timestamp ASC',
    );
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
}
