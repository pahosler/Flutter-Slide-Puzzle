// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_web_test/flutter_web_test.dart';
import 'package:flutter_web/gestures.dart';
import 'package:flutter_web/widgets.dart' hide TypeMatcher;

void main() {
  testWidgets('Scroll notification basics', (WidgetTester tester) async {
    ScrollNotification notification;

    await tester.pumpWidget(new NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification value) {
          if (value is ScrollStartNotification ||
              value is ScrollUpdateNotification ||
              value is ScrollEndNotification) notification = value;
          return false;
        },
        child:
            new SingleChildScrollView(child: const SizedBox(height: 1200.0))));

    final TestGesture gesture =
        await tester.startGesture(const Offset(100.0, 100.0));
    await tester.pump(const Duration(seconds: 1));
    expect(notification, isInstanceOf<ScrollStartNotification>());
    expect(notification.depth, equals(0));
    final ScrollStartNotification start = notification;
    expect(start.dragDetails, isNotNull);
    expect(
        start.dragDetails.globalPosition, equals(const Offset(100.0, 100.0)));

    await gesture.moveBy(const Offset(-10.0, -10.0));
    await tester.pump(const Duration(seconds: 1));
    expect(notification, isInstanceOf<ScrollUpdateNotification>());
    expect(notification.depth, equals(0));
    final ScrollUpdateNotification update = notification;
    expect(update.dragDetails, isNotNull);
    expect(update.dragDetails.globalPosition, equals(const Offset(90.0, 90.0)));
    expect(update.dragDetails.delta, equals(const Offset(0.0, -10.0)));

    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(notification, isInstanceOf<ScrollEndNotification>());
    expect(notification.depth, equals(0));
    final ScrollEndNotification end = notification;
    expect(end.dragDetails, isNotNull);
    expect(end.dragDetails.velocity, equals(Velocity.zero));
  });

  testWidgets('Scroll notification depth', (WidgetTester tester) async {
    final List<Type> depth0Types = <Type>[];
    final List<Type> depth1Types = <Type>[];
    final List<int> depth0Values = <int>[];
    final List<int> depth1Values = <int>[];

    await tester.pumpWidget(new NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification value) {
          depth1Types.add(value.runtimeType);
          depth1Values.add(value.depth);
          return false;
        },
        child: new SingleChildScrollView(
            child: new SizedBox(
                height: 1200.0,
                child: new NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification value) {
                      depth0Types.add(value.runtimeType);
                      depth0Values.add(value.depth);
                      return false;
                    },
                    child: new Container(
                        padding: const EdgeInsets.all(50.0),
                        child: new SingleChildScrollView(
                            child: const SizedBox(height: 1200.0))))))));

    final TestGesture gesture =
        await tester.startGesture(const Offset(100.0, 100.0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveBy(const Offset(-10.0, -40.0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    final List<Type> types = <Type>[
      ScrollStartNotification,
      UserScrollNotification,
      ScrollUpdateNotification,
      ScrollEndNotification,
      UserScrollNotification,
    ];
    expect(depth0Types, equals(types));
    expect(depth1Types, equals(types));

    expect(depth0Values, equals(<int>[0, 0, 0, 0, 0]));
    expect(depth1Values, equals(<int>[1, 1, 1, 1, 1]));
  });
}
