import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../services/epub_service.dart';

String formatDownloadSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 KB/s';
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)}M/s';
  }
  return '${(bytesPerSecond / 1024).toStringAsFixed(1)}KB/s';
}

Future<void> showBookDownloadDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '下载内置书',
    barrierColor: Colors.black.withValues(alpha: .62),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return const _BookDownloadDialog();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _BookDownloadDialog extends StatefulWidget {
  const _BookDownloadDialog();

  @override
  State<_BookDownloadDialog> createState() => _BookDownloadDialogState();
}

class _BookDownloadDialogState extends State<_BookDownloadDialog>
    with SingleTickerProviderStateMixin {
  final EpubLibraryService _library = EpubLibraryService.instance;
  late final AnimationController _fishing;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _fishing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _library.addListener(_handleLibraryChanged);
  }

  @override
  void dispose() {
    _library.removeListener(_handleLibraryChanged);
    _fishing.dispose();
    super.dispose();
  }

  void _handleLibraryChanged() {
    if (!mounted || _closing) return;
    final info = _library.downloadProgressFor(EpubLibraryService.defaultId);
    if (!_library.isDefaultDownloading && info != null && info.progress >= .999) {
      _closing = true;
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return AnimatedBuilder(
      animation: _library,
      builder: (context, _) {
        final info = _library.downloadProgressFor(EpubLibraryService.defaultId);
        final progress = (info?.progress ?? 0).clamp(0.0, 1.0);
        final speed = info?.speedBytesPerSecond ?? 0;
        return PopScope(
          canPop: !_library.isDefaultDownloading,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 318,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  color: spec.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: spec.textPrimary.withValues(alpha: .08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .34),
                      blurRadius: 42,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 152,
                      child: AnimatedBuilder(
                        animation: _fishing,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _FishingCatPainter(
                              t: _fishing.value,
                              accent: spec.primary,
                            ),
                            size: const Size(double.infinity, 152),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              height: 22,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor:
                                        spec.textPrimary.withValues(alpha: .08),
                                    color: spec.primary,
                                  ),
                                  Center(
                                    child: Text(
                                      '${(progress * 100).toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: progress > .62
                                            ? spec.onHero
                                            : spec.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 64,
                          child: Text(
                            formatDownloadSpeed(speed),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '正在从最快的镜像下载，退出此窗口也会继续',
                      style: TextStyle(
                        color: spec.textSecondary.withValues(alpha: .8),
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('我稍后再来'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FishingCatPainter extends CustomPainter {
  final double t;
  final Color accent;

  _FishingCatPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = t * math.pi * 2;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: .16),
          accent.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(w * .5, h * .5), radius: w * .55),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final waterTop = h * .68;
    final waterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .22, waterTop, w * .74, h - waterTop),
      const Radius.circular(16),
    );
    final water = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8FD8FF).withValues(alpha: .55),
          const Color(0xFF3E8FB8).withValues(alpha: .45),
        ],
      ).createShader(waterRect.outerRect);
    canvas.drawRRect(waterRect, water);

    final bank = Paint()..color = const Color(0xFFC9A46B);
    canvas.drawPath(
      Path()
        ..moveTo(w * .06, h)
        ..lineTo(w * .1, h * .72)
        ..quadraticBezierTo(w * .18, h * .6, w * .32, h * .66)
        ..lineTo(w * .36, h)
        ..close(),
      bank,
    );
    final bankTop = Paint()..color = const Color(0xFFE0C38C);
    canvas.drawPath(
      Path()
        ..moveTo(w * .1, h * .72)
        ..quadraticBezierTo(w * .18, h * .61, w * .32, h * .67)
        ..lineTo(w * .32, h * .72)
        ..quadraticBezierTo(w * .19, h * .66, w * .1, h * .77)
        ..close(),
      bankTop,
    );

    for (var i = 0; i < 3; i++) {
      final ripplePhase = (t * 2 + i * .33) % 1;
      final ripple = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: .32 * (1 - ripplePhase));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * (.52 + i * .13), h * (.78 + i * .05)),
          width: 26 + ripplePhase * 44,
          height: 7 + ripplePhase * 12,
        ),
        ripple,
      );
    }

    final catBaseX = w * .19;
    final catBaseY = h * .7;
    final rodSwing = math.sin(phase * 1.1) * .04;
    final rodStart = Offset(catBaseX + 16, catBaseY - 10);
    final rodEnd = Offset(w * .63, h * .22);
    final rodTip = Offset(
      rodStart.dx +
          (rodEnd.dx - rodStart.dx) * math.cos(rodSwing) -
          (rodEnd.dy - rodStart.dy) * math.sin(rodSwing),
      rodStart.dy +
          (rodEnd.dx - rodStart.dx) * math.sin(rodSwing) +
          (rodEnd.dy - rodStart.dy) * math.cos(rodSwing),
    );

    final bobberBob = math.sin(phase * 1.6) * 2.2;
    final bobberX = w * .63;
    final bobberY = waterTop + 8 + bobberBob;
    canvas.drawLine(
      rodTip,
      Offset(bobberX, bobberY - 5),
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      Offset(bobberX, bobberY - 3),
      4.2,
      Paint()..color = const Color(0xFFE64A3B),
    );
    canvas.drawCircle(
      Offset(bobberX, bobberY + 1.2),
      3.4,
      Paint()..color = Colors.white,
    );

    final catchCycle = (t * 1.0) % 1.0;
    final fishVisible = catchCycle < .55;
    if (fishVisible) {
      final k = catchCycle / .55;
      final fishX = w * .63 - k * w * .13;
      final fishY = waterTop + 12 - math.sin(k * math.pi) * 34;
      final fishAngle = -0.9 + k * 1.7;
      canvas.save();
      canvas.translate(fishX, fishY);
      canvas.rotate(fishAngle);
      final fishPaint = Paint()..color = const Color(0xFFFF9F1A);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 11),
        fishPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-9, 0)
          ..lineTo(-15, -5)
          ..lineTo(-15, 5)
          ..close(),
        fishPaint,
      );
      canvas.drawCircle(
        const Offset(5.5, -2),
        1.3,
        Paint()..color = Colors.black87,
      );
      canvas.drawCircle(
        const Offset(5.5, -2),
        .5,
        Paint()..color = Colors.white,
      );
      canvas.restore();
      if (k > .25 && k < .8) {
        final dropPaint = Paint()
          ..color = const Color(0xFF9FE0FF).withValues(alpha: .8);
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(
              fishX + (i - 1) * 7,
              waterTop + 4 - math.sin(k * math.pi) * (8 + i * 6),
            ),
            1.6,
            dropPaint,
          );
        }
      }
    }

    final tailSwing = math.sin(phase) * .35;
    final tail = Paint()
      ..color = const Color(0xFFD98F4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(catBaseX - 13, catBaseY - 8);
    canvas.rotate(tailSwing);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-14, 4, -13, 17),
      tail,
    );
    canvas.restore();

    final body = Paint()..color = const Color(0xFFE8A15B);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(catBaseX, catBaseY - 6),
        width: 42,
        height: 46,
      ),
      body,
    );
    final belly = Paint()..color = const Color(0xFFF7E3C3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(catBaseX + 4, catBaseY + 2),
        width: 24,
        height: 28,
      ),
      belly,
    );

    final headCenter = Offset(catBaseX + 3, catBaseY - 33);
    final headPaint = Paint()..color = const Color(0xFFE8A15B);
    canvas.drawCircle(headCenter, 18, headPaint);
    final earPaint = Paint()..color = const Color(0xFFE8A15B);
    final innerEar = Paint()..color = const Color(0xFFF4B8B0);
    canvas.drawPath(
      Path()
        ..moveTo(headCenter.dx - 16, headCenter.dy - 10)
        ..lineTo(headCenter.dx - 12, headCenter.dy - 26)
        ..lineTo(headCenter.dx - 1, headCenter.dy - 14)
        ..close(),
      earPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(headCenter.dx - 13, headCenter.dy - 13)
        ..lineTo(headCenter.dx - 11, headCenter.dy - 21)
        ..lineTo(headCenter.dx - 5, headCenter.dy - 14)
        ..close(),
      innerEar,
    );
    canvas.drawPath(
      Path()
        ..moveTo(headCenter.dx + 4, headCenter.dy - 14)
        ..lineTo(headCenter.dx + 14, headCenter.dy - 26)
        ..lineTo(headCenter.dx + 18, headCenter.dy - 8)
        ..close(),
      earPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(headCenter.dx + 7, headCenter.dy - 14)
        ..lineTo(headCenter.dx + 13, headCenter.dy - 21)
        ..lineTo(headCenter.dx + 15, headCenter.dy - 11)
        ..close(),
      innerEar,
    );

    final stripe = Paint()
      ..color = const Color(0xFFC97B3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(headCenter.dx - 10, headCenter.dy - 14),
      Offset(headCenter.dx - 7, headCenter.dy - 9),
      stripe,
    );
    canvas.drawLine(
      Offset(headCenter.dx - 6, headCenter.dy - 16),
      Offset(headCenter.dx - 4, headCenter.dy - 10),
      stripe,
    );
    canvas.drawLine(
      Offset(headCenter.dx + 8, headCenter.dy - 14),
      Offset(headCenter.dx + 6, headCenter.dy - 9),
      stripe,
    );

    final eye = Paint()..color = const Color(0xFF2B1B10);
    final blink = (math.sin(phase * 1.3) > .94) ? .35 : 1.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - 6, headCenter.dy - 2),
        width: 4.6,
        height: 6.4 * blink,
      ),
      eye,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx + 7, headCenter.dy - 2),
        width: 4.6,
        height: 6.4 * blink,
      ),
      eye,
    );
    if (blink > .9) {
      final sparkle = Paint()..color = Colors.white;
      canvas.drawCircle(
        Offset(headCenter.dx - 7.4, headCenter.dy - 4),
        1.1,
        sparkle,
      );
      canvas.drawCircle(
        Offset(headCenter.dx + 5.6, headCenter.dy - 4),
        1.1,
        sparkle,
      );
    }

    final nose = Paint()..color = const Color(0xFFE0796F);
    canvas.drawPath(
      Path()
        ..moveTo(headCenter.dx - 2, headCenter.dy + 4)
        ..lineTo(headCenter.dx + 3, headCenter.dy + 4)
        ..lineTo(headCenter.dx + .5, headCenter.dy + 7)
        ..close(),
      nose,
    );
    final mouth = Paint()
      ..color = const Color(0xFF5A3A26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx - 2, headCenter.dy + 8),
        width: 6,
        height: 5,
      ),
      0,
      math.pi,
      false,
      mouth,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx + 4, headCenter.dy + 8),
        width: 6,
        height: 5,
      ),
      0,
      math.pi,
      false,
      mouth,
    );

    final whisker = Paint()
      ..color = const Color(0xFF8A6547)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(headCenter.dx - 10, headCenter.dy + 5),
      Offset(headCenter.dx - 24, headCenter.dy + 2),
      whisker,
    );
    canvas.drawLine(
      Offset(headCenter.dx - 10, headCenter.dy + 8),
      Offset(headCenter.dx - 24, headCenter.dy + 9),
      whisker,
    );
    canvas.drawLine(
      Offset(headCenter.dx + 12, headCenter.dy + 5),
      Offset(headCenter.dx + 26, headCenter.dy + 1),
      whisker,
    );
    canvas.drawLine(
      Offset(headCenter.dx + 12, headCenter.dy + 8),
      Offset(headCenter.dx + 26, headCenter.dy + 8),
      whisker,
    );

    canvas.save();
    canvas.translate(rodStart.dx, rodStart.dy);
    canvas.rotate(rodSwing);
    canvas.drawLine(
      Offset.zero,
      rodEnd - rodStart,
      Paint()
        ..color = const Color(0xFF7A4E2C)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    final paw = Paint()..color = const Color(0xFFF0B778);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(catBaseX + 16, catBaseY - 10),
        width: 13,
        height: 10,
      ),
      paw,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(catBaseX - 10, catBaseY + 12),
        width: 13,
        height: 9,
      ),
      paw,
    );

    final sparklePhase = (t * 2) % 1;
    if (fishVisible && sparklePhase < .4) {
      final sparkle = Paint()
        ..color = const Color(0xFFFFF2B0)
            .withValues(alpha: (1 - sparklePhase / .4).clamp(0.0, 1.0));
      final center = Offset(w * .63, h * .22);
      for (var i = 0; i < 4; i++) {
        final angle = i * math.pi / 2 + sparklePhase * 3;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * (7 + i * 2),
          1.8,
          sparkle,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FishingCatPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.accent != accent;
}
