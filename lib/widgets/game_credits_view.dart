import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/game_state.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import 'secret_word_display.dart';

/// Финальный экран: титры, слово, объяснение, вопросы на фоне.
class GameCreditsView extends StatelessWidget {
  const GameCreditsView({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final boss = state.boss?.name ?? '—';
    final explainer = state.explainer?.name ?? '—';
    final hasWinner = state.winnerName.isNotEmpty;
    final isNukeEnd = state.winReason.startsWith('Уничтожен ядерным');

    return Stack(
      children: [
        if (state.questions.isNotEmpty)
          _ScrollingQuestionsBackdrop(questions: state.questions),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(
                isNukeEnd
                    ? Icons.local_fire_department_rounded
                    : (hasWinner
                        ? Icons.emoji_events_rounded
                        : Icons.flag_rounded),
                size: 56,
                color: isNukeEnd
                    ? AppColors.danger
                    : (hasWinner
                        ? AppColors.accentWarm
                        : AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Игра окончена',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.winReason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              if (hasWinner) ...[
                const SizedBox(height: 28),
                _CreditBlock(
                  label: 'Отгадал',
                  value: state.winnerName,
                  color: AppColors.success,
                ),
              ],
              const SizedBox(height: 20),
              if (state.bossIsExplainer)
                _CreditBlock(
                  label: 'Загадал и объяснил',
                  value: boss,
                  color: AppColors.explainer,
                )
              else ...[
                _CreditBlock(
                  label: 'Загадал',
                  value: boss,
                  color: AppColors.boss,
                ),
                const SizedBox(height: 12),
                _CreditBlock(
                  label: 'Объяснил',
                  value: explainer,
                  color: AppColors.explainer,
                ),
              ],
              if (state.secretWord.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Было загадано',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SecretWordDisplay(
                        word: state.secretWord,
                        bare: true,
                      ),
                    ],
                  ),
                ),
              ],
              if (state.explanation.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.explainer.withValues(alpha: 0.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Объяснение',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.explainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.explanation,
                        style: const TextStyle(fontSize: 16, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditBlock extends StatelessWidget {
  const _CreditBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Вопросы на фоне — бесконечная прокрутка сверху вниз.
class _ScrollingQuestionsBackdrop extends StatefulWidget {
  const _ScrollingQuestionsBackdrop({required this.questions});

  final List<Question> questions;

  @override
  State<_ScrollingQuestionsBackdrop> createState() =>
      _ScrollingQuestionsBackdropState();
}

class _ScrollingQuestionsBackdropState extends State<_ScrollingQuestionsBackdrop>
    with SingleTickerProviderStateMixin {
  final _segmentKey = GlobalKey();
  late final AnimationController _controller;
  double _segmentHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _ScrollingQuestionsBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questions.length != widget.questions.length) {
      _segmentHeight = 0;
      _controller.stop();
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSegment());
  }

  void _measureSegment() {
    if (!mounted) return;
    final box = _segmentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _scheduleMeasure();
      return;
    }
    final h = box.size.height;
    if (h <= 0) return;

    final pxPerSec = 32.0;
    final durationMs = ((h / pxPerSec) * 1000).round().clamp(14000, 120000);

    if ((h - _segmentHeight).abs() < 1 && _controller.isAnimating) return;

    setState(() => _segmentHeight = h);
    _controller
      ..duration = Duration(milliseconds: durationMs)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _questionTile(Question q) {
    final answer = q.isAnswered ? q.answer.label : null;
    final answerColor = switch (q.answer) {
      QuestionAnswer.yes => AppColors.success,
      QuestionAnswer.no => AppColors.danger,
      QuestionAnswer.maybePartial => AppColors.accentWarm,
      QuestionAnswer.dontKnow => AppColors.explainer,
      QuestionAnswer.passedToBoss => AppColors.boss,
      _ => AppColors.textSecondary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.askerName,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            q.text,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppColors.textPrimary.withValues(alpha: 0.88),
            ),
          ),
          if (answer != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: answerColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: answerColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: answerColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _segment({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.questions.map(_questionTile).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Opacity(
            opacity: 0.24,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _segmentHeight <= 0
                  ? _segment(key: _segmentKey)
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _controller.value * _segmentHeight),
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          _segment(key: _segmentKey),
                          _segment(),
                          _segment(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
