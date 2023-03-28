// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine/util.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  test('$LruCache starts out empty', () {
    final LruCache<String, int> cache = LruCache<String, int>(10);
    expect(cache.length, 0);
  });

  test('$LruCache adds up to a maximum number of items in most recently used first order', () {
    final LruCache<String, int> cache = LruCache<String, int>(3);
    cache.cache('a', 1);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('a', 1),
    ]);
    expect(cache['a'], 1);
    expect(cache['b'], isNull);

    cache.cache('b', 2);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('b', 2),
      ('a', 1),
    ]);
    expect(cache['a'], 1);
    expect(cache['b'], 2);

    cache.cache('c', 3);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('c', 3),
      ('b', 2),
      ('a', 1),
    ]);

    cache.cache('d', 4);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('d', 4),
      ('c', 3),
      ('b', 2),
    ]);

    cache.cache('e', 5);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('e', 5),
      ('d', 4),
      ('c', 3),
    ]);
  });

  test('$LruCache promotes entry to most recently used position', () {
    final LruCache<String, int> cache = LruCache<String, int>(3);
    cache.cache('a', 1);
    cache.cache('b', 2);
    cache.cache('c', 3);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('c', 3),
      ('b', 2),
      ('a', 1),
    ]);

    cache.cache('b', 2);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('b', 2),
      ('c', 3),
      ('a', 1),
    ]);
  });

  test('$LruCache updates and promotes entry to most recently used position', () {
    final LruCache<String, int> cache = LruCache<String, int>(3);
    cache.cache('a', 1);
    cache.cache('b', 2);
    cache.cache('c', 3);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('c', 3),
      ('b', 2),
      ('a', 1),
    ]);
    expect(cache['b'], 2);

    cache.cache('b', 42);
    expect(cache.debugItemQueue.toList(), <(String, int)>[
      ('b', 42),
      ('c', 3),
      ('a', 1),
    ]);
    expect(cache['b'], 42);
  });
}
