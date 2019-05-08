// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Defines a 'package:test' shim.
// TODO(flutter_web): Remove this file once https://github.com/dart-lang/matcher/issues/98 is fixed

import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;
import 'package:test/test.dart' as test_package show TypeMatcher;

export 'package:flutter_web_test/flutter_web_test.dart' hide isInstanceOf;

/// A matcher that compares the type of the actual value to the type argument T.
Matcher isInstanceOf<T>() => test_package.TypeMatcher<T>();
