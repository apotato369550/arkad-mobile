import 'package:flutter/material.dart';
import 'app_view.dart';
import 'categories_screen.dart';
import 'chat_screen.dart';
import 'conversation_list_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/transaction_form_sheet.dart';

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
          onTransactionTap: (id) {
            Navigator.of(context).pop();
            _goToTransaction(id);
          },
        ),
      ),
    );
  }

  void _openConversations() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationListScreen(
          appState: widget.appState,
          onTransactionTap: (id) {
            Navigator.of(context).pop();
            _goToTransaction(id);
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
        onOpenConversations: _openConversations,
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
        AppView.categories => CategoriesScreen(appState: widget.appState),
        AppView.profile => ProfileScreen(appState: widget.appState),
        AppView.settings => SettingsScreen(appState: widget.appState),
      },
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'addTransactionFab',
            onPressed: () => showTransactionFormSheet(context, appState: widget.appState),
            backgroundColor: AppColors.darkGreen,
            foregroundColor: AppColors.pastelYellow,
            tooltip: 'Add transaction',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'chatFab',
            onPressed: _openChat,
            backgroundColor: AppColors.darkGreen,
            foregroundColor: AppColors.pastelYellow,
            tooltip: 'Chat with Arkad',
            child: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
    );
  }
}
