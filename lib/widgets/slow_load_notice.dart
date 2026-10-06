import 'dart:async';

import 'package:flutter/material.dart';

/// A loading spinner that, if the data still hasn't arrived after [after],
/// says so and offers a Retry — so a stalled connection never looks like an
/// endless spinner.
class SlowLoadNotice extends StatefulWidget {
  final VoidCallback onRetry;

  /// Optional connection check run once the load looks stuck; its result is
  /// shown under the message.
  final Future<String> Function()? diagnose;
  final Duration after;
  const SlowLoadNotice({
    super.key,
    required this.onRetry,
    this.diagnose,
    this.after = const Duration(seconds: 8),
  });

  @override
  State<SlowLoadNotice> createState() => _SlowLoadNoticeState();
}

class _SlowLoadNoticeState extends State<SlowLoadNotice> {
  Timer? _timer;
  bool _slow = false;
  String? _diagnosis;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.after, () {
      if (!mounted) return;
      setState(() => _slow = true);
      widget.diagnose?.call().then((text) {
        debugPrint('Slow load diagnosis: $text');
        if (mounted) setState(() => _diagnosis = text);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (_slow) ...[
            const SizedBox(height: 16),
            Text('Still loading — check your connection.',
                style: TextStyle(color: scheme.outline)),
            const SizedBox(height: 8),
            if (widget.diagnose != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _diagnosis ?? 'Checking connection…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.outline, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: widget.onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
