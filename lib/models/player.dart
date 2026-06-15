enum PlayerRole { none, boss, explainer, guesser }

extension PlayerRolePickerLabel on PlayerRole {
  String get pickerLabel => switch (this) {
        PlayerRole.boss => 'Босс',
        PlayerRole.explainer => 'Объясняющий',
        PlayerRole.guesser => 'Угадывающий',
        PlayerRole.none => 'Игрок',
      };
}

class Player {
  const Player({
    required this.id,
    required this.name,
    this.isHost = false,
    this.role = PlayerRole.none,
  });

  final String id;
  final String name;
  final bool isHost;
  final PlayerRole role;

  Player copyWith({
    String? id,
    String? name,
    bool? isHost,
    PlayerRole? role,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
        'role': role.name,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: json['isHost'] as bool? ?? false,
      role: PlayerRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => PlayerRole.none,
      ),
    );
  }
}
