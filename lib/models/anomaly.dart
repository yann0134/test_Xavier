class Anomaly {
  final String sellerName;
  final DateTime detectedAt;
  final String description;
  final String comparison;
  final String recommendation;
  final String severity;

  Anomaly({
    required this.sellerName,
    required this.detectedAt,
    required this.description,
    required this.comparison,
    required this.recommendation,
    required this.severity,
  });
}
