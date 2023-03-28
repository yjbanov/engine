// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../dom.dart';
import '../text/line_breaker.dart';
import '../util.dart';
import 'canvaskit_api.dart';

class Segmentation {
  const Segmentation(this.words, this.graphemes, this.breaks);

  final Uint32List words;
  final Uint32List graphemes;
  final Uint32List breaks;
}

// The number below were picked based on the following logic. Apps typically do
// not put a lot of text in a single paragraph. 10000 UTF-16 characters (i.e.
// 20kB) should be plenty. To avoid consuming too much memory strings longer
// than 10000 will not be cached. The cache size 10000 amounts to a worst case
// of 200MB, but that's highly unlikely, given that the vast majority of strings
// will be small. Even if the cache is filled with 200-character long paragraphs
// the cache will only consume 4MB. This logic assumes that the segmentation
// information is << the size of string.
//
// This could be improved in the future. For example, we can maintain multiple
// caches of different sizes that store strings of different lengths. For
// example, we can have a cache of size 10 that stores very long strings, a
// cache of 1000 that stores medium-length strings, and a cache of 10000 that
// stores short strings.
const int kCacheTextLengthLimit = 10000;
const int kCacheSize = 10000;

// Caches segmentation results. Paragraphs are frequently re-created because of
// style or font changes, while their text contents remain the same. This cache
// is effective at short-circuiting the segmentation of such paragraphs.
final LruCache<String, Segmentation> segmentationCache = LruCache<String, Segmentation>(kCacheSize);

/// Injects required ICU data into the [builder].
///
/// This should only be used with the CanvasKit Chromium variant that's compiled
/// without ICU data.
void injectClientICU(SkParagraphBuilder builder) {
  assert(
    canvasKit.ParagraphBuilder.RequiresClientICU(),
    'This method should only be used with the CanvasKit Chromium variant.',
  );

  final Segmentation segmentation = segmentText(builder.getText());
  builder.setWordsUtf16(segmentation.words);
  builder.setGraphemeBreaksUtf16(segmentation.graphemes);
  builder.setLineBreaksUtf16(segmentation.breaks);
}

/// Segments the [text].
///
/// Caches results in [segmentationCache].
Segmentation segmentText(String text) {
  final Segmentation? cached = segmentationCache[text];
  final Segmentation segmentation;

  // Don't cache strings that are too big to avoid blowing up memory.
  final bool exceedsTextLengthLimit = text.length > kCacheTextLengthLimit;

  if (cached == null || exceedsTextLengthLimit) {
    segmentation = Segmentation(
      fragmentUsingIntlSegmenter(text, IntlSegmenterGranularity.word),
      fragmentUsingIntlSegmenter(text, IntlSegmenterGranularity.grapheme),
      fragmentUsingV8LineBreaker(text),
    );
  } else {
    segmentation = cached;
  }

  if (!exceedsTextLengthLimit) {
    // Save or promote to most recently used.
    segmentationCache.cache(text, segmentation);
  }

  return segmentation;
}

/// The granularity at which to segment text.
///
/// To find all supported granularities, see:
/// - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/Segmenter/Segmenter
enum IntlSegmenterGranularity {
  grapheme,
  word,
}

final Map<IntlSegmenterGranularity, DomSegmenter> _intlSegmenters = <IntlSegmenterGranularity, DomSegmenter>{
  IntlSegmenterGranularity.grapheme: createIntlSegmenter(granularity: 'grapheme'),
  IntlSegmenterGranularity.word: createIntlSegmenter(granularity: 'word'),
};

Uint32List fragmentUsingIntlSegmenter(
  String text,
  IntlSegmenterGranularity granularity,
) {
  final DomSegmenter segmenter = _intlSegmenters[granularity]!;
  final DomIteratorWrapper<DomSegment> iterator = segmenter.segment(text).iterator();

  final List<int> breaks = <int>[];
  while (iterator.moveNext()) {
    breaks.add(iterator.current.index);
  }
  breaks.add(text.length);
  return Uint32List.fromList(breaks);
}

// These are the soft/hard line break values expected by Skia's SkParagraph.
const int _kSoftLineBreak = 0;
const int _kHardLineBreak = 1;

final DomV8BreakIterator _v8LineBreaker = createV8BreakIterator();

Uint32List fragmentUsingV8LineBreaker(String text) {
  final List<LineBreakFragment> fragments =
      breakLinesUsingV8BreakIterator(text, _v8LineBreaker);

  final int size = (fragments.length + 1) * 2;
  final Uint32List typedArray = Uint32List(size);

  typedArray[0] = 0; // start index
  typedArray[1] = _kSoftLineBreak; // break type

  for (int i = 0; i < fragments.length; i++) {
    final LineBreakFragment fragment = fragments[i];
    final int uint32Index = 2 + i * 2;
    typedArray[uint32Index] = fragment.end;
    typedArray[uint32Index + 1] = fragment.type == LineBreakType.mandatory
        ? _kHardLineBreak
        : _kSoftLineBreak;
  }

  return typedArray;
}
