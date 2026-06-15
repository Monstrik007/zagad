import 'dart:convert';

enum MessageType {
  join,
  joinAck,
  playerList,
  gameState,
  setMode,
  startGame,
  setSecretWord,
  pickExplainer,
  setExplanation,
  askQuestion,
  answerQuestion,
  questionReaction,
  sendHint,
  passToBoss,
  submitGuess,
  requestEndGame,
  confirmEndGame,
  rejectEndGame,
  bossEndGame,
  nukeBomb,
  leave,
  kick,
  error,
  discovery,
}

class NetworkMessage {
  const NetworkMessage({
    required this.type,
    this.payload = const {},
    this.senderId = '',
  });

  final MessageType type;
  final Map<String, dynamic> payload;
  final String senderId;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
        'senderId': senderId,
      };

  factory NetworkMessage.fromJson(Map<String, dynamic> json) {
    return NetworkMessage(
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.error,
      ),
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? {},
      ),
      senderId: json['senderId'] as String? ?? '',
    );
  }

  String encode() => jsonEncode(toJson());
}
