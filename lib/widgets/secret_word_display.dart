import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Секретное слово; для босса и отгадывающего — тап скрывает/показывает (блюр).
class SecretWordDisplay extends StatefulWidget {
  const SecretWordDisplay({
    super.key,
    required this.word,
    this.compact = true,
    this.allowPrivacyToggle = false,
    this.inline = false,
    this.inlinePrefix = 'Ваше слово: ',
    this.bare = false,
  });

  final String word;
  final bool compact;
  final bool allowPrivacyToggle;
  final bool inline;
  final String inlinePrefix;
  /// Только текст (без карточки), например в блоке «Было загадано».
  final bool bare;

  @override
  State<SecretWordDisplay> createState() => _SecretWordDisplayState();
}

class _SecretWordDisplayState extends State<SecretWordDisplay> {
  bool _hidden = false;

  void _toggle() {
    if (!widget.allowPrivacyToggle) return;
    setState(() => _hidden = !_hidden);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bare) return _buildBare();
    if (widget.inline) return _buildInline();
    return _buildCard();
  }

  Widget _buildBare() {
    return GestureDetector(
      onTap: widget.allowPrivacyToggle ? _toggle : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          _blurredText(
            widget.word,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          if (widget.allowPrivacyToggle) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _hidden ? 'Нажмите, чтобы показать' : 'Нажмите, чтобы скрыть',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInline() {
    final wordStyle = TextStyle(
      color: _hidden
          ? AppColors.textSecondary
          : AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return GestureDetector(
      onTap: widget.allowPrivacyToggle ? _toggle : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                children: [
                  TextSpan(text: widget.inlinePrefix),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: _blurredText(
                      '«${widget.word}»',
                      style: wordStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.allowPrivacyToggle) _privacyIcon(compact: true),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final fontSize = widget.compact ? 22.0 : 26.0;

    return GestureDetector(
      onTap: widget.allowPrivacyToggle ? _toggle : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: widget.compact ? 12 : 0),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 14 : 16,
          vertical: widget.compact ? 10 : 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.35),
              AppColors.accent.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(widget.compact ? 14 : 16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppColors.accent,
              size: widget.compact ? 20 : 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.allowPrivacyToggle
                        ? (_hidden
                            ? 'Слово скрыто'
                            : 'Секретное слово · нажмите, чтобы скрыть')
                        : 'Секретное слово',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _blurredText(
                    widget.word,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.allowPrivacyToggle) _privacyIcon(compact: widget.compact),
          ],
        ),
      ),
    );
  }

  Widget _privacyIcon({required bool compact}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        _hidden ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
        size: compact ? 18 : 22,
        color: AppColors.textSecondary.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _blurredText(String text, {required TextStyle style}) {
    final child = Text(text, style: style);
    if (!_hidden) return child;
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Opacity(
          opacity: 0.85,
          child: child,
        ),
      ),
    );
  }
}
