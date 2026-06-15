import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../widgets/game_credits_view.dart';
import '../widgets/explainer_end_game_wait_view.dart';
import '../widgets/game_phase_layout.dart';
import '../widgets/gradient_background.dart';
import '../widgets/hints_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/guesser_answer_filter_bar.dart';
import '../widgets/question_card.dart';
import '../widgets/role_badge.dart';
import '../widgets/secret_word_display.dart';
import '../widgets/connection_status_banner.dart';
import '../widgets/easter_egg_app_bar_title.dart';
import '../widgets/nuke_bomb_overlay.dart';
import '../widgets/session_ended_handler.dart';
import '../widgets/spectator_wait_view.dart';

void _dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<void> _confirmBossEndGame(
  BuildContext context,
  GameController ctrl,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.flag_rounded, color: AppColors.danger, size: 32),
      title: const Text('Завершить игру?'),
      content: const Text(
        'Игра закончится для всех участников.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Завершить',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    ctrl.bossEndGame();
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SessionEndedHandler(
      child: Consumer<GameController>(
        builder: (context, ctrl, _) {
          final state = ctrl.state;

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await ctrl.leaveRoom();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            child: GradientBackground(
              child: Scaffold(
                extendBodyBehindAppBar: false,
                appBar: AppBar(
                  title: EasterEggAppBarTitle(
                    state: state,
                    fallbackTitle: state.phase.title,
                  ),
                  actions: [
                    if (state.phase == GamePhase.playing && state.isBoss)
                      IconButton(
                        icon: const Icon(Icons.flag_rounded),
                        color: AppColors.danger,
                        tooltip: 'Конец игры',
                        onPressed: () => _confirmBossEndGame(context, ctrl),
                      ),
                    if (state.phase != GamePhase.lobby)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: RoleBadge(
                          role: state.localPlayer?.role ?? PlayerRole.none,
                          alsoExplainer:
                              state.bossIsExplainer && state.isBoss,
                        ),
                      ),
                  ],
                ),
                body: Column(
                  children: [
                    ConnectionStatusBanner(ctrl: ctrl),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _buildPhase(context, ctrl),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhase(BuildContext context, GameController ctrl) {
    switch (ctrl.state.phase) {
      case GamePhase.lobby:
        return _LobbyWait(key: const ValueKey('lobby'), ctrl: ctrl);
      case GamePhase.bossChooseWord:
        return _BossWordPhase(key: const ValueKey('boss_word'), ctrl: ctrl);
      case GamePhase.bossPickExplainer:
        return _PickExplainerPhase(key: const ValueKey('pick'), ctrl: ctrl);
      case GamePhase.explainerWrites:
        return _ExplainerPhase(key: const ValueKey('explain'), ctrl: ctrl);
      case GamePhase.playing:
        return _PlayingPhase(key: const ValueKey('play'), ctrl: ctrl);
      case GamePhase.endGameConfirm:
        return _EndConfirmPhase(key: const ValueKey('confirm'), ctrl: ctrl);
      case GamePhase.nukeBomb:
        return _NukeBombPhase(key: const ValueKey('nuke'), ctrl: ctrl);
      case GamePhase.finished:
        return _FinishedPhase(key: const ValueKey('done'), ctrl: ctrl);
    }
  }
}

class _LobbyWait extends StatelessWidget {
  const _LobbyWait({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;
    final reconnecting = ctrl.isReconnecting;
    final syncing = !ctrl.isHost &&
        ctrl.hasActiveSession &&
        !reconnecting &&
        state.players.isEmpty;
    final stuck =
        !ctrl.isHost && !reconnecting && !syncing && !ctrl.hasActiveSession;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (syncing) ...[
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              const Text(
                'Подключение к комнате…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ] else if (reconnecting) ...[
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(
                'Попытка переподключения… (${ctrl.reconnectAttempt})',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ждём ответа хоста',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ] else ...[
              Icon(
                stuck ? Icons.cloud_off_rounded : Icons.hourglass_top_rounded,
                size: 48,
                color: stuck ? AppColors.danger : AppColors.primaryLight,
              ),
              const SizedBox(height: 20),
              Text(
                stuck
                    ? 'Соединение с хостом потеряно'
                    : (ctrl.isHost ? 'Ожидаем игроков…' : 'В лобби хоста'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                stuck
                    ? 'Хост вышел или сеть прервалась'
                    : '${state.players.length} / ${state.minPlayers} игроков',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'На главную',
                icon: Icons.home_rounded,
                color: AppColors.surfaceLight,
                onPressed: () async {
                  await ctrl.leaveRoom();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BossWordPhase extends StatefulWidget {
  const _BossWordPhase({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  State<_BossWordPhase> createState() => _BossWordPhaseState();
}

class _BossWordPhaseState extends State<_BossWordPhase> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ctrl.state;
    if (!state.isBoss) {
      return SpectatorWaitView(
        playerName: state.boss?.name ?? 'Босс',
        action: 'загадывает слово',
        accentColor: AppColors.boss,
        icon: Icons.psychology_alt_rounded,
      );
    }

    return _PhaseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhaseHeader(
            icon: Icons.psychology_alt_rounded,
            color: AppColors.boss,
            title: 'Вы — босс',
            subtitle: state.bossIsExplainer
                ? 'Загадайте слово — потом вы же объясните его отгадывающему.'
                : 'Загадайте слово. Его увидят только вы и объясняющий.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Секретное слово',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Загадать',
            icon: Icons.check_rounded,
            onPressed: () {
              if (_controller.text.trim().isEmpty) return;
              widget.ctrl.submitSecretWord(_controller.text);
            },
          ),
        ],
      ),
    );
  }
}

class _PickExplainerPhase extends StatelessWidget {
  const _PickExplainerPhase({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    if (!ctrl.state.isBoss) {
      return SpectatorWaitView(
        playerName: ctrl.state.boss?.name ?? 'Босс',
        action: 'выбирает объясняющего',
        accentColor: AppColors.explainer,
        icon: Icons.record_voice_over_rounded,
      );
    }

    final candidates = ctrl.state.explainerCandidates;

    return _PhaseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PhaseHeader(
            icon: Icons.record_voice_over_rounded,
            color: AppColors.explainer,
            title: 'Кто объяснит?',
            subtitle: 'Выберите игрока, который будет объяснять слово.',
          ),
          const SizedBox(height: 16),
          ...candidates.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(p.name[0].toUpperCase()),
                ),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => ctrl.pickExplainer(p.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainerPhase extends StatefulWidget {
  const _ExplainerPhase({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  State<_ExplainerPhase> createState() => _ExplainerPhaseState();
}

class _ExplainerPhaseState extends State<_ExplainerPhase> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ctrl.state;

    if (state.isExplainer) {
      return _PhaseScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhaseHeader(
              icon: Icons.record_voice_over_rounded,
              color: AppColors.explainer,
              title: 'Вы объясняете',
              subtitle: state.bossIsExplainer
                  ? 'Напишите подсказку отгадывающему — не называйте слово напрямую.'
                  : 'Напишите предложение-подсказку, не называя слово напрямую.',
            ),
            if (state.secretWord.isNotEmpty) ...[
              const SizedBox(height: 16),
              SecretWordDisplay(
                word: state.secretWord,
                compact: false,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ваше объяснение',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Отправить объяснение',
              icon: Icons.send_rounded,
              onPressed: () {
                if (_controller.text.trim().isEmpty) return;
                widget.ctrl.submitExplanation(_controller.text);
              },
            ),
          ],
        ),
      );
    }

    final waiterName = state.bossIsExplainer
        ? (state.boss?.name ?? 'Босс')
        : (state.explainer?.name ?? 'Объясняющий');

    if (state.isGuesser) {
      return SpectatorWaitView(
        playerName: waiterName,
        action: 'пишет объяснение',
        accentColor: AppColors.explainer,
        icon: Icons.record_voice_over_rounded,
      );
    }

    return _PhaseScroll(
      child: Column(
        children: [
          SpectatorWaitView(
            playerName: waiterName,
            action: 'пишет объяснение',
            accentColor: AppColors.explainer,
            icon: Icons.record_voice_over_rounded,
          ),
          if (state.isBoss && state.secretWord.isNotEmpty) ...[
            const SizedBox(height: 24),
            SecretWordDisplay(
              word: state.secretWord,
              compact: false,
              allowPrivacyToggle: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayingPhase extends StatefulWidget {
  const _PlayingPhase({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  State<_PlayingPhase> createState() => _PlayingPhaseState();
}

class _PlayingPhaseState extends State<_PlayingPhase> {
  final _questionController = TextEditingController();
  final _questionFocusNode = FocusNode();
  final _hintController = TextEditingController();
  final _questionsScrollController = ScrollController();
  final _questionKeys = <String, GlobalKey>{};
  String? _highlightedQuestionId;
  GuesserAnswerFilter _guesserFilter = GuesserAnswerFilter.all;

  @override
  void didUpdateWidget(covariant _PlayingPhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleQuestionsChange(
      oldWidget.ctrl.state.questions,
      widget.ctrl.state.questions,
    );
  }

  String _answerToken(Question q) =>
      '${q.answer.name}:${q.answeredByBoss}:${q.endGameRejected}';

  void _handleQuestionsChange(
    List<Question> oldQuestions,
    List<Question> newQuestions,
  ) {
    if (newQuestions.length > oldQuestions.length) {
      final oldIds = oldQuestions.map((q) => q.id).toSet();
      final added = newQuestions.where((q) => !oldIds.contains(q.id));
      if (added.isNotEmpty) {
        _scrollQuestionsToTop();
        return;
      }
    }

    for (final nq in newQuestions) {
      final oq = oldQuestions.where((q) => q.id == nq.id).firstOrNull;
      if (oq == null) continue;
      if (_answerToken(oq) != _answerToken(nq) && nq.isAnswered) {
        _scrollToQuestion(nq.id);
        _flashQuestionHighlight(nq.id);
        break;
      }
    }
  }

  GlobalKey _keyForQuestion(String id) =>
      _questionKeys.putIfAbsent(id, GlobalKey.new);

  void _scrollQuestionsToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_questionsScrollController.hasClients) return;
      _questionsScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      _questionFocusNode.unfocus();
    });
  }

  void _scrollToQuestion(String questionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _questionKeys[questionId]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
      _questionFocusNode.unfocus();
    });
  }

  void _setGuesserFilter(GuesserAnswerFilter filter) {
    _dismissKeyboard();
    setState(() => _guesserFilter = filter);
  }

  void _onGuesserReaction(String questionId, String emoji) {
    _dismissKeyboard();
    widget.ctrl.setQuestionReaction(questionId, emoji);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _questionFocusNode.unfocus();
    });
  }

  void _flashQuestionHighlight(String questionId) {
    setState(() => _highlightedQuestionId = questionId);
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (_highlightedQuestionId == questionId) {
        setState(() => _highlightedQuestionId = null);
      }
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _questionFocusNode.dispose();
    _hintController.dispose();
    _questionsScrollController.dispose();
    super.dispose();
  }

  List<Question> _visibleQuestions(GameState state) {
    if (!state.isGuesser) return state.questions;
    return filterQuestionsForGuesser(state.questions, _guesserFilter);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ctrl.state;
    final visibleQuestions = _visibleQuestions(state);
    final bossCanHint =
        state.isBoss && state.hasQuestionsPendingBoss && !state.bossIsExplainer;
    final staffView = state.isBoss || state.isExplainer;

    return TapRegion(
      onTapOutside: (_) => _questionFocusNode.unfocus(),
      child: GamePhaseLayout(
      scrollController: _questionsScrollController,
      dismissKeyboardOnScroll: true,
      pinnedTop: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (staffView && state.secretWord.isNotEmpty)
            SecretWordDisplay(
              word: state.secretWord,
              allowPrivacyToggle: true,
              compact: true,
            ),
          if (state.explanation.isNotEmpty) ...[
            SizedBox(height: staffView ? 6 : 8),
            if (state.isGuesser)
              _ExplanationCard(text: state.explanation)
            else
              _CompactExplanationBanner(text: state.explanation),
          ],
          if (state.hints.isNotEmpty) ...[
            SizedBox(height: staffView ? 6 : 10),
            HintsPanel(hints: state.hints, compact: staffView),
          ],
          if (state.isExplainer) ...[
            const SizedBox(height: 6),
            _HintComposer(
              controller: _hintController,
              label: 'Подсказка отгадывающим',
              onSend: _sendHint,
            ),
          ],
          if (bossCanHint) ...[
            const SizedBox(height: 6),
            _BossPendingPanel(
              questions: state.pendingBossQuestions,
              hintComposer: _HintComposer(
                controller: _hintController,
                label: 'Подсказка от босса',
                onSend: _sendHint,
              ),
            ),
          ],
        ],
      ),
      pinnedBottom: state.isGuesser
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _questionController,
                  focusNode: _questionFocusNode,
                  autofocus: false,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Вопрос или ваш ответ',
                    hintText: 'Спросите или напишите слово',
                    isDense: true,
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  onSubmitted: (_) => _sendGuesserLine(),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Отправить',
                  icon: Icons.send_rounded,
                  color: AppColors.accent,
                  onPressed: _sendGuesserLine,
                ),
              ],
            )
          : null,
      scrollChildren: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.isGuesser && _guesserFilter != GuesserAnswerFilter.all
                    ? 'Вопросы (${visibleQuestions.length} из ${state.questions.length})'
                    : 'Вопросы (${state.questions.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            if (state.isGuesser)
              GuesserQuestionsFilterButton(
                value: _guesserFilter,
                onChanged: _setGuesserFilter,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.questions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Пока нет вопросов',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else if (visibleQuestions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              emptyFilterMessage(_guesserFilter),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...visibleQuestions.map(
            (q) {
              final canAnswer = (state.isExplainer &&
                      q.answer != QuestionAnswer.passedToBoss &&
                      !q.isAnswered) ||
                  (state.isBoss &&
                      q.answer == QuestionAnswer.passedToBoss &&
                      !q.answeredByBoss);
              return QuestionCard(
                key: _keyForQuestion(q.id),
                question: q,
                canAnswer: canAnswer,
                isBoss: state.isBoss,
                isExplainer: state.isExplainer,
                highlightAnswer: _highlightedQuestionId == q.id,
                allowReaction: state.isGuesser,
                localPlayerId: state.localPlayerId,
                onReaction: state.isGuesser
                    ? (emoji) => _onGuesserReaction(q.id, emoji)
                    : null,
                showEndGame:
                    state.isExplainer && !state.bossIsExplainer,
                showPassToBoss: !state.bossIsExplainer,
                onAnswer: (a) => widget.ctrl.answerQuestion(q.id, a),
                onPassToBoss: () => widget.ctrl.answerQuestion(
                  q.id,
                  QuestionAnswer.passedToBoss,
                ),
                onEndGame: () =>
                    widget.ctrl.requestEndGameForQuestion(q.id),
              );
            },
          ),
      ],
      ),
    );
  }

  void _sendHint() {
    final text = _hintController.text;
    if (text.trim().isEmpty) return;
    widget.ctrl.submitHint(text);
    _hintController.clear();
  }

  void _sendGuesserLine() {
    final text = _questionController.text;
    if (text.trim().isEmpty) return;
    widget.ctrl.submitGuesserLine(text);
    _questionController.clear();
  }

}

class _EndConfirmPhase extends StatelessWidget {
  const _EndConfirmPhase({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;

    if (state.isBoss) {
      return _PhaseScroll(
        child: Column(
          children: [
            const _PhaseHeader(
              icon: Icons.gavel_rounded,
              color: AppColors.boss,
              title: 'Конец игры',
              subtitle: 'Объясняющий запрашивает завершение игры.',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      state.explainer?.name ?? 'Объясняющий',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.explainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '«${state.endGameQuestionText}»',
                      style: const TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SecretWordDisplay(
                      word: state.secretWord,
                      inline: true,
                      allowPrivacyToggle: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Да, завершить игру',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              onPressed: () => ctrl.confirmEndGame(true),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Нет, продолжить',
              icon: Icons.close_rounded,
              color: AppColors.surfaceLight,
              onPressed: () => ctrl.confirmEndGame(false),
            ),
          ],
        ),
      );
    }

    return _PhaseScroll(
      child: ExplainerEndGameWaitView(
        questionText: state.endGameQuestionText,
        bossName: state.boss?.name,
      ),
    );
  }
}

class _NukeBombPhase extends StatelessWidget {
  const _NukeBombPhase({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;
    return NukeBombOverlay(
      throwerName: state.nukeThrowerName,
      targetName: state.nukeTargetName,
    );
  }
}

class _FinishedPhase extends StatelessWidget {
  const _FinishedPhase({super.key, required this.ctrl});
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: GameCreditsView(state: ctrl.state)),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: [
              if (ctrl.isHost)
                PrimaryButton(
                  label: 'Новая игра',
                  icon: Icons.refresh_rounded,
                  onPressed: ctrl.returnToLobby,
                ),
              if (ctrl.isHost) const SizedBox(height: 10),
              PrimaryButton(
                label: 'Выйти',
                icon: Icons.exit_to_app_rounded,
                color: AppColors.surfaceLight,
                onPressed: () async {
                  await ctrl.leaveRoom();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhaseScroll extends StatelessWidget {
  const _PhaseScroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: ValueKey(child.runtimeType),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: child,
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Крупное объяснение для отгадывающих.
class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.explainer.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: AppColors.explainer,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Объяснение',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.explainer,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Компактное объяснение для босса и объясняющего.
class _CompactExplanationBanner extends StatelessWidget {
  const _CompactExplanationBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.explainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.explainer.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: AppColors.explainer.withValues(alpha: 0.9),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textPrimary.withValues(alpha: 0.92),
                ),
                children: [
                  TextSpan(
                    text: 'Объяснение: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.explainer,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Свёрнутый блок переданных боссу вопросов — больше места под ленту.
class _BossPendingPanel extends StatelessWidget {
  const _BossPendingPanel({
    required this.questions,
    required this.hintComposer,
  });

  final List<Question> questions;
  final Widget hintComposer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.boss.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          initiallyExpanded: false,
          iconColor: AppColors.boss,
          collapsedIconColor: AppColors.boss.withValues(alpha: 0.8),
          title: Text(
            'К боссу · ${questions.length}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.boss.withValues(alpha: 0.95),
            ),
          ),
          subtitle: Text(
            'Подсказка до ответа',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
          children: [
            ...questions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '«${q.text}»',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary.withValues(alpha: 0.88),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
            hintComposer,
          ],
        ),
      ),
    );
  }
}

class _HintComposer extends StatelessWidget {
  const _HintComposer({
    required this.controller,
    required this.label,
    required this.onSend,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Без слова',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accentWarm,
            foregroundColor: Colors.white,
            minimumSize: const Size(44, 44),
          ),
        ),
      ],
    );
  }
}

