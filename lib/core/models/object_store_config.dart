class ObjectStoreConfig {
  const ObjectStoreConfig({
    required this.endpoint,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    this.useSsl = true,
  });

  final String endpoint;
  final String bucket;
  final String accessKey;
  final String secretKey;
  final bool useSsl;

  bool get isComplete =>
      endpoint.isNotEmpty &&
      bucket.isNotEmpty &&
      accessKey.isNotEmpty &&
      secretKey.isNotEmpty;

  Map<String, String> toMap() {
    return {
      'endpoint': endpoint,
      'bucket': bucket,
      'accessKey': accessKey,
      'secretKey': secretKey,
      'useSsl': useSsl ? '1' : '0',
    };
  }

  factory ObjectStoreConfig.fromMap(Map<String, String> map) {
    return ObjectStoreConfig(
      endpoint: map['endpoint'] ?? '',
      bucket: map['bucket'] ?? '',
      accessKey: map['accessKey'] ?? '',
      secretKey: map['secretKey'] ?? '',
      useSsl: map['useSsl'] != '0',
    );
  }

  ObjectStoreConfig copyWith({
    String? endpoint,
    String? bucket,
    String? accessKey,
    String? secretKey,
    bool? useSsl,
  }) {
    return ObjectStoreConfig(
      endpoint: endpoint ?? this.endpoint,
      bucket: bucket ?? this.bucket,
      accessKey: accessKey ?? this.accessKey,
      secretKey: secretKey ?? this.secretKey,
      useSsl: useSsl ?? this.useSsl,
    );
  }
}
