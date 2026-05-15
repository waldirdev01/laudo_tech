class BloodstainAnalysisModel {
  final String id;
  final DateTime createdAt;
  final String? ambiente;
  final String contextText;
  final String surfaceType;
  final String planeOrientation;
  final bool scalePresent;
  final List<String> overviewImagePaths;
  final List<String> closeUpImagePaths;
  final String resultText;

  const BloodstainAnalysisModel({
    required this.id,
    required this.createdAt,
    this.ambiente,
    required this.contextText,
    required this.surfaceType,
    required this.planeOrientation,
    required this.scalePresent,
    this.overviewImagePaths = const [],
    this.closeUpImagePaths = const [],
    required this.resultText,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'ambiente': ambiente,
    'contextText': contextText,
    'surfaceType': surfaceType,
    'planeOrientation': planeOrientation,
    'scalePresent': scalePresent,
    'overviewImagePaths': overviewImagePaths,
    'closeUpImagePaths': closeUpImagePaths,
    'resultText': resultText,
  };

  factory BloodstainAnalysisModel.fromJson(Map<String, dynamic> json) {
    return BloodstainAnalysisModel(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      ambiente: json['ambiente'] as String?,
      contextText: json['contextText'] as String? ?? '',
      surfaceType: json['surfaceType'] as String? ?? '',
      planeOrientation: json['planeOrientation'] as String? ?? '',
      scalePresent: json['scalePresent'] as bool? ?? false,
      overviewImagePaths:
          (json['overviewImagePaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      closeUpImagePaths:
          (json['closeUpImagePaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      resultText: json['resultText'] as String? ?? '',
    );
  }
}
