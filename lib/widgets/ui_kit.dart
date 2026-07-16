import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/tokens.dart';

/// Shared UI building blocks so every screen looks like one system.
/// Style only — none of these hold business logic.

/// White rounded panel with a soft shadow and thin border.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.panelBorder),
        boxShadow: AppShadows.panel,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Small section title + optional subtitle (Sora heading).
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              if (subtitle case final s?) ...[
                const SizedBox(height: 3),
                Text(s, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A colored gradient stat tile: icon chip, big value, small tag.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String tag;
  final IconData icon;
  final Gradient gradient;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.tag,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = (gradient is LinearGradient)
        ? (gradient as LinearGradient).colors.first
        : AppColors.violet;
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.glow(glowColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 12),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppTheme.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(tag,
                style: const TextStyle(
                    fontFamily: AppTheme.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Gradient action button (with icon). Tall, rounded, glowing when enabled;
/// a flat grey when disabled. Pass [gradient] (e.g. AppGradients.danger) for
/// destructive actions.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient gradient;
  final double height;
  final double fontSize;
  /// true = fill the parent's width (parent MUST give a bounded width, e.g. a
  /// stretch Column); false = size to content (safe inside an unbounded Row).
  final bool expand;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient = AppGradients.primary,
    this.height = 56,
    this.fontSize = 14,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final glow = (gradient is LinearGradient)
        ? (gradient as LinearGradient).colors.first
        : AppColors.violet;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: enabled ? gradient : null,
            color: enabled ? null : const Color(0xFFE4E1F0),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: enabled ? AppShadows.glow(glow) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: enabled ? Colors.white : AppColors.muted),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.body,
                          color: enabled ? Colors.white : AppColors.muted,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill segmented toggle: selected segment gets the violet gradient, the rest
/// a soft grey. One consistent look for Discount %/Rs, Payment, and filters.
class SegToggle extends StatelessWidget {
  final List<(String value, String label)> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final double height;
  const SegToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECF8),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: o.$1 == selected ? AppGradients.primary : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: o.$1 == selected ? AppShadows.glow(AppColors.violet) : null,
                ),
                child: Text(o.$2,
                    style: TextStyle(
                        fontFamily: AppTheme.body,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: o.$1 == selected ? Colors.white : AppColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Round outline +/- stepper button in the accent color, with hover/press.
class StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const StepperButton({super.key, required this.icon, this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(size, size),
          side: const BorderSide(color: AppColors.violet),
          foregroundColor: AppColors.violet,
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

/// Status pill. Kinds map to fixed colors (Paid/Due/Refund/Low stock).
enum BadgeKind { paid, due, refund, lowStock, neutral }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeKind kind;
  const StatusBadge({super.key, required this.text, required this.kind});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (kind) {
      BadgeKind.paid => (const Color(0xFF1EAE74), const Color(0xFFE3F7EE)),
      BadgeKind.due => (const Color(0xFFC98407), const Color(0xFFFFF3DC)),
      BadgeKind.refund => (const Color(0xFFE2456A), const Color(0xFFFFE6EC)),
      BadgeKind.lowStock => (AppColors.warn, AppColors.warnBg),
      BadgeKind.neutral => (AppColors.muted, const Color(0xFFEFECF8)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(text,
          style: TextStyle(
              fontFamily: AppTheme.body, fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Rounded gradient icon tile (used as list-row leading).
class GradientTile extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final double size;
  const GradientTile({super.key, required this.icon, required this.gradient, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}
