// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// Set this flag to true to see all the fired events in the console.
const _debugLogPointerEvents = false;

/// The signature of a callback that handles pointer events.
typedef PointerDataCallback = void Function(List<ui.PointerData>);

class PointerBinding {
  /// The singleton instance of this object.
  static PointerBinding get instance => _instance;
  static PointerBinding _instance;

  PointerBinding(this.domRenderer) {
    if (_instance == null) {
      _instance = this;
      _detector = const PointerSupportDetector();
      _adapter = _createAdapter();
    }
    assert(() {
      registerHotRestartListener(() {
        _adapter?.clearListeners();
      });
      return true;
    }());
  }

  final DomRenderer domRenderer;
  PointerSupportDetector _detector;
  BaseAdapter _adapter;

  /// Should be used in tests to define custom detection of pointer support.
  ///
  /// ```dart
  /// // Forces PointerBinding to use mouse events.
  /// class MyTestDetector extends PointerSupportDetector {
  ///   @override
  ///   final bool hasPointerEvents = false;
  ///
  ///   @override
  ///   final bool hasTouchEvents = false;
  ///
  ///   @override
  ///   final bool hasMouseEvents = true;
  /// }
  ///
  /// PointerBinding.instance.debugOverrideDetector(MyTestDetector());
  /// ```
  void debugOverrideDetector(PointerSupportDetector newDetector) {
    if (newDetector == null) {
      newDetector = const PointerSupportDetector();
    }
    // When changing the detector, we need to swap the adapter.
    if (newDetector != _detector) {
      _detector = newDetector;
      _adapter?.clearListeners();
      _adapter = _createAdapter();
    }
  }

  BaseAdapter _createAdapter() {
    if (_detector.hasPointerEvents) {
      return PointerAdapter(_onPointerData, domRenderer);
    }
    if (_detector.hasTouchEvents) {
      return TouchAdapter(_onPointerData, domRenderer);
    }
    if (_detector.hasMouseEvents) {
      return MouseAdapter(_onPointerData, domRenderer);
    }
    return null;
  }

  void _onPointerData(List<ui.PointerData> data) {
    ui.PointerDataPacket packet = ui.PointerDataPacket(data: data);
    ui.window.onPointerDataPacket(packet);
  }
}

class PointerSupportDetector {
  const PointerSupportDetector();

  bool get hasPointerEvents => js_util.hasProperty(html.window, 'PointerEvent');
  bool get hasTouchEvents => js_util.hasProperty(html.window, 'TouchEvent');
  bool get hasMouseEvents => js_util.hasProperty(html.window, 'MouseEvent');

  String toString() =>
      'pointers:$hasPointerEvents, touch:$hasTouchEvents, mouse:$hasMouseEvents';
}

/// Common functionality that's shared among adapters.
abstract class BaseAdapter {
  static final Map<String, html.EventListener> _listeners =
      <String, html.EventListener>{};

  final DomRenderer domRenderer;
  PointerDataCallback _callback;
  Map<int, bool> _isDownMap = {};
  bool _isButtonDown(int button) {
    return _isDownMap[button] == true;
  }

  void _updateButtonDownState(int button, bool value) {
    _isDownMap[button] = value;
  }

  BaseAdapter(this._callback, this.domRenderer) {
    _setup();
  }

  /// Each subclass is expected to override this method to attach its own event
  /// listeners and convert events into pointer events.
  void _setup();

  /// Remove all active event listeners.
  void clearListeners() {
    final html.Element glassPane = domRenderer.glassPaneElement;
    _listeners.forEach((String eventName, html.EventListener listener) {
      glassPane.removeEventListener(eventName, listener);
    });
    _listeners.clear();
  }

  void _addEventListener(String eventName, html.EventListener handler) {
    html.EventListener loggedHandler = (html.Event event) {
      if (_debugLogPointerEvents) print(event.type);
      // Report the event to semantics. This information is used to debounce
      // browser gestures. Semantics tells us whether it is safe to forward
      // the event to the framework.
      if (EngineSemanticsOwner.instance.receiveGlobalEvent(event)) {
        handler(event);
      }
    };
    _listeners[eventName] = loggedHandler;
    domRenderer.glassPaneElement
        .addEventListener(eventName, loggedHandler, true);
  }
}

const int _kPrimaryMouseButton = 0x1;
const int _kSecondaryMouseButton = 0x2;

int _pointerButtonFromHtmlEvent(html.Event event) {
  if (event is html.PointerEvent) {
    final html.PointerEvent pointerEvent = event;
    return pointerEvent.button == 2
        ? _kSecondaryMouseButton
        : _kPrimaryMouseButton;
  } else if (event is html.MouseEvent) {
    final html.MouseEvent mouseEvent = event;
    return mouseEvent.button == 2
        ? _kSecondaryMouseButton
        : _kPrimaryMouseButton;
  }
  return _kPrimaryMouseButton;
}

/// Adapter class to be used with browsers that support native pointer events.
class PointerAdapter extends BaseAdapter {
  PointerAdapter(PointerDataCallback callback, DomRenderer domRenderer)
      : super(callback, domRenderer);

  void _setup() {
    _addEventListener('pointerdown', (html.Event event) {
      int pointerButton = _pointerButtonFromHtmlEvent(event);
      if (_isButtonDown(pointerButton)) {
        // TODO(flutter_web): Remove this temporary fix for right click
        // on web platform once context guesture is implemented.
        _callback(_convertEventToPointerData(ui.PointerChange.up, event));
      }
      _updateButtonDownState(pointerButton, true);
      _callback(_convertEventToPointerData(ui.PointerChange.down, event));
    });

    _addEventListener('pointermove', (html.Event event) {
      // TODO(flutter_web): During a drag operation pointermove will set
      // button to -1 as opposed to mouse move which sets it to 2.
      // This check is currently defaulting to primary button for now.
      // Change this when context gesture is implemented in flutter framework.
      if (!_isButtonDown(_pointerButtonFromHtmlEvent(event))) return;
      _callback(_convertEventToPointerData(ui.PointerChange.move, event));
    });

    _addEventListener('pointerup', (html.Event event) {
      // The pointer could have been released by a `pointerout` event, in which
      // case `pointerup` should have no effect.
      int pointerButton = _pointerButtonFromHtmlEvent(event);
      if (!_isButtonDown(pointerButton)) return;
      _updateButtonDownState(pointerButton, false);
      _callback(_convertEventToPointerData(ui.PointerChange.up, event));
    });

    // A browser fires cancel event if it concludes the pointer will no longer
    // be able to generate events (example: device is deactivated)
    _addEventListener('pointercancel', (html.Event event) {
      _callback(_convertEventToPointerData(ui.PointerChange.cancel, event));
    });

    _addWheelEventListener((html.WheelEvent event) {
      if (_debugLogPointerEvents) print(event.type);
      _callback(_convertWheelEventToPointerData(event));
      // Prevent default so mouse wheel event doesn't get converted to
      // a scroll event that semantic nodes would process.
      event.preventDefault();
    });
  }

  List<ui.PointerData> _convertEventToPointerData(
    ui.PointerChange change,
    html.PointerEvent evt,
  ) {
    List<html.PointerEvent> allEvents = _expandEvents(evt);
    List<ui.PointerData> data = List(allEvents.length);
    for (int i = 0; i < allEvents.length; i++) {
      html.PointerEvent event = allEvents[i];
      data[i] = ui.PointerData(
        change: change,
        timeStamp: _eventTimeStampToDuration(event.timeStamp),
        kind: _pointerTypeToDeviceKind(event.pointerType),
        device: _uniqueDeviceIdFromType(event.pointerType),
        physicalX: event.client.x,
        physicalY: event.client.y,
        buttons: event.buttons,
        pressure: event.pressure,
        pressureMin: 0.0,
        pressureMax: 1.0,
        tilt: _computeHighestTilt(event),
      );
    }
    return data;
  }

  List<html.PointerEvent> _expandEvents(html.PointerEvent event) {
    // For browsers that don't support `getCoalescedEvents`, we fallback to
    // using the original event.
    if (js_util.hasProperty(event, 'getCoalescedEvents')) {
      var coalescedEvents = event.getCoalescedEvents();
      // Some events don't perform coalescing, so they return an empty list. In
      // that case, we also fallback to using the original event.
      if (coalescedEvents.isNotEmpty) {
        return coalescedEvents;
      }
    }
    return [event];
  }

  ui.PointerDeviceKind _pointerTypeToDeviceKind(String pointerType) {
    switch (pointerType) {
      case 'mouse':
        return ui.PointerDeviceKind.mouse;
      case 'pen':
        return ui.PointerDeviceKind.stylus;
      case 'touch':
        return ui.PointerDeviceKind.touch;
      default:
        return ui.PointerDeviceKind.unknown;
    }
  }

  /// Tilt angle is -90 to + 90. Take maximum deflection and convert to radians.
  double _computeHighestTilt(html.PointerEvent e) =>
      (e.tiltX.abs() > e.tiltY.abs() ? e.tiltX : e.tiltY).toDouble() /
      180.0 *
      math.pi;
}

/// Adapter to be used with browsers that support touch events.
class TouchAdapter extends BaseAdapter {
  TouchAdapter(PointerDataCallback callback, DomRenderer domRenderer)
      : super(callback, domRenderer);

  void _setup() {
    _addEventListener('touchstart', (html.Event event) {
      _updateButtonDownState(_kPrimaryMouseButton, true);
      _callback(_convertEventToPointerData(ui.PointerChange.down, event));
    });

    _addEventListener('touchmove', (html.Event event) {
      event.preventDefault(); // Prevents standard overscroll on iOS/Webkit.
      if (!_isButtonDown(_kPrimaryMouseButton)) return;
      _callback(_convertEventToPointerData(ui.PointerChange.move, event));
    });

    _addEventListener('touchend', (html.Event event) {
      _updateButtonDownState(_kPrimaryMouseButton, false);
      _callback(_convertEventToPointerData(ui.PointerChange.up, event));
    });

    _addEventListener('touchcancel', (html.Event event) {
      _callback(_convertEventToPointerData(ui.PointerChange.cancel, event));
    });
  }

  List<ui.PointerData> _convertEventToPointerData(
    ui.PointerChange change,
    html.TouchEvent event,
  ) {
    var touch = event.changedTouches.first;
    return [
      ui.PointerData(
        change: change,
        timeStamp: _eventTimeStampToDuration(event.timeStamp),
        kind: ui.PointerDeviceKind.touch,
        signalKind: ui.PointerSignalKind.none,
        device: _uniqueDeviceIdFromType('touch'),
        physicalX: touch.client.x,
        physicalY: touch.client.y,
        pressure: 1.0,
        pressureMin: 0.0,
        pressureMax: 1.0,
      )
    ];
  }
}

/// Adapter to be used with browsers that support mouse events.
class MouseAdapter extends BaseAdapter {
  MouseAdapter(PointerDataCallback callback, DomRenderer domRenderer)
      : super(callback, domRenderer);

  void _setup() {
    _addEventListener('mousedown', (html.Event event) {
      int pointerButton = _pointerButtonFromHtmlEvent(event);
      if (_isButtonDown(pointerButton)) {
        // TODO(flutter_web): Remove this temporary fix for right click
        // on web platform once context guesture is implemented.
        _callback(_convertEventToPointerData(ui.PointerChange.up, event));
      }
      _updateButtonDownState(pointerButton, true);
      _callback(_convertEventToPointerData(ui.PointerChange.down, event));
    });

    _addEventListener('mousemove', (html.Event event) {
      if (!_isButtonDown(_pointerButtonFromHtmlEvent(event))) return;
      _callback(_convertEventToPointerData(ui.PointerChange.move, event));
    });

    _addEventListener('mouseup', (html.Event event) {
      _updateButtonDownState(_pointerButtonFromHtmlEvent(event), false);
      _callback(_convertEventToPointerData(ui.PointerChange.up, event));
    });

    _addWheelEventListener((html.WheelEvent event) {
      if (_debugLogPointerEvents) print(event.type);
      _callback(_convertWheelEventToPointerData(event));
      event.preventDefault();
    });
  }

  List<ui.PointerData> _convertEventToPointerData(
    ui.PointerChange change,
    html.MouseEvent event,
  ) {
    return [
      ui.PointerData(
        change: change,
        timeStamp: _eventTimeStampToDuration(event.timeStamp),
        kind: ui.PointerDeviceKind.mouse,
        signalKind: ui.PointerSignalKind.none,
        device: _uniqueDeviceIdFromType('mouse'),
        physicalX: event.client.x,
        physicalY: event.client.y,
        buttons: event.buttons,
        pressure: 1.0,
        pressureMin: 0.0,
        pressureMax: 1.0,
      )
    ];
  }
}

/// Convert a floating number timestamp (in milliseconds) to a [Duration] by
/// splitting it into two integer components: milliseconds + microseconds.
Duration _eventTimeStampToDuration(num milliseconds) {
  int ms = milliseconds.toInt();
  int micro =
      ((milliseconds - ms) * Duration.microsecondsPerMillisecond).toInt();
  return new Duration(milliseconds: ms, microseconds: micro);
}

List<ui.PointerData> _convertWheelEventToPointerData(
  html.WheelEvent event,
) {
  const int domDeltaPixel = 0x00;
  const int domDeltaLine = 0x01;
  const int domDeltaPage = 0x02;

  // Flutter only supports pixel scroll delta. Convert deltaMode values
  // to pixels.
  double deltaX = event.deltaX;
  double deltaY = event.deltaY;
  switch (event.deltaMode) {
    case domDeltaLine:
      deltaX *= 32.0;
      deltaY *= 32.0;
      break;
    case domDeltaPage:
      deltaX *= ui.window.physicalSize.width;
      deltaY *= ui.window.physicalSize.height;
      break;
    case domDeltaPixel:
    default:
      break;
  }
  return [
    ui.PointerData(
      change: ui.PointerChange.add,
      timeStamp: _eventTimeStampToDuration(event.timeStamp),
      kind: ui.PointerDeviceKind.mouse,
      signalKind: ui.PointerSignalKind.scroll,
      device: _uniqueDeviceIdFromType('mouse'),
      physicalX: event.client.x,
      physicalY: event.client.y,
      buttons: event.buttons,
      pressure: 1.0,
      pressureMin: 0.0,
      pressureMax: 1.0,
      scrollDeltaX: deltaX,
      scrollDeltaY: deltaY,
    ),
    ui.PointerData(
      change: ui.PointerChange.hover,
      timeStamp: _eventTimeStampToDuration(event.timeStamp),
      kind: ui.PointerDeviceKind.mouse,
      signalKind: ui.PointerSignalKind.scroll,
      device: _uniqueDeviceIdFromType('mouse'),
      physicalX: event.client.x,
      physicalY: event.client.y,
      buttons: event.buttons,
      pressure: 1.0,
      pressureMin: 0.0,
      pressureMax: 1.0,
      scrollDeltaX: deltaX,
      scrollDeltaY: deltaY,
    )
  ];
}

void _addWheelEventListener(void listener(html.WheelEvent e)) {
  var eventOptions = js_util.newObject();
  js_util.setProperty(eventOptions, 'passive', false);
  js_util.callMethod(
      PointerBinding.instance.domRenderer.glassPaneElement,
      'addEventListener',
      ['wheel', js.allowInterop((event) => listener(event)), eventOptions]);
}

// Unique device id for each pointer type.
// TODO(flutter_web): Stabilize/Prepopulate device ids.
final Map<String, int> _devices = {};
int _uniqueDeviceIdFromType(String type) {
  var id = _devices[type];
  if (id == null) {
    id = _devices.length;
    _devices[type] = id;
  }
  return id;
}
