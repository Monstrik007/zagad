import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/game_hint.dart';
import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../network/game_client.dart';
import '../network/host_server.dart';
import '../network/local_network.dart';
import '../network/network_constants.dart';
import '../network/protocol.dart';

enum NetworkConnectionStatus { idle, connected, reconnecting }

class _ClientSession {
  const _ClientSession({
    required this.hostIp,
    required this.port,
    required this.playerId,
    required this.playerName,
    required this.roomCode,
  });

  final String hostIp;
  final int port;
  final String playerId;
  final String playerName;
  final String roomCode;
}

class GameController extends ChangeNotifier {
  final _uuid = const Uuid();
  final _random = Random();

  /// Полное состояние комнаты на хосте (со secretWord для всех проверок).
  GameState _room = const GameState();
  /// Состояние гостя с сервера.
  GameState _clientState = const GameState();

  GameState get state {
    if (isHost) {
      return _viewForPlayer(_room, _room.localPlayerId);
    }
    return _clientState;
  }

  void _mutate(GameState Function(GameState current) fn) {
    if (isHost) {
      _room = fn(_room);
    } else {
      _clientState = fn(_clientState);
    }
  }

  String get _localPlayerId =>
      isHost ? _room.localPlayerId : _clientState.localPlayerId;

  HostServer? _hostServer;
  GameClient? _client;
  DiscoveryBroadcaster? _discovery;
  DiscoveryListener? _discoveryListener;

  bool get isHost => _hostServer?.isRunning ?? false;
  String? _error;
  String? get error => _error;

  final Map<String, Map<String, dynamic>> _discoveredRoomMap = {};
  Timer? _discoveryPruneTimer;
  bool _discoveryPruneInFlight = false;

  static const int _discoveryStaleMs = 18000;
  static const int _discoveryDeadMs = 120000;

  List<Map<String, dynamic>> get discoveredRooms {
    final list = _discoveredRoomMap.values.toList();
    list.sort((a, b) {
      final ta = a['_lastSeen'] as int? ?? 0;
      final tb = b['_lastSeen'] as int? ?? 0;
      return tb.compareTo(ta);
    });
    return list;
  }

  bool _isLeaving = false;
  bool _intentionalLeave = false;
  String? _hostedRoomKey;
  String? sessionEndedMessage;

  _ClientSession? _savedClientSession;
  NetworkConnectionStatus _connectionStatus = NetworkConnectionStatus.idle;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _nukeFinishTimer;
  int _clientGeneration = 0;
  int _joinEpoch = 0;
  Completer<void>? _joinSyncCompleter;
  bool _waitingJoinSync = false;

  static const int _maxReconnectAttempts = 40;
  static const Duration _reconnectInterval = Duration(seconds: 2);
  static const Duration _joinSyncTimeout = Duration(seconds: 8);

  NetworkConnectionStatus get connectionStatus => _connectionStatus;
  int get reconnectAttempt => _reconnectAttempt;
  bool get isReconnecting =>
      _connectionStatus == NetworkConnectionStatus.reconnecting;

  bool get hasActiveSession =>
      isHost ||
      _connectionStatus == NetworkConnectionStatus.connected ||
      _connectionStatus == NetworkConnectionStatus.reconnecting;

  String _roomKey(String hostIp, String roomCode) => '$hostIp:$roomCode';

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> createRoom(String hostName, GameMode mode) async {
    await leaveRoom();

    final playerId = _uuid.v4();
    final roomCode = _generateRoomCode();

    _hostServer = HostServer();
    _hostServer!.onMessage = _handleHostMessage;
    _hostServer!.onClientDisconnected = _onClientSocketDisconnected;

    final ip = await _hostServer!.start();
    if (ip == null) {
      _setError('Не удалось запустить сервер. Проверьте Wi‑Fi.');
      return false;
    }

    _discovery = DiscoveryBroadcaster();
    await _discovery!.start(
      roomCode: roomCode,
      hostIp: ip,
      hostName: hostName,
    );

    _hostedRoomKey = _roomKey(ip, roomCode);

    _room = GameState(
      localPlayerId: playerId,
      roomCode: roomCode,
      hostAddress: ip,
      mode: mode,
      players: [Player(id: playerId, name: hostName, isHost: true)],
    );
    _pushState();
    return true;
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Подготовка к поиску комнат: закрыть старую сессию хоста/гостя.
  Future<void> prepareJoinSession() async {
    await leaveRoom();
    await startDiscovery(resetRoomList: true);
  }

  Future<void> startDiscovery({bool resetRoomList = true}) async {
    stopDiscoveryListenerOnly();
    if (resetRoomList) _discoveredRoomMap.clear();
    _discoveryListener = DiscoveryListener();
    _discoveryListener!.onRoomFound = _onRoomDiscovered;
    _discoveryListener!.onRoomClosed = (room) {
      unawaited(_handleDiscoveredRoomClosed(room));
    };
    await _discoveryListener!.start();

    _discoveryPruneTimer?.cancel();
    _discoveryPruneTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pruneStaleDiscoveredRooms());
    });
  }

  void _onRoomDiscovered(Map<String, dynamic> room) {
    final hostIp = room['hostIp'] as String? ?? '';
    final roomCode = room['roomCode'] as String? ?? '';
    final key = _roomKey(hostIp, roomCode);
    if (key.isEmpty || key == ':') return;
    if (!LocalNetwork.isPrivateLan(hostIp)) return;
    if (_hostServer?.isRunning == true) return;
    if (key == _hostedRoomKey) return;

    final entry = Map<String, dynamic>.from(room)
      ..['_lastSeen'] = DateTime.now().millisecondsSinceEpoch;
    _discoveredRoomMap[key] = entry;
    notifyListeners();
  }

  void _announceRoomOnLan() {
    _discovery?.announceNow();
  }

  Future<bool> _probeGameHost(String hostIp, int port) async {
    final targets = await LocalNetwork.connectionTargets(hostIp);
    for (final host in targets) {
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(milliseconds: 2000),
        );
        await socket.close();
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> _handleDiscoveredRoomClosed(Map<String, dynamic> room) async {
    final hostIp = room['hostIp'] as String? ?? '';
    final roomCode = room['roomCode'] as String? ?? '';
    if (hostIp.isEmpty) return;

    final key = _roomKey(hostIp, roomCode);
    final existing = _discoveredRoomMap[key];
    if (existing != null) {
      final seen = existing['_lastSeen'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - seen < 30000) {
        return;
      }
    }

    final port = room['port'] as int? ?? gamePort;
    if (await _probeGameHost(hostIp, port)) {
      if (existing != null) {
        _discoveredRoomMap[key] = Map<String, dynamic>.from(existing)
          ..['_lastSeen'] = DateTime.now().millisecondsSinceEpoch;
        notifyListeners();
      }
      return;
    }

    _removeDiscoveredRoom(hostIp, roomCode);
  }

  Future<void> _pruneStaleDiscoveredRooms() async {
    if (_discoveryPruneInFlight || _discoveredRoomMap.isEmpty) return;
    _discoveryPruneInFlight = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final staleBefore = _discoveredRoomMap.length;
      final toRemove = <String>[];

      for (final entry in _discoveredRoomMap.entries) {
        final seen = entry.value['_lastSeen'] as int? ?? 0;
        final age = now - seen;
        if (age < _discoveryDeadMs) {
          if (age >= _discoveryStaleMs) {
            final hostIp = entry.value['hostIp'] as String? ?? '';
            final port = entry.value['port'] as int? ?? gamePort;
            if (hostIp.isNotEmpty && await _probeGameHost(hostIp, port)) {
              _discoveredRoomMap[entry.key] =
                  Map<String, dynamic>.from(entry.value)
                    ..['_lastSeen'] = now;
            }
          }
          continue;
        }
        toRemove.add(entry.key);
      }

      for (final key in toRemove) {
        _discoveredRoomMap.remove(key);
      }

      if (_discoveredRoomMap.length != staleBefore) {
        notifyListeners();
      }
    } finally {
      _discoveryPruneInFlight = false;
    }
  }

  void _removeDiscoveredRoom(String hostIp, String roomCode) {
    final key = _roomKey(hostIp, roomCode);
    if (_discoveredRoomMap.remove(key) != null) {
      notifyListeners();
    }
  }

  void stopDiscoveryListenerOnly() {
    _discoveryPruneTimer?.cancel();
    _discoveryPruneTimer = null;
    _discoveryListener?.stop();
    _discoveryListener = null;
  }

  void refreshDiscovery() {
    unawaited(startDiscovery(resetRoomList: false));
  }

  void stopDiscovery() {
    stopDiscoveryListenerOnly();
  }

  Future<bool> joinRoom({
    required String hostIp,
    required String playerName,
    String? roomCode,
    int port = gamePort,
  }) async {
    final ticket = ++_joinEpoch;
    await leaveRoom();
    if (ticket != _joinEpoch) return false;

    final playerId = _uuid.v4();
    final gen = ++_clientGeneration;
    final client = GameClient();
    _client = client;
    client.onMessage = _handleClientMessage;
    client.onDisconnected = () {
      if (gen != _clientGeneration) return;
      _onClientDisconnected();
    };

    final ok = await client.connect(hostIp, port: port);
    if (gen != _clientGeneration || ticket != _joinEpoch) return false;
    if (!ok) {
      final detail = client.lastConnectError ?? '';
      final refused = detail.toLowerCase().contains('refused') ||
          detail.contains('отклонено');
      _setError(
        refused
            ? 'Хост недоступен на $hostIp:$port. Убедитесь, что комната открыта, оба в одной Wi‑Fi, порт $port не заблокирован файрволом.'
            : 'Не удалось подключиться к $hostIp:$port${detail.isNotEmpty ? ' ($detail)' : ''}',
      );
      await leaveRoom();
      return false;
    }

    _clientState = _clientState.copyWith(
      localPlayerId: playerId,
      hostAddress: hostIp,
      roomCode: roomCode ?? '',
    );

    _savedClientSession = _ClientSession(
      hostIp: hostIp,
      port: port,
      playerId: playerId,
      playerName: playerName,
      roomCode: roomCode ?? '',
    );
    _intentionalLeave = false;
    _connectionStatus = NetworkConnectionStatus.connected;
    _reconnectAttempt = 0;

    _waitingJoinSync = true;
    _joinSyncCompleter = Completer<void>();

    client.send(NetworkMessage(
      type: MessageType.join,
      senderId: playerId,
      payload: {'name': playerName, 'id': playerId},
    ));

    try {
      await _joinSyncCompleter!.future.timeout(_joinSyncTimeout);
    } catch (_) {
      if (ticket == _joinEpoch) {
        _setError('Хост не ответил. Проверьте Wi‑Fi и попробуйте снова.');
        await leaveRoom();
      }
      return false;
    } finally {
      _waitingJoinSync = false;
      _joinSyncCompleter = null;
    }

    notifyListeners();
    return ticket == _joinEpoch;
  }

  void setMode(GameMode mode) {
    if (!isHost) return;
    _room = _room.copyWith(
      mode: mode,
      presetExplainerId: mode == GameMode.short ? _room.presetBossId : '',
    );
    _pushState();
  }

  void setManualLobbyRoles(bool manual) {
    if (!isHost) return;
    _room = _room.copyWith(
      manualLobbyRoles: manual,
      presetBossId: manual ? _room.presetBossId : '',
      presetExplainerId: '',
    );
    _pushState();
  }

  void setPresetBoss(String? playerId) {
    if (!isHost) return;
    final id = playerId ?? '';
    _room = _room.copyWith(
      manualLobbyRoles: true,
      presetBossId: id,
      presetExplainerId: _room.isShortMode ? id : '',
    );
    _pushState();
  }

  Future<void> kickPlayer(String playerId) async {
    if (!isHost || playerId == _room.localPlayerId) return;
    await _hostServer?.disconnectPlayer(
      playerId,
      farewell: const NetworkMessage(
        type: MessageType.kick,
        payload: {'reason': 'kicked'},
      ),
    );
    _room = _room.copyWith(
      players: _room.players.where((p) => p.id != playerId).toList(),
      presetBossId: _room.presetBossId == playerId ? '' : _room.presetBossId,
      presetExplainerId: _room.presetExplainerId == playerId
          ? ''
          : _room.presetExplainerId,
    );
    _pushState();
  }

  void startGame() {
    if (!isHost || !_room.canStartGameNow) return;

    final Player boss;
    if (_room.manualLobbyRoles && _room.presetBossId.isNotEmpty) {
      boss = _room.players.firstWhere((p) => p.id == _room.presetBossId);
    } else {
      boss = _room.players[_random.nextInt(_room.players.length)];
    }

    final explainerId = _room.isShortMode ? boss.id : '';

    _room = _room.copyWith(
      phase: GamePhase.bossChooseWord,
      bossId: boss.id,
      explainerId: explainerId,
      questions: [],
      hints: [],
      secretWord: '',
      explanation: '',
      winnerName: '',
      winReason: '',
      pendingEndGuess: '',
      endGameRequesterId: '',
      endGameQuestionId: '',
      endGameQuestionText: '',
      nukeThrowerName: '',
      nukeTargetName: '',
      nukeTargetId: '',
    );
    _assignRoles();
    _pushState();
  }

  void _assignRoles() {
    _room = _room.copyWith(
      players: _room.players.map((p) {
        PlayerRole role = PlayerRole.guesser;
        if (p.id == _room.bossId) {
          role = PlayerRole.boss;
        } else if (p.id == _room.explainerId) {
          role = PlayerRole.explainer;
        }
        return p.copyWith(role: role);
      }).toList(),
    );
  }

  void submitSecretWord(String word) {
    if (!state.isBoss) return;
    final trimmed = word.trim();
    final nextPhase = state.isShortMode
        ? GamePhase.explainerWrites
        : GamePhase.bossPickExplainer;
    _applyAndSync(() {
      _mutate((s) => s.copyWith(secretWord: trimmed, phase: nextPhase));
    }, MessageType.setSecretWord, {'word': trimmed});
  }

  void pickExplainer(String playerId) {
    if (!state.isBoss) return;
    _applyAndSync(() {
      _mutate((s) => s.copyWith(
            explainerId: playerId,
            phase: GamePhase.explainerWrites,
          ));
      if (isHost) _assignRoles();
    }, MessageType.pickExplainer, {'explainerId': playerId});
  }

  void submitExplanation(String text) {
    if (!state.isExplainer) return;
    final trimmed = text.trim();
    _applyAndSync(() {
      _mutate((s) => s.copyWith(
            explanation: trimmed,
            phase: GamePhase.playing,
          ));
    }, MessageType.setExplanation, {'text': trimmed});
  }

  /// Вопрос или попытка угадать слово (проверка только на хосте).
  void submitGuesserLine(String text) {
    if (!state.isGuesser || text.trim().isEmpty) return;
    final trimmed = text.trim();
    final q = Question(
      id: _uuid.v4(),
      askerId: _localPlayerId,
      askerName: state.localPlayer?.name ?? 'Игрок',
      text: trimmed,
      createdAt: DateTime.now(),
    );

    if (isHost) {
      if (_tryWinByGuess(trimmed, q.askerName)) {
        _pushState();
        return;
      }
      _room = _room.copyWith(questions: [q, ..._room.questions]);
      _pushState();
      return;
    }

    _client?.send(NetworkMessage(
      type: MessageType.askQuestion,
      senderId: _localPlayerId,
      payload: q.toJson(),
    ));
    notifyListeners();
  }

  void askQuestion(String text) => submitGuesserLine(text);

  bool _canSendHint() {
    if (state.isExplainer) return true;
    if (state.isBoss && state.hasQuestionsPendingBoss) return true;
    return false;
  }

  void submitHint(String text) {
    if (!_canSendHint() || text.trim().isEmpty) return;
    final fromBoss = state.isBoss && !state.isExplainer;
    final hint = GameHint(
      id: _uuid.v4(),
      text: text.trim(),
      createdAt: DateTime.now(),
      fromBoss: fromBoss,
    );

    if (isHost) {
      _room = _room.copyWith(hints: [hint, ..._room.hints]);
      _pushState();
      return;
    }

    _client?.send(NetworkMessage(
      type: MessageType.sendHint,
      senderId: _localPlayerId,
      payload: hint.toJson(),
    ));
    notifyListeners();
  }

  void answerQuestion(String questionId, QuestionAnswer answer) {
    final questions = isHost ? _room.questions : _clientState.questions;
    final idx = questions.indexWhere((q) => q.id == questionId);
    if (idx < 0) return;
    final q = questions[idx];

    if (answer == QuestionAnswer.passedToBoss) {
      if (!state.isExplainer) return;
      _applyAndSync(() {
        _updateQuestion(idx, q.copyWith(answer: QuestionAnswer.passedToBoss));
      }, MessageType.passToBoss, {'questionId': questionId});
      return;
    }

    final passedToBoss = q.answer == QuestionAnswer.passedToBoss;
    if (passedToBoss) {
      if (!state.isBoss) return;
      _applyAndSync(() {
        _updateQuestion(
          idx,
          q.copyWith(answer: answer, answeredByBoss: true),
        );
      }, MessageType.answerQuestion, {
        'questionId': questionId,
        'answer': answer.name,
        'byBoss': true,
      });
    } else {
      if (!state.isExplainer) return;
      _applyAndSync(() {
        _updateQuestion(idx, q.copyWith(answer: answer));
      }, MessageType.answerQuestion, {
        'questionId': questionId,
        'answer': answer.name,
        'byBoss': false,
      });
    }
  }

  void setQuestionReaction(String questionId, String emoji) {
    if (!state.isGuesser || !QuestionReactions.isAllowed(emoji)) return;
    final playerId = _localPlayerId;
    if (playerId.isEmpty) return;

    final questions = isHost ? _room.questions : _clientState.questions;
    final idx = questions.indexWhere((q) => q.id == questionId);
    if (idx < 0) return;
    final q = questions[idx];
    final next = QuestionReactions.toggle(q.reactions, emoji, playerId);
    if (_reactionsEqual(next, q.reactions)) return;

    _applyAndSync(() {
      _updateQuestion(idx, q.copyWith(reactions: next));
    }, MessageType.questionReaction, {
      'questionId': questionId,
      'reaction': emoji,
    });
  }

  bool _reactionsEqual(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      for (final id in entry.value) {
        if (!other.contains(id)) return false;
      }
    }
    return true;
  }

  void _updateQuestion(int idx, Question q) {
    if (isHost) {
      final list = List<Question>.from(_room.questions);
      list[idx] = q;
      _room = _room.copyWith(questions: list);
    } else {
      final list = List<Question>.from(_clientState.questions);
      list[idx] = q;
      _clientState = _clientState.copyWith(questions: list);
    }
  }

  void submitGuess(String guess) => submitGuesserLine(guess);

  bool _tryWinByGuess(String guess, String winnerName) {
    final secret = _room.secretWord;
    if (secret.isEmpty) return false;
    if (!_isCorrectGuess(guess, secret)) return false;
    _finishGame(winnerName: winnerName, reason: 'Угадал слово!');
    return true;
  }

  bool _isCorrectGuess(String guess, String secret) {
    if (_normalize(guess) == _normalize(secret)) return true;
    final g = _normalize(guess);
    final words = _normalize(secret).split(' ');
    if (words.length == 1 && g == words.first) return true;
    return false;
  }

  void requestEndGameForQuestion(String questionId) {
    if (!state.isExplainer || state.bossIsExplainer) return;
    final q = state.questions.cast<Question?>().firstWhere(
          (x) => x?.id == questionId,
          orElse: () => null,
        );
    if (q == null || q.endGameRejected) return;

    _applyAndSync(() {
      _mutate((s) => s.copyWith(
            phase: GamePhase.endGameConfirm,
            endGameQuestionId: questionId,
            endGameQuestionText: q.text,
            endGameRequesterId: _localPlayerId,
            pendingEndGuess: '',
          ));
    }, MessageType.requestEndGame, {
      'questionId': questionId,
      'questionText': q.text,
    });
  }

  String _winnerNameForEndGameQuestion(GameState s) {
    final qid = s.endGameQuestionId;
    if (qid.isEmpty) return '';
    for (final q in s.questions) {
      if (q.id != qid) continue;
      final name = q.askerName.trim();
      if (name.isNotEmpty) return name;
      final player = s.players.where((p) => p.id == q.askerId).firstOrNull;
      return player?.name ?? '';
    }
    return '';
  }

  void confirmEndGame(bool confirmed) {
    if (!state.isBoss) return;
    if (confirmed) {
      final winner = _winnerNameForEndGameQuestion(state);
      _applyAndSync(() {
        _finishGame(
          winnerName: winner,
          reason: winner.isNotEmpty
              ? 'Босс подтвердил: отгадал $winner'
              : 'Босс подтвердил конец игры',
        );
      }, MessageType.confirmEndGame, {});
      return;
    }
    final qid = state.endGameQuestionId;
    _applyAndSync(() {
      _mutate((s) {
        final questions = s.questions.map((q) {
          if (q.id == qid) return q.copyWith(endGameRejected: true);
          return q;
        }).toList();
        return s.copyWith(
          phase: GamePhase.playing,
          questions: questions,
          endGameQuestionId: '',
          endGameQuestionText: '',
          endGameRequesterId: '',
          pendingEndGuess: '',
        );
      });
    }, MessageType.rejectEndGame, {'questionId': qid});
  }

  void bossEndGame() {
    if (!state.isBoss) return;
    _applyAndSync(() {
      _finishGame(winnerName: '', reason: 'Босс завершил игру');
    }, MessageType.bossEndGame, {});
  }

  void dropNukeBomb(String targetPlayerId) {
    if (targetPlayerId.isEmpty) return;
    final phase = state.phase;
    if (phase == GamePhase.lobby ||
        phase == GamePhase.finished ||
        phase == GamePhase.nukeBomb) {
      return;
    }
    if (isHost) {
      _startNukeSequence(
        targetPlayerId: targetPlayerId,
        throwerId: _localPlayerId,
      );
    } else {
      _client?.send(NetworkMessage(
        type: MessageType.nukeBomb,
        senderId: _localPlayerId,
        payload: {'targetId': targetPlayerId},
      ));
    }
  }

  void _startNukeSequence({
    required String targetPlayerId,
    required String throwerId,
  }) {
    if (_room.phase == GamePhase.nukeBomb) return;

    Player? thrower;
    Player? target;
    for (final p in _room.players) {
      if (p.id == throwerId) thrower = p;
      if (p.id == targetPlayerId) target = p;
    }
    if (target == null) return;

    _nukeFinishTimer?.cancel();
    _room = _room.copyWith(
      phase: GamePhase.nukeBomb,
      nukeThrowerName: thrower?.name ?? 'Кто-то',
      nukeTargetName: target.name,
      nukeTargetId: target.id,
    );
    _pushState();

    _nukeFinishTimer = Timer(const Duration(seconds: 5), () {
      _nukeFinishTimer = null;
      if (!isHost || _room.phase != GamePhase.nukeBomb) return;
      final victim = _room.nukeTargetName;
      _finishGame(
        winnerName: '',
        reason: 'Уничтожен ядерным зарядом: $victim',
      );
      _room = _room.copyWith(
        nukeThrowerName: '',
        nukeTargetName: '',
        nukeTargetId: '',
      );
      _pushState();
    });
  }

  void _cancelNukeTimer() {
    _nukeFinishTimer?.cancel();
    _nukeFinishTimer = null;
  }

  void returnToLobby() {
    if (!isHost) return;
    _cancelNukeTimer();
    _room = _room.copyWith(
      phase: GamePhase.lobby,
      bossId: '',
      explainerId: '',
      secretWord: '',
      explanation: '',
      questions: [],
      hints: [],
      winnerName: '',
      winReason: '',
      pendingEndGuess: '',
      endGameRequesterId: '',
      endGameQuestionId: '',
      endGameQuestionText: '',
      nukeThrowerName: '',
      nukeTargetName: '',
      nukeTargetId: '',
      manualLobbyRoles: false,
      presetBossId: '',
      presetExplainerId: '',
      players: _room.players
          .map((p) => p.copyWith(role: PlayerRole.none))
          .toList(),
    );
    _pushState();
  }

  void _finishGame({required String winnerName, required String reason}) {
    if (isHost) {
      _room = _room.copyWith(
        phase: GamePhase.finished,
        winnerName: winnerName,
        winReason: reason,
      );
    } else {
      _clientState = _clientState.copyWith(
        phase: GamePhase.finished,
        winnerName: winnerName,
        winReason: reason,
      );
    }
  }

  String _normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-zа-яё0-9\s]', unicode: true), '');
  }

  void _applyAndSync(
    VoidCallback update,
    MessageType type,
    Map<String, dynamic> payload,
  ) {
    update();
    if (isHost) {
      _pushState();
    } else {
      _client?.send(NetworkMessage(
        type: type,
        senderId: _localPlayerId,
        payload: payload,
      ));
      notifyListeners();
    }
  }

  void _registerPlayerJoin({
    required String clientId,
    required String playerId,
    required String playerName,
  }) {
    if (playerId.isEmpty) return;

    var players = _room.players
        .where((p) => p.name != playerName || p.id == playerId)
        .toList();

    final idx = players.indexWhere((p) => p.id == playerId);
    if (idx >= 0) {
      players[idx] = players[idx].copyWith(name: playerName);
    } else {
      players = [...players, Player(id: playerId, name: playerName)];
    }

    _room = _room.copyWith(players: players);
    _hostServer!.linkPlayer(playerId, clientId);
    _sendJoinStateToPlayer(playerId, reconnect: idx >= 0);
    _pushState();
    _announceRoomOnLan();
  }

  void _sendJoinStateToPlayer(String playerId, {required bool reconnect}) {
    _hostServer!.sendToPlayer(
      playerId,
      NetworkMessage(
        type: MessageType.joinAck,
        payload: {'ok': true, if (reconnect) 'reconnect': true},
      ),
    );
    _hostServer!.sendToPlayer(
      playerId,
      NetworkMessage(
        type: MessageType.gameState,
        payload: _viewForPlayer(_room, playerId).toJson(),
      ),
    );
  }

  void _removePlayerById(String playerId) {
    if (playerId.isEmpty) return;
    if (!_room.players.any((p) => p.id == playerId)) return;

    var presetBossId = _room.presetBossId;
    var presetExplainerId = _room.presetExplainerId;
    if (presetBossId == playerId) presetBossId = '';
    if (presetExplainerId == playerId) presetExplainerId = '';

    _room = _room.copyWith(
      players: _room.players.where((p) => p.id != playerId).toList(),
      presetBossId: presetBossId,
      presetExplainerId: presetExplainerId,
    );
    _pushState();
  }

  void _completeJoinSyncIfReady() {
    if (!_waitingJoinSync || _joinSyncCompleter == null) return;
    final me = _clientState.localPlayerId;
    if (me.isEmpty) return;
    if (!_clientState.players.any((p) => p.id == me)) return;
    if (!_joinSyncCompleter!.isCompleted) {
      _joinSyncCompleter!.complete();
    }
  }

  void _handleHostMessage(NetworkMessage msg, String clientId) {
    switch (msg.type) {
      case MessageType.join:
        _registerPlayerJoin(
          clientId: clientId,
          playerId: msg.payload['id'] as String? ?? msg.senderId,
          playerName: msg.payload['name'] as String? ?? 'Игрок',
        );
        break;
      case MessageType.leave:
        _removePlayerById(msg.senderId);
        break;
      default:
        _processAction(msg);
        _pushState();
        break;
    }
  }

  void _applyClientGameState(GameState incoming) {
    final localId = incoming.localPlayerId.isNotEmpty
        ? incoming.localPlayerId
        : (_clientState.localPlayerId.isNotEmpty
            ? _clientState.localPlayerId
            : (_savedClientSession?.playerId ?? ''));

    final merged = incoming.copyWith(
      localPlayerId: localId,
      hostAddress: incoming.hostAddress.isNotEmpty
          ? incoming.hostAddress
          : _clientState.hostAddress,
      roomCode: incoming.roomCode.isNotEmpty
          ? incoming.roomCode
          : _clientState.roomCode,
    );
    _clientState = _viewForLocal(merged);
  }

  void _handleClientMessage(NetworkMessage msg) {
    switch (msg.type) {
      case MessageType.joinAck:
        _onClientReconnected();
        _completeJoinSyncIfReady();
        notifyListeners();
        break;
      case MessageType.gameState:
        _applyClientGameState(GameState.fromJson(msg.payload));
        _onClientReconnected();
        _completeJoinSyncIfReady();
        notifyListeners();
        break;
      case MessageType.leave:
        _endSession('Хост покинул игру');
        break;
      case MessageType.kick:
        _endSession('Вас исключили из комнаты');
        break;
      default:
        break;
    }
  }

  void _processAction(NetworkMessage msg) {
    switch (msg.type) {
      case MessageType.setSecretWord:
        final word = msg.payload['word'] as String? ?? '';
        _room = _room.copyWith(
          secretWord: word,
          phase: _room.isShortMode
              ? GamePhase.explainerWrites
              : GamePhase.bossPickExplainer,
        );
        break;
      case MessageType.pickExplainer:
        _room = _room.copyWith(
          explainerId: msg.payload['explainerId'] as String? ?? '',
          phase: GamePhase.explainerWrites,
        );
        _assignRoles();
        break;
      case MessageType.setExplanation:
        _room = _room.copyWith(
          explanation: msg.payload['text'] as String? ?? '',
          phase: GamePhase.playing,
        );
        break;
      case MessageType.askQuestion:
        final q = Question.fromJson(msg.payload);
        if (_tryWinByGuess(q.text, q.askerName)) break;
        if (!_room.questions.any((x) => x.id == q.id)) {
          _room = _room.copyWith(questions: [q, ..._room.questions]);
        }
        break;
      case MessageType.sendHint:
        final hint = GameHint.fromJson(msg.payload);
        if (!_room.hints.any((h) => h.id == hint.id)) {
          _room = _room.copyWith(hints: [hint, ..._room.hints]);
        }
        break;
      case MessageType.answerQuestion:
        _patchAnswer(
          msg.payload['questionId'] as String? ?? '',
          msg.payload['answer'] as String? ?? '',
          byBoss: msg.payload['byBoss'] as bool? ?? false,
        );
        break;
      case MessageType.questionReaction:
        _patchQuestionReaction(
          msg.payload['questionId'] as String? ?? '',
          msg.payload['reaction'] as String? ?? '',
          msg.senderId,
        );
        break;
      case MessageType.passToBoss:
        _patchAnswer(
          msg.payload['questionId'] as String? ?? '',
          QuestionAnswer.passedToBoss.name,
        );
        break;
      case MessageType.submitGuess:
        _tryWinByGuess(
          msg.payload['guess'] as String? ?? '',
          msg.payload['playerName'] as String? ?? 'Игрок',
        );
        break;
      case MessageType.requestEndGame:
        _room = _room.copyWith(
          phase: GamePhase.endGameConfirm,
          endGameQuestionId: msg.payload['questionId'] as String? ?? '',
          endGameQuestionText: msg.payload['questionText'] as String? ?? '',
          endGameRequesterId: msg.senderId,
          pendingEndGuess: '',
        );
        break;
      case MessageType.confirmEndGame:
        final winner = _winnerNameForEndGameQuestion(_room);
        _finishGame(
          winnerName: winner,
          reason: winner.isNotEmpty
              ? 'Босс подтвердил: отгадал $winner'
              : 'Босс подтвердил конец игры',
        );
        break;
      case MessageType.rejectEndGame:
        final qid = msg.payload['questionId'] as String? ??
            _room.endGameQuestionId;
        final questions = _room.questions.map((q) {
          if (q.id == qid) return q.copyWith(endGameRejected: true);
          return q;
        }).toList();
        _room = _room.copyWith(
          phase: GamePhase.playing,
          questions: questions,
          endGameQuestionId: '',
          endGameQuestionText: '',
          endGameRequesterId: '',
          pendingEndGuess: '',
        );
        break;
      case MessageType.bossEndGame:
        _finishGame(winnerName: '', reason: 'Босс завершил игру');
        break;
      case MessageType.nukeBomb:
        _startNukeSequence(
          targetPlayerId: msg.payload['targetId'] as String? ?? '',
          throwerId: msg.senderId,
        );
        break;
      default:
        break;
    }
  }

  void _patchQuestionReaction(
    String questionId,
    String emoji,
    String playerId,
  ) {
    if (!QuestionReactions.isAllowed(emoji) || playerId.isEmpty) return;
    final idx = _room.questions.indexWhere((q) => q.id == questionId);
    if (idx < 0) return;
    final q = _room.questions[idx];
    final next = QuestionReactions.toggle(q.reactions, emoji, playerId);
    if (_reactionsEqual(next, q.reactions)) return;
    _updateQuestion(idx, q.copyWith(reactions: next));
  }

  void _patchAnswer(String questionId, String answerName, {bool byBoss = false}) {
    final idx = _room.questions.indexWhere((q) => q.id == questionId);
    if (idx < 0) return;
    final q = _room.questions[idx];
    final answer = QuestionAnswer.values.firstWhere(
      (a) => a.name == answerName,
      orElse: () => QuestionAnswer.none,
    );
    if (answer == QuestionAnswer.passedToBoss) {
      _updateQuestion(idx, q.copyWith(answer: QuestionAnswer.passedToBoss));
    } else if (byBoss) {
      _updateQuestion(
        idx,
        q.copyWith(answer: answer, answeredByBoss: true),
      );
    } else {
      _updateQuestion(idx, q.copyWith(answer: answer));
    }
  }

  GameState _viewForPlayer(GameState full, String playerId) {
    final showSecret = full.phase == GamePhase.finished ||
        playerId == full.bossId ||
        playerId == full.explainerId;
    return full.copyWith(
      localPlayerId: playerId,
      secretWord: showSecret ? full.secretWord : '',
    );
  }

  GameState _viewForLocal(GameState incoming) {
    final showSecret = incoming.phase == GamePhase.finished ||
        incoming.localPlayerId == incoming.bossId ||
        incoming.localPlayerId == incoming.explainerId;
    return incoming.copyWith(
      secretWord: showSecret ? incoming.secretWord : '',
    );
  }

  void _pushState() {
    if (!isHost) {
      notifyListeners();
      return;
    }
    final server = _hostServer;
    if (server == null) return;

    for (final player in _room.players) {
      if (player.isHost) continue;
      final view = _viewForPlayer(_room, player.id);
      server.sendToPlayer(
        player.id,
        NetworkMessage(
          type: MessageType.gameState,
          payload: view.toJson(),
        ),
      );
    }
    notifyListeners();
  }

  void _onClientSocketDisconnected(String clientId) {
    if (!isHost) return;
    final playerIds = _playerIdToClientEntries(clientId);
    if (playerIds.isEmpty) return;
    var players = List<Player>.from(_room.players);
    var presetBossId = _room.presetBossId;
    var presetExplainerId = _room.presetExplainerId;
    for (final id in playerIds) {
      players.removeWhere((p) => p.id == id);
      if (presetBossId == id) presetBossId = '';
      if (presetExplainerId == id) presetExplainerId = '';
    }
    _room = _room.copyWith(
      players: players,
      presetBossId: presetBossId,
      presetExplainerId: presetExplainerId,
    );
    _pushState();
  }

  List<String> _playerIdToClientEntries(String clientId) {
    return _hostServer?.playerIdsForClient(clientId) ?? [];
  }

  void _onClientDisconnected() {
    if (_isLeaving || _intentionalLeave) return;
    if (_savedClientSession == null) {
      _endSession('Соединение с хостом потеряно');
      return;
    }
    unawaited(_beginReconnect());
  }

  Future<void> _beginReconnect() async {
    if (_connectionStatus == NetworkConnectionStatus.reconnecting) return;
    _connectionStatus = NetworkConnectionStatus.reconnecting;
    _reconnectAttempt = 0;
    final old = _client;
    _client = null;
    if (old != null) {
      old.onDisconnected = null;
      await old.disconnect();
    }
    notifyListeners();
    _scheduleReconnectTick();
  }

  void _scheduleReconnectTick() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectInterval, _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_isLeaving ||
        _intentionalLeave ||
        _savedClientSession == null ||
        _connectionStatus != NetworkConnectionStatus.reconnecting) {
      return;
    }

    _reconnectAttempt++;
    notifyListeners();

    final session = _savedClientSession!;
    final gen = ++_clientGeneration;
    final client = GameClient();
    _client = client;
    client.onMessage = _handleClientMessage;
    client.onDisconnected = () {
      if (gen != _clientGeneration) return;
      _onClientDisconnected();
    };

    final ok = await client.connect(session.hostIp, port: session.port);
    if (gen != _clientGeneration) return;
    if (!ok) {
      if (_reconnectAttempt >= _maxReconnectAttempts) {
        _endSession('Не удалось восстановить связь с хостом');
      } else {
        _scheduleReconnectTick();
      }
      return;
    }

    _clientState = _clientState.copyWith(
      localPlayerId: session.playerId,
      hostAddress: session.hostIp,
      roomCode: session.roomCode,
    );

    client.send(NetworkMessage(
      type: MessageType.join,
      senderId: session.playerId,
      payload: {
        'name': session.playerName,
        'id': session.playerId,
        'reconnect': true,
      },
    ));
  }

  void _onClientReconnected() {
    if (_connectionStatus != NetworkConnectionStatus.reconnecting) return;
    _connectionStatus = NetworkConnectionStatus.connected;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    notifyListeners();
  }

  void _endSession(String message) {
    if (_intentionalLeave || _isLeaving) return;
    _joinEpoch++;
    _waitingJoinSync = false;
    if (_joinSyncCompleter != null && !_joinSyncCompleter!.isCompleted) {
      _joinSyncCompleter!.completeError('session ended');
    }
    _joinSyncCompleter = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionStatus = NetworkConnectionStatus.idle;
    sessionEndedMessage = message;
    leaveRoom();
  }

  void clearSessionEnded() {
    sessionEndedMessage = null;
    notifyListeners();
  }

  Future<void> leaveRoom() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _intentionalLeave = true;
    _waitingJoinSync = false;
    if (_joinSyncCompleter != null && !_joinSyncCompleter!.isCompleted) {
      _joinSyncCompleter!.completeError('left');
    }
    _joinSyncCompleter = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelNukeTimer();
    _savedClientSession = null;
    _connectionStatus = NetworkConnectionStatus.idle;
    _reconnectAttempt = 0;
    _clientGeneration++;

    final roomCode = isHost ? _room.roomCode : _clientState.roomCode;
    final hostIp = isHost ? _room.hostAddress : _clientState.hostAddress;
    final leavingPlayerId = _localPlayerId;

    final client = _client;
    if (client != null &&
        client.isConnected &&
        leavingPlayerId.isNotEmpty &&
        !isHost) {
      try {
        client.send(NetworkMessage(
          type: MessageType.leave,
          senderId: leavingPlayerId,
          payload: const {'reason': 'client_left'},
        ));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      } catch (_) {}
    }

    stopDiscoveryListenerOnly();

    final broadcaster = _discovery;
    _discovery = null;
    if (broadcaster != null) {
      await broadcaster.stop(roomCode: roomCode, hostIp: hostIp);
    }

    final server = _hostServer;
    _hostServer = null;
    if (server != null) {
      await server.stop(
        farewell: const NetworkMessage(
          type: MessageType.leave,
          payload: {'reason': 'host_left'},
        ),
      );
    }

    if (client != null) {
      client.onDisconnected = null;
      await client.disconnect();
    }
    _client = null;

    _hostedRoomKey = null;
    _discoveredRoomMap.clear();
    _room = const GameState();
    _clientState = const GameState();
    _error = null;
    _isLeaving = false;
    _intentionalLeave = false;
    notifyListeners();
  }
}
