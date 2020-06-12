// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(dnfield): Remove unused_import ignores when https://github.com/dart-lang/sdk/issues/35164 is resolved.

// @dart = 2.9

part of dart.ui;

@pragma('vm:entry-point')
// ignore: unused_element
void _updateWindowMetrics(
  double devicePixelRatio,
  double width,
  double height,
  double depth,
  double viewPaddingTop,
  double viewPaddingRight,
  double viewPaddingBottom,
  double viewPaddingLeft,
  double viewInsetTop,
  double viewInsetRight,
  double viewInsetBottom,
  double viewInsetLeft,
  double systemGestureInsetTop,
  double systemGestureInsetRight,
  double systemGestureInsetBottom,
  double systemGestureInsetLeft,
) {
  window
    .._devicePixelRatio = devicePixelRatio
    .._physicalSize = Size(width, height)
    .._physicalDepth = depth
    .._viewPadding = WindowPadding._(
        top: viewPaddingTop,
        right: viewPaddingRight,
        bottom: viewPaddingBottom,
        left: viewPaddingLeft)
    .._viewInsets = WindowPadding._(
        top: viewInsetTop,
        right: viewInsetRight,
        bottom: viewInsetBottom,
        left: viewInsetLeft)
    .._padding = WindowPadding._(
        top: math.max(0.0, viewPaddingTop - viewInsetTop),
        right: math.max(0.0, viewPaddingRight - viewInsetRight),
        bottom: math.max(0.0, viewPaddingBottom - viewInsetBottom),
        left: math.max(0.0, viewPaddingLeft - viewInsetLeft))
    .._systemGestureInsets = WindowPadding._(
        top: math.max(0.0, systemGestureInsetTop),
        right: math.max(0.0, systemGestureInsetRight),
        bottom: math.max(0.0, systemGestureInsetBottom),
        left: math.max(0.0, systemGestureInsetLeft));
  _invoke(window.onMetricsChanged, window._onMetricsChangedZone);
}

typedef _LocaleClosure = String? Function();

String? _localeClosure() {
  if (window.locale == null) {
    return null;
  }
  return window.locale.toString();
}

@pragma('vm:entry-point')
// ignore: unused_element
_LocaleClosure? _getLocaleClosure() => _localeClosure;

int _frameCount = 0;
int _updateLocalesCount = 0;
int _updateLocalesSize = 0;
int _updateLocalesMicros = 0;

int _updatePointerDataPacketCount = 0;
int _updatePointerDataPacketSize = 0;
int _updatePointerDataPacketMicros = 0;
int _updatePointerDataPacketMaxMicros = 0;
int _updatePointerDataPacketMaxLength = 0;
int _updatePointerDataPacketProcessedMicros = 0;

int _updateDummyPointerDataPacketCount = 0;
int _updateDummyPointerDataPacketSize = 0;
int _updateDummyPointerDataPacketMicros = 0;
int _updateDummyPointerDataPacketMaxMicros = 0;

int _decodeTextBoxesCount = 0;
int _decodeTextBoxesSize = 0;
int _decodeTextBoxesMicros = 0;
int _decodeTextBoxesMaxMicros = 0;
int _decodeTextBoxesMaxLength = 0;

int _decodeDummyTextBoxesCount = 0;
int _decodeDummyTextBoxesSize = 0;
int _decodeDummyTextBoxesMicros = 0;
int _decodeDummyTextBoxesMaxMicros = 0;

Timer? _benchTimer;

void _benchNextFrame() {
  _frameCount += 1;

  _benchTimer ??= Timer(const Duration(seconds: 1), () {
    print('''
--------------------------- $_frameCount -----------------------------------
Locales
Count     : $_updateLocalesCount
Size      : $_updateLocalesSize
Micros    : $_updateLocalesMicros

Pointers
Count     : $_updatePointerDataPacketCount
Size      : $_updatePointerDataPacketSize
Micros    : $_updatePointerDataPacketMicros
MaxMicros : $_updatePointerDataPacketMaxMicros
PrcMicros : $_updatePointerDataPacketProcessedMicros
MaxLength : $_updatePointerDataPacketMaxLength

Dummy pointers
Count     : $_updateDummyPointerDataPacketCount
Size      : $_updateDummyPointerDataPacketSize
Micros    : $_updateDummyPointerDataPacketMicros
MaxMicros : $_updateDummyPointerDataPacketMaxMicros

Text boxes
Count     : $_decodeTextBoxesCount
Size      : $_decodeTextBoxesSize
Micros    : $_decodeTextBoxesMicros
MaxMicros : $_decodeTextBoxesMaxMicros
MaxLength : $_decodeTextBoxesMaxLength

Dummy text boxes
Count     : $_decodeDummyTextBoxesCount
Size      : $_decodeDummyTextBoxesSize
Micros    : $_decodeDummyTextBoxesMicros
MaxMicros : $_decodeDummyTextBoxesMaxMicros
----------------------------------------------------------------------------
''');
    _benchTimer = null;
  });
}

@pragma('vm:entry-point')
// ignore: unused_element
void _updateLocales(List<String> locales) {
  const int stringsPerLocale = 4;
  final int numLocales = locales.length ~/ stringsPerLocale;
  final int start = developer.Timeline.now;
  final List<Locale> newLocales = <Locale>[];
  _updateLocalesSize += numLocales;
  for (int localeIndex = 0; localeIndex < numLocales; localeIndex++) {
    final String countryCode = locales[localeIndex * stringsPerLocale + 1];
    final String scriptCode = locales[localeIndex * stringsPerLocale + 2];

    newLocales.add(Locale.fromSubtags(
      languageCode: locales[localeIndex * stringsPerLocale],
      countryCode: countryCode.isEmpty ? null : countryCode,
      scriptCode: scriptCode.isEmpty ? null : scriptCode,
    ));
  }
  final int listPopulated = developer.Timeline.now;
  window._locales = newLocales;
  _invoke(window.onLocaleChanged, window._onLocaleChangedZone);
  _updateLocalesCount++;
  _updateLocalesMicros += listPopulated - start;
}

@pragma('vm:entry-point')
// ignore: unused_element
void _updatePlatformResolvedLocale(List<String> localeData) {
  if (localeData.length != 4) {
    return;
  }
  final String countryCode = localeData[1];
  final String scriptCode = localeData[2];

  window._platformResolvedLocale = Locale.fromSubtags(
    languageCode: localeData[0],
    countryCode: countryCode.isEmpty ? null : countryCode,
    scriptCode: scriptCode.isEmpty ? null : scriptCode,
  );
}

@pragma('vm:entry-point')
// ignore: unused_element
void _updateUserSettingsData(String jsonData) {
  final Map<String, dynamic> data = json.decode(jsonData) as Map<String, dynamic>;
  if (data.isEmpty) {
    return;
  }
  _updateTextScaleFactor((data['textScaleFactor'] as num).toDouble());
  _updateAlwaysUse24HourFormat(data['alwaysUse24HourFormat'] as bool);
  _updatePlatformBrightness(data['platformBrightness'] as String);
}

@pragma('vm:entry-point')
// ignore: unused_element
void _updateLifecycleState(String state) {
  // We do not update the state if the state has already been used to initialize
  // the lifecycleState.
  if (!window._initialLifecycleStateAccessed)
    window._initialLifecycleState = state;
}


void _updateTextScaleFactor(double textScaleFactor) {
  window._textScaleFactor = textScaleFactor;
  _invoke(window.onTextScaleFactorChanged, window._onTextScaleFactorChangedZone);
}

void _updateAlwaysUse24HourFormat(bool alwaysUse24HourFormat) {
  window._alwaysUse24HourFormat = alwaysUse24HourFormat;
}

void _updatePlatformBrightness(String brightnessName) {
  window._platformBrightness = brightnessName == 'dark' ? Brightness.dark : Brightness.light;
  _invoke(window.onPlatformBrightnessChanged, window._onPlatformBrightnessChangedZone);
}

@pragma('vm:entry-point')
// ignore: unused_element
void _updateSemanticsEnabled(bool enabled) {
  window._semanticsEnabled = enabled;
  _invoke(window.onSemanticsEnabledChanged, window._onSemanticsEnabledChangedZone);
}

@pragma('vm:entry-point')
// ignore: unused_element
void _updateAccessibilityFeatures(int values) {
  final AccessibilityFeatures newFeatures = AccessibilityFeatures._(values);
  if (newFeatures == window._accessibilityFeatures)
    return;
  window._accessibilityFeatures = newFeatures;
  _invoke(window.onAccessibilityFeaturesChanged, window._onAccessibilityFeaturesChangedZone);
}

@pragma('vm:entry-point')
// ignore: unused_element
void _dispatchPlatformMessage(String name, ByteData? data, int responseId) {
  if (name == ChannelBuffers.kControlChannelName) {
    try {
      channelBuffers.handleMessage(data!);
    } catch (ex) {
      _printDebug('Message to "$name" caused exception $ex');
    } finally {
      window._respondToPlatformMessage(responseId, null);
    }
  } else if (window.onPlatformMessage != null) {
    _invoke3<String, ByteData?, PlatformMessageResponseCallback>(
      window.onPlatformMessage,
      window._onPlatformMessageZone,
      name,
      data,
      (ByteData? responseData) {
        window._respondToPlatformMessage(responseId, responseData);
      },
    );
  } else {
    channelBuffers.push(name, data, (ByteData? responseData) {
      window._respondToPlatformMessage(responseId, responseData);
    });
  }
}

@pragma('vm:entry-point')
// ignore: unused_element
void _dispatchPointerDataPacket(ByteData packet) {
  if (window.onPointerDataPacket != null) {
    final int start = developer.Timeline.now;
    final PointerDataPacket dataPacket = _unpackPointerDataPacket(packet);
    final int length = dataPacket.data.length;
    final int listPopulated = developer.Timeline.now;
    _updatePointerDataPacketCount++;
    final int time = listPopulated - start;
    _updatePointerDataPacketMicros += time;
    if (time > _updatePointerDataPacketMaxMicros) {
      _updatePointerDataPacketMaxMicros = time;
    }
    if (length > _updatePointerDataPacketMaxLength) {
      _updatePointerDataPacketMaxLength = length;
    }
    _invoke1<PointerDataPacket>(window.onPointerDataPacket, window._onPointerDataPacketZone, dataPacket);
    final int dataProcessed = developer.Timeline.now - listPopulated;
    _updatePointerDataPacketProcessedMicros += dataProcessed;
    _unpackDummyPointerData(length);
  }
}

@pragma('vm:entry-point')
// ignore: unused_element
void _dispatchSemanticsAction(int id, int action, ByteData? args) {
  _invoke3<int, SemanticsAction, ByteData?>(
    window.onSemanticsAction,
    window._onSemanticsActionZone,
    id,
    SemanticsAction.values[action]!,
    args,
  );
}

@pragma('vm:entry-point')
// ignore: unused_element
void _beginFrame(int microseconds) {
  _benchNextFrame();
  _invoke1<Duration>(window.onBeginFrame, window._onBeginFrameZone, Duration(microseconds: microseconds));
}

@pragma('vm:entry-point')
// ignore: unused_element
void _reportTimings(List<int> timings) {
  assert(timings.length % FramePhase.values.length == 0);
  final List<FrameTiming> frameTimings = <FrameTiming>[];
  for (int i = 0; i < timings.length; i += FramePhase.values.length) {
    frameTimings.add(FrameTiming(timings.sublist(i, i + FramePhase.values.length)));
  }
  _invoke1(window.onReportTimings, window._onReportTimingsZone, frameTimings);
}

@pragma('vm:entry-point')
// ignore: unused_element
void _drawFrame() {
  _invoke(window.onDrawFrame, window._onDrawFrameZone);
}

// ignore: always_declare_return_types, prefer_generic_function_type_aliases
typedef _UnaryFunction(Null args);
// ignore: always_declare_return_types, prefer_generic_function_type_aliases
typedef _BinaryFunction(Null args, Null message);

@pragma('vm:entry-point')
// ignore: unused_element
void _runMainZoned(Function startMainIsolateFunction,
                   Function userMainFunction,
                   List<String> args) {
  startMainIsolateFunction((){
    runZonedGuarded<void>(() {
      if (userMainFunction is _BinaryFunction) {
        // This seems to be undocumented but supported by the command line VM.
        // Let's do the same in case old entry-points are ported to Flutter.
        (userMainFunction as dynamic)(args, '');
      } else if (userMainFunction is _UnaryFunction) {
        (userMainFunction as dynamic)(args);
      } else {
        userMainFunction();
      }
    }, (Object error, StackTrace stackTrace) {
      _reportUnhandledException(error.toString(), stackTrace.toString());
    });
  }, null);
}

void _reportUnhandledException(String error, String stackTrace) native 'Window_reportUnhandledException';

/// Invokes [callback] inside the given [zone].
void _invoke(void callback()?, Zone zone) {
  if (callback == null)
    return;

  assert(zone != null); // ignore: unnecessary_null_comparison

  if (identical(zone, Zone.current)) {
    callback();
  } else {
    zone.runGuarded(callback);
  }
}

/// Invokes [callback] inside the given [zone] passing it [arg].
void _invoke1<A>(void callback(A a)?, Zone zone, A arg) {
  if (callback == null)
    return;

  assert(zone != null); // ignore: unnecessary_null_comparison

  if (identical(zone, Zone.current)) {
    callback(arg);
  } else {
    zone.runUnaryGuarded<A>(callback, arg);
  }
}

/// Invokes [callback] inside the given [zone] passing it [arg1], [arg2], and [arg3].
void _invoke3<A1, A2, A3>(void callback(A1 a1, A2 a2, A3 a3)?, Zone zone, A1 arg1, A2 arg2, A3 arg3) {
  if (callback == null)
    return;

  assert(zone != null); // ignore: unnecessary_null_comparison

  if (identical(zone, Zone.current)) {
    callback(arg1, arg2, arg3);
  } else {
    zone.runGuarded(() {
      callback(arg1, arg2, arg3);
    });
  }
}

// If this value changes, update the encoding code in the following files:
//
//  * pointer_data.cc
//  * pointers.dart
//  * AndroidTouchProcessor.java
const int _kPointerDataFieldCount = 28;

final PointerData _dummyPointerData = PointerData(
  timeStamp: Duration.zero,
  change: PointerChange.values[0],
  kind: PointerDeviceKind.values[0],
  signalKind: PointerSignalKind.values[0],
  device: 0,
  pointerIdentifier: 0,
  physicalX: 0,
  physicalY: 0,
  physicalDeltaX: 0,
  physicalDeltaY: 0,
  buttons: 0,
  obscured: false,
  synthesized: false,
  pressure: 0,
  pressureMin: 0,
  pressureMax: 0,
  distance: 0,
  distanceMax: 0,
  size: 0,
  radiusMajor: 0,
  radiusMinor: 0,
  radiusMin: 0,
  radiusMax: 0,
  orientation: 0,
  tilt: 0,
  platformData: 0,
  scrollDeltaX: 0,
  scrollDeltaY: 0,
);

void _unpackDummyPointerData(int length) {
  _updateDummyPointerDataPacketSize += length;
  final int start = developer.Timeline.now;
  final List<PointerData> data = <PointerData>[];
  for (int i = 0; i < length; ++i) {
    data.add(_dummyPointerData);
  }
  final int listPopulated = developer.Timeline.now;
  _updateDummyPointerDataPacketCount++;
  final int time = listPopulated - start;
  _updateDummyPointerDataPacketMicros += time;
  if (time > _updateDummyPointerDataPacketMaxMicros) {
    _updateDummyPointerDataPacketMaxMicros = time;
  }
}

PointerDataPacket _unpackPointerDataPacket(ByteData packet) {
  const int kStride = Int64List.bytesPerElement;
  const int kBytesPerPointerData = _kPointerDataFieldCount * kStride;
  final int length = packet.lengthInBytes ~/ kBytesPerPointerData;
  assert(length * kBytesPerPointerData == packet.lengthInBytes);
  //final List<PointerData> data = <PointerData>[];
  final List<PointerData> data = List.filled(length, _dummyPointerData, growable: false);
  _updatePointerDataPacketSize += length;
  for (int i = 0; i < length; ++i) {
    int offset = i * _kPointerDataFieldCount;
    data[i] = (PointerData(
      timeStamp: Duration(microseconds: packet.getInt64(kStride * offset++, _kFakeHostEndian)),
      change: PointerChange.values[packet.getInt64(kStride * offset++, _kFakeHostEndian)],
      kind: PointerDeviceKind.values[packet.getInt64(kStride * offset++, _kFakeHostEndian)],
      signalKind: PointerSignalKind.values[packet.getInt64(kStride * offset++, _kFakeHostEndian)],
      device: packet.getInt64(kStride * offset++, _kFakeHostEndian),
      pointerIdentifier: packet.getInt64(kStride * offset++, _kFakeHostEndian),
      physicalX: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      physicalY: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      physicalDeltaX: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      physicalDeltaY: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      buttons: packet.getInt64(kStride * offset++, _kFakeHostEndian),
      obscured: packet.getInt64(kStride * offset++, _kFakeHostEndian) != 0,
      synthesized: packet.getInt64(kStride * offset++, _kFakeHostEndian) != 0,
      pressure: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      pressureMin: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      pressureMax: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      distance: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      distanceMax: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      size: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      radiusMajor: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      radiusMinor: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      radiusMin: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      radiusMax: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      orientation: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      tilt: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      platformData: packet.getInt64(kStride * offset++, _kFakeHostEndian),
      scrollDeltaX: packet.getFloat64(kStride * offset++, _kFakeHostEndian),
      scrollDeltaY: packet.getFloat64(kStride * offset++, _kFakeHostEndian)
    ));
    assert(offset == (i + 1) * _kPointerDataFieldCount);
  }
  return PointerDataPacket(data: data);
}
