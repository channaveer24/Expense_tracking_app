import 'package:flutter/material.dart';

import '../../data/models/expense.dart';
import '../constants/categories.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 44});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = styleFor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(s.icon, color: s.color, size: size * 0.5),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
      );
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile(this.e, {super.key, this.onTap, this.showDate = false});
  final Expense e;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          CategoryAvatar(e.category),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(showDate ? '${dayLabel(e.date)} · ${e.category}' : e.category,
                    style: t.bodySmall?.copyWith(color: muted)),
                Pill(e.type, color: e.type == 'Need' ? kNeedColor : kWantColor),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(inr(e.amount),
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(paymentIcon(e.paymentMethod), size: 13, color: muted),
              const SizedBox(width: 3),
              Text(e.paymentMethod, style: t.bodySmall?.copyWith(color: muted)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: cs.primary),
        ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}

/// Pulsing microphone button driven by the live mic level.
class MicOrb extends StatefulWidget {
  const MicOrb({super.key, required this.listening, required this.level, this.onTap, this.size = 120});
  final bool listening;
  final double level;
  final VoidCallback? onTap;
  final double size;

  @override
  State<MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop listening' : 'Start voice input',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: size * 1.9,
          height: size * 1.9,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(alignment: Alignment.center, children: [
              if (widget.listening)
                for (var i = 0; i < 2; i++)
                  Builder(builder: (_) {
                    final p = (_c.value + i * 0.5) % 1.0;
                    return Container(
                      width: size * (1 + p * (0.6 + widget.level * 0.4)),
                      height: size * (1 + p * (0.6 + widget.level * 0.4)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: (1 - p) * 0.25),
                      ),
                    );
                  }),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: size * (1 + (widget.listening ? widget.level * 0.12 : 0)),
                height: size * (1 + (widget.listening ? widget.level * 0.12 : 0)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.listening
                        ? const [Color(0xFF8F7CFF), Color(0xFF5B4BE0)]
                        : const [Color(0xFF7C6CF6), Color(0xFF4E3FD0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(widget.listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    color: Colors.white, size: size * 0.42),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
