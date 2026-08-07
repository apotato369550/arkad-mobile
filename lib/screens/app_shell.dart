import 'package:flutter/material.dart';
import 'app_view.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/nav_drawer.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.appState});

  final AppState appState;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppView _view = AppView.dashboard;
  int _highlightedTransactionId = -1;

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          appState: widget.appState,
          onOpenSettings: () {
            Navigator.of(context).pop();
            setState(() => _view = AppView.settings);
          },
        ),
      ),
    );
  }

  void _goToTransaction(int id) {
    setState(() {
      _view = AppView.transactions;
      _highlightedTransactionId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text(_view.label)),
      drawer: NavDrawer(
        current: _view,
        onSelect: (v) => setState(() => _view = v),
        onOpenChat: _openChat,
      ),
      body: switch (_view) {
        AppView.dashboard => DashboardScreen(
            appState: widget.appState,
            onTransactionTap: _goToTransaction,
          ),
        AppView.transactions => TransactionsScreen(
            appState: widget.appState,
            highlightId: _highlightedTransactionId,
          ),
        AppView.profile => ProfileScreen(appState: widget.appState),
        AppView.settings => SettingsScreen(appState: widget.appState),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: _openChat,
        backgroundColor: AppColors.darkGreen,
        foregroundColor: AppColors.pastelYellow,
        tooltip: 'Chat with Arkad',
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }
}
