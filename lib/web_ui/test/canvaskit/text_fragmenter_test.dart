// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';

import 'common.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  setUpCanvasKitTest();

  group('$fragmentUsingIntlSegmenter', () {
    test('fragments text into words', () {
      final Uint32List breaks = fragmentUsingIntlSegmenter(
        'Hello world 你好世界',
        IntlSegmenterGranularity.word,
      );
      expect(
        breaks,
        orderedEquals(<int>[0, 5, 6, 11, 12, 14, 16]),
      );
    });

    test('fragments multi-line text into words', () {
      final Uint32List breaks = fragmentUsingIntlSegmenter(
        'Lorem ipsum\ndolor 你好世界 sit\namet',
        IntlSegmenterGranularity.word,
      );
      expect(
        breaks,
        orderedEquals(<int>[
          0, 5, 6, 11, 12, // "Lorem ipsum\n"
          17, 18, 20, 22, 23, 26, 27, // "dolor 你好世界 sit\n"
          31, // "amet"
        ]),
      );
    });

    test('fragments text into grapheme clusters', () {
      // The smiley emoji has a length of 2.
      // The family emoji has a length of 11.
      final Uint32List breaks = fragmentUsingIntlSegmenter(
        'Lorem🙂ipsum👨‍👩‍👧‍👦',
        IntlSegmenterGranularity.grapheme,
      );
      expect(
        breaks,
        orderedEquals(<int>[
          0, 1, 2, 3, 4, 5, 7, // "Lorem🙂"
          8, 9, 10, 11, 12, 23, // "ipsum👨‍👩‍👧‍👦"
        ]),
      );
    });

    test('fragments multi-line text into grapheme clusters', () {
      // The smiley emojis have a length of 2 each.
      // The family emoji has a length of 11.
      final Uint32List breaks = fragmentUsingIntlSegmenter(
        'Lorem🙂\nipsum👨‍👩‍👧‍👦dolor\n😄',
        IntlSegmenterGranularity.grapheme,
      );
      expect(
        breaks,
        orderedEquals(<int>[
          0, 1, 2, 3, 4, 5, 7, 8, // "Lorem🙂\n"
          9, 10, 11, 12, 13, 24, // "ipsum👨‍👩‍👧‍👦"
          25, 26, 27, 28, 29, 30, 32, // "dolor😄\n"
        ]),
      );
    });
  }, skip: !browserSupportsCanvaskitChromium);

  group('$fragmentUsingV8LineBreaker', () {
    const int kSoft = 0;
    const int kHard = 1;

    test('fragments text into soft and hard line breaks', () {
      final Uint32List breaks = fragmentUsingV8LineBreaker(
        'Lorem-ipsum 你好🙂\nDolor sit',
      );
      expect(
        breaks,
        orderedEquals(<int>[
          0, kSoft,
          6, kSoft, // "Lorem-"
          12, kSoft, // "ipsum "
          13, kSoft, // "你"
          14, kSoft, // "好"
          17, kHard, // "🙂\n"
          23, kSoft, // "Dolor "
          26, kSoft, // "sit"
        ]),
      );
    });
  }, skip: !browserSupportsCanvaskitChromium);

  group('segmentText', () {
    setUp(() {
      segmentationCache.clear();
    });

    tearDown(() {
      segmentationCache.clear();
    });

    test('segments correctly', () {
      const String text = 'Lorem-ipsum 你好🙂\nDolor sit';
      final Segmentation segmentation = segmentText(text);
      expect(
        segmentation.words,
        fragmentUsingIntlSegmenter(text, IntlSegmenterGranularity.word),
      );
      expect(
        segmentation.graphemes,
        fragmentUsingIntlSegmenter(text, IntlSegmenterGranularity.grapheme),
      );
      expect(
        segmentation.breaks,
        fragmentUsingV8LineBreaker(text),
      );
    });

    test('caches segmentation results in LRU fashion', () {
      const String text1 = 'hello';
      segmentText(text1);
      expect(segmentationCache.debugItemQueue, hasLength(1));
      expect(segmentationCache[text1], isNotNull);

      const String text2 = 'world';
      segmentText(text2);
      expect(segmentationCache.debugItemQueue, hasLength(2));
      expect(segmentationCache[text2], isNotNull);

      // "world" was segmented last, so it should be first, as in most recently used.
      expect(segmentationCache.debugItemQueue.first.$1, 'world');
      expect(segmentationCache.debugItemQueue.last.$1, 'hello');
    });

    test('does not cache long text', () {
      final String text1 = 'a' * (kCacheTextLengthLimit + 1);
      segmentText(text1);
      expect(segmentationCache.debugItemQueue, hasLength(0));

      final String text2 = 'a' * kCacheTextLengthLimit;
      segmentText(text2);
      expect(segmentationCache.debugItemQueue, hasLength(1));
      expect(segmentationCache[text2], isNotNull);
    });

    test('has a limit on the number of entries', () {
      int totalCount = 0;
      for (final String letter in const <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j']) {
        for (final String digit in const <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
          for (int count = 1; count <= 10000; count++) {
            totalCount += 1;
            final String text = letter * count;
            segmentText(text);
            expect(segmentationCache.debugItemQueue, hasLength(lessThanOrEqualTo(kCacheSize)));
          }
        }
      }

      expect(totalCount, 50000);
      expect(segmentationCache.length, kCacheSize);
    });
  });
}
