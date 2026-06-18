import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flaxtter/utils/interactive_content.dart';

/// Enables mouse-button drag scrolling only when the pointer is over non-interactive
/// blank space (not links, buttons, tweet text, etc.).
class BlankAreaMouseDragScroll extends StatefulWidget {
  const BlankAreaMouseDragScroll({
    super.key,
    required this.child,
    this.scrollController,
  });

  final Widget child;
  final ScrollController? scrollController;

  @override
  State<BlankAreaMouseDragScroll> createState() => _BlankAreaMouseDragScrollState();
}

class _BlankAreaMouseDragScrollState extends State<BlankAreaMouseDragScroll> {
  /// Minimum pointer movement before a press becomes a scroll drag instead of a click.
  static const _dragSlop = 4.0;

  int? _activePointer;
  Offset? _downGlobalPosition;
  Offset? _downLocalPosition;
  ScrollPosition? _pendingScrollPosition;
  Drag? _drag;

  void _hitTestAt(Offset globalPosition, HitTestResult result) {
    final view = View.of(context);
    WidgetsBinding.instance.hitTestInView(result, globalPosition, view.viewId);
  }

  bool _targetIsInteractive(HitTestTarget target) {
    if (target is RenderMetaData && target.metaData == interactiveContentTag) {
      return true;
    }
    if (target is RenderSemanticsAnnotations) {
      final properties = target.properties;
      if (properties.onTap != null || properties.onLongPress != null) {
        return true;
      }
    }
    return false;
  }

  bool _isInteractiveHit(Offset globalPosition) {
    final result = HitTestResult();
    _hitTestAt(globalPosition, result);

    for (final entry in result.path) {
      if (_targetIsInteractive(entry.target)) {
        return true;
      }
    }
    return false;
  }

  ScrollPosition? _scrollPositionAt(Offset globalPosition) {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      return widget.scrollController!.position;
    }

    final result = HitTestResult();
    _hitTestAt(globalPosition, result);

    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderObject) {
        continue;
      }
      RenderObject? renderObject = target;
      while (renderObject != null) {
        if (renderObject is RenderViewport) {
          final offset = renderObject.offset;
          if (offset is ScrollPosition) {
            return offset;
          }
        }
        renderObject = renderObject.parent;
      }
    }
    return null;
  }

  void _cancelDrag() {
    _drag = null;
    _activePointer = null;
    _downGlobalPosition = null;
    _downLocalPosition = null;
    _pendingScrollPosition = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if (_isInteractiveHit(event.position)) {
      return;
    }

    final position = _scrollPositionAt(event.position);
    if (position == null) {
      return;
    }

    _activePointer = event.pointer;
    _downGlobalPosition = event.position;
    _downLocalPosition = event.localPosition;
    _pendingScrollPosition = position;
  }

  void _startDrag(Offset globalPosition) {
    final scrollPosition = _pendingScrollPosition;
    final downGlobal = _downGlobalPosition;
    final downLocal = _downLocalPosition;
    if (scrollPosition == null || downGlobal == null || downLocal == null) {
      return;
    }

    _drag = scrollPosition.drag(
      DragStartDetails(
        globalPosition: downGlobal,
        localPosition: downLocal,
      ),
      _cancelDrag,
    );
    _drag!.update(
      DragUpdateDetails(
        globalPosition: globalPosition,
        localPosition: globalPosition,
        delta: globalPosition - downGlobal,
      ),
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }

    if (_drag == null) {
      final down = _downGlobalPosition;
      if (down == null) {
        return;
      }
      if ((event.position - down).distance < _dragSlop) {
        return;
      }
      if (_isInteractiveHit(down)) {
        _cancelDrag();
        return;
      }
      _startDrag(event.position);
      return;
    }

    _drag!.update(
      DragUpdateDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        delta: event.delta,
      ),
    );
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }

    _drag?.end(DragEndDetails());
    _cancelDrag();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: widget.child,
    );
  }
}
