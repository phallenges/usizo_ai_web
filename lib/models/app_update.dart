/// The newest published Android release, as reported by the backend API.
class AppUpdate {
  const AppUpdate({
    required this.latestVersion,
    required this.downloadUrl,
    this.updateAvailable = false,
    this.updateRequired = false,
    this.notes = '',
    this.sizeBytes,
    this.publishedAt,
    this.source = 'static',
  });

  final String latestVersion;
  final String downloadUrl;
  final bool updateAvailable;
  final bool updateRequired;
  final String notes;
  final int? sizeBytes;
  final String? publishedAt;

  /// Where the backend read the version from: `github`, `atom`, or `static`.
  final String source;

  factory AppUpdate.fromJson(Map<String, Object?> json) {
    final size = json['sizeBytes'];
    return AppUpdate(
      latestVersion: '${json['latestVersion'] ?? ''}',
      downloadUrl: '${json['downloadUrl'] ?? ''}',
      updateAvailable: json['updateAvailable'] == true,
      updateRequired: json['updateRequired'] == true,
      notes: '${json['notes'] ?? ''}',
      sizeBytes: size is int ? size : null,
      publishedAt: json['publishedAt'] as String?,
      source: '${json['source'] ?? 'static'}',
    );
  }

  String get sizeLabel => sizeBytes == null
      ? ''
      : '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
}
