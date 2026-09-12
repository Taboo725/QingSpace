import 'package:flutter/gestures.dart';
import 'package:photo_view/photo_view.dart';

const double _kMinScale = 0.1;
const double _kMaxScale = 5.0;
const double _kZoomStep = 1.1;

/// Applies desktop scroll-wheel zoom to a [PhotoViewController].
///
/// Ignores non-scroll pointer signals and a null [controller], so call sites
/// can hand the raw event straight through from a `Listener`.
void applyScrollZoom(
  PointerSignalEvent event,
  PhotoViewController? controller,
) {
  if (event is! PointerScrollEvent || controller == null) return;
  final factor = event.scrollDelta.dy > 0 ? 1 / _kZoomStep : _kZoomStep;
  controller.scale = ((controller.scale ?? 1.0) * factor).clamp(
    _kMinScale,
    _kMaxScale,
  );
}
