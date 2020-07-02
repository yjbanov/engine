// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// Degree to radian ratio.
///
/// Skia takes sweep angles in degress. This constant is used to convert
/// radians that come from the Flutter framework to degrees.
const double toDegrees = 180.0 / math.pi;

// These constants are from SkScalar.h
const double SK_ScalarRoot2Over2 = 0.707106781;
const double SK_ScalarNearlyZero = 1.0 / (1 << 12);

// These constants are from SkPathTypes.h
class SkPathVerb {
  static const double kMove  = 0;
  static const double kLine  = 1;
  static const double kQuad  = 2;
  static const double kConic = 3;
  static const double kCubic = 4;
  static const double kClose = 5;
}

// These constants are from SkPathTypes.h
class SkPathSegmentMask {
  static const int kLine   = 1 << 0;
  static const int kQuad   = 1 << 1;
  static const int kConic  = 1 << 2;
  static const int kCubic  = 1 << 3;
}

enum SkPathDirection {
  /// Clockwise.
  kCW,

  /// Counter clockwise.
  kCCW,
}

class CkRectPointIterator {
  CkRectPointIterator(ui.Rect rect, SkPathDirection direction, int startIndex)
    : _currentIndex = startIndex,
      _advance = direction == SkPathDirection.kCW ? 1 : 3 {
    final double left = rect.left;
    final double top = rect.top;
    final double right = rect.right;
    final double bottom = rect.bottom;

    _pointsX[0] = left;
    _pointsY[0] = top;

    _pointsX[1] = right;
    _pointsY[1] = top;

    _pointsX[2] = right;
    _pointsY[2] = bottom;

    _pointsX[3] = left;
    _pointsY[3] = bottom;
  }

  final Float32List _pointsX = Float32List(4);
  final Float32List _pointsY = Float32List(4);
  final int _advance;
  int _currentIndex;

  double get currentX => _pointsX[_currentIndex];
  double get currentY => _pointsY[_currentIndex];
  void next() {
    _currentIndex = (_currentIndex + _advance) % 4;
  }
}

class CkOvalPointIterator {
  CkOvalPointIterator(ui.Rect oval, SkPathDirection direction, int startIndex)
    : _currentIndex = startIndex,
      _advance = direction == SkPathDirection.kCW ? 1 : 3 {
    final double left = oval.left;
    final double top = oval.top;
    final double right = oval.right;
    final double bottom = oval.bottom;
    final double width = right - left;
    final double height = bottom - top;
    final double centerX = left + width / 2;
    final double centerY = top + height / 2;

    _pointsX[0] = centerX;
    _pointsY[0] = top;

    _pointsX[1] = right;
    _pointsY[1] = centerY;

    _pointsX[2] = centerX;
    _pointsY[2] = bottom;

    _pointsX[3] = left;
    _pointsY[3] = centerY;
  }

  final Float32List _pointsX = Float32List(4);
  final Float32List _pointsY = Float32List(4);
  final int _advance;
  int _currentIndex;

  double get currentX => _pointsX[_currentIndex];
  double get currentY => _pointsY[_currentIndex];
  void next() {
    _currentIndex = (_currentIndex + _advance) % 4;
  }
}

class CkPathBuilder {
  final Float32ListBuilder _verbs = Float32ListBuilder();
  final Float32ListBuilder _points = Float32ListBuilder();
  final Float32ListBuilder _weights = Float32ListBuilder();

  int _segmentMask = 0;
  bool _needsMoveVerb = false;
  double _lastMovePointX = 0;
  double _lastMovePointY = 0;

  void addArc(ui.Rect oval, double startAngle, double sweepAngle) {
    // This code is ported from SkPath.cpp.
    final double sweepAngleDegrees = sweepAngle * toDegrees;
    if (sweepAngleDegrees >= 360 || sweepAngleDegrees <= 360) {
      // We can treat the arc as an oval if it begins at one of our legal starting positions.
      // See SkPath::addOval() docs.
      double startOver90 = startAngle / 90;
      double startOver90I = startOver90.floor() + 0.5;
      double error = (startOver90 - startOver90I).abs();
      if (error <= SK_ScalarNearlyZero) {
          // Index 1 is at startAngle == 0.
          double startIndex = (startOver90I + 1.0) % 4.0;
          startIndex = startIndex < 0 ? startIndex + 4 : startIndex;
          assert(startIndex >= 0);
          _addOval(oval, sweepAngle > 0 ? SkPathDirection.kCW : SkPathDirection.kCCW, startIndex.floor());
      }
    }
    arcTo(oval, startAngle, sweepAngle, true);
  }

  void _addOval(ui.Rect oval, SkPathDirection direction, int startIndex) {
    final CkOvalPointIterator ovalIter = CkOvalPointIterator(oval, direction, startIndex);
    final CkRectPointIterator rectIter = CkRectPointIterator(oval, direction, startIndex + (direction == SkPathDirection.kCW ? 0 : 1));

    // The corner iterator pts are tracking "behind" the oval/radii pts.

    moveTo(ovalIter.currentX, ovalIter.currentY);
    for (int i = 0; i < 4; i += 1) {
        rectIter.next();
        ovalIter.next();
        this.conicTo(rectIter.currentX, rectIter.currentY, ovalIter.currentX, ovalIter.currentY, SK_ScalarRoot2Over2);
    }
  }

  void addOval(ui.Rect oval) {
    final double left = oval.left;
    final double top = oval.top;
    final double right = oval.right;
    final double bottom = oval.bottom;
    final double width = right - left;
    final double height = bottom - top;
    final double centerX = left + width / 2;
    final double centerY = top + height / 2;
    moveTo(centerX, top);
    conicTo(left, top, centerX, top, SK_ScalarRoot2Over2);
    conicTo(right, top, right, centerY, SK_ScalarRoot2Over2);
    conicTo(right, bottom, centerX, bottom, SK_ScalarRoot2Over2);
    conicTo(left, bottom, left, centerY, SK_ScalarRoot2Over2);
  }

  void addPolygon(List<ui.Offset> points, bool close) {
    // TODO: implement addPolygon
  }

  void addRRect(ui.RRect rrect) {
    // TODO: implement addRRect
  }

  void addRect(ui.Rect rect) {
    // TODO: implement addRect
  }

  void arcTo(ui.Rect rect, double startAngle, double sweepAngle, bool forceMoveTo) {
    // TODO: implement arcTo
  }

  void arcToPoint(ui.Offset arcEnd, {ui.Radius radius = ui.Radius.zero, double rotation = 0.0, bool largeArc = false, bool clockwise = true}) {
    // TODO: implement arcToPoint
  }

  void close() {
    _ensureMove();
    _verbs.add(SkPathVerb.kClose);
    _needsMoveVerb = true;
  }

  void conicTo(double x1, double y1, double x2, double y2, double w) {
    _ensureMove();
    _points.add(x1);
    _points.add(y1);
    _points.add(x2);
    _points.add(y2);
    _verbs.add(SkPathVerb.kConic);
    _weights.add(w);
    _segmentMask |= SkPathSegmentMask.kCubic;
  }

  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    _ensureMove();
    _points.add(x1);
    _points.add(y1);
    _points.add(x2);
    _points.add(y2);
    _points.add(x3);
    _points.add(y3);
    _verbs.add(SkPathVerb.kCubic);
    _segmentMask |= SkPathSegmentMask.kCubic;
  }

  void lineTo(double x, double y) {
    _ensureMove();
    _points.add(x);
    _points.add(y);
    _verbs.add(SkPathVerb.kLine);
    _segmentMask |= SkPathSegmentMask.kLine;
  }

  void moveTo(double x, double y) {
    _points.add(x);
    _points.add(y);
    _verbs.add(SkPathVerb.kMove);
    _lastMovePointX = x;
    _lastMovePointY = y;
    _needsMoveVerb = false;
  }

  void _ensureMove() {
    if (_needsMoveVerb) {
      moveTo(_lastMovePointX, _lastMovePointY);
    }
  }

  void quadraticBezierTo(double x1, double y1, double x2, double y2) {
    _ensureMove();
    _points.add(x1);
    _points.add(y1);
    _points.add(x2);
    _points.add(y2);
    _verbs.add(SkPathVerb.kQuad);
    _segmentMask |= SkPathSegmentMask.kQuad;
  }

  void relativeArcToPoint(ui.Offset arcEndDelta, {ui.Radius radius = ui.Radius.zero, double rotation = 0.0, bool largeArc = false, bool clockwise = true}) {
    // TODO: implement relativeArcToPoint
  }

  void relativeConicTo(double x1, double y1, double x2, double y2, double w) {
    // TODO: implement relativeConicTo
  }

  void relativeCubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    // TODO: implement relativeCubicTo
  }

  void relativeLineTo(double dx, double dy) {
    // TODO: implement relativeLineTo
  }

  void relativeMoveTo(double dx, double dy) {
    // TODO: implement relativeMoveTo
  }

  void relativeQuadraticBezierTo(double x1, double y1, double x2, double y2) {
    // TODO: implement relativeQuadraticBezierTo
  }

  void reset() {
    _points.clear();
    _verbs.clear();
    _weights.clear();
  }
}
