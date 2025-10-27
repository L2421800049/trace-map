class MapLogEntry {
  const MapLogEntry({
    required this.timestamp,
    required this.message,
  });

  final DateTime timestamp;
  final String message;

  Map<String, Object?> toMap() => {
        'timestamp': timestamp.millisecondsSinceEpoch,
        'message': message,
      };

  static MapLogEntry fromMap(Map<String, Object?> map) {
    return MapLogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      ),
      message: map['message'] as String,
    );
  }
}
