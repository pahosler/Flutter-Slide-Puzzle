// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';
import 'dart:typed_data';

import 'package:flutter_web_ui/ui.dart' as ui;
import 'package:flutter_web_ui/src/engine.dart';
import 'package:flutter_web_test/flutter_web_test.dart';

final MethodCodec codec = JSONMethodCodec();

TextEditingElement editingElement;
EditingState lastEditingState;

final InputConfiguration singlelineConfig =
    InputConfiguration(inputType: InputType.text);
final Map<String, dynamic> flutterSinglelineConfig = {
  'inputType': {
    'name': 'TextInputType.text',
  },
  'obscureText': false,
};

final InputConfiguration multilineConfig =
    InputConfiguration(inputType: InputType.multiline);
final Map<String, dynamic> flutterMultilineConfig = {
  'inputType': {
    'name': 'TextInputType.multiline',
  },
  'obscureText': false,
};

void trackEditingState(EditingState editingState) {
  lastEditingState = editingState;
}

void main() {
  group('$TextEditingElement', () {
    setUp(() {
      editingElement = TextEditingElement();
    });

    tearDown(() {
      try {
        editingElement.disable();
      } catch (e) {
        if (e is AssertionError) {
          // This is fine. It just means the test itself disabled the editing element.
        } else {
          rethrow;
        }
      }
    });

    test('Creates element when enabled and removes it when disabled', () {
      expect(
        document.getElementsByTagName('input'),
        hasLength(0),
      );
      // The focus initially is on the body.
      expect(document.activeElement, document.body);

      editingElement.enable(singlelineConfig, onChange: trackEditingState);
      expect(
        document.getElementsByTagName('input'),
        hasLength(1),
      );
      final InputElement input = document.getElementsByTagName('input')[0];
      // Now the editing element should have focus.
      expect(document.activeElement, input);
      expect(editingElement.domElement, input);

      editingElement.disable();
      expect(
        document.getElementsByTagName('input'),
        hasLength(0),
      );
      // The focus is back to the body.
      expect(document.activeElement, document.body);
    });

    test('Can read editing state correctly', () {
      editingElement.enable(singlelineConfig, onChange: trackEditingState);

      final InputElement input = editingElement.domElement;
      input.value = 'foo bar';
      input.dispatchEvent(Event.eventType('Event', 'input'));
      expect(
        lastEditingState,
        EditingState(text: 'foo bar', baseOffset: 7, extentOffset: 7),
      );

      input.setSelectionRange(4, 6);
      document.dispatchEvent(Event.eventType('Event', 'selectionchange'));
      expect(
        lastEditingState,
        EditingState(text: 'foo bar', baseOffset: 4, extentOffset: 6),
      );
    });

    test('Can set editing state correctly', () {
      editingElement.enable(singlelineConfig, onChange: trackEditingState);
      editingElement.setEditingState(
          EditingState(text: 'foo bar baz', baseOffset: 2, extentOffset: 7));

      checkInputEditingState(editingElement.domElement, 'foo bar baz', 2, 7);
    });

    test('Re-acquires focus', () async {
      editingElement.enable(singlelineConfig, onChange: trackEditingState);
      expect(document.activeElement, editingElement.domElement);

      editingElement.domElement.blur();
      // The focus remains on [editingElement.domElement].
      expect(document.activeElement, editingElement.domElement);
    });

    test('Multi-line mode also works', () {
      // The textarea element is created lazily.
      expect(document.getElementsByTagName('textarea'), hasLength(0));
      editingElement.enable(multilineConfig, onChange: trackEditingState);
      expect(document.getElementsByTagName('textarea'), hasLength(1));

      final TextAreaElement textarea =
          document.getElementsByTagName('textarea')[0];
      // Now the textarea should have focus.
      expect(document.activeElement, textarea);
      expect(editingElement.domElement, textarea);

      textarea.value = 'foo\nbar';
      textarea.dispatchEvent(Event.eventType('Event', 'input'));
      textarea.setSelectionRange(4, 6);
      textarea.dispatchEvent(Event.eventType('Event', 'selectionchange'));
      // Can read textarea state correctly (and preserves new lines).
      expect(
        lastEditingState,
        EditingState(text: 'foo\nbar', baseOffset: 4, extentOffset: 6),
      );

      // Can set textarea state correctly (and preserves new lines).
      editingElement.setEditingState(
          EditingState(text: 'bar\nbaz', baseOffset: 2, extentOffset: 7));
      checkTextAreaEditingState(textarea, 'bar\nbaz', 2, 7);

      // Re-acquires focus.
      textarea.blur();
      expect(document.activeElement, textarea);

      editingElement.disable();
      // The textarea should be cleaned up.
      expect(document.getElementsByTagName('textarea'), hasLength(0));
      // The focus is back to the body.
      expect(document.activeElement, document.body);
    });

    test('Same instance can be re-enabled with different config', () {
      // Make sure there's nothing in the DOM yet.
      expect(document.getElementsByTagName('input'), hasLength(0));
      expect(document.getElementsByTagName('textarea'), hasLength(0));

      // Use single-line config and expect an `<input>` to be created.
      editingElement.enable(singlelineConfig, onChange: trackEditingState);
      expect(document.getElementsByTagName('input'), hasLength(1));
      expect(document.getElementsByTagName('textarea'), hasLength(0));

      // Disable and check that all DOM elements were removed.
      editingElement.disable();
      expect(document.getElementsByTagName('input'), hasLength(0));
      expect(document.getElementsByTagName('textarea'), hasLength(0));

      // Use multi-line config and expect an `<textarea>` to be created.
      editingElement.enable(multilineConfig, onChange: trackEditingState);
      expect(document.getElementsByTagName('input'), hasLength(0));
      expect(document.getElementsByTagName('textarea'), hasLength(1));

      // Disable again and check that all DOM elements were removed.
      editingElement.disable();
      expect(document.getElementsByTagName('input'), hasLength(0));
      expect(document.getElementsByTagName('textarea'), hasLength(0));
    });

    test('Can swap backing elements on the fly', () {
      // TODO(mdebbar): implement.
    });

    group('[persistent mode]', () {
      test('Does not accept dom elements of a wrong type', () {
        // A regular <span> shouldn't be accepted.
        final HtmlElement span = SpanElement();
        expect(
          () => PersistentTextEditingElement(span, onDomElementSwap: null),
          throwsAssertionError,
        );
      });

      test('Does not re-acquire focus', () {
        // See [PersistentTextEditingElement._refocus] for an explanation of why
        // re-acquiring focus shouldn't happen in persistent mode.
        final InputElement input = InputElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(input, onDomElementSwap: () {});
        expect(document.activeElement, document.body);

        document.body.append(input);
        persistentEditingElement.enable(singlelineConfig,
            onChange: trackEditingState);
        expect(document.activeElement, input);

        // The input should lose focus now.
        persistentEditingElement.domElement.blur();
        expect(document.activeElement, document.body);

        persistentEditingElement.disable();
      });

      test('Does not dispose and recreate dom elements in persistent mode', () {
        final InputElement input = InputElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(input, onDomElementSwap: () {});

        // The DOM element should've been eagerly created.
        expect(input, isNotNull);
        // But doesn't have focus.
        expect(document.activeElement, document.body);

        // Can't enable before the input element is inserted into the DOM.
        expect(
          () => persistentEditingElement.enable(singlelineConfig,
              onChange: trackEditingState),
          throwsAssertionError,
        );

        document.body.append(input);
        persistentEditingElement.enable(singlelineConfig,
            onChange: trackEditingState);
        expect(document.activeElement, persistentEditingElement.domElement);
        // It doesn't create a new DOM element.
        expect(persistentEditingElement.domElement, input);

        persistentEditingElement.disable();
        // It doesn't remove the DOM element.
        expect(persistentEditingElement.domElement, input);
        expect(document.body.contains(persistentEditingElement.domElement),
            isTrue);
        // But the DOM element loses focus.
        expect(document.activeElement, document.body);
      });

      test('Refocuses when setting editing state', () {
        final InputElement input = InputElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(input, onDomElementSwap: () {});

        document.body.append(input);
        persistentEditingElement.enable(singlelineConfig,
            onChange: trackEditingState);
        expect(document.activeElement, input);

        persistentEditingElement.domElement.blur();
        expect(document.activeElement, document.body);

        // The input should regain focus now.
        persistentEditingElement.setEditingState(EditingState(text: 'foo'));
        expect(document.activeElement, input);

        persistentEditingElement.disable();
      });

      test('Works in multi-line mode', () {
        final TextAreaElement textarea = TextAreaElement();
        final PersistentTextEditingElement persistentEditingElement =
            PersistentTextEditingElement(textarea, onDomElementSwap: () {});

        expect(persistentEditingElement.domElement, textarea);
        expect(document.activeElement, document.body);

        // Can't enable before the textarea is inserted into the DOM.
        expect(
          () => persistentEditingElement.enable(singlelineConfig,
              onChange: trackEditingState),
          throwsAssertionError,
        );

        document.body.append(textarea);
        persistentEditingElement.enable(multilineConfig,
            onChange: trackEditingState);
        // Focuses the textarea.
        expect(document.activeElement, textarea);

        // Doesn't re-acquire focus.
        textarea.blur();
        expect(document.activeElement, document.body);

        // Re-focuses when setting editing state
        persistentEditingElement.setEditingState(EditingState(text: 'foo'));
        expect(document.activeElement, textarea);

        persistentEditingElement.disable();
        // It doesn't remove the textarea from the DOM.
        expect(persistentEditingElement.domElement, textarea);
        expect(document.body.contains(persistentEditingElement.domElement),
            isTrue);
        // But the textarea loses focus.
        expect(document.activeElement, document.body);
      });
    });
  });

  group('$HybridTextEditing', () {
    HybridTextEditing textEditing;
    PlatformMessagesSpy spy = PlatformMessagesSpy();

    setUp(() {
      textEditing = HybridTextEditing();
      spy.activate();
    });

    tearDown(() {
      spy.deactivate();
    });

    test('setClient, show, setEditingState, hide', () {
      MethodCall setClient =
          MethodCall('TextInput.setClient', [123, flutterSinglelineConfig]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      // Editing shouldn't have started yet.
      expect(document.activeElement, document.body);

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      checkInputEditingState(textEditing.editingElement.domElement, '', 0, 0);

      MethodCall setEditingState = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState));

      checkInputEditingState(
          textEditing.editingElement.domElement, 'abcd', 2, 3);

      MethodCall hide = MethodCall('TextInput.hide');
      textEditing.handleTextInput(codec.encodeMethodCall(hide));

      // Text editing should've stopped.
      expect(document.activeElement, document.body);

      // Confirm that [HybridTextEditing] didn't send any messages.
      expect(spy.messages, isEmpty);
    });

    test('setClient, setEditingState, show, clearClient', () {
      MethodCall setClient =
          MethodCall('TextInput.setClient', [123, flutterSinglelineConfig]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      MethodCall setEditingState = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState));

      // Editing shouldn't have started yet.
      expect(document.activeElement, document.body);

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      checkInputEditingState(
          textEditing.editingElement.domElement, 'abcd', 2, 3);

      MethodCall clearClient = MethodCall('TextInput.clearClient');
      textEditing.handleTextInput(codec.encodeMethodCall(clearClient));

      expect(document.activeElement, document.body);

      // Confirm that [HybridTextEditing] didn't send any messages.
      expect(spy.messages, isEmpty);
    });

    test('setClient, setEditingState, show, setEditingState, clearClient', () {
      MethodCall setClient =
          MethodCall('TextInput.setClient', [123, flutterSinglelineConfig]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      MethodCall setEditingState1 = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState1));

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      MethodCall setEditingState2 = MethodCall('TextInput.setEditingState', {
        'text': 'xyz',
        'selectionBase': 0,
        'selectionExtent': 2,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState2));

      // The second [setEditingState] should override the first one.
      checkInputEditingState(
          textEditing.editingElement.domElement, 'xyz', 0, 2);

      MethodCall clearClient = MethodCall('TextInput.clearClient');
      textEditing.handleTextInput(codec.encodeMethodCall(clearClient));

      // Confirm that [HybridTextEditing] didn't send any messages.
      expect(spy.messages, isEmpty);
    });

    test('Syncs the editing state back to Flutter', () {
      MethodCall setClient =
          MethodCall('TextInput.setClient', [123, flutterSinglelineConfig]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      MethodCall setEditingState = MethodCall('TextInput.setEditingState', {
        'text': 'abcd',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState));

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      final InputElement input = textEditing.editingElement.domElement;

      input.value = 'something';
      input.dispatchEvent(Event.eventType('Event', 'input'));

      expect(spy.messages, hasLength(1));
      MethodCall call = spy.messages[0];
      spy.messages.clear();
      expect(call.method, 'TextInputClient.updateEditingState');
      expect(
        call.arguments,
        [
          123, // Client ID
          {'text': 'something', 'selectionBase': 9, 'selectionExtent': 9}
        ],
      );

      input.setSelectionRange(2, 5);
      document.dispatchEvent(Event.eventType('Event', 'selectionchange'));

      expect(spy.messages, hasLength(1));
      call = spy.messages[0];
      spy.messages.clear();
      expect(call.method, 'TextInputClient.updateEditingState');
      expect(
        call.arguments,
        [
          123, // Client ID
          {'text': 'something', 'selectionBase': 2, 'selectionExtent': 5}
        ],
      );

      MethodCall clearClient = MethodCall('TextInput.clearClient');
      textEditing.handleTextInput(codec.encodeMethodCall(clearClient));
    });

    test('Multi-line mode also works', () {
      MethodCall setClient =
          MethodCall('TextInput.setClient', [123, flutterMultilineConfig]);
      textEditing.handleTextInput(codec.encodeMethodCall(setClient));

      // Editing shouldn't have started yet.
      expect(document.activeElement, document.body);

      MethodCall show = MethodCall('TextInput.show');
      textEditing.handleTextInput(codec.encodeMethodCall(show));

      final TextAreaElement textarea = textEditing.editingElement.domElement;
      checkTextAreaEditingState(textarea, '', 0, 0);

      // Can set editing state and preserve new lines.
      MethodCall setEditingState = MethodCall('TextInput.setEditingState', {
        'text': 'foo\nbar',
        'selectionBase': 2,
        'selectionExtent': 3,
      });
      textEditing.handleTextInput(codec.encodeMethodCall(setEditingState));
      checkTextAreaEditingState(textarea, 'foo\nbar', 2, 3);

      // Sends the changes back to Flutter.
      textarea.value = 'something\nelse';
      textarea.dispatchEvent(Event.eventType('Event', 'input'));
      textarea.setSelectionRange(2, 5);
      document.dispatchEvent(Event.eventType('Event', 'selectionchange'));

      // Two messages should've been sent. One for the 'input' event and one for
      // the 'selectionchange' event.
      expect(spy.messages, hasLength(2));
      MethodCall call = spy.messages.last;
      spy.messages.clear();
      expect(call.method, 'TextInputClient.updateEditingState');
      expect(
        call.arguments,
        [
          123, // Client ID
          {'text': 'something\nelse', 'selectionBase': 2, 'selectionExtent': 5}
        ],
      );

      MethodCall hide = MethodCall('TextInput.hide');
      textEditing.handleTextInput(codec.encodeMethodCall(hide));

      // Text editing should've stopped.
      expect(document.activeElement, document.body);

      // Confirm that [HybridTextEditing] didn't send any more messages.
      expect(spy.messages, isEmpty);
    });
  });
}

void checkInputEditingState(
    InputElement input, String text, int start, int end) {
  expect(document.activeElement, input);
  expect(input.value, text);
  expect(input.selectionStart, start);
  expect(input.selectionEnd, end);
}

void checkTextAreaEditingState(
  TextAreaElement textarea,
  String text,
  int start,
  int end,
) {
  expect(document.activeElement, textarea);
  expect(textarea.value, text);
  expect(textarea.selectionStart, start);
  expect(textarea.selectionEnd, end);
}

class PlatformMessagesSpy {
  bool _isActive = false;
  ui.PlatformMessageCallback _backup;

  final List<MethodCall> messages = [];

  void activate() {
    assert(!_isActive);
    _isActive = true;
    _backup = ui.window.onPlatformMessage;
    ui.window.onPlatformMessage = (String channel, ByteData data,
        ui.PlatformMessageResponseCallback callback) {
      messages.add(codec.decodeMethodCall(data));
    };
  }

  void deactivate() {
    assert(_isActive);
    _isActive = false;
    messages.clear();
    ui.window.onPlatformMessage = _backup;
  }
}
