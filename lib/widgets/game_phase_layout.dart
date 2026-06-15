import 'package:flutter/material.dart';

/// Фиксированная верхняя/нижняя зона + прокручиваемый список (шапка не уезжает).
class GamePhaseLayout extends StatelessWidget {
  const GamePhaseLayout({
    super.key,
    this.pinnedTop,
    this.pinnedBottom,
    required this.scrollChildren,
    this.scrollPadding = const EdgeInsets.fromLTRB(20, 8, 20, 16),
    this.scrollController,
    this.dismissKeyboardOnScroll = false,
  });

  final Widget? pinnedTop;
  final Widget? pinnedBottom;
  final List<Widget> scrollChildren;
  final EdgeInsets scrollPadding;
  final ScrollController? scrollController;
  final bool dismissKeyboardOnScroll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinnedTop != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: pinnedTop!,
          ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: scrollPadding,
            keyboardDismissBehavior: dismissKeyboardOnScroll
                ? ScrollViewKeyboardDismissBehavior.onDrag
                : ScrollViewKeyboardDismissBehavior.manual,
            children: scrollChildren,
          ),
        ),
        if (pinnedBottom != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: pinnedBottom!,
            ),
          ),
      ],
    );
  }
}
