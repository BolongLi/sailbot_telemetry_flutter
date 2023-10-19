import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;

class AlignPositioned extends SingleChildRenderObjectWidget {
  const AlignPositioned({
    Key? key,
    this.alignment = Alignment.center,
    required this.centerPoint,
    this.widthFactor,
    this.heightFactor,
    Widget? child,
  })  : assert(widthFactor == null || widthFactor >= 0.0),
        assert(heightFactor == null || heightFactor >= 0.0),
        super(key: key, child: child);
  final AlignmentGeometry alignment;
  final Offset centerPoint;
  final double? widthFactor;
  final double? heightFactor;
  @override
  RenderAlignPositionedBox createRenderObject(BuildContext context) {
    return RenderAlignPositionedBox(
      alignment: alignment,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      textDirection: Directionality.maybeOf(context),
      centerPoint: this.centerPoint,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderAlignPositionedBox renderObject) {
    renderObject
      ..alignment = alignment
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..textDirection = Directionality.maybeOf(context)
      ..centerPoint = centerPoint;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties
        .add(DoubleProperty('widthFactor', widthFactor, defaultValue: null));
    properties
        .add(DoubleProperty('heightFactor', heightFactor, defaultValue: null));
  }
}

class RenderAlignPositionedBox extends RenderAligningShiftedBox {
  Offset centerPoint;
  RenderAlignPositionedBox({
    RenderBox? child,
    double? widthFactor,
    double? heightFactor,
    AlignmentGeometry alignment = Alignment.center,
    TextDirection? textDirection,
    required this.centerPoint,
  })  : assert(widthFactor == null || widthFactor >= 0.0),
        assert(heightFactor == null || heightFactor >= 0.0),
        _widthFactor = widthFactor,
        _heightFactor = heightFactor,
        super(child: child, alignment: alignment, textDirection: textDirection);
  double? get widthFactor => _widthFactor;
  double? _widthFactor;
  set widthFactor(double? value) {
    assert(value == null || value >= 0.0);
    if (_widthFactor == value) return;
    _widthFactor = value;
    markNeedsLayout();
  }

  set alignment(AlignmentGeometry value) {
    super.alignment = value;
    _resolvedAlignment = alignment.resolve(textDirection);
  }

  double? get heightFactor => _heightFactor;
  double? _heightFactor;
  late Alignment _resolvedAlignment = alignment.resolve(textDirection);
  set heightFactor(double? value) {
    assert(value == null || value >= 0.0);
    if (_heightFactor == value) return;
    _heightFactor = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final bool shrinkWrapWidth =
        _widthFactor != null || constraints.maxWidth == double.infinity;
    final bool shrinkWrapHeight =
        _heightFactor != null || constraints.maxHeight == double.infinity;
    if (child != null) {
      final Size childSize = child!.getDryLayout(constraints.loosen());
      return constraints.constrain(Size(
        shrinkWrapWidth
            ? childSize.width * (_widthFactor ?? 1.0)
            : double.infinity,
        shrinkWrapHeight
            ? childSize.height * (_heightFactor ?? 1.0)
            : double.infinity,
      ));
    }
    return constraints.constrain(Size(
      shrinkWrapWidth ? 0.0 : double.infinity,
      shrinkWrapHeight ? 0.0 : double.infinity,
    ));
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    final bool shrinkWrapWidth =
        _widthFactor != null || constraints.maxWidth == double.infinity;
    final bool shrinkWrapHeight =
        _heightFactor != null || constraints.maxHeight == double.infinity;
    if (child != null) {
      child!.layout(constraints.loosen(), parentUsesSize: true);
      size = constraints.constrain(Size(
        shrinkWrapWidth
            ? child!.size.width * (_widthFactor ?? 1.0)
            : double.infinity,
        shrinkWrapHeight
            ? child!.size.height * (_heightFactor ?? 1.0)
            : double.infinity,
      ));
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      final moveX = _resolvedAlignment.x - 1;
      final moveY = _resolvedAlignment.y - 1;
      log(_resolvedAlignment.y.toString());
      childParentData.offset = this.centerPoint +
          Offset(
            child!.size.width / 2 * moveX,
            child!.size.height / 2 * moveY,
          );
    } else {
      size = constraints.constrain(Size(
        shrinkWrapWidth ? 0.0 : double.infinity,
        shrinkWrapHeight ? 0.0 : double.infinity,
      ));
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    super.debugPaintSize(context, offset);
    assert(() {
      final Paint paint;
      if (child != null && !child!.size.isEmpty) {
        final Path path;
        paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFFFFFF00);
        path = Path();
        final BoxParentData childParentData =
            child!.parentData! as BoxParentData;
        if (childParentData.offset.dy > 0.0) {
          final double headSize =
              math.min(childParentData.offset.dy * 0.2, 10.0);
          path
            ..moveTo(offset.dx + size.width / 2.0, offset.dy)
            ..relativeLineTo(0.0, childParentData.offset.dy - headSize)
            ..relativeLineTo(headSize, 0.0)
            ..relativeLineTo(-headSize, headSize)
            ..relativeLineTo(-headSize, -headSize)
            ..relativeLineTo(headSize, 0.0)
            ..moveTo(offset.dx + size.width / 2.0, offset.dy + size.height)
            ..relativeLineTo(0.0, -childParentData.offset.dy + headSize)
            ..relativeLineTo(headSize, 0.0)
            ..relativeLineTo(-headSize, -headSize)
            ..relativeLineTo(-headSize, headSize)
            ..relativeLineTo(headSize, 0.0);
          context.canvas.drawPath(path, paint);
        }
        if (childParentData.offset.dx > 0.0) {
          final double headSize =
              math.min(childParentData.offset.dx * 0.2, 10.0);
          path
            ..moveTo(offset.dx, offset.dy + size.height / 2.0)
            ..relativeLineTo(childParentData.offset.dx - headSize, 0.0)
            ..relativeLineTo(0.0, headSize)
            ..relativeLineTo(headSize, -headSize)
            ..relativeLineTo(-headSize, -headSize)
            ..relativeLineTo(0.0, headSize)
            ..moveTo(offset.dx + size.width, offset.dy + size.height / 2.0)
            ..relativeLineTo(-childParentData.offset.dx + headSize, 0.0)
            ..relativeLineTo(0.0, headSize)
            ..relativeLineTo(-headSize, -headSize)
            ..relativeLineTo(headSize, -headSize)
            ..relativeLineTo(0.0, headSize);
          context.canvas.drawPath(path, paint);
        }
      } else {
        paint = Paint()..color = const Color(0x90909090);
        context.canvas.drawRect(offset & size, paint);
      }
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DoubleProperty('widthFactor', _widthFactor, ifNull: 'expand'));
    properties
        .add(DoubleProperty('heightFactor', _heightFactor, ifNull: 'expand'));
  }
}
