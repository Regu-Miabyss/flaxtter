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
  int? _activePointer;
  Drag? _drag;

  void _hitTestAt(Offset globalPosition, HitTestResult result) {
    final view = View.of(context);
    WidgetsBinding.instance.hitTestInView(result, globalPosition, view.viewId);
  }

  bool _isInteractiveHit(Offset globalPosition) {
    final result = HitTestResult();
    _hitTestAt(globalPosition, result);

    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData == interactiveContentTag) {
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
    _drag = position.drag(
      DragStartDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
      ),
      _cancelDrag,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _drag == null) {
      return;
    }
    if (event.kind != PointerDeviceKind.mouse) {
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
    _drag = null;
    _activePointer = null;
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
