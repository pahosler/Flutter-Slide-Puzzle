// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web_ui/ui.dart' as ui;

import 'package:flutter_web/foundation.dart';
import 'package:flutter_web/gestures.dart';
import 'package:flutter_web/scheduler.dart';
import 'package:flutter_web/services.dart';

import '../flutter_test_alternative.dart';

typedef HandleEventCallback = void Function(PointerEvent event);

class TestGestureFlutterBinding extends BindingBase
    with ServicesBinding, SchedulerBinding, GestureBinding {
  HandleEventCallback callback;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    super.handleEvent(event, entry);
    if (callback != null) {
      callback(event);
    }
  }
}

TestGestureFlutterBinding _binding = TestGestureFlutterBinding();

void ensureTestGestureBinding() {
  _binding ??= TestGestureFlutterBinding();
  assert(GestureBinding.instance != null);
}

void main() {
  ui.window.webOnlyScheduleFrameCallback = () {};
  setUp(ensureTestGestureBinding);

  group(MouseTracker, () {
    final List<PointerEnterEvent> enter = <PointerEnterEvent>[];
    final List<PointerHoverEvent> move = <PointerHoverEvent>[];
    final List<PointerExitEvent> exit = <PointerExitEvent>[];
    final MouseTrackerAnnotation annotation = MouseTrackerAnnotation(
      onEnter: (PointerEnterEvent event) => enter.add(event),
      onHover: (PointerHoverEvent event) => move.add(event),
      onExit: (PointerExitEvent event) => exit.add(event),
    );
    bool isInHitRegion;
    MouseTracker tracker;

    void clear() {
      enter.clear();
      exit.clear();
      move.clear();
    }

    setUp(() {
      clear();
      isInHitRegion = true;
      tracker = MouseTracker(
        GestureBinding.instance.pointerRouter,
        (Offset _) => isInHitRegion ? annotation : null,
      );
    });

    test('receives and processes mouse hover events', () {
      final ui.PointerDataPacket packet1 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 0.0 * ui.window.devicePixelRatio,
          physicalY: 0.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      final ui.PointerDataPacket packet2 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 1.0 * ui.window.devicePixelRatio,
          physicalY: 101.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      const ui.PointerDataPacket packet3 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.remove,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      final ui.PointerDataPacket packet4 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 1.0 * ui.window.devicePixelRatio,
          physicalY: 201.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      final ui.PointerDataPacket packet5 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 1.0 * ui.window.devicePixelRatio,
          physicalY: 301.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
          device: 1,
        ),
      ]);
      tracker.attachAnnotation(annotation);
      isInHitRegion = true;
      ui.window.onPointerDataPacket(packet1);
      tracker.collectMousePositions();
      expect(enter.length, equals(1), reason: 'enter contains $enter');
      expect(enter.first.position, equals(const Offset(0.0, 0.0)));
      expect(enter.first.device, equals(0));
      expect(enter.first.runtimeType, equals(PointerEnterEvent));
      expect(exit.length, equals(0), reason: 'exit contains $exit');
      expect(move.length, equals(1), reason: 'move contains $move');
      expect(move.first.position, equals(const Offset(0.0, 0.0)));
      expect(move.first.device, equals(0));
      expect(move.first.runtimeType, equals(PointerHoverEvent));
      clear();

      ui.window.onPointerDataPacket(packet2);
      tracker.collectMousePositions();
      expect(enter.length, equals(0), reason: 'enter contains $enter');
      expect(exit.length, equals(0), reason: 'exit contains $exit');
      expect(move.length, equals(1), reason: 'move contains $move');
      expect(move.first.position, equals(const Offset(1.0, 101.0)));
      expect(move.first.device, equals(0));
      expect(move.first.runtimeType, equals(PointerHoverEvent));
      clear();

      ui.window.onPointerDataPacket(packet3);
      tracker.collectMousePositions();
      expect(enter.length, equals(0), reason: 'enter contains $enter');
      expect(move.length, equals(0), reason: 'move contains $move');
      expect(exit.length, equals(1), reason: 'exit contains $exit');
      expect(exit.first.position, isNull);
      expect(exit.first.device, isNull);
      expect(exit.first.runtimeType, equals(PointerExitEvent));

      clear();
      ui.window.onPointerDataPacket(packet4);
      tracker.collectMousePositions();
      expect(enter.length, equals(1), reason: 'enter contains $enter');
      expect(enter.first.position, equals(const Offset(1.0, 201.0)));
      expect(enter.first.device, equals(0));
      expect(enter.first.runtimeType, equals(PointerEnterEvent));
      expect(exit.length, equals(0), reason: 'exit contains $exit');
      expect(move.length, equals(1), reason: 'move contains $move');
      expect(move.first.position, equals(const Offset(1.0, 201.0)));
      expect(move.first.device, equals(0));
      expect(move.first.runtimeType, equals(PointerHoverEvent));

      // add in a second mouse simultaneously.
      clear();
      ui.window.onPointerDataPacket(packet5);
      tracker.collectMousePositions();
      expect(enter.length, equals(1), reason: 'enter contains $enter');
      expect(enter.first.position, equals(const Offset(1.0, 301.0)));
      expect(enter.first.device, equals(1));
      expect(enter.first.runtimeType, equals(PointerEnterEvent));
      expect(exit.length, equals(0), reason: 'exit contains $exit');
      expect(move.length, equals(2), reason: 'move contains $move');
      expect(move.first.position, equals(const Offset(1.0, 201.0)));
      expect(move.first.device, equals(0));
      expect(move.first.runtimeType, equals(PointerHoverEvent));
      expect(move.last.position, equals(const Offset(1.0, 301.0)));
      expect(move.last.device, equals(1));
      expect(move.last.runtimeType, equals(PointerHoverEvent));
    });
    test('detects exit when annotated layer no longer hit', () {
      final ui.PointerDataPacket packet1 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 0.0 * ui.window.devicePixelRatio,
          physicalY: 0.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 1.0 * ui.window.devicePixelRatio,
          physicalY: 101.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      final ui.PointerDataPacket packet2 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 1.0 * ui.window.devicePixelRatio,
          physicalY: 201.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      isInHitRegion = true;
      tracker.attachAnnotation(annotation);

      ui.window.onPointerDataPacket(packet1);
      tracker.collectMousePositions();
      expect(enter.length, equals(1), reason: 'enter contains $enter');
      expect(enter.first.position, equals(const Offset(1.0, 101.0)));
      expect(enter.first.device, equals(0));
      expect(enter.first.runtimeType, equals(PointerEnterEvent));
      expect(move.length, equals(1), reason: 'move contains $move');
      expect(move.first.position, equals(const Offset(1.0, 101.0)));
      expect(move.first.device, equals(0));
      expect(move.first.runtimeType, equals(PointerHoverEvent));
      expect(exit.length, equals(0), reason: 'exit contains $exit');
      // Simulate layer going away by detaching it.
      clear();
      isInHitRegion = false;

      ui.window.onPointerDataPacket(packet2);
      tracker.collectMousePositions();
      expect(enter.length, equals(0), reason: 'enter contains $enter');
      expect(move.length, equals(0), reason: 'enter contains $move');
      expect(exit.length, equals(1), reason: 'enter contains $exit');
      expect(exit.first.position, const Offset(1.0, 201.0));
      expect(exit.first.device, equals(0));
      expect(exit.first.runtimeType, equals(PointerExitEvent));
    });
    test('detects exit when mouse goes away', () {
      final ui.PointerDataPacket packet1 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 0.0 * ui.window.devicePixelRatio,
          physicalY: 0.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
        ui.PointerData(
          change: ui.PointerChange.hover,
          physicalX: 1.0 * ui.window.devicePixelRatio,
          physicalY: 101.0 * ui.window.devicePixelRatio,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      const ui.PointerDataPacket packet2 =
          ui.PointerDataPacket(data: <ui.PointerData>[
        ui.PointerData(
          change: ui.PointerChange.remove,
          kind: PointerDeviceKind.mouse,
        ),
      ]);
      isInHitRegion = true;
      tracker.attachAnnotation(annotation);
      ui.window.onPointerDataPacket(packet1);
      tracker.collectMousePositions();
      ui.window.onPointerDataPacket(packet2);
      tracker.collectMousePositions();
      expect(enter.length, equals(1), reason: 'enter contains $enter');
      expect(enter.first.position, equals(const Offset(1.0, 101.0)));
      expect(enter.first.device, equals(0));
      expect(enter.first.runtimeType, equals(PointerEnterEvent));
      expect(move.length, equals(1), reason: 'move contains $move');
      expect(move.first.position, equals(const Offset(1.0, 101.0)));
      expect(move.first.device, equals(0));
      expect(move.first.runtimeType, equals(PointerHoverEvent));
      expect(exit.length, equals(1), reason: 'exit contains $exit');
      expect(exit.first.position, isNull);
      expect(exit.first.device, isNull);
      expect(exit.first.runtimeType, equals(PointerExitEvent));
    });
  });
}
