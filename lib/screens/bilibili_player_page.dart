import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../providers/app_providers.dart';

class BilibiliPlayerPage extends StatefulWidget {
  final String name;
  final String bvid;

  const BilibiliPlayerPage({
    super.key,
    required this.name,
    required this.bvid,
  });

  @override
  State<BilibiliPlayerPage> createState() => _BilibiliPlayerPageState();
}

class _BilibiliPlayerPageState extends State<BilibiliPlayerPage> {
  late final WebViewController _web;
  bool _loading = true;
  String? _error;

  String get _playerUrl =>
      'https://player.bilibili.com/player.html?bvid=${widget.bvid}'
      '&page=1&high_quality=1&danmaku=0&autoplay=1';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
            _web.runJavaScript(_injectedScript);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _loading = false;
              _error = 'B 站页面加载失败，请检查网络后重试。';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'about' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            if (uri.scheme != 'http' && uri.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            final host = uri.host.toLowerCase();
            if (host == 'bilibili.com' ||
                host.endsWith('.bilibili.com') ||
                host == 'b23.tv' ||
                host.endsWith('.b23.tv')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _web.setUserAgent(
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    );
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
    if (!mounted) return;
    await _web.loadRequest(Uri.parse(_playerUrl));
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _web.loadRequest(Uri.parse(_playerUrl));
  }

  void _handleBack() {
    if (mounted) Navigator.of(context).pop();
  }

  static const String _injectedScript = '''
(function() {
  if (window.__ftBiliInjected) return;
  window.__ftBiliInjected = true;
  var style = document.createElement('style');
  style.innerHTML = '.open-app-img,.open-app-btn,.launch-app-btn,.fixed-open-app{display:none!important;}';
  if (document.head) document.head.appendChild(style);
  document.addEventListener('click', function(e) {
    var a = e.target && e.target.closest ? e.target.closest('a') : null;
    if (!a) return;
    if (a.target === '_blank') a.target = '_self';
    if (a.href && a.href.indexOf('bilibili://') === 0) e.preventDefault();
  }, true);
})();
''';

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: spec.background,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'B 站 · 应用内播放',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _web)),
            if (_loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: spec.primary,
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: ColoredBox(
                  color: spec.background,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.smart_display_outlined,
                            size: 38,
                            color: spec.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 12.5,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
