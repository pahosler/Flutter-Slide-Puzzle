// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';
import 'package:flutter_web/material.dart';
import 'package:flutter_web/rendering.dart';
import 'package:flutter_web_ui/ui.dart';

void main() {
  test('ensure frame is scheduled for markNeedsSemanticsUpdate', () {
    final TestRenderObject renderObject = TestRenderObject();
    int onNeedVisualUpdateCallCount = 0;
    final PipelineOwner owner = PipelineOwner(onNeedVisualUpdate: () {
      onNeedVisualUpdateCallCount += 1;
    });
    owner.ensureSemantics();
    renderObject.attach(owner);
    renderObject.layout(const BoxConstraints
        .tightForFinite()); // semantics are only calculated if layout information is up to date.
    owner.flushSemantics();

    expect(onNeedVisualUpdateCallCount, 1);
    renderObject.markNeedsSemanticsUpdate();
    expect(onNeedVisualUpdateCallCount, 2);
  });

  test('detached RenderObject does not do semantics', () {
    final TestRenderObject renderObject = TestRenderObject();
    expect(renderObject.attached, isFalse);
    expect(renderObject.describeSemanticsConfigurationCallCount, 0);

    renderObject.markNeedsSemanticsUpdate();
    expect(renderObject.describeSemanticsConfigurationCallCount, 0);
  });
}

class TestRenderObject extends RenderObject {
  @override
  void debugAssertDoesMeetConstraints() {}

  @override
  Rect get paintBounds => null;

  @override
  void performLayout() {}

  @override
  void performResize() {}

  @override
  Rect get semanticBounds => Rect.fromLTWH(0.0, 0.0, 10.0, 20.0);

  int describeSemanticsConfigurationCallCount = 0;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    describeSemanticsConfigurationCallCount++;
  }
}
