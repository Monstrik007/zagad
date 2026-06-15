/// Реакции отгадывающих (долгое нажатие на вопрос).
class QuestionReactions {
  QuestionReactions._();

  static const allowed = ['😂', '🥰', '❤️', '💩'];
  static const maxDistinct = 4;

  static bool isAllowed(String emoji) => allowed.contains(emoji);

  /// emoji → id игроков, поставивших эту реакцию.
  static Map<String, List<String>> toggle(
    Map<String, List<String>> current,
    String emoji,
    String playerId,
  ) {
    if (!isAllowed(emoji) || playerId.isEmpty) return current;

    final next = <String, List<String>>{};
    for (final entry in current.entries) {
      next[entry.key] = List<String>.from(entry.value);
    }

    final voters = List<String>.from(next[emoji] ?? []);
    if (voters.contains(playerId)) {
      voters.remove(playerId);
      if (voters.isEmpty) {
        next.remove(emoji);
      } else {
        next[emoji] = voters;
      }
    } else {
      if (next.length >= maxDistinct && !next.containsKey(emoji)) {
        return current;
      }
      voters.add(playerId);
      next[emoji] = voters;
    }
    return next;
  }

  static int count(Map<String, List<String>> reactions, String emoji) =>
      reactions[emoji]?.length ?? 0;

  static bool hasPlayer(
    Map<String, List<String>> reactions,
    String emoji,
    String playerId,
  ) =>
      reactions[emoji]?.contains(playerId) ?? false;

  static List<MapEntry<String, int>> sortedCounts(
    Map<String, List<String>> reactions,
  ) {
    return allowed
        .where((e) => count(reactions, e) > 0)
        .map((e) => MapEntry(e, count(reactions, e)))
        .toList();
  }
}

enum QuestionAnswer {
  none,
  yes,
  no,
  maybePartial,
  invalidQuestion,
  dontKnow,
  passedToBoss,
}

extension QuestionAnswerLabel on QuestionAnswer {
  String get label {
    switch (this) {
      case QuestionAnswer.yes:
        return 'Да';
      case QuestionAnswer.no:
        return 'Нет';
      case QuestionAnswer.maybePartial:
        return 'Возможно частично';
      case QuestionAnswer.invalidQuestion:
        return 'Некорректный вопрос';
      case QuestionAnswer.dontKnow:
        return 'Не знаю';
      case QuestionAnswer.passedToBoss:
        return 'К боссу';
      case QuestionAnswer.none:
        return '';
    }
  }

  /// Короткая подпись для кнопок ответа.
  String get shortLabel {
    switch (this) {
      case QuestionAnswer.yes:
        return 'Да';
      case QuestionAnswer.no:
        return 'Нет';
      case QuestionAnswer.maybePartial:
        return 'Частично';
      case QuestionAnswer.invalidQuestion:
        return 'Некорр.';
      case QuestionAnswer.dontKnow:
        return 'Не знаю';
      case QuestionAnswer.passedToBoss:
        return 'К боссу';
      case QuestionAnswer.none:
        return '';
    }
  }
}

class Question {
  const Question({
    required this.id,
    required this.askerId,
    required this.askerName,
    required this.text,
    this.answer = QuestionAnswer.none,
    this.answeredByBoss = false,
    this.endGameRejected = false,
    this.reactions = const {},
    this.createdAt,
  });

  final String id;
  final String askerId;
  final String askerName;
  final String text;
  final QuestionAnswer answer;
  final bool answeredByBoss;
  /// Босс отклонил «Конец игры» по этому вопросу — кнопка неактивна.
  final bool endGameRejected;
  /// Реакции: emoji → id отгадывающих (по одной реакции типа на игрока).
  final Map<String, List<String>> reactions;
  final DateTime? createdAt;

  bool get hasReactions =>
      reactions.values.any((voters) => voters.isNotEmpty);

  Question copyWith({
    String? id,
    String? askerId,
    String? askerName,
    String? text,
    QuestionAnswer? answer,
    bool? answeredByBoss,
    bool? endGameRejected,
    Map<String, List<String>>? reactions,
    DateTime? createdAt,
  }) {
    return Question(
      id: id ?? this.id,
      askerId: askerId ?? this.askerId,
      askerName: askerName ?? this.askerName,
      text: text ?? this.text,
      answer: answer ?? this.answer,
      answeredByBoss: answeredByBoss ?? this.answeredByBoss,
      endGameRejected: endGameRejected ?? this.endGameRejected,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isAnswered {
    if (answer == QuestionAnswer.none) return false;
    if (answer == QuestionAnswer.passedToBoss && !answeredByBoss) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'askerId': askerId,
        'askerName': askerName,
        'text': text,
        'answer': answer.name,
        'answeredByBoss': answeredByBoss,
        'endGameRejected': endGameRejected,
        'reactions': reactions,
        'createdAt': createdAt?.toIso8601String(),
      };

  static Map<String, List<String>> _parseReactions(Map<String, dynamic> json) {
    final raw = json['reactions'];
    if (raw is Map) {
      final map = <String, List<String>>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        if (!QuestionReactions.isAllowed(key)) continue;
        final value = entry.value;
        if (value is List) {
          final ids = value.map((e) => e.toString()).where((id) => id.isNotEmpty);
          if (ids.isNotEmpty) map[key] = ids.toList();
        } else if (value is int && value > 0) {
          map[key] = List.filled(value, '?');
        } else if (value is num && value.toInt() > 0) {
          map[key] = List.filled(value.toInt(), '?');
        }
      }
      return map;
    }
    final legacy = json['reaction'] as String? ?? '';
    if (legacy.isNotEmpty && QuestionReactions.isAllowed(legacy)) {
      return {legacy: ['?']};
    }
    return {};
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      askerId: json['askerId'] as String,
      askerName: json['askerName'] as String,
      text: json['text'] as String,
      answer: QuestionAnswer.values.firstWhere(
        (a) => a.name == json['answer'],
        orElse: () => QuestionAnswer.none,
      ),
      answeredByBoss: json['answeredByBoss'] as bool? ?? false,
      endGameRejected: json['endGameRejected'] as bool? ?? false,
      reactions: _parseReactions(json),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}
