import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/app_state.dart';
import 'services/persistence_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Guarded: a missing/malformed .env must never block startup — it only
  // ever supplies the optional debug-mode API key (see AppConfig).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  runApp(const ArkadApp());
}

class ArkadApp extends StatelessWidget {
  const ArkadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arkad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AppRoot(),
    );
  }
}

/// Loads local persistence once, creates the single [AppState], then routes
/// to onboarding or straight into the app shell depending on saved profile.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final persistence = await PersistenceService.create();
    setState(() => _appState = AppState(persistence));
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;
    if (appState == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.darkGreen)),
      );
    }
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.profile.onboardingComplete) {
          return OnboardingScreen(appState: appState);
        }
        return AppShell(appState: appState);
      },
    );
  }
}
