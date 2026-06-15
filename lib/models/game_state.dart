import 'game_hint.dart';
import 'game_phase.dart';
import 'player.dart';
import 'question.dart';

class GameState {
  const GameState({
    this.phase = GamePhase.lobby,
    this.mode = GameMode.full,
    this.players = const [],
    this.localPlayerId = '',
    this.roomCode = '',
    this.hostAddress = '',
    this.bossId = '',
    this.explainerId = '',
    this.secretWord = '',
    this.explanation = '',
    this.questions = const [],
    this.hints = const [],
    this.winnerName = '',
    this.winReason = '',
    this.endGameRequesterId = '',
    this.pendingEndGuess = '',
    this.endGameQuestionId = '',
    this.endGameQuestionText = '',
    this.manualLobbyRoles = false,
    this.presetBossId = '',
    this.presetExplainerId = '',
    this.nukeThrowerName = '',
    this.nukeTargetName = '',
    this.nukeTargetId = '',
  });

  final GamePhase phase;
  final GameMode mode;
  final List<Player> players;
  final String localPlayerId;
  final String roomCode;
  final String hostAddress;
  final String bossId;
  final String explainerId;
  final String secretWord;
  final String explanation;
  final List<Question> questions;
  final List<GameHint> hints;
  final String winnerName;
  final String winReason;
  final String endGameRequesterId;
  final String pendingEndGuess;
  final String endGameQuestionId;
  final String endGameQuestionText;
  /// Роли задаёт хост вручную перед стартом (иначе случайно).
  final bool manualLobbyRoles;
  final String presetBossId;
  final String presetExplainerId;
  final String nukeThrowerName;
  final String nukeTargetName;
  final String nukeTargetId;

  bool get isShortMode => mode == GameMode.short;

  int get minPlayers => isShortMode ? 2 : 3;

  Player? get localPlayer {
    try {
      return players.firstWhere((p) => p.id == localPlayerId);
    } catch (_) {
      return null;
    }
  }

  Player? get boss => _playerById(bossId);
  Player? get explainer => _playerById(explainerId);

  Player? _playerById(String id) {
    if (id.isEmpty) return null;
    try {
      return players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// В короткой игре босс одновременно объясняет слово.
  bool get bossIsExplainer =>
      isShortMode && bossId.isNotEmpty && explainerId == bossId;

  bool get isBoss => localPlayerId == bossId;
  bool get isExplainer => localPlayerId == explainerId;

  bool get isGuesser {
    if (localPlayerId.isEmpty) return false;
    if (bossIsExplainer) return localPlayerId != bossId;
    return localPlayerId != bossId && localPlayerId != explainerId;
  }

  List<Player> get guessers {
    if (bossIsExplainer) {
      return players.where((p) => p.id != bossId).toList();
    }
    return players
        .where((p) => p.id != bossId && p.id != explainerId)
        .toList();
  }

  List<Player> get explainerCandidates =>
      players.where((p) => p.id != bossId).toList();

  bool get canStartGame => players.length >= minPlayers;

  bool get lobbyRolesReady {
    if (!manualLobbyRoles) return true;
    return presetBossId.isNotEmpty;
  }

  bool get canStartGameNow => canStartGame && lobbyRolesReady;

  /// Вопросы, переданные объясняющим боссу — ждут ответа (и подсказок) босса.
  bool get hasQuestionsPendingBoss => questions.any(
        (q) =>
            q.answer == QuestionAnswer.passedToBoss && !q.answeredByBoss,
      );

  List<Question> get pendingBossQuestions => questions
      .where(
        (q) =>
            q.answer == QuestionAnswer.passedToBoss && !q.answeredByBoss,
      )
      .toList();

  GameState copyWith({
    GamePhase? phase,
    GameMode? mode,
    List<Player>? players,
    String? localPlayerId,
    String? roomCode,
    String? hostAddress,
    String? bossId,
    String? explainerId,
    String? secretWord,
    String? explanation,
    List<Question>? questions,
    List<GameHint>? hints,
    String? winnerName,
    String? winReason,
    String? endGameRequesterId,
    String? pendingEndGuess,
    String? endGameQuestionId,
    String? endGameQuestionText,
    bool? manualLobbyRoles,
    String? presetBossId,
    String? presetExplainerId,
    String? nukeThrowerName,
    String? nukeTargetName,
    String? nukeTargetId,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      players: players ?? this.players,
      localPlayerId: localPlayerId ?? this.localPlayerId,
      roomCode: roomCode ?? this.roomCode,
      hostAddress: hostAddress ?? this.hostAddress,
      bossId: bossId ?? this.bossId,
      explainerId: explainerId ?? this.explainerId,
      secretWord: secretWord ?? this.secretWord,
      explanation: explanation ?? this.explanation,
      questions: questions ?? this.questions,
      hints: hints ?? this.hints,
      winnerName: winnerName ?? this.winnerName,
      winReason: winReason ?? this.winReason,
      endGameRequesterId:
          endGameRequesterId ?? this.endGameRequesterId,
      pendingEndGuess: pendingEndGuess ?? this.pendingEndGuess,
      endGameQuestionId: endGameQuestionId ?? this.endGameQuestionId,
      endGameQuestionText:
          endGameQuestionText ?? this.endGameQuestionText,
      manualLobbyRoles: manualLobbyRoles ?? this.manualLobbyRoles,
      presetBossId: presetBossId ?? this.presetBossId,
      presetExplainerId: presetExplainerId ?? this.presetExplainerId,
      nukeThrowerName: nukeThrowerName ?? this.nukeThrowerName,
      nukeTargetName: nukeTargetName ?? this.nukeTargetName,
      nukeTargetId: nukeTargetId ?? this.nukeTargetId,
    );
  }

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'mode': mode.name,
        'players': players.map((p) => p.toJson()).toList(),
        'localPlayerId': localPlayerId,
        'roomCode': roomCode,
        'hostAddress': hostAddress,
        'bossId': bossId,
        'explainerId': explainerId,
        'secretWord': secretWord,
        'explanation': explanation,
        'questions': questions.map((q) => q.toJson()).toList(),
        'hints': hints.map((h) => h.toJson()).toList(),
        'winnerName': winnerName,
        'winReason': winReason,
        'endGameRequesterId': endGameRequesterId,
        'pendingEndGuess': pendingEndGuess,
        'endGameQuestionId': endGameQuestionId,
        'endGameQuestionText': endGameQuestionText,
        'manualLobbyRoles': manualLobbyRoles,
        'presetBossId': presetBossId,
        'presetExplainerId': presetExplainerId,
        'nukeThrowerName': nukeThrowerName,
        'nukeTargetName': nukeTargetName,
        'nukeTargetId': nukeTargetId,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      phase: GamePhase.values.firstWhere(
        (p) => p.name == json['phase'],
        orElse: () => GamePhase.lobby,
      ),
      mode: GameMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => GameMode.full,
      ),
      players: (json['players'] as List<dynamic>?)
              ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      localPlayerId: json['localPlayerId'] as String? ?? '',
      roomCode: json['roomCode'] as String? ?? '',
      hostAddress: json['hostAddress'] as String? ?? '',
      bossId: json['bossId'] as String? ?? '',
      explainerId: json['explainerId'] as String? ?? '',
      secretWord: json['secretWord'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) => Question.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hints: (json['hints'] as List<dynamic>?)
              ?.map((e) => GameHint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      winnerName: json['winnerName'] as String? ?? '',
      winReason: json['winReason'] as String? ?? '',
      endGameRequesterId: json['endGameRequesterId'] as String? ?? '',
      pendingEndGuess: json['pendingEndGuess'] as String? ?? '',
      endGameQuestionId: json['endGameQuestionId'] as String? ?? '',
      endGameQuestionText: json['endGameQuestionText'] as String? ?? '',
      manualLobbyRoles: json['manualLobbyRoles'] as bool? ?? false,
      presetBossId: json['presetBossId'] as String? ?? '',
      presetExplainerId: json['presetExplainerId'] as String? ?? '',
      nukeThrowerName: json['nukeThrowerName'] as String? ?? '',
      nukeTargetName: json['nukeTargetName'] as String? ?? '',
      nukeTargetId: json['nukeTargetId'] as String? ?? '',
    );
  }
}
