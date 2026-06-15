import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_hint.dart';
import '../theme/app_theme.dart';

/// Подсказки: последняя видна сразу; остальные — по нажатию (отгадывающие).
class HintsPanel extends StatefulWidget {
  const HintsPanel({
    super.key,
    required this.hints,
    this.compact = false,
  });

  final List<GameHint> hints;
  final bool compact;

  @override
  State<HintsPanel> createState() => _HintsPanelState();
}

class _HintsPanelState extends State<HintsPanel> {
  bool _expanded = false;

  @override
  void didUpdateWidget(HintsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hints.length <= 1 && _expanded) {
      setState(() => _expanded = false);
    }
  }

  void _toggle() {
    if (widget.hints.length <= 1) return;
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hints.isEmpty) return const SizedBox.shrink();
    if (widget.compact) return _buildCompact();
    return _buildGuesserView(context);
  }

  Widget _buildGuesserView(BuildContext context) {
    final multi = widget.hints.length > 1;
    final latest = widget.hints.first;
    final olderCount = widget.hints.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: multi ? _toggle : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    color: AppColors.accentWarm,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      multi
                          ? (_expanded
                              ? 'Все подсказки'
                              : 'Последняя подсказка')
                          : 'Подсказка',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentWarm,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (multi) ...[
                    Text(
                      _expanded ? 'Свернуть' : '+$olderCount',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentWarm.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 22,
                      color: AppColors.accentWarm,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: _expanded && multi
              ? _buildExpandedHints(context)
              : _hintBubble(latest, emphasized: true),
        ),
      ],
    );
  }

  Widget _buildExpandedHints(BuildContext context) {
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.26)
        .clamp(120.0, 240.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.hints.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _hintBubble(widget.hints[i], emphasized: i == 0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact() {
    final latest = widget.hints.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.tips_and_updates_rounded,
              color: AppColors.accentWarm.withValues(alpha: 0.9),
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              'Подсказки · ${widget.hints.length}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.accentWarm.withValues(alpha: 0.95),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            if (widget.hints.length > 1)
              InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.accentWarm,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _hintBubble(latest, emphasized: true, compact: true),
              if (_expanded && widget.hints.length > 1) ...[
                const SizedBox(height: 4),
                ...widget.hints.sublist(1).map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _hintBubble(h, compact: true),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _hintBubble(
    GameHint hint, {
    bool emphasized = false,
    bool compact = false,
  }) {
    final color = hint.fromBoss ? AppColors.boss : AppColors.explainer;
    final icon = hint.fromBoss
        ? Icons.workspace_premium_rounded
        : Icons.record_voice_over_rounded;
    final label = hint.fromBoss ? 'Босс' : 'Объясняющий';

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: RichText(
          maxLines: emphasized ? 4 : 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textPrimary.withValues(alpha: 0.9),
            ),
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              TextSpan(text: hint.text),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        14,
        emphasized ? 12 : 10,
        14,
        emphasized ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: emphasized ? 0.45 : 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint.text,
            style: TextStyle(
              fontSize: emphasized ? 15 : 14,
              fontWeight: emphasized ? FontWeight.w500 : FontWeight.w400,
              height: 1.4,
              color: AppColors.textPrimary.withValues(
                alpha: emphasized ? 1 : 0.88,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
