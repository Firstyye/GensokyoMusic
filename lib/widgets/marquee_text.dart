import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration pauseDuration;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scroll();
    });
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      scrollController.jumpTo(0);
    }
  }

  void _scroll() async {
    while (mounted) {
      if (scrollController.hasClients &&
          scrollController.position.maxScrollExtent > 0) {
        await Future.delayed(widget.pauseDuration);
        if (!mounted) break;

        final maxScrollExtent = scrollController.position.maxScrollExtent;
        final durationSeconds =
            (maxScrollExtent / 30).round() + 1; // Adjust speed

        await scrollController.animateTo(
          maxScrollExtent,
          duration: Duration(seconds: durationSeconds),
          curve: Curves.linear,
        );

        await Future.delayed(widget.pauseDuration);
        if (!mounted) break;

        scrollController.jumpTo(0);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style),
    );
  }
}
