// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:flutter_web_ui/src/engine.dart';
import 'package:flutter_web_test/flutter_web_test.dart';

void main() {
  test('creating elements works', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    expect(element, isNotNull);
  });
  test('can append children to parents', () {
    var renderer = new DomRenderer();
    var parent = renderer.createElement('div');
    var child = renderer.createElement('div');
    renderer.append(parent, child);
    expect(parent.children, hasLength(1));
  });
  test('can set text on elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    renderer.setText(element, 'Hello World');
    expect(element.text, 'Hello World');
  });
  test('can set attributes on elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    renderer.setElementAttribute(element, 'id', 'foo');
    expect(element.id, 'foo');
  });
  test('can add classes to elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    renderer.addElementClass(element, 'foo');
    renderer.addElementClass(element, 'bar');
    expect(element.classes, ['foo', 'bar']);
  });
  test('can remove classes from elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    renderer.addElementClass(element, 'foo');
    renderer.addElementClass(element, 'bar');
    expect(element.classes, ['foo', 'bar']);
    renderer.removeElementClass(element, 'foo');
    expect(element.classes, ['bar']);
  });
  test('can set style properties on elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    renderer.setElementStyle(element, 'color', 'red');
    expect(element.style.color, 'red');
  });
  test('can remove style properties from elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    renderer.setElementStyle(element, 'color', 'blue');
    expect(element.style.color, 'blue');
    renderer.setElementStyle(element, 'color', null);
    expect(element.style.color, '');
  });
  test('elements can have children', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    renderer.createElement('div', parent: element);
    expect(element.children, hasLength(1));
  });
  test('can detach elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    var child = renderer.createElement('div', parent: element);
    renderer.detachElement(child);
    expect(element.children, isEmpty);
  });
  test('can reattach detached elements', () {
    var renderer = new DomRenderer();
    var element = renderer.createElement('div');
    var child = renderer.createElement('div', parent: element);
    var otherChild = renderer.createElement('foo', parent: element);
    renderer.detachElement(child);
    expect(element.children, hasLength(1));
    renderer.attachBeforeElement(element, otherChild, child);
    expect(element.children, hasLength(2));
  });
  test('insert two elements in the middle of a child list', () {
    var renderer = new DomRenderer();
    var parent = renderer.createElement('div');
    renderer.createElement('a', parent: parent);
    var childD = renderer.createElement('d', parent: parent);
    expect(parent.innerHtml, '<a></a><d></d>');
    var childB = renderer.createElement('b', parent: parent);
    var childC = renderer.createElement('c', parent: parent);
    renderer.attachBeforeElement(parent, childD, childB);
    renderer.attachBeforeElement(parent, childD, childC);
    expect(parent.innerHtml, '<a></a><b></b><c></c><d></d>');
  });
  test('replaces viewport meta tags during style reset', () {
    html.MetaElement existingMeta = html.MetaElement()
      ..name = 'viewport'
      ..content = 'foo=bar';
    html.document.head.append(existingMeta);
    expect(existingMeta.isConnected, true);

    var renderer = new DomRenderer();
    renderer.reset();
  });
}
