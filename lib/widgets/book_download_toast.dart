import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/epub_service.dart';

/// 挂在 MaterialApp.builder 之上，任何页面都能看到下载完成的小猫提示。
class BookDownloadToastHost extends StatefulWidget {
  const BookDownloadToastHost({super.key});

  @override
  State<BookDownloadToastHost> createState() => _BookDownloadToastHostState();
}

class _BookDownloadToastHostState extends State<BookDownloadToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = false;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _lastTick = EpubLibraryService.instance.downloadCompleted.value;
    EpubLibraryService.instance.downloadCompleted.addListener(_onCompleted);
  }

  @override
  void dispose() {
    EpubLibraryService.instance.downloadCompleted.removeListener(_onCompleted);
    _controller.dispose();
    super.dispose();
  }

  void _onCompleted() {
    final tick = EpubLibraryService.instance.downloadCompleted.value;
    if (tick == _lastTick) return;
    _lastTick = tick;
    if (!mounted) return;
    setState(() => _visible = true);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _controller.value;
            double slide;
            if (value < .14) {
              slide = 168 * (1 - Curves.easeOutCubic.transform(value / .14));
            } else if (value < .84) {
              slide = 0;
            } else {
              slide = 168 *
                  Curves.easeInCubic.transform((value - .84) / .16);
            }
            final wiggle = math.sin(value * math.pi * 8) * 1.5;
            return Transform.translate(
              offset: Offset(slide, wiggle),
              child: child,
            );
          },
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(4, 4),
                  child: CustomPaint(
                    size: const Size(168, 62),
                    painter: _CloudBubblePainter(),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(18, 0),
                  child: SizedBox(
                    width: 92,
                    height: 108,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _PeekingCatPainter(t: _controller.value),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloudBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 8, size.width - 14, size.height - 16);
    final cloud = Path();
    final circles = <Rect>[
      Rect.fromCircle(center: Offset(body.left + 16, body.top + 14), radius: 13),
      Rect.fromCircle(center: Offset(body.left + 36, body.top + 8), radius: 15),
      Rect.fromCircle(center: Offset(body.left + 60, body.top + 9), radius: 14),
      Rect.fromCircle(center: Offset(body.left + 84, body.top + 12), radius: 13),
      Rect.fromCircle(
          center: Offset(body.right - 12, body.top + 18), radius: 12),
      Rect.fromCircle(
          center: Offset(body.left + 14, body.bottom - 12), radius: 12),
      Rect.fromCircle(
          center: Offset(body.left + 42, body.bottom - 8), radius: 14),
      Rect.fromCircle(
          center: Offset(body.right - 28, body.bottom - 10), radius: 13),
      Rect.fromCircle(
          center: Offset(body.right - 10, body.bottom - 14), radius: 11),
    ];
    cloud.addRRect(
      RRect.fromRectAndRadius(body.deflate(4), const Radius.circular(18)),
    );
    for (final circle in circles) {
      cloud.addOval(circle);
    }
    final tail = Path()
      ..moveTo(size.width - 18, size.height * .48)
      ..lineTo(size.width, size.height * .54)
      ..lineTo(size.width - 16, size.height * .64)
      ..close();
    final shape = Path.combine(PathOperation.union, cloud, tail);

    canvas.drawShadow(shape, Colors.black.withValues(alpha: .3), 8, false);
    canvas.drawPath(shape, Paint()..color = Colors.white);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE3E8EF),
    );

    final text = TextPainter(
      text: const TextSpan(
        text: '你要的书下好喽~',
        style: TextStyle(
          color: Color(0xFF1B2430),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 40);
    text.paint(
      canvas,
      Offset((size.width - 14 - text.width) / 2, (size.height - text.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PeekingCatPainter extends CustomPainter {
  final double t;

  _PeekingCatPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = t * math.pi * 2;
    final cx = w * .62;
    final cy = h * .46;

    final head = Paint()..color = const Color(0xFFF0B778);
    final dark = Paint()..color = const Color(0xFFD98F4E);
    final cream = Paint()..color = const Color(0xFFF9E7C9);
    final innerEar = Paint()..color = const Color(0xFFF4B8B0);
    final line = Paint()
      ..color = const Color(0xFF8A6547)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), w * .42, head);

    canvas.drawPath(
      Path()
        ..moveTo(cx - w * .4, cy - w * .18)
        ..lineTo(cx - w * .3, cy - w * .56)
        ..lineTo(cx - w * .04, cy - w * .32)
        ..close(),
      head,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * .33, cy - w * .23)
        ..lineTo(cx - w * .28, cy - w * .46)
        ..lineTo(cx - w * .12, cy - w * .3)
        ..close(),
      innerEar,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx + w * .08, cy - w * .32)
        ..lineTo(cx + w * .33, cy - w * .55)
        ..lineTo(cx + w * .42, cy - w * .14)
        ..close(),
      head,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx + w * .16, cy - w * .3)
        ..lineTo(cx + w * .31, cy - w * .45)
        ..lineTo(cx + w * .36, cy - w * .19)
        ..close(),
      innerEar,
    );

    final stripe = Paint()
      ..color = const Color(0xFFC97B3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - w * .18, cy - w * .33),
      Offset(cx - w * .12, cy - w * .2),
      stripe,
    );
    canvas.drawLine(
      Offset(cx - w * .06, cy - w * .38),
      Offset(cx - w * .02, cy - w * .24),
      stripe,
    );
    canvas.drawLine(
      Offset(cx + w * .16, cy - w * .33),
      Offset(cx + w * .13, cy - w * .2),
      stripe,
    );

    final blink = math.sin(phase * 1.7) > .9;
    final eye = Paint()..color = const Color(0xFF2B1B10);
    if (blink) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx - w * .15, cy),
          width: w * .13,
          height: w * .07,
        ),
        math.pi,
        math.pi,
        false,
        line,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx + w * .13, cy),
          width: w * .13,
          height: w * .07,
        ),
        math.pi,
        math.pi,
        false,
        line,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - w * .15, cy),
          width: w * .12,
          height: w * .18,
        ),
        eye,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + w * .13, cy),
          width: w * .12,
          height: w * .18,
        ),
        eye,
      );
      canvas.drawCircle(
        Offset(cx - w * .18, cy - w * .05),
        w * .028,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(cx + w * .1, cy - w * .05),
        w * .028,
        Paint()..color = Colors.white,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * .01, cy + w * .17),
        width: w * .34,
        height: w * .24,
      ),
      cream,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * .05, cy + w * .1)
        ..lineTo(cx + w * .04, cy + w * .1)
        ..lineTo(cx - w * .005, cy + w * .15)
        ..close(),
      Paint()..color = const Color(0xFFE0796F),
    );
    final mouth = Paint()
      ..color = const Color(0xFF5A3A26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - w * .05, cy + w * .17),
        width: w * .12,
        height: w * .09,
      ),
      0,
      math.pi,
      false,
      mouth,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx + w * .05, cy + w * .17),
        width: w * .12,
        height: w * .09,
      ),
      0,
      math.pi,
      false,
      mouth,
    );

    canvas.drawLine(
      Offset(cx - w * .2, cy + w * .13),
      Offset(cx - w * .46, cy + w * .08),
      line,
    );
    canvas.drawLine(
      Offset(cx - w * .2, cy + w * .18),
      Offset(cx - w * .47, cy + w * .2),
      line,
    );
    canvas.drawLine(
      Offset(cx + w * .2, cy + w * .13),
      Offset(cx + w * .46, cy + w * .06),
      line,
    );
    canvas.drawLine(
      Offset(cx + w * .2, cy + w * .18),
      Offset(cx + w * .47, cy + w * .18),
      line,
    );

    final paw = Paint()..color = const Color(0xFFF9E7C9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * .28, h - 10),
        width: w * .24,
        height: h * .12,
      ),
      paw,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + w * .12, h - 8),
        width: w * .24,
        height: h * .12,
      ),
      paw,
    );
    canvas.drawCircle(
      Offset(cx - w * .28, h - 11),
      w * .055,
      dark..color = const Color(0xFFF0B778),
    );
    canvas.drawCircle(
      Offset(cx + w * .12, h - 9),
      w * .055,
      Paint()..color = const Color(0xFFF0B778),
    );
  }

  @override
  bool shouldRepaint(covariant _PeekingCatPainter oldDelegate) =>
      oldDelegate.t != t;
}
