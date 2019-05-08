// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// A layer to be composed into a scene.
///
/// A layer is the lowest-level rendering primitive. It represents an atomic
/// painting command.
abstract class Layer {
  /// The layer that contains us as a child.
  ContainerLayer parent;

  /// An estimated rectangle that this layer will draw into.
  ui.Rect paintBounds = ui.Rect.zero;

  /// Whether or not this layer actually needs to be painted in the scene.
  bool get needsPainting => !paintBounds.isEmpty;

  /// Pre-process this layer before painting.
  ///
  /// In this step, we compute the estimated [paintBounds] as well as
  /// apply heuristics to prepare the render cache for pictures that
  /// should be cached.
  void preroll(PrerollContext prerollContext, Matrix4 matrix);

  /// Paint this layer into the scene.
  void paint(PaintContext paintContext);
}

/// A context shared by all layers during the preroll pass.
class PrerollContext {
  /// A raster cache. Used to register candidates for caching.
  final RasterCache rasterCache;

  PrerollContext(this.rasterCache);
}

/// A context shared by all layers during the paint pass.
class PaintContext {
  /// The canvas to paint to.
  final BitmapCanvas canvas;

  /// A raster cache potentially containing pre-rendered pictures.
  final RasterCache rasterCache;

  PaintContext(this.canvas, this.rasterCache);
}

/// A layer that contains child layers.
abstract class ContainerLayer extends Layer {
  final List<Layer> _layers = <Layer>[];

  /// Register [child] as a child of this layer.
  void add(Layer child) {
    child.parent = this;
    _layers.add(child);
  }

  @override
  void preroll(PrerollContext context, Matrix4 matrix) {
    paintBounds = prerollChildren(context, matrix);
  }

  /// Run [preroll] on all of the child layers.
  ///
  /// Returns a [Rect] that covers the paint bounds of all of the child layers.
  /// If all of the child layers have empty paint bounds, then the returned
  /// [Rect] is empty.
  ui.Rect prerollChildren(PrerollContext context, Matrix4 childMatrix) {
    var childPaintBounds = ui.Rect.zero;
    for (var layer in _layers) {
      layer.preroll(context, childMatrix);
      if (childPaintBounds.isEmpty) {
        childPaintBounds = layer.paintBounds;
      } else if (!layer.paintBounds.isEmpty) {
        childPaintBounds = childPaintBounds.expandToInclude(layer.paintBounds);
      }
    }
    return childPaintBounds;
  }

  /// Calls [paint] on all child layers that need painting.
  void paintChildren(PaintContext context) {
    assert(needsPainting);

    for (var layer in _layers) {
      if (layer.needsPainting) {
        layer.paint(context);
      }
    }
  }
}

/// A layer that clips its child layers by a given [Path].
class ClipPathLayer extends ContainerLayer {
  /// The path used to clip child layers.
  final ui.Path _clipPath;

  ClipPathLayer(this._clipPath);

  @override
  void preroll(PrerollContext context, Matrix4 matrix) {
    final childPaintBounds = prerollChildren(context, matrix);
    final clipBounds = _clipPath.getBounds();
    if (childPaintBounds.overlaps(clipBounds)) {
      paintBounds = childPaintBounds.intersect(clipBounds);
    }
  }

  @override
  void paint(PaintContext context) {
    assert(needsPainting);

    context.canvas.save();
    context.canvas.clipPath(_clipPath);
    paintChildren(context);
    context.canvas.restore();
  }
}

/// A layer that clips its child layers by a given [Rect].
class ClipRectLayer extends ContainerLayer {
  /// The rectangle used to clip child layers.
  final ui.Rect _clipRect;

  ClipRectLayer(this._clipRect);

  @override
  void preroll(PrerollContext context, Matrix4 matrix) {
    final childPaintBounds = prerollChildren(context, matrix);
    if (childPaintBounds.overlaps(_clipRect)) {
      paintBounds = childPaintBounds.intersect(_clipRect);
    }
  }

  @override
  void paint(PaintContext context) {
    assert(needsPainting);

    context.canvas.save();
    context.canvas.clipRect(_clipRect);
    paintChildren(context);
    context.canvas.restore();
  }
}

/// A layer that clips its child layers by a given [RRect].
class ClipRRectLayer extends ContainerLayer {
  /// The rounded rectangle used to clip child layers.
  final ui.RRect _clipRRect;

  ClipRRectLayer(this._clipRRect);

  @override
  void preroll(PrerollContext context, Matrix4 matrix) {
    final childPaintBounds = prerollChildren(context, matrix);
    if (childPaintBounds.overlaps(_clipRRect.outerRect)) {
      paintBounds = childPaintBounds.intersect(_clipRRect.outerRect);
    }
  }

  @override
  void paint(PaintContext context) {
    assert(needsPainting);

    context.canvas.save();
    context.canvas.clipRRect(_clipRRect);
    paintChildren(context);
    context.canvas.restore();
  }
}

/// A layer that transforms its child layers by the given transform matrix.
class TransformLayer extends ContainerLayer {
  /// The matrix with which to transform the child layers.
  final Matrix4 _transform;

  TransformLayer(this._transform);

  @override
  void preroll(PrerollContext context, Matrix4 matrix) {
    final childMatrix = matrix * _transform;
    final childPaintBounds = prerollChildren(context, childMatrix);
    paintBounds = _transformRect(_transform, childPaintBounds);
  }

  /// Applies the given matrix as a perspective transform to the given point.
  ///
  /// This function assumes the given point has a z-coordinate of 0.0. The
  /// z-coordinate of the result is ignored.
  static ui.Offset _transformPoint(Matrix4 transform, ui.Offset point) {
    final Vector3 position3 = Vector3(point.dx, point.dy, 0.0);
    final Vector3 transformed3 = transform.perspectiveTransform(position3);
    return ui.Offset(transformed3.x, transformed3.y);
  }

  /// Returns a rect that bounds the result of applying the given matrix as a
  /// perspective transform to the given rect.
  ///
  /// This function assumes the given rect is in the plane with z equals 0.0.
  /// The transformed rect is then projected back into the plane with z equals
  /// 0.0 before computing its bounding rect.
  static ui.Rect _transformRect(Matrix4 transform, ui.Rect rect) {
    final ui.Offset point1 = _transformPoint(transform, rect.topLeft);
    final ui.Offset point2 = _transformPoint(transform, rect.topRight);
    final ui.Offset point3 = _transformPoint(transform, rect.bottomLeft);
    final ui.Offset point4 = _transformPoint(transform, rect.bottomRight);
    return ui.Rect.fromLTRB(
        _min4(point1.dx, point2.dx, point3.dx, point4.dx),
        _min4(point1.dy, point2.dy, point3.dy, point4.dy),
        _max4(point1.dx, point2.dx, point3.dx, point4.dx),
        _max4(point1.dy, point2.dy, point3.dy, point4.dy));
  }

  static double _min4(double a, double b, double c, double d) {
    return math.min(a, math.min(b, math.min(c, d)));
  }

  static double _max4(double a, double b, double c, double d) {
    return math.max(a, math.max(b, math.max(c, d)));
  }

  @override
  void paint(PaintContext context) {
    assert(needsPainting);

    context.canvas.save();
    context.canvas.transform(_transform.storage);
    paintChildren(context);
    context.canvas.restore();
  }
}

/// A layer containing a [Picture].
class PictureLayer extends Layer {
  /// The picture to paint into the canvas.
  final ui.Picture picture;

  /// The offset at which to paint the picture.
  final ui.Offset offset;

  /// A hint to the compositor about whether this picture is complex.
  final bool isComplex;

  /// A hint to the compositor that this picture is likely to change.
  final bool willChange;

  PictureLayer(this.picture, this.offset, this.isComplex, this.willChange);

  @override
  void preroll(PrerollContext context, Matrix4 matrix) {
    final cache = context.rasterCache;
    if (cache != null) {
      final translateMatrix = Matrix4.identity()
        ..setTranslationRaw(offset.dx, offset.dy, 0);
      final cacheMatrix = translateMatrix * matrix;
      cache.prepare(picture, cacheMatrix, isComplex, willChange);
    }

    paintBounds = picture.cullRect.shift(offset);
  }

  @override
  void paint(PaintContext context) {
    assert(picture != null);
    assert(needsPainting);

    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);

    if (context.rasterCache != null) {
      final cacheMatrix = context.canvas.currentTransform;
      final result = context.rasterCache.get(picture, cacheMatrix);
      if (result.isValid) {
        result.draw(context.canvas);
        return;
      }
    }
    context.canvas.drawPicture(picture);
    context.canvas.restore();
  }
}

/// A layer representing a physical shape.
///
/// The shape clips its children to a given [Path], and casts a shadow based
/// on the given elevation.
class PhysicalShapeLayer extends ContainerLayer {
  final double _elevation;
  final ui.Color _color;
  final ui.Color _shadowColor;
  final ui.Path _path;
  final ui.Clip _clipBehavior;

  PhysicalShapeLayer(
    this._elevation,
    this._color,
    this._shadowColor,
    this._path,
    this._clipBehavior,
  );

  @override
  void preroll(PrerollContext context, Matrix4 matrix) {
    prerollChildren(context, matrix);
    paintBounds =
        ElevationShadow.computeShadowRect(_path.getBounds(), _elevation);
  }

  @override
  void paint(PaintContext context) {
    assert(needsPainting);

    if (_elevation != 0) {
      drawShadow(context.canvas, _path, _shadowColor, _elevation,
          _color.alpha != 0xff);
    }

    final paint = (ui.Paint()..color = _color).webOnlyPaintData;
    if (_clipBehavior != ui.Clip.antiAliasWithSaveLayer) {
      context.canvas.drawPath(_path, paint);
    }

    int saveCount = context.canvas.save();
    switch (_clipBehavior) {
      case ui.Clip.hardEdge:
        context.canvas.clipPath(_path);
        break;
      case ui.Clip.antiAlias:
        // TODO(het): This is supposed to be different from Clip.hardEdge in
        // that it anti-aliases the clip. The canvas clipPath() method
        // should support this.
        context.canvas.clipPath(_path);
        break;
      case ui.Clip.antiAliasWithSaveLayer:
        context.canvas.clipPath(_path);
        context.canvas.saveLayer(paintBounds, null);
        break;
      case ui.Clip.none:
        break;
    }

    if (_clipBehavior == ui.Clip.antiAliasWithSaveLayer) {
      // If we want to avoid the bleeding edge artifact
      // (https://github.com/flutter/flutter/issues/18057#issue-328003931)
      // using saveLayer, we have to call drawPaint instead of drawPath as
      // anti-aliased drawPath will always have such artifacts.
      context.canvas.drawPaint(paint);
    }

    paintChildren(context);

    context.canvas.restoreToCount(saveCount);
  }

  /// Draws a shadow on the given [canvas] for the given [path].
  ///
  /// The blur of the shadow is decided by the [elevation], and the
  /// shadow is painted with the given [color].
  static void drawShadow(BitmapCanvas canvas, ui.Path path, ui.Color color,
      double elevation, bool transparentOccluder) {
    canvas.drawShadow(path, color, elevation, transparentOccluder);
  }
}
