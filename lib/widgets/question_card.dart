import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';

class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.canAnswer,
    required this.isBoss,
    required this.isExplainer,
    required this.onAnswer,
    required this.onPassToBoss,
    required this.onEndGame,
    this.showEndGame = false,
    this.showPassToBoss = true,
    this.highlightAnswer = false,
    this.allowReaction = false,
    this.localPlayerId = '',
    this.onReaction,
  });

  final Question question;
  final bool canAnswer;
  final bool isBoss;
  final bool isExplainer;
  final void Function(QuestionAnswer answer) onAnswer;
  final VoidCallback onPassToBoss;
  final VoidCallback onEndGame;
  final bool showEndGame;
  final bool showPassToBoss;
  final bool highlightAnswer;
  final bool allowReaction;
  final String localPlayerId;
  final void Function(String emoji)? onReaction;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlightCtrl;
  late final Animation<double> _highlightAnim;

  @override
  void initState() {
    super.initState();
    _highlightCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _highlightAnim = CurvedAnimation(
      parent: _highlightCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightAnswer && !oldWidget.highlightAnswer) {
      _highlightCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _highlightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final answered = question.isAnswered;
    final waitingBoss = question.answer == QuestionAnswer.passedToBoss &&
        !question.answeredByBoss;

    final highlightColor = _answerColor(question.answer);
    final glow = _highlightAnim.value;

    Widget cardBody = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                child: Text(
                  question.askerName.isNotEmpty
                      ? question.askerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.askerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              if (answered && !waitingBoss) _answerChip(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (waitingBoss && !widget.isBoss)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Ожидает ответа босса…',
                style: TextStyle(
                  color: AppColors.boss.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (widget.canAnswer && (!answered || waitingBoss)) ...[
            const SizedBox(height: 12),
            _buildAnswerActions(context, waitingBoss),
          ],
        ],
      ),
    );

    final card = AnimatedBuilder(
      animation: _highlightAnim,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              margin: EdgeInsets.zero,
              elevation: glow > 0.05 ? 2 + glow * 4 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: glow > 0.02
                      ? highlightColor.withValues(alpha: 0.25 + glow * 0.55)
                      : Colors.white.withValues(alpha: 0.06),
                  width: glow > 0.02 ? 1 + glow * 1.5 : 1,
                ),
              ),
              color: glow > 0.02
                  ? Color.lerp(
                      AppColors.surface,
                      highlightColor.withValues(alpha: 0.12),
                      glow * 0.85,
                    )
                  : null,
              child: child,
            ),
            if (question.hasReactions)
              Positioned(
                bottom: -8,
                right: -4,
                child: _ReactionBadges(reactions: question.reactions),
              ),
          ],
        );
      },
      child: cardBody,
    );

    if (!widget.allowReaction || widget.onReaction == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          FocusManager.instance.primaryFocus?.unfocus();
          _showReactionBubble(context);
        },
        child: card,
      ),
    );
  }

  void _showReactionBubble(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || widget.onReaction == null) return;

    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final anchor = Offset(
      origin.dx + size.width * 0.5,
      origin.dy + 8,
    );

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: (anchor.dx - 118).clamp(8.0, MediaQuery.sizeOf(ctx).width - 244),
              top: (anchor.dy - 58).clamp(8.0, MediaQuery.sizeOf(ctx).height - 72),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: QuestionReactions.allowed.map((emoji) {
                      final count =
                          QuestionReactions.count(widget.question.reactions, emoji);
                      final mine = QuestionReactions.hasPlayer(
                        widget.question.reactions,
                        emoji,
                        widget.localPlayerId,
                      );
                      final atMaxDistinct =
                          widget.question.reactions.length >=
                              QuestionReactions.maxDistinct;
                      final disabled = atMaxDistinct && !mine;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: disabled
                              ? null
                              : () {
                                  FocusManager.instance.primaryFocus
                                      ?.unfocus();
                                  Navigator.pop(ctx);
                                  widget.onReaction!(emoji);
                                },
                          borderRadius: BorderRadius.circular(14),
                          child: Opacity(
                            opacity: disabled ? 0.35 : 1,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: mine
                                  ? BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(14),
                                    )
                                  : null,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      right: -6,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.primaryLight
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Widget _buildAnswerActions(BuildContext context, bool waitingBoss) {
    final showBossRow = waitingBoss && widget.isBoss;
    final showExplainerRow = !waitingBoss && widget.isExplainer;

    if (!showBossRow && !showExplainerRow) return const SizedBox.shrink();

    final showPass = showExplainerRow && widget.showPassToBoss;
    final showEnd = showExplainerRow && widget.showEndGame;

    return Row(
      children: [
        Expanded(
          child: _mainAnswerButton(
            label: 'Да',
            color: AppColors.success,
            icon: Icons.check_rounded,
            onTap: () => widget.onAnswer(QuestionAnswer.yes),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _mainAnswerButton(
            label: 'Нет',
            color: AppColors.danger,
            icon: Icons.close_rounded,
            onTap: () => widget.onAnswer(QuestionAnswer.no),
          ),
        ),
        const SizedBox(width: 10),
        _moreAnswersButton(
          showPassToBoss: showPass,
          showEndGame: showEnd,
        ),
      ],
    );
  }

  Widget _mainAnswerButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moreAnswersButton({
    required bool showPassToBoss,
    required bool showEndGame,
  }) {
    return PopupMenuButton<void>(
      tooltip: 'Другие ответы',
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.surface,
      itemBuilder: (context) => [
        _menuItem(
          label: QuestionAnswer.maybePartial.label,
          icon: Icons.help_outline_rounded,
          color: AppColors.accentWarm,
          onTap: () => widget.onAnswer(QuestionAnswer.maybePartial),
        ),
        _menuItem(
          label: QuestionAnswer.invalidQuestion.label,
          icon: Icons.block_rounded,
          color: AppColors.textSecondary,
          onTap: () => widget.onAnswer(QuestionAnswer.invalidQuestion),
        ),
        _menuItem(
          label: QuestionAnswer.dontKnow.label,
          icon: Icons.psychology_outlined,
          color: AppColors.explainer,
          onTap: () => widget.onAnswer(QuestionAnswer.dontKnow),
        ),
        if (showPassToBoss)
          _menuItem(
            label: 'К боссу',
            icon: Icons.workspace_premium_outlined,
            color: AppColors.boss,
            onTap: widget.onPassToBoss,
          ),
        if (showEndGame)
          _menuItem(
            label: 'Конец игры',
            icon: Icons.flag_outlined,
            color: AppColors.accentWarm,
            enabled: !widget.question.endGameRejected,
            onTap: widget.question.endGameRejected ? null : widget.onEndGame,
          ),
      ],
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: AppColors.textSecondary,
          size: 26,
        ),
      ),
    );
  }

  PopupMenuItem<void> _menuItem({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return PopupMenuItem<void>(
      enabled: enabled,
      height: 44,
      onTap: onTap == null
          ? null
          : () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: enabled ? color : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color:
                    enabled ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerChip() {
    final answer = widget.question.answer;
    var label = answer.label;
    if (widget.question.answeredByBoss &&
        (answer == QuestionAnswer.yes || answer == QuestionAnswer.no)) {
      label = 'Босс: $label';
    }
    final color = _answerColor(answer);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _answerColor(QuestionAnswer answer) {
    return switch (answer) {
      QuestionAnswer.yes => AppColors.success,
      QuestionAnswer.no => AppColors.danger,
      QuestionAnswer.maybePartial => AppColors.accentWarm,
      QuestionAnswer.invalidQuestion => AppColors.textSecondary,
      QuestionAnswer.dontKnow => AppColors.explainer,
      QuestionAnswer.passedToBoss => AppColors.boss,
      QuestionAnswer.none => Colors.grey,
    };
  }
}

class _ReactionBadges extends StatelessWidget {
  const _ReactionBadges({required this.reactions});

  final Map<String, List<String>> reactions;

  @override
  Widget build(BuildContext context) {
    final entries = QuestionReactions.sortedCounts(reactions);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _ReactionBadge(
            emoji: entries[i].key,
            count: entries[i].value,
          ),
        ],
      ],
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  const _ReactionBadge({required this.emoji, required this.count});

  final String emoji;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 1 ? '$count$emoji' : emoji;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: count > 1 ? 15 : 22,
          height: 1.1,
          fontWeight: count > 1 ? FontWeight.w800 : FontWeight.normal,
        ),
      ),
    );
  }
}
