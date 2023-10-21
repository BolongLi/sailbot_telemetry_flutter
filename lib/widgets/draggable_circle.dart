import 'package:flutter/material.dart';

class CircleDragWidget extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  CircleDragWidget({
    required this.width,
    required this.height,
    required this.radius,
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
            final validX = position.dx
                .clamp(0.0 + widget.radius, widget.width - widget.radius);
            final validY = position.dy
                .clamp(0.0 + widget.radius, widget.height - widget.radius);
            if ((details.localPosition - Offset(validX, validY)).distance <=
                widget.radius) {
              setState(() {
                position = details.localPosition;
              });
            }
          },
          onPanUpdate: (details) {
            setState(() {
              position = details.localPosition;
            });
          },
          child: CustomPaint(
            painter: CirclePainter(position, widget.radius),
            child: Container(),
          ),
        ),
      ),
    );
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
