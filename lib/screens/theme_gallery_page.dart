import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class ThemeGalleryPage extends StatelessWidget {
  const ThemeGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final spec = themeProvider.currentSpec;
    final customPath = themeProvider.customBackgroundPath;
    final hasCustom = customPath != null && File(customPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题工坊'),
        actions: [
          IconButton(
            tooltip: '恢复默认',
            onPressed: () async {
              await themeProvider.clearCustomBackground();
              await themeProvider.setTheme(AppThemes.ironForge.id);
              await themeProvider.setMode(AppThemeMode.light);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复黑金主题与昼间模式')),
                );
              }
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
        children: [
          FadeSlideIn(
            child: GlassPanel(
              gradient: spec.heroGradient,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(spec.emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          spec.name,
                          style: TextStyle(
                            color: spec.onHero,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ThemeModeSwitch(
                        mode: themeProvider.mode,
                        spec: spec,
                        onChanged: (mode) {
                          themeProvider.setMode(mode);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        spec.subtitle,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: spec.onHeroMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _colorDot(spec, spec.primary),
                      _colorDot(spec, spec.secondary),
                      _colorDot(spec, spec.accent),
                      _colorDot(spec, spec.card),
                      const Spacer(),
                      Text(
                        hasCustom ? '叠加自定义背景' : '点击下方主题实时切换',
                        style: TextStyle(
                          color: spec.onHero.withValues(alpha: .62),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: '内置主题',
            subtitle: '参考开源 Material 3 调色板与流行影音应用设计',
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppThemes.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: .78,
            ),
            itemBuilder: (context, index) {
              final theme = AppThemes.all[index];
              final selected = theme.id == themeProvider.themeId;
              return FadeSlideIn(
                index: index,
                child: _ThemeCard(
                  spec: themeProvider.specFor(theme.id),
                  selected: selected,
                  onTap: () => themeProvider.setTheme(theme.id),
                ),
              );
            },
          ),
          const SectionHeader(
            title: '自定义图片主题',
            subtitle: '从相册导入一张图片，作为整个应用的沉浸式背景',
          ),
          FadeSlideIn(
            child: GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 152,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: spec.textPrimary.withValues(alpha: .04),
                      image: hasCustom
                          ? DecorationImage(
                              image: FileImage(File(customPath)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(
                        color: spec.textPrimary.withValues(alpha: .08),
                      ),
                    ),
                    child: hasCustom
                        ? Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Pill(
                                label: '已启用',
                                icon: Icons.check_circle_rounded,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wallpaper_rounded,
                                size: 38,
                                color: spec.textSecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '还没有导入图片',
                                style: TextStyle(
                                  color: spec.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 90,
                            );
                            if (picked == null) return;
                            final dir =
                                await getApplicationDocumentsDirectory();
                            final target =
                                '${dir.path}/theme_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await File(picked.path).copy(target);
                            await themeProvider.setCustomBackground(target);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('图片主题已应用')),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 19),
                          label: Text(hasCustom ? '更换图片' : '导入图片'),
                        ),
                      ),
                      if (hasCustom) ...[
                        const SizedBox(width: 10),
                        IconButton.outlined(
                          onPressed: () async {
                            await themeProvider.clearCustomBackground();
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          tooltip: '移除自定义背景',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '主题会同步改变背景、卡片、按钮、输入框与弹窗风格。图片主题会自动叠加暗色蒙层，保证文字清晰可读。',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 11.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(AppThemeSpec spec, Color color) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: spec.onHero.withValues(alpha: .35)),
      ),
    );
  }
}

class _ThemeModeSwitch extends StatefulWidget {
  final AppThemeMode mode;
  final AppThemeSpec spec;
  final ValueChanged<AppThemeMode> onChanged;

  const _ThemeModeSwitch({
    required this.mode,
    required this.spec,
    required this.onChanged,
  });

  @override
  State<_ThemeModeSwitch> createState() => _ThemeModeSwitchState();
}

class _ThemeModeSwitchState extends State<_ThemeModeSwitch>
    with SingleTickerProviderStateMixin {
  static const double _width = 104;
  static const double _height = 34;
  static const double _thumbSize = 28;
  static const double _padding = 3;
  static const double _travel = _width - _padding * 2 - _thumbSize;

  late final AnimationController _spin;
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  double get _selectedFraction => widget.mode.index / 2;
  double get _fraction => _dragFraction ?? _selectedFraction;

  int get _displayIndex {
    final index = (_fraction * 2).round();
    return index < 0 ? 0 : (index > 2 ? 2 : index);
  }

  void _selectFromDx(double dx) {
    final fraction = (dx / _width).clamp(0.0, 1.0);
    _commit((fraction * 2).round());
  }

  void _commit(int index) {
    setState(() => _dragFraction = null);
    final safeIndex = index < 0 ? 0 : (index > 2 ? 2 : index);
    final mode = AppThemeMode.values[safeIndex];
    if (mode != widget.mode) widget.onChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final trackColor = widget.spec.onHero.withValues(
      alpha: widget.spec.isDark ? .18 : .09,
    );
    final borderColor = widget.spec.onHero.withValues(
      alpha: widget.spec.isDark ? .20 : .14,
    );
    final markerColor = widget.spec.onHero.withValues(alpha: .48);
    final thumbColor =
        widget.spec.isDark ? Colors.white : widget.spec.textPrimary;
    final thumbForeground =
        widget.spec.isDark ? const Color(0xFF101216) : Colors.white;

    return Semantics(
      button: true,
      label: '主题明暗模式',
      value: switch (widget.mode) {
        AppThemeMode.light => '昼',
        AppThemeMode.system => '跟随系统',
        AppThemeMode.dark => '夜',
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _selectFromDx(details.localPosition.dx),
        onHorizontalDragStart: (_) {
          setState(() => _dragFraction = _selectedFraction);
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            _dragFraction = (details.localPosition.dx / _width).clamp(0.0, 1.0);
          });
        },
        onHorizontalDragEnd: (_) {
          _commit((_fraction * 2).round());
        },
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(_height / 2),
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
              for (var i = 0; i < 3; i++) _slotMarker(i, markerColor),
              AnimatedPositioned(
                duration: _dragFraction == null
                    ? const Duration(milliseconds: 220)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                left: _padding + _fraction * _travel,
                top: _padding,
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _displayIndex == 1
                      ? RotationTransition(
                          turns: _spin,
                          child: const SizedBox.square(
                            dimension: 17,
                            child: CustomPaint(
                              painter: _TaijiPainter(),
                            ),
                          ),
                        )
                      : Text(
                          _displayIndex == 0 ? '昼' : '夜',
                          style: TextStyle(
                            color: thumbForeground,
                            fontSize: 12,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotMarker(int index, Color color) {
    final center = _padding + _travel * (index / 2) + _thumbSize / 2;
    return Positioned(
      left: center - 5,
      top: 0,
      bottom: 0,
      width: 10,
      child: Center(
        child: Opacity(
          opacity: .34,
          child: index == 1
              ? const SizedBox.square(
                  dimension: 10,
                  child: CustomPaint(
                    painter: _TaijiPainter(
                      inkColor: Colors.black87,
                      paperColor: Colors.white,
                    ),
                  ),
                )
              : Text(
                  index == 0 ? '昼' : '夜',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TaijiPainter extends CustomPainter {
  final Color inkColor;
  final Color paperColor;

  const _TaijiPainter({
    this.inkColor = const Color(0xFF111111),
    this.paperColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paper = Paint()..color = paperColor;
    final ink = Paint()..color = inkColor;

    canvas.drawCircle(center, radius, paper);

    final rightHalf = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..arcTo(rect, -math.pi / 2, math.pi, false)
      ..close();
    canvas.drawPath(rightHalf, ink);
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius / 2),
      radius / 2,
      ink,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius / 2),
      radius / 2,
      paper,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius / 2),
      radius / 6,
      ink,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius / 2),
      radius / 6,
      paper,
    );

    canvas.drawCircle(
      center,
      radius - .5,
      Paint()
        ..color = inkColor.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TaijiPainter oldDelegate) =>
      oldDelegate.inkColor != inkColor || oldDelegate.paperColor != paperColor;
}

class _ThemeCard extends StatelessWidget {
  final AppThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: spec.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: selected ? spec.primary : spec.onHero.withValues(alpha: .10),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: spec.primary.withValues(alpha: .35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(spec.emoji, style: const TextStyle(fontSize: 20)),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: spec.primary),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: spec.card.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: spec.textPrimary.withValues(alpha: .06),
                      ),
                    ),
                    padding: const EdgeInsets.all(9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: spec.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(
                                color: spec.textPrimary.withValues(alpha: .4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          height: 5,
                          width: 70,
                          decoration: BoxDecoration(
                            color: spec.textPrimary.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    spec.name,
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 9.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: spec.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
