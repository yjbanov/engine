// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:ui/ui.dart' as ui;

import 'canvas.dart';
import 'canvaskit_api.dart';
import 'picture.dart';

class CkPictureRecorder implements ui.PictureRecorder {
  SkPictureRecorder? _skRecorder;
  CkCanvas? _recordingCanvas;

  CkCanvas beginRecording(ui.Rect bounds) {
    final recorder = _skRecorder = SkPictureRecorder();
    final skRect = toSkRect(bounds);
    final skCanvas = recorder.beginRecording(skRect);
    return _recordingCanvas = CkCanvas(skCanvas);
  }

  CkCanvas? get recordingCanvas => _recordingCanvas;

  @override
  CkPicture endRecording() {
    final recorder = _skRecorder;

    if (recorder == null) {
      throw StateError('PictureRecorder is not recording');
    }

    final skPicture = recorder.finishRecordingAsPicture();
    recorder.delete();
    _skRecorder = null;
    final result = CkPicture(skPicture);
    // We invoke the handler here, not in the picture constructor, because we want
    // [result.approximateBytesUsed] to be available for the handler.
    ui.Picture.onCreate?.call(result);
    return result;
  }

  @override
  bool get isRecording => _skRecorder != null;
}
