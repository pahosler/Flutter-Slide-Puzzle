// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// A canvas that renders to DOM elements and CSS properties.
class DomCanvas extends EngineCanvas with SaveElementStackTracking {
  final html.Element rootElement = new html.Element.tag('flt-dom-canvas');

  DomCanvas() {
    rootElement.style
      ..position = 'absolute'
      ..top = '0'
      ..right = '0'
      ..bottom = '0'
      ..left = '0';
  }

  /// Prepare to reuse this canvas by clearing it's current contents.
  @override
  void clear() {
    super.clear();
    // TODO(yjbanov): we should measure if reusing old elements is beneficial.
    domRenderer.clearDom(rootElement);
  }

  @override
  void clipRect(ui.Rect rect) {
    throw UnimplementedError();
  }

  @override
  void clipRRect(ui.RRect rrect) {
    throw UnimplementedError();
  }

  @override
  void clipPath(ui.Path path) {
    throw UnimplementedError();
  }

  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    // TODO(yjbanov): implement blendMode
    html.Element box = html.Element.tag('draw-color');
    box.style
      ..position = 'absolute'
      ..top = '0'
      ..right = '0'
      ..bottom = '0'
      ..left = '0'
      ..backgroundColor = color.toCssString();
    currentElement.append(box);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawPaint(ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawRect(ui.Rect rect, ui.PaintData paint) {
    assert(paint.shader == null);
    final rectangle = html.Element.tag('draw-rect');
    assert(() {
      rectangle.setAttribute('flt-rect', '$rect');
      rectangle.setAttribute('flt-paint', '$paint');
      return true;
    }());
    String effectiveTransform;
    bool isStroke = paint.style == ui.PaintingStyle.stroke;
    var left = math.min(rect.left, rect.right);
    var right = math.max(rect.left, rect.right);
    var top = math.min(rect.top, rect.bottom);
    var bottom = math.max(rect.top, rect.bottom);
    if (currentTransform.isIdentity()) {
      if (isStroke) {
        effectiveTransform =
            'translate(${left - (paint.strokeWidth / 2.0)}px, ${top - (paint.strokeWidth / 2.0)}px)';
      } else {
        effectiveTransform = 'translate(${left}px, ${top}px)';
      }
    } else {
      // Clone to avoid mutating _transform.
      Matrix4 translated = currentTransform.clone();
      if (isStroke) {
        translated.translate(
            left - (paint.strokeWidth / 2.0), top - (paint.strokeWidth / 2.0));
      } else {
        translated.translate(left, top);
      }
      effectiveTransform = matrix4ToCssTransform(translated);
    }
    var style = rectangle.style;
    style
      ..position = 'absolute'
      ..transformOrigin = '0 0 0'
      ..transform = effectiveTransform;

    final String cssColor = paint.color?.toCssString() ?? '#000000';

    if (paint.maskFilter != null) {
      style.filter = 'blur(${paint.maskFilter.webOnlySigma}px)';
    }

    if (isStroke) {
      style
        ..width = '${right - left - paint.strokeWidth}px'
        ..height = '${bottom - top - paint.strokeWidth}px'
        ..border = '${paint.strokeWidth}px solid ${cssColor}';
    } else {
      style
        ..width = '${right - left}px'
        ..height = '${bottom - top}px'
        ..backgroundColor = cssColor;
    }

    currentElement.append(rectangle);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawOval(ui.Rect rect, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawPath(ui.Path path, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawShadow(ui.Path path, ui.Color color, double elevation,
      bool transparentOccluder) {
    throw UnimplementedError();
  }

  @override
  void drawImage(ui.Image image, ui.Offset p, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawImageRect(
      ui.Image image, ui.Rect src, ui.Rect dst, ui.PaintData paint) {
    throw UnimplementedError();
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    assert(paragraph.webOnlyIsLaidOut);

    html.Element paragraphElement =
        paragraph.webOnlyGetParagraphElement().clone(true);

    String cssTransform =
        matrix4ToCssTransform(transformWithOffset(currentTransform, offset));

    final html.CssStyleDeclaration paragraphStyle = paragraphElement.style;
    paragraphStyle
      ..position = 'absolute'
      ..transformOrigin = '0 0 0'
      ..transform = cssTransform
      ..whiteSpace = 'pre-wrap'
      ..width = '${paragraph.width}px';

    final ParagraphGeometricStyle style =
        paragraph.webOnlyGetParagraphGeometricStyle();

    // TODO(flutter_web): Implement the ellipsis overflow for multi-line text
    //  too. As a pre-requisite, we need to be able to programmatically find
    //  line breaks.
    if (style.ellipsis != null &&
        (style.maxLines == null || style.maxLines == 1)) {
      paragraphStyle
        ..height = '${paragraph.webOnlyMaxLinesHeight}px'
        ..whiteSpace = 'pre'
        ..overflow = 'hidden'
        ..textOverflow = 'ellipsis';
    } else if (paragraph.didExceedMaxLines) {
      paragraphStyle
        ..height = '${paragraph.webOnlyMaxLinesHeight}px'
        ..overflowY = 'hidden';
    } else {
      paragraphStyle.height = '${paragraph.height}px';
    }

    currentElement.append(paragraphElement);
  }
}
