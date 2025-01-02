class LastUpdateTerms {
  String key;
  int timestamp;

  LastUpdateTerms({required this.key, required this.timestamp});

  @override
  String toString() {
    return '{key: $key, timestamp: $timestamp}';
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'timestamp': timestamp,
    };
  }

  factory LastUpdateTerms.fromJson(Map<String, dynamic> json) {
    return LastUpdateTerms(
      key: json['key'],
      timestamp: json['timestamp'],
    );
  }
}
