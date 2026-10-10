import 'dart:async';

import 'package:flutter/material.dart';

/// A tap that cannot be repeated while its action is still running.
/// If the action returns a Future, further taps are ignored until it completes and [builder] is told it is busy
/// (so the button can show a spinner). That stops one request from being sent two or three times by a fast tap.
class AsyncTap extends StatefulWidget {
  final FutureOr<void> Function()? onTap;
  final bool enabled;
  final Widget Function(BuildContext context, bool busy) builder;
  const AsyncTap({super.key, required this.onTap, required this.builder, this.enabled = true});

  @override
  State<AsyncTap> createState() => _AsyncTapState();
}

class _AsyncTapState extends State<AsyncTap> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy || !widget.enabled || widget.onTap == null) return;
    final result = widget.onTap!();
    if (result is Future) {
      setState(() => _busy = true);
      try {
        await result;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled && widget.onTap != null ? _tap : null,
        child: widget.builder(context, _busy),
      );
}
