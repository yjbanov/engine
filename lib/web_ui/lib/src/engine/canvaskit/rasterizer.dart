// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ui/src/engine.dart' show frameReferences;
import 'package:ui/ui.dart' as ui;

import 'canvas.dart';
import 'layer_tree.dart';
import 'surface.dart';

/// A class that can rasterize [LayerTree]s into a given [Surface].
class Rasterizer {
  final Surface surface;
  final CompositorContext context = CompositorContext();
  final List<ui.VoidCallback> _oneTimePostFrameCallbacks = <ui.VoidCallback>[];
  final List<ui.VoidCallback> _postFrameCallbacks = <ui.VoidCallback>[];

  Rasterizer(this.surface);

  void setSkiaResourceCacheMaxBytes(int bytes) =>
      surface.setSkiaResourceCacheMaxBytes(bytes);

  /// Creates a new frame from this rasterizer's surface, draws the given
  /// [LayerTree] into it, and then submits the frame.
  void draw(LayerTree layerTree) {
    try {
      if (layerTree.frameSize.isEmpty) {
        // Available drawing area is empty. Skip drawing.
        return;
      }

      final SurfaceFrame frame = surface.acquireFrame(layerTree.frameSize);
      surface.viewEmbedder.frameSize = layerTree.frameSize;
      final CkCanvas canvas = frame.skiaCanvas;
      final Frame compositorFrame =
          context.acquireFrame(canvas, surface.viewEmbedder);

      compositorFrame.raster(layerTree, ignoreRasterCache: true);
      surface.addToScene();
      frame.submit();
      surface.viewEmbedder.submitFrame();
    } finally {
      _runPostFrameCallbacks();
    }
  }

  /// Schedules a persistent [callback] to be run at the end of every frame.
  ///
  /// If added outside a frame, will start running in the next frame.
  void addPostFrameCallback(ui.VoidCallback callback) {
    _postFrameCallbacks.add(callback);
  }

  /// Schedules the [callback] to be run once at the end of the current frame.
  ///
  /// If added outside a frame, will run at the end of the next frame.
  void addOneTimePostFrameCallback(ui.VoidCallback callback) {
    _oneTimePostFrameCallbacks.add(callback);
  }

  void _runPostFrameCallbacks() {
    if (_oneTimePostFrameCallbacks.isNotEmpty) {
      final List<ui.VoidCallback> oneTimeCallbacks = _oneTimePostFrameCallbacks.toList();
      _oneTimePostFrameCallbacks.clear();
      for (int i = 0; i < oneTimeCallbacks.length; i++) {
        oneTimeCallbacks[i].call();
      }
    }
    for (int i = 0; i < _postFrameCallbacks.length; i++) {
      final ui.VoidCallback callback = _postFrameCallbacks[i];
      callback();
    }
    for (int i = 0; i < frameReferences.length; i++) {
      frameReferences[i].value = null;
    }
    frameReferences.clear();
  }
}
