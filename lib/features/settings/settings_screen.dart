import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/expense_providers.dart';
import '../export/excel_service.dart';

const _native = MethodChannel('expense_tracker/native');

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _export() async {
    final list = ref.read(expensesProvider).value ?? const [];
    if (list.isEmpty) return _toast('Nothing to export yet.');
    setState(() => _busy = true);
    try {
      await ExcelService.exportAndShare(list);
    } catch (e) {
      _toast('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final rows = await ExcelService.pickAndParse();
      if (rows == null || !mounted) return;
      if (rows.isEmpty) return _toast('No rows found. The sheet needs Date and Amount columns.');
      final existing = ref.read(expensesProvider).value?.length ?? 0;
      final mode = existing == 0
          ? 'append'
          : await showDialog<String>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text('Import ${rows.length} expenses'),
                content: Text('You already have $existing expenses in the app. '
                    'Add the sheet rows to them, or replace everything?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, 'replace'), child: const Text('Replace')),
                  FilledButton(onPressed: () => Navigator.pop(c, 'append'), child: const Text('Add')),
                ],
              ),
            );
      if (mode == null) return;
      final n = ref.read(expensesProvider.notifier);
      if (mode == 'replace') await n.clear();
      await n.addAll(rows);
      final total = rows.fold<double>(0, (s, e) => s + e.amount);
      _toast('Imported ${rows.length} expenses · ${inr(total)}');
    } catch (e) {
      _toast('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTile() async {
    String? r;
    try {
      r = await _native.invokeMethod<String>('requestAddTile');
    } catch (_) {
      r = 'error';
    }
    if (!mounted) return;
    switch (r) {
      case 'added':
        _toast('"Log Expense" tile added. Swipe down from the top to use it.');
      case 'exists':
        _toast('The "Log Expense" tile is already in your Quick Settings. Swipe down twice to find it.');
      default:
        // Declined, unsupported (Android 12 and older) or blocked by the phone maker.
        _showTileHelp();
    }
  }

  void _showTileHelp() => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Add the lock-screen tile'),
          content: const SingleChildScrollView(
            child: Text('1. Unlock the phone and swipe down twice from the top so the full Quick Settings panel opens.\n'
                '2. Tap the pencil / Edit icon (Samsung: the ⋮ menu → Edit buttons; Xiaomi: Edit / Sort).\n'
                '3. Scroll the list of available tiles to the bottom and find "Log Expense" (mic icon).\n'
                '4. Long-press it and drag it up into the active tiles, then tap Done / back.\n\n'
                'Not in the list? Restart the phone once after installing, then check again.\n\n'
                'Then, even when locked: swipe down → tap "Log Expense" → speak.'),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Got it'))],
        ),
      );

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all expenses?'),
        content: const Text('This permanently removes every expense on this phone. Export to Excel first if you want a backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(expensesProvider.notifier).clear();
      _toast('All expenses deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final count = ref.watch(expensesProvider).value?.length ?? 0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text('Settings', style: t.headlineMedium),
          ),
          if (_busy) const LinearProgressIndicator(),
          _Group(title: 'Excel', children: [
            _Item(
              icon: Icons.ios_share_rounded,
              color: AppColors.mint,
              title: 'Export to Excel',
              subtitle: 'Expenses + Dashboard sheets · $count rows',
              onTap: _busy ? null : _export,
            ),
            _Item(
              icon: Icons.file_open_rounded,
              color: const Color(0xFF4F8EF7),
              title: 'Import from Excel',
              subtitle: 'Load rows from your existing Expense Tracker.xlsx',
              onTap: _busy ? null : _import,
            ),
          ]),
          _Group(title: 'Lock-screen voice', children: [
            _Item(
              icon: Icons.add_to_home_screen_rounded,
              color: AppColors.primary,
              title: 'Add "Log Expense" quick tile',
              subtitle: 'Swipe down on the lock screen and tap to speak',
              onTap: _addTile,
            ),
            _Item(
              icon: Icons.offline_bolt_rounded,
              color: const Color(0xFFF5A524),
              title: 'Enable offline speech',
              subtitle: 'Google app > Settings > Voice > Offline speech recognition > English (India)',
              onTap: () async {
                try {
                  await _native.invokeMethod('openVoiceSettings');
                } catch (_) {}
              },
            ),
          ]),
          _Group(title: 'Data', children: [
            _Item(
              icon: Icons.lock_rounded,
              color: cs.onSurfaceVariant,
              title: 'Stored only on this phone',
              subtitle: 'Local SQLite database · no account, no cloud',
            ),
            _Item(
              icon: Icons.delete_forever_rounded,
              color: cs.error,
              title: 'Delete all expenses',
              onTap: count == 0 ? null : _clear,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.1, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Card(clipBehavior: Clip.antiAlias, child: Column(children: children)),
        ]),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.color, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      );
}
