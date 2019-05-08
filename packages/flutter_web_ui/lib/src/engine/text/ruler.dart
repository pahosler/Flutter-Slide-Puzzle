// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// Contains the subset of [ui.ParagraphStyle] properties that affect layout.
class ParagraphGeometricStyle {
  ParagraphGeometricStyle({
    this.fontWeight,
    this.fontStyle,
    this.fontFamily,
    this.fontSize,
    this.lineHeight,
    this.maxLines,
    this.letterSpacing,
    this.wordSpacing,
    this.decoration,
    this.ellipsis,
  });

  final ui.FontWeight fontWeight;
  final ui.FontStyle fontStyle;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final int maxLines;
  final double letterSpacing;
  final double wordSpacing;
  final String decoration;
  final String ellipsis;

  // Since all fields above are primitives, cache hashcode since ruler lookups
  // use this style as key.
  int _cachedHashCode;

  /// Returns the font-family that should be used to style the paragraph. It may
  /// or may not be different from [fontFamily]:
  ///
  /// - Always returns "Ahem" in tests.
  /// - Provides correct defaults when [fontFamily] doesn't have a value.
  String get effectiveFontFamily {
    if (assertionsEnabled) {
      // In widget tests we use a predictable-size font "Ahem". This makes
      // widget tests predictable and less flaky.
      if (domRenderer.debugIsInWidgetTest) {
        return 'Ahem';
      }
    }
    if (fontFamily == null || fontFamily.isEmpty) {
      return DomRenderer.defaultFontFamily;
    }
    return fontFamily;
  }

  String _cssFontString;

  /// Cached font string that can be used in CSS.
  ///
  /// See <https://developer.mozilla.org/en-US/docs/Web/CSS/font>.
  String get cssFontString {
    if (_cssFontString == null) {
      _cssFontString = _buildCssFontString();
    }
    return _cssFontString;
  }

  String _buildCssFontString() {
    final result = StringBuffer();

    // Font style
    if (fontStyle != null) {
      result.write(fontStyle == ui.FontStyle.normal ? 'normal' : 'italic');
    } else {
      result.write(DomRenderer.defaultFontStyle);
    }
    result.write(' ');

    // Font weight.
    if (fontWeight != null) {
      result.write(ui.webOnlyFontWeightToCss(fontWeight));
    } else {
      result.write(DomRenderer.defaultFontWeight);
    }
    result.write(' ');

    if (fontSize != null) {
      result.write(fontSize.floor());
      result.write('px');
    } else {
      result.write(DomRenderer.defaultFontSize);
    }
    result.write(' ');
    result.write(effectiveFontFamily);

    return result.toString();
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    final ParagraphGeometricStyle typedOther = other;
    return fontWeight == typedOther.fontWeight &&
        fontStyle == typedOther.fontStyle &&
        fontFamily == typedOther.fontFamily &&
        fontSize == typedOther.fontSize &&
        lineHeight == typedOther.lineHeight &&
        maxLines == typedOther.maxLines &&
        letterSpacing == typedOther.letterSpacing &&
        wordSpacing == typedOther.wordSpacing &&
        decoration == typedOther.decoration &&
        ellipsis == typedOther.ellipsis;
  }

  @override
  int get hashCode => _cachedHashCode ??= ui.hashValues(
        fontWeight,
        fontStyle,
        fontFamily,
        fontSize,
        lineHeight,
        maxLines,
        letterSpacing,
        wordSpacing,
        decoration,
        ellipsis,
      );

  @override
  String toString() {
    if (assertionsEnabled) {
      return '$runtimeType(fontWeight: $fontWeight, fontStyle: $fontStyle,'
          ' fontFamily: $fontFamily, fontSize: $fontSize,'
          ' lineHeight: $lineHeight,'
          ' maxLines: $maxLines,'
          ' letterSpacing: $letterSpacing,'
          ' wordSpacing: $wordSpacing,'
          ' decoration: $decoration,'
          ' ellipsis: $ellipsis,'
          ')';
    } else {
      return super.toString();
    }
  }
}

/// Provides text dimensions found on [_element]. The idea behind this class is
/// to allow the [ParagraphRuler] to mutate multiple dom elements and allow
/// consumers to lazily read the measurements.
///
/// The [ParagraphRuler] would have multiple instances of [TextDimensions] with
/// different backing elements for different types of measurements. When a
/// measurement is needed, the [ParagraphRuler] would mutate all the backing
/// elements at once. The consumer of the ruler can later read those
/// measurements.
///
/// The rationale behind this is to minimize browser reflows by batching dom
/// writes first, then performing all the reads.
class TextDimensions {
  TextDimensions(this._element);

  final html.HtmlElement _element;
  html.Rectangle<num> _cachedBoundingClientRect;

  /// Attempts to efficiently copy text from [from].
  ///
  /// The primary efficiency gain is from rare occurrence of rich text in
  /// typical apps.
  void updateText(ui.Paragraph from, ParagraphGeometricStyle style) {
    assert(from != null);
    assert(_element != null);
    assert(from.webOnlyDebugHasSameRootStyle(style));
    assert(() {
      bool wasEmptyOrPlainText = _element.childNodes.isEmpty ||
          (_element.childNodes.length == 1 &&
              _element.childNodes.first is html.Text);
      if (!wasEmptyOrPlainText) {
        throw Exception(
            'Failed to copy text into the paragraph measuring element. The '
            'element already contains rich text "${_element.innerHtml}". It is '
            'likely that a previous measurement did not clean up after '
            'itself.');
      }
      return true;
    }());

    _invalidateBoundsCache();
    String plainText = from.webOnlyGetPlainText();
    if (plainText != null) {
      // Plain text: just set the string. The paragraph's style is assumed to
      // match the style set on the `element`. Setting text as plain string is
      // faster because it doesn't change the DOM structure or CSS attributes,
      // and therefore doesn't trigger style recalculations in the browser.
      _element.text = plainText;
    } else {
      // Rich text: deeply copy contents. This is the slow case that should be
      // avoided if fast layout performance is desired.
      final html.Element copy = from.webOnlyGetParagraphElement().clone(true);
      _element.children.addAll(copy.children);
    }
  }

  // Updated element style width.
  void updateWidth(String cssWidth) {
    _invalidateBoundsCache();
    _element.style.width = cssWidth;
  }

  void _invalidateBoundsCache() {
    _cachedBoundingClientRect = null;
  }

  /// Sets text of contents to a single space character to measure empty text.
  void updateTextToSpace() {
    _invalidateBoundsCache();
    _element.text = ' ';
  }

  /// Applies geometric style properties to the [element].
  void applyStyle(ParagraphGeometricStyle style) {
    _element.style
      ..fontSize = style.fontSize != null ? '${style.fontSize.floor()}px' : null
      ..fontFamily = style.effectiveFontFamily
      ..fontWeight = style.fontWeight != null
          ? ui.webOnlyFontWeightToCss(style.fontWeight)
          : null
      ..fontStyle = style.fontStyle != null
          ? style.fontStyle == ui.FontStyle.normal ? 'normal' : 'italic'
          : null
      ..letterSpacing =
          style.letterSpacing != null ? '${style.letterSpacing}px' : null
      ..wordSpacing =
          style.wordSpacing != null ? '${style.wordSpacing}px' : null
      ..textDecoration = style.decoration;
    if (style.lineHeight != null) {
      _element.style.lineHeight = style.lineHeight.toString();
    }
    _invalidateBoundsCache();
  }

  /// Appends element and probe to hostElement that is setup for a specific
  /// TextStyle.
  void appendToHost(html.HtmlElement hostElement) {
    hostElement.append(_element);
    _invalidateBoundsCache();
  }

  html.Rectangle<num> _readAndCacheMetrics() =>
      _cachedBoundingClientRect ??= _element.getBoundingClientRect();

  /// The width of the paragraph being measured.
  double get width => _readAndCacheMetrics().width;

  /// The height of the paragraph being measured.
  double get height => _readAndCacheMetrics().height;
}

/// Performs 4 types of measurements:
///
/// 1. Single line: can be prepared by calling [measureAsSingleLine].
///    Measurement values will be available at [singleLineDimensions].
///
/// 2. Minimum intrinsic width: can be prepared by calling
///    [measureMinIntrinsicWidth]. Measurement values will be available at
///    [minIntrinsicDimensions].
///
/// 3. Constrained: can be prepared by calling [measureWithConstraints] and
///    passing the constraints. Measurement values will be available at
///    [constrainedDimensions].
///
/// 4. Boxes: within a paragraph, it measures a list of text boxes that enclose
///    a given range of text.
///
/// For performance reasons, it's advised to use [measureAll] and then reading
/// whatever measurements are needed. This causes the browser to only reflow
/// once instead of many times.
///
/// The [measureAll] method performs the first 3 stateful measurements but not
/// the 4th one.
///
/// This class is both reusable and stateful. Use it carefully. The correct
/// usage is as follows:
///
/// * First, call [willMeasure] passing it the paragraph to be measured.
/// * Call any of the [measureAsSingleLine], [measureMinIntrinsicWidth],
///   [measureWithConstraints], or [measureAll], to prepare the respective
///   measurement. These methods can be called any number of times.
/// * Call [didMeasure] to indicate that you are done with the paragraph passed
///   to the [willMeasure] method.
///
/// It is safe to reuse this object as long as paragraphs passed to the
/// [measure] method have the same style.
///
/// The only stateless method provided by this class is [measureBoxesForRange]
/// that doesn't rely on [willMeasure] and [didMeasure] lifecycle methods.
///
/// This class optimizes for plain text paragraphs, which should constitute the
/// majority of paragraphs in typical apps.
class ParagraphRuler {
  /// The only style that this [ParagraphRuler] measures text.
  final ParagraphGeometricStyle style;

  /// Probe to use for measuring alphabetic base line.
  final _probe = html.DivElement();

  /// Cached value of alphabetic base line.
  double _cachedAlphabeticBaseline;

  ParagraphRuler(this.style) {
    _configureSingleLineHostElements();
    // Since alphabeticbaseline will be same regardless of constraints.
    // We can measure it using a probe on the single line dimensions
    // host.
    _singleLineHost.append(_probe);
    _configureMinIntrinsicHostElements();
    _configureConstrainedHostElements();
  }

  /// The alphabetic baseline of the paragraph being measured.
  double get alphabeticBaseline =>
      _cachedAlphabeticBaseline ??= _probe.getBoundingClientRect().bottom;

  // Elements used to measure single-line metrics.
  final html.DivElement _singleLineHost = html.DivElement();
  final TextDimensions singleLineDimensions =
      TextDimensions(html.ParagraphElement());

  // Elements used to measure minIntrinsicWidth.
  final html.DivElement _minIntrinsicHost = html.DivElement();
  TextDimensions minIntrinsicDimensions =
      TextDimensions(html.ParagraphElement());

  // Elements used to measure metrics under a width constraint.
  final html.DivElement _constrainedHost = html.DivElement();
  TextDimensions constrainedDimensions =
      TextDimensions(html.ParagraphElement());

  // Elements used to measure the line-height metric.
  html.DivElement _lineHeightHost;
  TextDimensions _lineHeightDimensions;
  TextDimensions get lineHeightDimensions {
    // Lazily create the elements for line-height measurement since they are not
    // always needed.
    if (_lineHeightDimensions == null) {
      _lineHeightHost = html.DivElement();
      _lineHeightDimensions = TextDimensions(html.ParagraphElement());
      _configureLineHeightHostElements();
    }
    return _lineHeightDimensions;
  }

  /// The number of times this ruler was used this frame.
  ///
  /// This value is used to determine which rulers are rarely used and should be
  /// evicted from the ruler cache.
  int get hitCount => _hitCount;
  int _hitCount = 0;

  /// Resets the hit count back to zero.
  void resetHitCount() {
    _hitCount = 0;
  }

  /// Makes sure this ruler is not used again after it has been disposed of,
  /// which would indicate a bug.
  bool get debugIsDisposed => _debugIsDisposed;
  bool _debugIsDisposed = false;

  void _configureSingleLineHostElements() {
    _singleLineHost.style
      ..visibility = 'hidden'
      ..position = 'absolute'
      ..top = '0' // this is important as baseline == probe.bottom
      ..left = '0'
      ..display = 'flex'
      ..flexDirection = 'row'
      ..alignItems = 'baseline'
      ..margin = '0'
      ..border = '0'
      ..padding = '0';

    singleLineDimensions.applyStyle(style);

    // Force single-line (even if wider than screen) and preserve whitespaces.
    singleLineDimensions._element.style.whiteSpace = 'pre';

    singleLineDimensions.appendToHost(_singleLineHost);
    TextMeasurementService.instance.addHostElement(_singleLineHost);
  }

  void _configureMinIntrinsicHostElements() {
    // Configure min intrinsic host elements.
    _minIntrinsicHost.style
      ..visibility = 'hidden'
      ..position = 'absolute'
      ..top = '0' // this is important as baseline == probe.bottom
      ..left = '0'
      ..display = 'flex'
      ..flexDirection = 'row'
      ..margin = '0'
      ..border = '0'
      ..padding = '0';

    minIntrinsicDimensions.applyStyle(style);

    // "flex: 0" causes the paragraph element to shrink horizontally, exposing
    // its minimum intrinsic width.
    minIntrinsicDimensions._element.style
      ..flex = '0'
      ..display = 'inline'
      // Preserve whitespaces.
      ..whiteSpace = 'pre-wrap';

    _minIntrinsicHost.append(minIntrinsicDimensions._element);
    TextMeasurementService.instance.addHostElement(_minIntrinsicHost);
  }

  void _configureConstrainedHostElements() {
    _constrainedHost.style
      ..visibility = 'hidden'
      ..position = 'absolute'
      ..top = '0' // this is important as baseline == probe.bottom
      ..left = '0'
      ..display = 'flex'
      ..flexDirection = 'row'
      ..alignItems = 'baseline'
      ..margin = '0'
      ..border = '0'
      ..padding = '0';

    constrainedDimensions.applyStyle(style);
    constrainedDimensions._element.style
      ..display = 'block'
      // Preserve whitespaces.
      ..whiteSpace = 'pre-wrap';

    constrainedDimensions.appendToHost(_constrainedHost);
    TextMeasurementService.instance.addHostElement(_constrainedHost);
  }

  void _configureLineHeightHostElements() {
    _lineHeightHost.style
      ..visibility = 'hidden'
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..margin = '0'
      ..border = '0'
      ..padding = '0';

    lineHeightDimensions.applyStyle(style);

    // Force single-line (even if wider than screen) and preserve whitespaces.
    lineHeightDimensions._element.style.whiteSpace = 'pre';

    // To measure line-height, all we need is a whitespace.
    lineHeightDimensions.updateTextToSpace();

    lineHeightDimensions.appendToHost(_lineHeightHost);
    TextMeasurementService.instance.addHostElement(_lineHeightHost);
  }

  /// The paragraph being measured.
  ui.Paragraph _paragraph;

  /// Prepares this ruler for measuring the given [paragraph].
  ///
  /// This method must be called before calling any of the `measure*` methods.
  void willMeasure(ui.Paragraph paragraph) {
    assert(paragraph != null);
    assert(() {
      if (_paragraph != null) {
        throw Exception(
            'Attempted to reuse a $ParagraphRuler but it is currently '
            'measuring another paragraph ($_paragraph). It is possible that ');
      }
      return true;
    }());
    assert(paragraph.webOnlyDebugHasSameRootStyle(style));
    _hitCount += 1;
    _paragraph = paragraph;
  }

  /// Prepares all 3 measurements:
  /// 1. single line.
  /// 2. minimum intrinsic width.
  /// 3. constrained.
  void measureAll(ui.ParagraphConstraints constraints) {
    measureAsSingleLine();
    measureMinIntrinsicWidth();
    measureWithConstraints(constraints);
  }

  /// Lays out the paragraph in a single line, giving it infinite amount of
  /// horizontal space.
  ///
  /// Measures [width], [height], and [alphabeticBaseline].
  void measureAsSingleLine() {
    assert(!_debugIsDisposed);
    assert(_paragraph != null);

    // HACK(mdebbar): TextField uses an empty string to measure the line height,
    // which doesn't work. So we need to replace it with a whitespace. The
    // correct fix would be to do line height and baseline measurements and
    // cache them separately.
    if (_paragraph.webOnlyGetPlainText() == '') {
      singleLineDimensions.updateTextToSpace();
    } else {
      singleLineDimensions.updateText(_paragraph, style);
    }
  }

  /// Lays out the paragraph inside a flex row and sets "flex: 0", which
  /// squeezes the paragraph, forcing it to occupy minimum intrinsic width.
  ///
  /// Measures [width] and [height].
  void measureMinIntrinsicWidth() {
    assert(!_debugIsDisposed);
    assert(_paragraph != null);

    minIntrinsicDimensions.updateText(_paragraph, style);
  }

  /// Lays out the paragraph giving it a width constraint.
  ///
  /// Measures [width], [height], and [alphabeticBaseline].
  void measureWithConstraints(ui.ParagraphConstraints constraints) {
    assert(!_debugIsDisposed);
    assert(_paragraph != null);

    constrainedDimensions.updateText(_paragraph, style);

    // The extra 0.5 is because sometimes the browser needs slightly more space
    // than the size it reports back. When that happens the text may be wrap
    // when we thought it didn't.
    constrainedDimensions.updateWidth('${constraints.width + 0.5}px');
  }

  /// Performs clean-up after a measurement is done, preparing this ruler for
  /// a future reuse.
  ///
  /// Call this method immediately after calling `measure*` methods for a
  /// particular [paragraph]. This ruler is not reusable until [didMeasure] is
  /// called.
  void didMeasure() {
    assert(_paragraph != null);
    // Remove any rich text we set during layout for the following reasons:
    // - there won't be any text for the browser to lay out when we commit the
    //   current frame.
    // - this keeps the cost of removing content together with the measurement
    //   in the profile. Otherwise, the cost of removing will be paid by a
    //   random next paragraph measured in the future, and make the performance
    //   profile hard to understand.
    //
    // We do not do this for plain text, because replacing plain text is more
    // expensive than paying the cost of the DOM mutation to clean it.
    if (_paragraph.webOnlyGetPlainText() == null) {
      domRenderer
        ..clearDom(singleLineDimensions._element)
        ..clearDom(minIntrinsicDimensions._element)
        ..clearDom(constrainedDimensions._element);
    }
    _paragraph = null;
  }

  /// Performs stateless measurement of text boxes for a given range of text.
  ///
  /// This method doesn't depend on [willMeasure] and [didMeasure] lifecycle
  /// methods.
  List<ui.TextBox> measureBoxesForRange(
    String plainText,
    ui.ParagraphConstraints constraints, {
    int start,
    int end,
    double alignOffset,
    ui.TextDirection textDirection,
  }) {
    assert(!_debugIsDisposed);
    assert(start >= 0 && start <= plainText.length);
    assert(end >= 0 && end <= plainText.length);
    assert(start <= end);

    final String before = plainText.substring(0, start);
    final String rangeText = plainText.substring(start, end);
    final String after = plainText.substring(end);

    final html.SpanElement rangeSpan = html.SpanElement()..text = rangeText;

    // Setup the [ruler.constrainedDimensions] element to be used for measurement.
    domRenderer.clearDom(constrainedDimensions._element);
    constrainedDimensions._element
      ..appendText(before)
      ..append(rangeSpan)
      ..appendText(after);
    constrainedDimensions.updateWidth('${constraints.width}px');

    // Measure the rects of [rangeSpan].
    final List<html.Rectangle<num>> clientRects = rangeSpan.getClientRects();
    final List<ui.TextBox> boxes = [];

    for (html.Rectangle<num> rect in clientRects) {
      boxes.add(ui.TextBox.fromLTRBD(
        rect.left + alignOffset,
        rect.top,
        rect.right + alignOffset,
        rect.bottom,
        textDirection,
      ));
    }

    // Cleanup after measuring the boxes.
    domRenderer.clearDom(constrainedDimensions._element);
    return boxes;
  }

  /// Detaches this ruler from the DOM and makes it unusable for future
  /// measurements.
  ///
  /// Disposed rulers should be garbage collected after calling this method.
  void dispose() {
    assert(() {
      if (_paragraph != null) {
        throw Exception('Attempted to dispose of a ruler in the middle of '
            'measurement. This is likely a bug in the framework.');
      }
      return true;
    }());
    _singleLineHost.remove();
    _minIntrinsicHost.remove();
    _constrainedHost.remove();
    _lineHeightHost?.remove();
    assert(() {
      _debugIsDisposed = true;
      return true;
    }());
  }

  // Bounded cache for text measurement for a particular width constraint.
  Map<String, List<RulerCacheEntry>> _measurementCache =
      Map<String, List<RulerCacheEntry>>();
  // Mru list for cache.
  final List<String> _mruList = [];
  static const int _cacheLimit = 2400;
  // Number of items to evict when cache limit is reached.
  static const int _cacheBlockFactor = 100;
  // Number of constraint results per unique text item.
  // This limit prevents growth during animation where the size of a container
  // is changing.
  static const int _constraintCacheSize = 8;

  void cacheMeasurement(ui.Paragraph paragraph,
      ui.ParagraphConstraints constraints, RulerCacheEntry item) {
    final plainText = paragraph.webOnlyGetPlainText();
    List<RulerCacheEntry> constraintCache = _measurementCache[plainText];
    if (constraintCache == null) {
      constraintCache = _measurementCache[plainText] = List<RulerCacheEntry>();
    }
    constraintCache.add(item);
    if (constraintCache.length > _constraintCacheSize) {
      constraintCache.removeAt(0);
    }
    _mruList.add(plainText);
    if (_mruList.length > _cacheLimit) {
      // Evict a range.
      for (int i = 0; i < _cacheBlockFactor; i++) {
        _measurementCache.remove(_mruList[i]);
      }
      _mruList.removeRange(0, _cacheBlockFactor);
    }
  }

  RulerCacheEntry cacheLookup(
      ui.Paragraph paragraph, ui.ParagraphConstraints constraints) {
    List<RulerCacheEntry> constraintCache =
        _measurementCache[paragraph.webOnlyGetPlainText()];
    if (constraintCache == null) {
      return null;
    }
    for (int i = 0, len = constraintCache.length; i < len; i++) {
      RulerCacheEntry item = constraintCache[i];
      if (item.constraintWidth == constraints.width) {
        return item;
      }
    }
    return null;
  }
}

/// Item used to cache mru measurements.
class RulerCacheEntry {
  final double constraintWidth;
  final bool isSingleLine;
  final double width;
  final double height;
  final double lineHeight;
  final double minIntrinsicWidth;
  final double maxIntrinsicWidth;
  final double alphabeticBaseline;
  final double ideographicBaseline;

  RulerCacheEntry(this.constraintWidth,
      {this.isSingleLine,
      this.width,
      this.height,
      this.lineHeight,
      this.minIntrinsicWidth,
      this.maxIntrinsicWidth,
      this.alphabeticBaseline,
      this.ideographicBaseline});

  void applyToParagraph(ui.Paragraph paragraph) {
    paragraph.webOnlySetComputedLayout(
        isSingleLine: isSingleLine,
        width: width,
        height: height,
        lineHeight: lineHeight,
        minIntrinsicWidth: minIntrinsicWidth,
        maxIntrinsicWidth: maxIntrinsicWidth,
        alphabeticBaseline: alphabeticBaseline,
        ideographicBaseline: ideographicBaseline);
  }
}
