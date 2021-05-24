// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';

import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

import 'common.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  group('CanvasKit API', () {
    setUpCanvasKitTest();

    test('getShapedLines - single style', () {
      final CkParagraphStyle paragraphStyle = CkParagraphStyle(
        fontFamily: 'Roboto',
        fontSize: 10,
      );
      final CkParagraphBuilder builder = CkParagraphBuilder(paragraphStyle);
      builder.pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFAABBCC),
      ));
      builder.addText('Hello World!');
      builder.pop();
      final CkParagraph paragraph = builder.build();

      {
        paragraph.layout(const ui.ParagraphConstraints(width: 1000));
        // "Hello World!" all on one line
        expect(paragraph.shapedLines, hasLength(1));
        expect(paragraph.shapedLines.single.runs, hasLength(1));
        expect(paragraph.shapedLines.single.textRange.first, 0);
        expect(paragraph.shapedLines.single.textRange.last, 12);
      }

      {
        paragraph.layout(const ui.ParagraphConstraints(width: 30));
        expect(paragraph.shapedLines, hasLength(2));
        // "Hello"
        final ShapedLine firstLine = paragraph.shapedLines[0];
        expect(firstLine.runs, hasLength(1));
        expect(firstLine.textRange.first, 0);
        expect(firstLine.textRange.last, 5);
        // "World!"
        final ShapedLine secondLine = paragraph.shapedLines[1];
        expect(secondLine.runs, hasLength(1));
        expect(secondLine.textRange.first, 6);
        expect(secondLine.textRange.last, 12);
      }

      {
        paragraph.layout(const ui.ParagraphConstraints(width: 28));
        expect(paragraph.shapedLines, hasLength(3));
        // "Hello"
        final ShapedLine firstLine = paragraph.shapedLines[0];
        expect(firstLine.runs, hasLength(1));
        expect(firstLine.textRange.first, 0);
        expect(firstLine.textRange.last, 5);
        // "World"
        final ShapedLine secondLine = paragraph.shapedLines[1];
        expect(secondLine.runs, hasLength(1));
        expect(secondLine.textRange.first, 6);
        expect(secondLine.textRange.last, 11);
        // "!"
        final ShapedLine thirdLine = paragraph.shapedLines[2];
        expect(thirdLine.runs, hasLength(1));
        expect(thirdLine.textRange.first, 11);
        expect(thirdLine.textRange.last, 12);
      }
    });

    test('getShapedLines - multiple styles', () {
      final CkParagraphStyle paragraphStyle = CkParagraphStyle(
        fontFamily: 'Roboto',
        fontSize: 10,
      );
      final CkParagraphBuilder builder = CkParagraphBuilder(paragraphStyle);
      builder.pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFAABBCC),
      ));
      builder.addText('Hello ');
      builder.pop();
      builder.pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFCCBBAA),
      ));
      builder.addText('World!');
      builder.pop();
      final CkParagraph paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: 1000));

      // "Hello " "World!" one line, multiple runs
      expect(paragraph.shapedLines, hasLength(1));
      expect(paragraph.shapedLines.single.textRange.first, 0);
      expect(paragraph.shapedLines.single.textRange.last, 12);

      expect(paragraph.shapedLines.single.runs, hasLength(2));
      final GlyphRun firstRun = paragraph.shapedLines.single.runs[0];
      expect(firstRun.offsets, Uint32List.fromList(<int>[0, 1, 2, 3, 4, 5, 6]));

      final GlyphRun secondRun = paragraph.shapedLines.single.runs[1];
      expect(secondRun.offsets, Uint32List.fromList(<int>[6, 7, 8, 9, 10, 11, 12]));
    });

    test('drawGlyphs', () {
      final CkParagraphStyle paragraphStyle = CkParagraphStyle(
        fontFamily: 'Roboto',
        fontSize: 10,
      );
      final CkParagraphBuilder builder = CkParagraphBuilder(paragraphStyle);
      builder.pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFAABBCC),
      ));
      builder.addText('Hello ');
      builder.pop();
      builder.pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFCCBBAA),
      ));
      builder.addText('World!');
      builder.pop();
      final CkParagraph paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: 1000));

      final CkPictureRecorder recorder = CkPictureRecorder();
      final CkCanvas canvas = recorder.beginRecording(ui.Rect.largest);
      canvas.drawParagraph(paragraph, const ui.Offset(10, 10));
    });
  });
}
