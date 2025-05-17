class ReceivedFile {
  final String path;
  final String name;
  final bool isEncrypted;
  final DateTime receivedAt;
  
  ReceivedFile({
    required this.path,
    required this.name,
    required this.isEncrypted,
    required this.receivedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'isEncrypted': isEncrypted,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }
  
  factory ReceivedFile.fromJson(Map<String, dynamic> json) {
    return ReceivedFile(
      path: json['path'],
      name: json['name'],
      isEncrypted: json['isEncrypted'] ?? false,
      receivedAt: DateTime.parse(json['receivedAt']),
    );
  }
}
