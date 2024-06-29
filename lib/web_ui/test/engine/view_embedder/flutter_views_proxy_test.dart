// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui_web/src/ui_web.dart';

void main() {
  internalBootstrapBrowserTest(() => doTests);
}

Future<void> doTests() async {
  group('FlutterViewManagerProxy', () {
    final platformDispatcher =
        EnginePlatformDispatcher.instance;
    final viewManager =
        FlutterViewManager(platformDispatcher);
    final views =
        FlutterViewManagerProxy(viewManager: viewManager);

    late EngineFlutterView view;
    late int viewId;
    late DomElement hostElement;

    int registerViewWithOptions(Map<String, Object?> options) {
      final jsOptions =
          options.toJSAnyDeep as JsFlutterViewOptions;
      viewManager.registerView(view, jsViewOptions: jsOptions);
      return viewId;
    }

    setUp(() {
      view = EngineFlutterView(platformDispatcher, createDomElement('div'));
      viewId = view.viewId;
      hostElement = createDomElement('div');
    });

    tearDown(() {
      viewManager.unregisterView(viewId);
    });

    group('getHostElement', () {
      test('null when viewId is unknown', () {
        final element = views.getHostElement(33930);
        expect(element, isNull);
      });

      test('can retrieve hostElement for a known view', () {
        final viewId = registerViewWithOptions(<String, Object?>{
          'hostElement': hostElement,
        });

        final element = views.getHostElement(viewId);

        expect(element, hostElement);
      });
    });

    group('getInitialData', () {
      test('null when viewId is unknown', () {
        final element = views.getInitialData(33930);
        expect(element, isNull);
      });

      test('can retrieve initialData for a known view', () {
        final viewId = registerViewWithOptions(<String, Object?>{
          'hostElement': hostElement,
          'initialData': <String, Object?>{
            'someInt': 42,
            'someString': 'A String',
            'decimals': <double>[math.pi, math.e],
          },
        });

        final element =
            views.getInitialData(viewId) as InitialData?;

        expect(element, isNotNull);
        expect(element!.someInt, 42);
        expect(element.someString, 'A String');
        expect(element.decimals, <double>[math.pi, math.e]);
      });
    });
  });
}

// The JS-interop definition of the `initialData` object passed to the views of this app.
@JS()
@staticInterop
class InitialData {}

/// The attributes of the [InitialData] object.
extension InitialDataExtension on InitialData {
  external int get someInt;
  external String? get someString;

  @JS('decimals')
  external JSArray<JSNumber> get _decimals;
  List<double> get decimals =>
      _decimals.toDart.map((JSNumber e) => e.toDartDouble).toList();
}
