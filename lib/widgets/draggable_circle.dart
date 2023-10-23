import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:developer' as dev;

class CircleDragWidget extends StatefulWidget {
  final double width;
  final double height;
  final double lineLength;
  final double radius;
  double angle = 0;
  Function callback;
  final GlobalKey<CircleDragWidgetState> key;

  CircleDragWidget({
    required this.width,
    required this.height,
    required this.lineLength,
    required this.radius,
    required this.callback,
    required this.key,
  }) : super(key: key);

  @override
  CircleDragWidgetState createState() =>
      CircleDragWidgetState(lineLength, width);

  void incrementAngle(amount) {
    key.currentState?._incrementAngle(amount);
  }
}

class CircleDragWidgetState extends State<CircleDragWidget> {
  Offset position;

  CircleDragWidgetState(var lineLength, var width)
      : position = Offset(width / 2, lineLength);

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

  void _incrementAngle(double amount) {
    if ((widget.angle + amount).abs() > pi / 2) {
      return;
    }
    widget.angle += amount;
    widget.callback(widget.angle);
    double circleX = widget.width / 2 + widget.lineLength * sin(widget.angle);
    double circleY = widget.lineLength * cos(widget.angle);
    setState(() {
      position = Offset(circleX, circleY);
    });
  }

  void _updateCirclePosition(double dx) {
    if (dx < 0 || dx > widget.width) return;
    double angle = (dx - (widget.width / 2)) / (widget.width / 2) * (pi / 2);
    widget.angle = angle;
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
