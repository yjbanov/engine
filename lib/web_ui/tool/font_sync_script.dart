// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This script downloads a subset of fonts from fonts.google.com and packages
/// it as a CIPD archive. These fonts are used as a fallback by the CanvasKit
/// renderer when the app developer does not provide fonts covering text
/// rendered by the app.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as pathlib;

import '../dev/environment.dart';

const String _kCipdDirectory = 'flutter/web_fallback_fonts';

const List<_GoogleFont> _notoFonts = <_GoogleFont>[
  _RobotoFont(),
  _GoogleFont('Noto Sans SC', FontLicense.ofl),
  _GoogleFont('Noto Sans TC', FontLicense.ofl),
  _GoogleFont('Noto Sans HK', FontLicense.ofl),
  _GoogleFont('Noto Sans JP', FontLicense.ofl),
  _GoogleFont('Noto Naskh Arabic UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Armenian', FontLicense.ofl),
  _GoogleFont('Noto Sans Bengali UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Myanmar UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Egyptian Hieroglyphs', FontLicense.ofl),
  _GoogleFont('Noto Sans Ethiopic', FontLicense.ofl),
  _GoogleFont('Noto Sans Georgian', FontLicense.ofl),
  _GoogleFont('Noto Sans Gujarati UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Gurmukhi UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Hebrew', FontLicense.ofl),
  _GoogleFont('Noto Sans Devanagari UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Kannada UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Khmer UI', FontLicense.ofl),
  _GoogleFont('Noto Sans KR', FontLicense.ofl),
  _GoogleFont('Noto Sans Lao UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Malayalam UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Sinhala', FontLicense.ofl),
  _GoogleFont('Noto Sans Tamil UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Telugu UI', FontLicense.ofl),
  _GoogleFont('Noto Sans Thai UI', FontLicense.ofl),
  _GoogleFont('Noto Sans', FontLicense.ofl),
];

final File _fontsLockFile = File(pathlib.join(
  environment.webUiDevDir.path,
  'fonts_lock.yaml',
));

Future<void> main(List<String> arguments) async {
  final String revision = _generateRevision();
  final HttpClient client = HttpClient();
  try {
    await _download(revision, client);
    await _archive(revision);
    await _updateLockFile(revision);
    print('CIPD updated with new fonts.');
    print('Next steps:');
    print('  - Run `cipd ls $_kCipdDirectory` and make sure revision "$revision" exists.');
    print('  - Run `git status` and verify that there is a pending change in ${_fontsLockFile.path} pointing to "${_toCipdPackagePath(revision)}".');
    print('  - Submit a pull request to the engine so that the changes takes effect.');
  } finally {
    client.close();
  }
}

String _generateRevision() {
  String _twoDigits(int n) {
    if (n >= 10) {
      return '$n';
    }
    return '0$n';
  }

  final DateTime now = DateTime.now().toUtc();
  final String m = _twoDigits(now.month);
  final String d = _twoDigits(now.day);
  final String h = _twoDigits(now.hour);
  final String min = _twoDigits(now.minute);
  final String sec = _twoDigits(now.second);
  return '${now.year}$m${d}_$h$min$sec';
}

String _toCipdPackagePath(String revision) {
  return '$_kCipdDirectory/$revision.zip';
}

Directory _toFontsDirectory(String revision) {
  return Directory(pathlib.join(
    environment.webUiBuildDir.path,
    'fonts',
    revision,
  ));
}

Future<void> _archive(String revision) async {
  print('Archiving fonts');
  final Directory fontsDirectory = _toFontsDirectory(revision);
  final ZipFileEncoder encoder = ZipFileEncoder();
  encoder.zipDirectory(fontsDirectory);
}

Future<void> _updateLockFile(String revision) async {
  print('Updating lock file');
  const String fileHeader = '''
# THIS FILE IS GENERATED. DO NOT EDIT BY HAND.
# Use the lib/web_ui/tool/font_sync_script.dart script to update this file.
# Points to the CIPD package containing fallback fonts used by CanvasKit.
  ''';
  await _fontsLockFile.writeAsString(
    '${fileHeader.trim()}\n'
    'cipd: "${_toCipdPackagePath(revision)}"\n',
  );
}

Future<void> _download(String revision, HttpClient client) async {
  print('Downloading fonts');
  final Directory fontsDirectory = _toFontsDirectory(revision);
  if (fontsDirectory.existsSync()) {
    await fontsDirectory.delete(recursive: true);
  }
  await fontsDirectory.create(recursive: true);

  final List<Map<String, dynamic>> fallbacks = <Map<String, dynamic>>[];
  for (final _GoogleFont font in _notoFonts) {
    print(font.name);
    final _ResolvedGoogleFont resolvedFont = await font.resolve(client);
    for (final _ResolvedNotoSubset subset in resolvedFont.subsets) {
      final Uri subsetUrl = Uri.parse(subset.url);
      final String fontFilePath = pathlib.join(
        fontsDirectory.path,
        subset.bundlePath,
      );
      final File fontFile = File(fontFilePath);
      await fontFile.parent.create(recursive: true);

      print('  Downloading $subsetUrl');
      final HttpClientRequest request = await client.getUrl(subsetUrl);
      final HttpClientResponse response = await request.close();
      final IOSink fileSink = fontFile.openWrite();
      await response.pipe(fileSink);

      fallbacks.add(<String, dynamic>{
        'family': subset.family,
        // Use Posix paths in the JSON manifest so that the manifest is the same
        // no matter what OS it was generated on.
        'path': pathlib.split(subset.bundlePath).join('/'),
        'url': subset.url,
        // TODO(yjbanov): extract ranges from the font file instead of trusting the CSS file.
        'ranges': subset.ranges.map<List<int>>((CodeunitRange range) {
          return <int>[range.start, range.end];
        }).toList(),
      });
    }
  }

  final File manifestFile = File(pathlib.join(fontsDirectory.path, 'manifest.json'));
  manifestFile.writeAsString(const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
    'revision': revision,
    'fallbacks': fallbacks,
  }));
}

enum FontLicense {
  /// The Open Font License.
  ///
  /// See also:
  ///  * https://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=OFL
  ofl,

  /// Apache 2.0 License.
  apache2,
}

class _GoogleFont {
  const _GoogleFont(this.name, this.license);

  final String name;
  final FontLicense license;

  String get googleFontsCssUrl =>
      'https://fonts.googleapis.com/css2?family=${name.replaceAll(' ', '+')}';

  Future<_ResolvedGoogleFont> resolve(HttpClient client) async {
    final HttpClientRequest request = await client.getUrl(Uri.parse(googleFontsCssUrl));
    request.headers.set('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36');
    final HttpClientResponse response = await request.close();
    final String googleFontCss = await response.transform<String>(const Utf8Decoder()).join();
    return _ResolvedGoogleFont.fromCss(name, googleFontCss);
  }
}

class _RobotoFont extends _GoogleFont {
  const _RobotoFont() : super('Roboto', FontLicense.apache2);

  @override
  Future<_ResolvedGoogleFont> resolve(HttpClient client) async {
    return const _ResolvedGoogleFont('Roboto', <_ResolvedNotoSubset>[
      _ResolvedNotoSubset(
        url: 'https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Me5WZLCzYlKw.ttf',
        family: 'Roboto',
        bundlePathOverride: 'Roboto.ttf',
        ranges: <CodeunitRange>[
        ],
      ),
    ]);
  }
}

class CodeunitRange {
  final int start;
  final int end;

  const CodeunitRange(this.start, this.end);

  bool contains(int codeUnit) {
    return start <= codeUnit && codeUnit <= end;
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! CodeunitRange) {
      return false;
    }
    final CodeunitRange range = other;
    return range.start == start && range.end == end;
  }

  @override
  int get hashCode => 17 * start + end;

  @override
  String toString() => '[$start, $end]';
}

class _ResolvedGoogleFont {
  const _ResolvedGoogleFont(this.name, this.subsets);

  /// Parse the CSS file for a font and make a list of resolved subsets.
  ///
  /// A CSS file from Google Fonts looks like this:
  ///
  ///     /* [0] */
  ///     @font-face {
  ///       font-family: 'Noto Sans KR';
  ///       font-style: normal;
  ///       font-weight: 400;
  ///       src: url(https://fonts.gstatic.com/s/notosanskr/v13/PbykFmXiEBPT4ITbgNA5Cgm20xz64px_1hVWr0wuPNGmlQNMEfD4.0.woff2) format('woff2');
  ///       unicode-range: U+f9ca-fa0b, U+ff03-ff05, U+ff07, U+ff0a-ff0b, U+ff0d-ff19, U+ff1b, U+ff1d, U+ff20-ff5b, U+ff5d, U+ffe0-ffe3, U+ffe5-ffe6;
  ///     }
  ///     /* [1] */
  ///     @font-face {
  ///       font-family: 'Noto Sans KR';
  ///       font-style: normal;
  ///       font-weight: 400;
  ///       src: url(https://fonts.gstatic.com/s/notosanskr/v13/PbykFmXiEBPT4ITbgNA5Cgm20xz64px_1hVWr0wuPNGmlQNMEfD4.1.woff2) format('woff2');
  ///       unicode-range: U+f92f-f980, U+f982-f9c9;
  ///     }
  ///     /* [2] */
  ///     @font-face {
  ///       font-family: 'Noto Sans KR';
  ///       font-style: normal;
  ///       font-weight: 400;
  ///       src: url(https://fonts.gstatic.com/s/notosanskr/v13/PbykFmXiEBPT4ITbgNA5Cgm20xz64px_1hVWr0wuPNGmlQNMEfD4.2.woff2) format('woff2');
  ///       unicode-range: U+d723-d728, U+d72a-d733, U+d735-d748, U+d74a-d74f, U+d752-d753, U+d755-d757, U+d75a-d75f, U+d762-d764, U+d766-d768, U+d76a-d76b, U+d76d-d76f, U+d771-d787, U+d789-d78b, U+d78d-d78f, U+d791-d797, U+d79a, U+d79c, U+d79e-d7a3, U+f900-f909, U+f90b-f92e;
  ///     }
  factory _ResolvedGoogleFont.fromCss(String name, String css) {
    final List<_ResolvedNotoSubset> subsets = <_ResolvedNotoSubset>[];
    bool resolvingFontFace = false;
    String? fontFaceUrl;
    List<CodeunitRange>? fontFaceUnicodeRanges;
    for (final String line in LineSplitter.split(css)) {
      // Search for the beginning of a @font-face.
      if (!resolvingFontFace) {
        if (line == '@font-face {') {
          resolvingFontFace = true;
        } else {
          continue;
        }
      } else {
        // We are resolving a @font-face, read out the url and ranges.
        if (line.startsWith('  src:')) {
          final int urlStart = line.indexOf('url(');
          if (urlStart == -1) {
            throw Exception('Unable to resolve Noto font URL: $line');
          }
          final int urlEnd = line.indexOf(')');
          fontFaceUrl = line.substring(urlStart + 4, urlEnd);
        } else if (line.startsWith('  unicode-range:')) {
          fontFaceUnicodeRanges = <CodeunitRange>[];
          final String rangeString = line.substring(17, line.length - 1);
          final List<String> rawRanges = rangeString.split(', ');
          for (final String rawRange in rawRanges) {
            final List<String> startEnd = rawRange.split('-');
            if (startEnd.length == 1) {
              final String singleRange = startEnd.single;
              assert(singleRange.startsWith('U+'));
              final int rangeValue =
                  int.parse(singleRange.substring(2), radix: 16);
              fontFaceUnicodeRanges.add(CodeunitRange(rangeValue, rangeValue));
            } else {
              assert(startEnd.length == 2);
              final String startRange = startEnd[0];
              final String endRange = startEnd[1];
              assert(startRange.startsWith('U+'));
              final int startValue =
                  int.parse(startRange.substring(2), radix: 16);
              final int endValue = int.parse(endRange, radix: 16);
              fontFaceUnicodeRanges.add(CodeunitRange(startValue, endValue));
            }
          }
        } else if (line == '}') {
          if (fontFaceUrl == null || fontFaceUnicodeRanges == null) {
            throw Exception('Unable to parse Google Fonts CSS: $css');
          }
          subsets
              .add(_ResolvedNotoSubset(url: fontFaceUrl, family: name, ranges: fontFaceUnicodeRanges));
          resolvingFontFace = false;
        } else {
          continue;
        }
      }
    }

    if (resolvingFontFace) {
      throw Exception('Unable to parse Google Fonts CSS: $css');
    }

    return _ResolvedGoogleFont(name, subsets);
  }

  final String name;
  final List<_ResolvedNotoSubset> subsets;
}

class _ResolvedNotoSubset {
  const _ResolvedNotoSubset({
    required this.url,
    required this.family,
    required this.ranges,
    this.bundlePathOverride,
  });

  final String url;
  final String family;
  final List<CodeunitRange> ranges;
  final String? bundlePathOverride;

  /// The path to the font file inside the CIPD bundle.
  String get bundlePath => bundlePathOverride ?? pathlib.joinAll(Uri.parse(url).pathSegments);

  @override
  String toString() => '_ResolvedNotoSubset($family, $url)';
}
