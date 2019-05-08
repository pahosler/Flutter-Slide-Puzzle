// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// Defines canvas interface common across canvases that the [SceneBuilder]
/// renders to.
///
/// This can be used either as an interface or super-class.
abstract class EngineCanvas {
  /// The element that is attached to the DOM.
  html.Element get rootElement;

  void dispose() {
    clear();
  }

  void clear();

  void save();

  void restore();

  void translate(double dx, double dy);

  void scale(double sx, double sy);

  void rotate(double radians);

  void skew(double sx, double sy);

  void transform(Float64List matrix4);

  void clipRect(ui.Rect rect);

  void clipRRect(ui.RRect rrect);

  void clipPath(ui.Path path);

  void drawColor(ui.Color color, ui.BlendMode blendMode);

  void drawLine(ui.Offset p1, ui.Offset p2, ui.PaintData paint);

  void drawPaint(ui.PaintData paint);

  void drawRect(ui.Rect rect, ui.PaintData paint);

  void drawRRect(ui.RRect rrect, ui.PaintData paint);

  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.PaintData paint);

  void drawOval(ui.Rect rect, ui.PaintData paint);

  void drawCircle(ui.Offset c, double radius, ui.PaintData paint);

  void drawPath(ui.Path path, ui.PaintData paint);

  void drawShadow(
      ui.Path path, ui.Color color, double elevation, bool transparentOccluder);

  void drawImage(ui.Image image, ui.Offset p, ui.PaintData paint);

  void drawImageRect(
      ui.Image image, ui.Rect src, ui.Rect dst, ui.PaintData paint);

  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset);
}

/// Adds an [offset] transformation to a [transform] matrix and returns the
/// combined result.
///
/// If the given offset is zero, returns [transform] matrix as is. Otherwise,
/// returns a new [Matrix4] object representing the combined transformation.
Matrix4 transformWithOffset(Matrix4 transform, ui.Offset offset) {
  if (offset == ui.Offset.zero) {
    return transform;
  }

  // Clone to avoid mutating transform.
  Matrix4 effectiveTransform = transform.clone();
  effectiveTransform.translate(offset.dx, offset.dy, 0.0);
  return effectiveTransform;
}

class _SaveStackEntry {
  _SaveStackEntry({
    @required this.transform,
    @required this.clipStack,
  });

  final Matrix4 transform;
  final List<_SaveClipEntry> clipStack;
}

/// Tagged union of clipping parameters used for canvas.
class _SaveClipEntry {
  final ui.Rect rect;
  final ui.RRect rrect;
  final ui.Path path;
  final Matrix4 currentTransform;
  _SaveClipEntry.rect(this.rect, this.currentTransform)
      : rrect = null,
        path = null;
  _SaveClipEntry.rrect(this.rrect, this.currentTransform)
      : rect = null,
        path = null;
  _SaveClipEntry.path(this.path, this.currentTransform)
      : rect = null,
        rrect = null;
}

/// Provides save stack tracking functionality to implementations of
/// [EngineCanvas].
mixin SaveStackTracking on EngineCanvas {
  static final Vector3 _unitZ = Vector3(0.0, 0.0, 1.0);

  final List<_SaveStackEntry> _saveStack = <_SaveStackEntry>[];

  /// The stack that maintains clipping operations used when text is painted
  /// onto bitmap canvas but is composited as separate element.
  List<_SaveClipEntry> _clipStack;

  /// Returns whether there are active clipping regions on the canvas.
  bool get isClipped => _clipStack != null;

  /// Empties the save stack and the element stack, and resets the transform
  /// and clip parameters.
  ///
  /// Classes that override this method must call `super.clear()`.
  void clear() {
    _saveStack.clear();
    _clipStack = null;
    _currentTransform = Matrix4.identity();
  }

  /// The current transformation matrix.
  Matrix4 get currentTransform => _currentTransform;
  Matrix4 _currentTransform = Matrix4.identity();

  /// Saves current clip and transform on the save stack.
  ///
  /// Classes that override this method must call `super.save()`.
  void save() {
    _saveStack.add(_SaveStackEntry(
      transform: _currentTransform.clone(),
      clipStack: _clipStack == null ? null : List.from(_clipStack),
    ));
  }

  /// Restores current clip and transform from the save stack.
  ///
  /// Classes that override this method must call `super.restore()`.
  void restore() {
    if (_saveStack.isEmpty) {
      return;
    }
    final _SaveStackEntry entry = _saveStack.removeLast();
    _currentTransform = entry.transform;
    _clipStack = entry.clipStack;
  }

  /// Multiplies the [currentTransform] matrix by a translation.
  ///
  /// Classes that override this method must call `super.translate()`.
  void translate(double dx, double dy) {
    _currentTransform.translate(dx, dy);
  }

  /// Scales the [currentTransform] matrix.
  ///
  /// Classes that override this method must call `super.scale()`.
  void scale(double sx, double sy) {
    _currentTransform.scale(sx, sy);
  }

  /// Rotates the [currentTransform] matrix.
  ///
  /// Classes that override this method must call `super.rotate()`.
  void rotate(double radians) {
    _currentTransform.rotate(_unitZ, radians);
  }

  /// Skews the [currentTransform] matrix.
  ///
  /// Classes that override this method must call `super.skew()`.
  void skew(double sx, double sy) {
    final skewMatrix = Matrix4.identity();
    final Float64List storage = skewMatrix.storage;
    storage[1] = sy;
    storage[4] = sx;
    _currentTransform.multiply(skewMatrix);
  }

  /// Multiplies the [currentTransform] matrix by another matrix.
  ///
  /// Classes that override this method must call `super.transform()`.
  void transform(Float64List matrix4) {
    _currentTransform.multiply(Matrix4.fromFloat64List(matrix4));
  }

  /// Adds a rectangle to clipping stack.
  ///
  /// Classes that override this method must call `super.clipRect()`.
  @override
  void clipRect(ui.Rect rect) {
    _clipStack ??= [];
    _clipStack.add(new _SaveClipEntry.rect(rect, _currentTransform.clone()));
  }

  /// Adds a round rectangle to clipping stack.
  ///
  /// Classes that override this method must call `super.clipRRect()`.
  @override
  void clipRRect(ui.RRect rrect) {
    _clipStack ??= [];
    _clipStack.add(new _SaveClipEntry.rrect(rrect, _currentTransform.clone()));
  }

  /// Adds a path to clipping stack.
  ///
  /// Classes that override this method must call `super.clipPath()`.
  @override
  void clipPath(ui.Path path) {
    _clipStack ??= [];
    _clipStack.add(new _SaveClipEntry.path(path, _currentTransform.clone()));
  }
}
