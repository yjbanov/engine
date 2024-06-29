// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_util';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';

import '../../common/matchers.dart';
import '../../html/image_test.dart';

void main() {
  internalBootstrapBrowserTest(() => doTests);
}

Future<void> doTests() async {
  group('FlutterViewManager', () {
    final platformDispatcher = EnginePlatformDispatcher.instance;
    final viewManager = FlutterViewManager(platformDispatcher);

    group('registerView', () {
      test('can register view', () {
        final view = EngineFlutterView(platformDispatcher, createDomElement('div'));
        final viewId = view.viewId;

        viewManager.registerView(view);

        expect(viewManager[viewId], view);
      });

      test('fails if the same viewId is already registered', () {
        final view = EngineFlutterView(platformDispatcher, createDomElement('div'));

        viewManager.registerView(view);

        expect(() { viewManager.registerView(view); }, throwsAssertionError);
      });

      test('stores JSOptions that getOptions can retrieve', () {
        final view = EngineFlutterView(platformDispatcher, createDomElement('div'));
        final viewId = view.viewId;
        final expectedOptions = jsify(<String, Object?>{
          'hostElement': createDomElement('div'),
        }) as JsFlutterViewOptions;

        viewManager.registerView(view, jsViewOptions: expectedOptions);

        final storedOptions = viewManager.getOptions(viewId);
        expect(storedOptions, expectedOptions);
      });
    });

    group('unregisterView', () {
      test('unregisters a view', () {
        final view = EngineFlutterView(platformDispatcher, createDomElement('div'));
        final viewId = view.viewId;

        viewManager.registerView(view);
        expect(viewManager[viewId], isNotNull);

        viewManager.unregisterView(viewId);
        expect(viewManager[viewId], isNull);
      });
    });

    group('onViewsChanged', () {
      // Prepares a "timed-out" version of the onViewsChanged Stream so tests
      // can't hang "forever" waiting for this to complete. This stream will close
      // after 100ms of inactivity, regardless of what the test or the code do.
      final onViewCreated = viewManager.onViewCreated.timeout(
          const Duration(milliseconds: 100), onTimeout: (EventSink<int> sink) {
        sink.close();
      });

      final onViewDisposed = viewManager.onViewDisposed.timeout(
          const Duration(milliseconds: 100), onTimeout: (EventSink<int> sink) {
        sink.close();
      });

      test('on view registered/unregistered - fires event', () async {
        final view = EngineFlutterView(platformDispatcher, createDomElement('div'));
        final viewId = view.viewId;

        final Future<List<void>> viewCreatedEvents = onViewCreated.toList();
        final Future<List<void>> viewDisposedEvents = onViewDisposed.toList();
        viewManager.registerView(view);
        viewManager.unregisterView(viewId);

        expect(viewCreatedEvents, completes);
        expect(viewDisposedEvents, completes);

        final createdViewsList = await viewCreatedEvents;
        final disposedViewsList = await viewCreatedEvents;

        expect(createdViewsList, listEqual(<int>[viewId]),
            reason: 'Should fire creation event for view');
        expect(disposedViewsList, listEqual(<int>[viewId]),
            reason: 'Should fire dispose event for view');
      });
    });

    group('findViewForElement', () {
      test('finds view for root and descendant elements', () {
        final host = createDomElement('div');
        final view = EngineFlutterView(platformDispatcher, host);

        viewManager.registerView(view);

        final rootElement = view.dom.rootElement;
        final child1 = createDomElement('div');
        final child2 = createDomElement('div');
        final child3 = createDomElement('div');
        rootElement.append(child1);
        rootElement.append(child2);
        child2.append(child3);

        expect(viewManager.findViewForElement(rootElement), view);
        expect(viewManager.findViewForElement(child1), view);
        expect(viewManager.findViewForElement(child2), view);
        expect(viewManager.findViewForElement(child3), view);
      });

      test('returns null for host element', () {
        final host = createDomElement('div');
        final view = EngineFlutterView(platformDispatcher, host);
        viewManager.registerView(view);

        expect(viewManager.findViewForElement(host), isNull);
      });

      test("returns null for elements that don't belong to any view", () {
        final host = createDomElement('div');
        final view = EngineFlutterView(platformDispatcher, host);
        viewManager.registerView(view);

        final disconnectedElement = createDomElement('div');
        final childOfBody = createDomElement('div');

        domDocument.body!.append(childOfBody);

        expect(viewManager.findViewForElement(disconnectedElement), isNull);
        expect(viewManager.findViewForElement(childOfBody), isNull);
        expect(viewManager.findViewForElement(domDocument.body), isNull);
      });

      test('does not recognize elements from unregistered views', () {
        final host = createDomElement('div');
        final view = EngineFlutterView(platformDispatcher, host);
        viewManager.registerView(view);

        final rootElement = view.dom.rootElement;
        final child1 = createDomElement('div');
        final child2 = createDomElement('div');
        final child3 = createDomElement('div');
        rootElement.append(child1);
        rootElement.append(child2);
        child2.append(child3);

        expect(viewManager.findViewForElement(rootElement), view);
        expect(viewManager.findViewForElement(child1), view);
        expect(viewManager.findViewForElement(child2), view);
        expect(viewManager.findViewForElement(child3), view);

        viewManager.unregisterView(view.viewId);

        expect(viewManager.findViewForElement(rootElement), isNull);
        expect(viewManager.findViewForElement(child1), isNull);
        expect(viewManager.findViewForElement(child2), isNull);
        expect(viewManager.findViewForElement(child3), isNull);
      });
    });
  });
}
