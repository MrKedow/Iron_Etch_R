import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final spec = themeProvider.currentSpec;
    final customImage = themeProvider.customBackgroundPath;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: spec.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (customImage != null && File(customImage).existsSync())
          Builder(
            builder: (context) {
              final size = MediaQuery.sizeOf(context);
              final dpr = MediaQuery.devicePixelRatioOf(context);
              return Image.file(
                File(customImage),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: (size.width * dpr).round(),
                cacheHeight: (size.height * dpr).round(),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );
            },
          ),
        if (customImage != null)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  spec.background.withValues(alpha: .72),
                  spec.background.withValues(alpha: .88),
                  spec.background.withValues(alpha: .96),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-.9, -1.1),
                radius: 1.1,
                colors: [
                  spec.primary.withValues(alpha: .16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1.2, .9),
                radius: .9,
                colors: [
                  spec.secondary.withValues(alpha: .12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final Border? border;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color,
    this.gradient,
    this.radius = 24,
    this.border,
    this.shadows,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final isDark = spec.isDark;

    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ??
            (gradient == null
                ? spec.card.withValues(alpha: spec.glass ? .62 : .96)
                : null),
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            Border.all(
              color: spec.textPrimary.withValues(alpha: isDark ? .075 : .11),
            ),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .32 : .07),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: spec.primary.withValues(alpha: isDark ? .055 : .055),
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return _Pressable(onTap: onTap!, child: panel);
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? .975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(2, 26, 2, 12),
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: spec.textPrimary,
                    letterSpacing: .2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: spec.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class GradientIconBadge extends StatelessWidget {
  final IconData icon;
  final List<Color>? colors;
  final double size;
  final double iconSize;

  const GradientIconBadge({
    super.key,
    required this.icon,
    this.colors,
    this.size = 46,
    this.iconSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final palette = colors ?? [spec.primary, spec.secondary];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: [
          BoxShadow(
            color: palette.first.withValues(alpha: .28),
            blurRadius: 16,
            offset: Offset(0, size * .18),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? accent;
  final Gradient? gradient;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
    this.accent,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final color = accent ?? spec.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? spec.textPrimary.withValues(alpha: spec.isDark ? .045 : .055)
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: spec.textPrimary.withValues(alpha: spec.isDark ? .055 : .1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final tone = color ?? spec.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:
            filled ? tone.withValues(alpha: .16) : tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: spec.primary.withValues(alpha: .1),
                border: Border.all(
                  color: spec.primary.withValues(alpha: .18),
                ),
              ),
              child: Icon(icon, size: 38, color: spec.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: spec.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: spec.textSecondary,
                height: 1.6,
                fontSize: 13,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + Duration(milliseconds: index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 22),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class StatusBattery extends StatelessWidget {
  final int level;
  final double height;
  final double? width;
  final Color? outlineColor;
  final Color? textColor;
  final Color? bodyColor;

  const StatusBattery({
    super.key,
    required this.level,
    this.height = 12.5,
    this.width,
    this.outlineColor,
    this.textColor,
    this.bodyColor,
  });

  static Color fillColorFor(int value) {
    if (value > 80) return const Color(0xFF00FF00);
    if (value >= 60) return const Color(0xFF9ACD32);
    if (value >= 30) return const Color(0xFF98FB98);
    return const Color(0xFFBCE672);
  }

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0, 100);
    final resolvedTextColor =
        textColor ?? (clamped >= 50 ? const Color(0xFF0B1622) : Colors.white);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BatteryPainter(
          progress: clamped / 100,
          fillColor: fillColorFor(clamped),
          outlineColor: outlineColor ?? Colors.white.withValues(alpha: .62),
          bodyColor: bodyColor,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              '$clamped%',
              style: TextStyle(
                color: resolvedTextColor,
                fontSize: (height * .68).clamp(7.5, 12.0),
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: .1,
                shadows: const [
                  Shadow(color: Colors.black26, blurRadius: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Color outlineColor;
  final Color? bodyColor;

  _BatteryPainter({
    required this.progress,
    required this.fillColor,
    required this.outlineColor,
    this.bodyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyWidth = size.width - 3.4;
    if (bodyWidth <= 0) return;
    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final cap = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.fill;

    final bodyRect = Rect.fromLTWH(0.5, 0.5, bodyWidth - 1, size.height - 1);
    final body = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(3),
    );
    final capRect = Rect.fromLTWH(
      bodyWidth + 0.6,
      size.height * .28,
      2.4,
      size.height * .44,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(1)),
      cap,
    );

    if (bodyColor != null) {
      canvas.drawRRect(body, Paint()..color = bodyColor!);
    }

    if (progress > 0) {
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(
            bodyRect.deflate(1.4), const Radius.circular(2)),
      );
      final innerWidth = (bodyWidth - 2.8) * progress;
      canvas.drawRect(
        Rect.fromLTWH(1.4, 1.4, innerWidth, size.height - 2.8),
        fill,
      );
      canvas.restore();
    }
    canvas.drawRRect(body, outline);
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.bodyColor != bodyColor;
}

String formatCompact(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return value.toStringAsFixed(value is int ? 0 : 1);
}

String weekdayLabel(DateTime date) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[date.weekday - 1];
}

String dayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 6) return '凌晨好';
  if (hour < 11) return '早上好';
  if (hour < 14) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

AppThemeSpec specOf(BuildContext context) {
  return context.watch<ThemeProvider>().currentSpec;
}
