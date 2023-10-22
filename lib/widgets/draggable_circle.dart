import 'package:flutter/material.dart';
import 'dart:math';

class CircleDragWidget extends StatefulWidget {
  final double width;
  final double height;
  final double lineLength;
  final double radius;
  Function callback;

  CircleDragWidget({
    required this.width,
    required this.height,
    required this.lineLength,
    required this.radius,
    required this.callback,
  });

  @override
  _CircleDragWidgetState createState() => _CircleDragWidgetState();
}

class _CircleDragWidgetState extends State<CircleDragWidget> {
  Offset position;

  _CircleDragWidgetState() : position = Offset(100, 100);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.blue),
      child: ConstrainedBox(
        constraints:
            BoxConstraints.tightFor(width: widget.width, height: widget.height),
        child: GestureDetector(
          onPanDown: (details) {
            _updateCirclePosition(details.localPosition.dx);
          },
          onPanUpdate: (details) {
            _updateCirclePosition(details.localPosition.dx);
          },
          child: CustomPaint(
            painter: CirclePainter(position, widget.radius),
            child: Container(),
          ),
        ),
      ),
    );
  }

  void _updateCirclePosition(double dx) {
    if (dx < 0 || dx > widget.width) return;
    double angle = (dx - (widget.width / 2)) / (widget.width / 2) * (pi / 2);
    widget.callback(angle);
    double circleX = widget.width / 2 + widget.lineLength * sin(angle);
    double circleY = widget.lineLength * cos(angle);

    setState(() {
      position = Offset(circleX, circleY);
    });
  }
}

class CirclePainter extends CustomPainter {
  final Offset position;
  final double radius;

  CirclePainter(this.position, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw the line from top center to circle's position
    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0;

    final validX = position.dx.clamp(0.0 + radius, size.width - radius);
    final validY = position.dy.clamp(0.0 + radius, size.height - radius);

    final topCenter = Offset(size.width / 2, 0);
    canvas.drawLine(topCenter, Offset(validX, validY), linePaint);
    canvas.drawCircle(Offset(validX, validY), radius, paint);
  }

  @override
  bool shouldRepaint(CirclePainter oldDelegate) {
    return position != oldDelegate.position || radius != oldDelegate.radius;
  }
}
