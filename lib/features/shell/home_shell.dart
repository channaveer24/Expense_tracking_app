import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/expense_providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expense_form_sheet.dart';
import '../expenses/expenses_screen.dart';
import '../settings/settings_screen.dart';
import '../voice/voice_capture_sheet.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // Expenses logged from the lock-screen tile are written by a separate
    // engine; reload when the app comes back to the foreground.
    _life = AppLifecycleListener(onResume: () => ref.read(expensesProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onSeeAll: () => setState(() => _tab = 1)),
      const ExpensesScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _tab == 2
          ? null
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              FloatingActionButton.small(
                heroTag: 'manual',
                tooltip: 'Add manually',
                onPressed: () => showExpenseForm(context),
                child: const Icon(Icons.edit_rounded),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 68,
                height: 68,
                child: FloatingActionButton(
                  heroTag: 'voice',
                  tooltip: 'Log by voice',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 6,
                  onPressed: () => showVoiceCapture(context),
                  child: const Icon(Icons.mic_rounded, size: 32),
                ),
              ),
            ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
