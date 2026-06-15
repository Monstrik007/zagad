import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/session_ended_handler.dart';
import 'game_screen.dart';

class HostLobbyScreen extends StatefulWidget {
  const HostLobbyScreen({super.key, required this.playerName});

  final String playerName;

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    final ctrl = context.read<GameController>();
    final ok = await ctrl.createRoom(widget.playerName, GameMode.full);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error ?? 'Ошибка')),
      );
    }
  }

  Future<void> _leave(BuildContext context) async {
    final ctrl = context.read<GameController>();
    await ctrl.leaveRoom();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SessionEndedHandler(
      child: Consumer<GameController>(
        builder: (context, ctrl, _) {
          if (ctrl.state.phase != GamePhase.lobby &&
              ctrl.state.phase != GamePhase.finished) {
            return const GameScreen();
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await _leave(context);
            },
            child: GradientBackground(
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _leave(context),
                  ),
                  title: const Text('Ваша комната'),
                ),
                body: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _LobbyBody(ctrl: ctrl),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LobbyBody extends StatelessWidget {
  const _LobbyBody({required this.ctrl});

  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NetworkCard(hostAddress: state.hostAddress),
          const SizedBox(height: 20),
          _ModeSelector(ctrl: ctrl),
          const SizedBox(height: 16),
          _RoleSetupPanel(ctrl: ctrl),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Игроки',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.players.length}',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _PlayerList(ctrl: ctrl)),
          const SizedBox(height: 12),
          PrimaryButton(
            label: _startLabel(state),
            icon: Icons.play_arrow_rounded,
            onPressed: state.canStartGameNow
                ? () {
                    ctrl.startGame();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  String _startLabel(GameState state) {
    if (!state.canStartGame) {
      final need = state.minPlayers - state.players.length;
      return 'Нужно ещё $need';
    }
    if (state.manualLobbyRoles && !state.lobbyRolesReady) {
      return 'Выберите босса';
    }
    return 'Начать игру';
  }
}

class _NetworkCard extends StatefulWidget {
  const _NetworkCard({required this.hostAddress});

  final String hostAddress;

  @override
  State<_NetworkCard> createState() => _NetworkCardState();
}

class _NetworkCardState extends State<_NetworkCard> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final hostAddress = widget.hostAddress;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.35),
            AppColors.accent.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_tethering_rounded,
                    color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Адрес для подключения',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hostAddress.isEmpty ? '…' : hostAddress,
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Скопировать IP',
                onPressed: hostAddress.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: hostAddress),
                        );
                        if (!mounted) return;
                        setState(() => _copied = true);
                        Future<void>.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _copied = false);
                        });
                      },
                icon: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 20,
                  color: _copied ? AppColors.success : null,
                ),
              ),
            ],
          ),
          if (_copied) ...[
            const SizedBox(height: 6),
            Text(
              'IP скопирован',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success.withValues(alpha: 0.95),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Гости: «Войти в комнату» → ваш IP или комната в списке',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.ctrl});

  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;

    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            title: 'Полная',
            subtitle: '3+ игрока',
            icon: Icons.groups_rounded,
            selected: state.mode == GameMode.full,
            onTap: () => ctrl.setMode(GameMode.full),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeCard(
            title: 'Короткая',
            subtitle: '2 игрока',
            icon: Icons.people_alt_rounded,
            selected: state.mode == GameMode.short,
            onTap: () => ctrl.setMode(GameMode.short),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 108,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.45),
                      AppColors.primary.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.primaryLight.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? AppColors.primaryLight : AppColors.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: selected
                      ? AppColors.textPrimary.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSetupPanel extends StatelessWidget {
  const _RoleSetupPanel({required this.ctrl});

  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;
    final manual = state.manualLobbyRoles;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.accentWarm.withValues(alpha: 0.95)),
              const SizedBox(width: 8),
              Text(
                'Роли при старте',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Случайно'),
                icon: Icon(Icons.shuffle_rounded, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('Вручную'),
                icon: Icon(Icons.tune_rounded, size: 18),
              ),
            ],
            selected: {manual},
            onSelectionChanged: (s) => ctrl.setManualLobbyRoles(s.first),
          ),
          if (manual) ...[
            const SizedBox(height: 8),
            const Text(
              'Выберите босса — объясняющего назначит он в игре',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.ctrl});

  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;

    return ListView.builder(
      itemCount: state.players.length,
      itemBuilder: (_, i) {
        final p = state.players[i];
        return _PlayerTile(player: p, ctrl: ctrl);
      },
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.ctrl});

  final Player player;
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final state = ctrl.state;
    final isBoss = state.presetBossId == player.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.35),
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (player.isHost) ...[
                        const SizedBox(width: 8),
                        _tag('Хост', AppColors.accent),
                      ],
                    ],
                  ),
                  if (state.manualLobbyRoles) ...[
                    const SizedBox(height: 8),
                    _roleChip(
                      'Босс',
                      AppColors.boss,
                      isBoss,
                      () => ctrl.setPresetBoss(isBoss ? null : player.id),
                    ),
                  ],
                ],
              ),
            ),
            if (!player.isHost)
              IconButton(
                tooltip: 'Исключить',
                onPressed: () => ctrl.kickPlayer(player.id),
                icon: Icon(
                  Icons.person_remove_rounded,
                  color: AppColors.danger.withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(
    String label,
    Color color,
    bool selected,
    VoidCallback onTap,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: selected ? color : AppColors.textSecondary,
      ),
      selectedColor: color.withValues(alpha: 0.22),
      backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.5),
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.55) : Colors.white12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
