import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/detection.dart';

/// Classroom photo with face-detection bounding boxes drawn on top.
///
/// Boxes are tappable; the selected box is highlighted. Colors:
/// green = assigned to a student, amber = selected, red = unassigned.
/// Wrapped in an [InteractiveViewer] for zoom / pan.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    required this.assignedNames, // detectionId -> student display name
    required this.selectedDetectionId,
    required this.onSelectDetection,
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final List<Detection> detections;
  final Map<int, String> assignedNames;
  final int? selectedDetectionId;
  final ValueChanged<int> onSelectDetection;

  @override
  Widget build(BuildContext context) {
    final aspect = imageWidth > 0 && imageHeight > 0
        ? imageWidth / imageHeight
        : 16 / 9;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final renderSize =
                Size(constraints.maxWidth, constraints.maxWidth / aspect);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final local = details.localPosition;
                // Map the tap back to original-image pixels.
                final ix = local.dx / renderSize.width * imageWidth;
                final iy = local.dy / renderSize.height * imageHeight;
                for (final d in detections.reversed) {
                  if (ix >= d.x &&
                      ix <= d.x + d.width &&
                      iy >= d.y &&
                      iy <= d.y + d.height) {
                    onSelectDetection(d.id);
                    return;
                  }
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    imageBytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                  CustomPaint(
                    painter: _DetectionPainter(
                      detections: detections,
                      assignedNames: assignedNames,
                      selectedDetectionId: selectedDetectionId,
                      imageWidth: imageWidth.toDouble(),
                      imageHeight: imageHeight.toDouble(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  _DetectionPainter({
    required this.detections,
    required this.assignedNames,
    required this.selectedDetectionId,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<Detection> detections;
  final Map<int, String> assignedNames;
  final int? selectedDetectionId;
  final double imageWidth;
  final double imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / imageWidth;
    final sy = size.height / imageHeight;

    for (final d in detections) {
      final rect = Rect.fromLTWH(
        d.x * sx,
        d.y * sy,
        d.width * sx,
        d.height * sy,
      );
      final isSelected = d.id == selectedDetectionId;
      final isAssigned = assignedNames.containsKey(d.id);
      final color = isSelected
          ? Colors.amber
          : isAssigned
              ? Colors.green
              : Colors.red;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4 : 2.5
        ..color = color;
      canvas.drawRect(rect, paint);

      final label = assignedNames[d.id] ?? d.label;
      _drawLabel(canvas, label, rect, color);
    }
  }

  void _drawLabel(Canvas canvas, String text, Rect rect, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: ' $text ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelHeight = textPainter.height + 6;
    var labelTop = rect.top - labelHeight;
    if (labelTop < 0) labelTop = rect.bottom;
    final bgRect = Rect.fromLTWH(
      rect.left,
      labelTop,
      textPainter.width + 8,
      labelHeight,
    );
    canvas.drawRect(
      bgRect,
      Paint()..color = color.withValues(alpha: 0.9),
    );
    textPainter.paint(canvas, Offset(rect.left + 4, labelTop + 3));
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter old) =>
      old.detections != detections ||
      old.assignedNames != assignedNames ||
      old.selectedDetectionId != selectedDetectionId;
}
