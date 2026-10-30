import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_providers.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _navigationTimer = Timer(const Duration(milliseconds: 1750), _enterApp);
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheAssets());
  }

  void _precacheAssets() {
    final themeProvider = context.read<ThemeProvider>();
    final path = themeProvider.customBackgroundPath;
    if (path == null || !File(path).existsSync()) return;
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    precacheImage(
      ResizeImage(
        FileImage(File(path)),
        width: (size.width * dpr).round(),
        height: (size.height * dpr).round(),
      ),
      context,
    );
  }

  void _enterApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) => const MainScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _enterApp,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final imageScale =
                1.08 + Curves.easeOut.transform(t.clamp(0, 1)) * .08;
            final titleT = Curves.easeOutCubic
                .transform(((t - .18) / .32).clamp(0.0, 1.0));
            final subtitleT =
                Curves.easeOutCubic.transform(((t - .36) / .3).clamp(0.0, 1.0));
            final lineT =
                Curves.easeOutCubic.transform(((t - .48) / .3).clamp(0.0, 1.0));
            final progressT =
                Curves.easeInOut.transform(((t - .55) / .4).clamp(0.0, 1.0));

            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: imageScale,
                  child: Image.asset(
                    'assets/images/splash_strength.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF090C11),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .58),
                        Colors.black.withValues(alpha: .28),
                        Colors.black.withValues(alpha: .78),
                        Colors.black.withValues(alpha: .96),
                      ],
                      stops: const [0, .34, .72, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: -size.width * .3,
                  top: -size.height * .1,
                  child: Container(
                    width: size.width * .9,
                    height: size.width * .9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          spec.primary.withValues(alpha: .22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Opacity(
                          opacity: titleT,
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .34),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: .22),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.asset(
                                    'assets/icon/app_icon.png',
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'IRON ETCHED',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Transform.translate(
                          offset: Offset(0, (1 - titleT) * 34),
                          child: Opacity(
                            opacity: titleT,
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.white,
                                  const Color(0xFFFFE3A8),
                                  spec.primary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                '铁镌',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 82,
                                  height: .95,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 10,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 30,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 64 * lineT,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [spec.primary, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Transform.translate(
                          offset: Offset(0, (1 - subtitleT) * 20),
                          child: Opacity(
                            opacity: subtitleT,
                            child: const Text(
                              '镌刻每一次撸铁',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 5.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: subtitleT * .72,
                          child: const Text(
                            '记录 · 分析 · 进阶',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Opacity(
                          opacity: subtitleT,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 4,
                                      color:
                                          Colors.white.withValues(alpha: .14),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progressT,
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              spec.primary,
                                              Colors.white,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    progressT >= 1 ? '准备就绪' : '正在唤醒你的力量…',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11.5,
                                      letterSpacing: .6,
                                    ),
                                  ),
                                  const Text(
                                    'v3.2.2',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
