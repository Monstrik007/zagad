import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/gradient_background.dart';
import '../widgets/home_tagline.dart';
import '../widgets/primary_button.dart';
import 'host_lobby_screen.dart';
import 'join_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 56,
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              Text(
                'Загадчики',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
              ),
              const SizedBox(height: 12),
              const HomeTagline(),
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ваше имя',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Создать комнату',
                icon: Icons.wifi_tethering_rounded,
                onPressed: () => _openHost(context),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Войти в комнату',
                icon: Icons.login_rounded,
                color: AppColors.surfaceLight,
                onPressed: () => _openJoin(context),
              ),
              const SizedBox(height: 32),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _openHost(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack(context, 'Введите имя');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostLobbyScreen(playerName: name),
      ),
    );
  }

  void _openJoin(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack(context, 'Введите имя');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JoinScreen(playerName: name),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
