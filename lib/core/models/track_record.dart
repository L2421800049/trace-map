import 'dart:convert';

import 'location_sample.dart';

class TrackRecord {
  TrackRecord({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.startName,
    required this.endName,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.samples,
  });

  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final String startName;
  final String endName;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final List<LocationSample> samples;

  String get title => '$startName → $endName';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'start_name': startName,
      'end_name': endName,
      'start_lat': startLatitude,
      'start_lng': startLongitude,
      'end_lat': endLatitude,
      'end_lng': endLongitude,
      'points_json': jsonEncode(
        samples.map((sample) => sample.toMap()).toList(),
      ),
    };
  }

  factory TrackRecord.fromMap(Map<String, Object?> map) {
    final rawJson = map['points_json'] as String;
    final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
    final samples = decoded
        .map(
          (item) =>
              LocationSample.fromMap(Map<String, Object?>.from(item as Map)),
        )
        .toList();

    return TrackRecord(
      id: map['id'] as int?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      startName: map['start_name'] as String,
      endName: map['end_name'] as String,
      startLatitude: (map['start_lat'] as num).toDouble(),
      startLongitude: (map['start_lng'] as num).toDouble(),
      endLatitude: (map['end_lat'] as num).toDouble(),
      endLongitude: (map['end_lng'] as num).toDouble(),
      samples: samples,
    );
  }
}
