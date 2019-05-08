// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// Generic callback signature, used by [_futurize].
typedef Callback<T> = void Function(T result);

/// Signature for a method that receives a [_Callback].
///
/// Return value should be null on success, and a string error message on
/// failure.
typedef Callbacker<T> = String Function(Callback<T> callback);

/// Converts a method that receives a value-returning callback to a method that
/// returns a Future.
///
/// Return a [String] to cause an [Exception] to be synchronously thrown with
/// that string as a message.
///
/// If the callback is called with null, the future completes with an error.
///
/// Example usage:
///
/// ```dart
/// typedef IntCallback = void Function(int result);
///
/// String _doSomethingAndCallback(IntCallback callback) {
///   new Timer(new Duration(seconds: 1), () { callback(1); });
/// }
///
/// Future<int> doSomething() {
///   return _futurize(_doSomethingAndCallback);
/// }
/// ```
Future<T> futurize<T>(Callbacker<T> callbacker) {
  final Completer<T> completer = new Completer<T>.sync();
  final String error = callbacker((T t) {
    if (t == null) {
      completer.completeError(new Exception('operation failed'));
    } else {
      completer.complete(t);
    }
  });
  if (error != null) throw new Exception(error);
  return completer.future;
}

/// Converts [matrix] to CSS transform value.
String matrix4ToCssTransform(Matrix4 matrix) {
  return float64ListToCssTransform(matrix.storage);
}

/// Returns `true` is the [matrix] describes an identity transformation.
bool isIdentityFloat64ListTransform(Float64List matrix) {
  assert(matrix.length == 16);
  final Float64List m = matrix;
  return m[0] == 1.0 &&
      m[1] == 0.0 &&
      m[2] == 0.0 &&
      m[3] == 0.0 &&
      m[4] == 0.0 &&
      m[5] == 1.0 &&
      m[6] == 0.0 &&
      m[7] == 0.0 &&
      m[8] == 0.0 &&
      m[9] == 0.0 &&
      m[10] == 1.0 &&
      m[11] == 0.0 &&
      m[12] == 0.0 &&
      m[13] == 0.0 &&
      m[14] == 0.0 &&
      m[15] == 1.0;
}

/// Converts [matrix] to CSS transform value.
String float64ListToCssTransform(Float64List matrix) {
  assert(matrix.length == 16);
  final Float64List m = matrix;
  if (m[0] == 1.0 &&
      m[1] == 0.0 &&
      m[2] == 0.0 &&
      m[3] == 0.0 &&
      m[4] == 0.0 &&
      m[5] == 1.0 &&
      m[6] == 0.0 &&
      m[7] == 0.0 &&
      m[8] == 0.0 &&
      m[9] == 0.0 &&
      m[10] == 1.0 &&
      m[11] == 0.0 &&
      // 12 can be anything
      // 13 can be anything
      m[14] == 0.0 &&
      m[15] == 1.0) {
    var tx = m[12];
    var ty = m[13];
    return 'translate(${tx}px, ${ty}px)';
  } else {
    return 'matrix3d(${m[0]},${m[1]},${m[2]},${m[3]},${m[4]},${m[5]},${m[6]},${m[7]},${m[8]},${m[9]},${m[10]},${m[11]},${m[12]},${m[13]},${m[14]},${m[15]})';
  }
}

bool get assertionsEnabled {
  var k = false;
  assert(k = true);
  return k;
}

/// Converts a rectangular clip specified in local coordinates to screen
/// coordinates given the effective [transform].
///
/// The resulting clip is a rectangle aligned to the pixel grid, i.e. two of
/// its sides are vertical and two are horizontal. In the presence of rotations
/// the rectangle is inflated such that it fits the rotated rectangle.
ui.Rect localClipRectToGlobalClip({ui.Rect localClip, Matrix4 transform}) {
  return localClipToGlobalClip(
    localLeft: localClip.left,
    localTop: localClip.top,
    localRight: localClip.right,
    localBottom: localClip.bottom,
    transform: transform,
  );
}

/// Converts a rectangular clip specified in local coordinates to screen
/// coordinates given the effective [transform].
///
/// This is the same as [localClipRectToGlobalClip], except that the local clip
/// rect is specified in terms of left, top, right, and bottom edge offsets.
ui.Rect localClipToGlobalClip({
  double localLeft,
  double localTop,
  double localRight,
  double localBottom,
  Matrix4 transform,
}) {
  assert(localLeft != null);
  assert(localTop != null);
  assert(localRight != null);
  assert(localBottom != null);

  // Construct a matrix where each row represents a vector pointing at
  // one of the four corners of the (left, top, right, bottom) rectangle.
  // Using the row-major order allows us to multiply the matrix in-place
  // by the transposed current transformation matrix. The vector_math
  // library has a convenience function `multiplyTranspose` that performs
  // the multiplication without copying. This way we compute the positions
  // of all four points in a single matrix-by-matrix multiplication at the
  // cost of one `Matrix4` instance and one `Float64List` instance.
  //
  // The rejected alternative was to use `Vector3` for each point and
  // multiply by the current transform. However, that would cost us four
  // `Vector3` instances, four `Float64List` instances, and four
  // matrix-by-vector multiplications.
  //
  // `Float64List` initializes the array with zeros, so we do not have to
  // fill in every single element.
  final Float64List pointData = Float64List(16);

  // Row 0: top-left
  pointData[0] = localLeft;
  pointData[4] = localTop;
  pointData[12] = 1;

  // Row 1: top-right
  pointData[1] = localRight;
  pointData[5] = localTop;
  pointData[13] = 1;

  // Row 2: bottom-left
  pointData[2] = localLeft;
  pointData[6] = localBottom;
  pointData[14] = 1;

  // Row 3: bottom-right
  pointData[3] = localRight;
  pointData[7] = localBottom;
  pointData[15] = 1;

  final Matrix4 pointMatrix = Matrix4.fromFloat64List(pointData);
  pointMatrix.multiplyTranspose(transform);

  return ui.Rect.fromLTRB(
    math.min(math.min(math.min(pointData[0], pointData[1]), pointData[2]),
        pointData[3]),
    math.min(math.min(math.min(pointData[4], pointData[5]), pointData[6]),
        pointData[7]),
    math.max(math.max(math.max(pointData[0], pointData[1]), pointData[2]),
        pointData[3]),
    math.max(math.max(math.max(pointData[4], pointData[5]), pointData[6]),
        pointData[7]),
  );
}

/// Returns true if [rect] contains every point that is also contained by the
/// [other] rect.
///
/// Points on the edges of both rectangles are also considered. For example,
/// this returns true when the two rects are equal to each other.
bool rectContainsOther(ui.Rect rect, ui.Rect other) {
  return rect.left <= other.left &&
      rect.top <= other.top &&
      rect.right >= other.right &&
      rect.bottom >= other.bottom;
}
