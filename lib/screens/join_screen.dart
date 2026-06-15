import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../models/game_phase.dart';
import '../network/network_constants.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/session_ended_handler.dart';
import 'game_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.playerName});

  final String playerName;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _ipController = TextEditingController();
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameController>().prepareJoinSession();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _exit(BuildContext context) async {
    final ctrl = context.read<GameController>();
    await ctrl.leaveRoom();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SessionEndedHandler(
      child: Consumer<GameController>(
        builder: (context, ctrl, _) {
          if (ctrl.state.phase != GamePhase.lobby &&
              ctrl.state.players.isNotEmpty &&
              ctrl.hasActiveSession) {
            return const GameScreen();
          }

          return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _exit(context);
          },
          child: GradientBackground(
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => _exit(context),
                ),
                title: const Text('Поиск комнат'),
                actions: [
                  IconButton(
                    tooltip: 'Обновить поиск',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => ctrl.refreshDiscovery(),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Найденные комнаты',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Все в одной Wi‑Fi сети',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ctrl.discoveredRooms.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Ищем комнаты…',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Не появилась? Нажмите обновить или введите IP ниже',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: ctrl.discoveredRooms.length,
                              itemBuilder: (_, i) {
                                final room = ctrl.discoveredRooms[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Icon(Icons.meeting_room_rounded),
                                    ),
                                    title: Text(
                                      room['hostName'] as String? ?? 'Комната',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      room['hostIp'] as String? ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    trailing: _joining
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                    onTap: _joining
                                        ? null
                                        : () => _join(
                                              ctrl,
                                              hostIp:
                                                  room['hostIp'] as String,
                                              roomCode: room['roomCode']
                                                  as String?,
                                              port: room['port'] as int? ??
                                                  gamePort,
                                            ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        16 + bottomInset,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Подключение по IP',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _ipController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'IP хоста',
                              hintText: '192.168.1.5',
                              prefixIcon: Icon(Icons.lan_rounded),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Подключиться',
                            icon: Icons.link_rounded,
                            onPressed: _joining
                                ? null
                                : () {
                                    final ip = _ipController.text.trim();
                                    if (ip.isEmpty) return;
                                    _join(ctrl, hostIp: ip);
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Future<void> _join(
    GameController ctrl, {
    required String hostIp,
    String? roomCode,
    int port = gamePort,
  }) async {
    setState(() => _joining = true);
    final ok = await ctrl.joinRoom(
      hostIp: hostIp,
      playerName: widget.playerName,
      roomCode: roomCode,
      port: port,
    );
    if (!mounted) return;
    setState(() => _joining = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error ?? 'Ошибка подключения')),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }
}
