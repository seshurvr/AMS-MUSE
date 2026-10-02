/// A detected face/person box in the classroom photo.
/// Coordinates are in original-image pixels.
class Detection {
  Detection({
    required this.id,
    required this.detectionNumber,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });

  final int id;
  final int detectionNumber;
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  String get label => 'Person $detectionNumber';

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
        id: json['id'] as int,
        detectionNumber: (json['detection_number'] ?? 0) as int,
        x: ((json['x'] ?? 0) as num).toDouble(),
        y: ((json['y'] ?? 0) as num).toDouble(),
        width: ((json['width'] ?? 0) as num).toDouble(),
        height: ((json['height'] ?? 0) as num).toDouble(),
        confidence: ((json['confidence'] ?? 0) as num).toDouble(),
      );
}
