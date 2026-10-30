import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../providers/app_providers.dart';
import '../services/epub_service.dart';
import '../theme/app_theme.dart';

class EpubReaderPage extends StatefulWidget {
  final EpubBook book;
  final int? initialChapter;

  const EpubReaderPage({
    super.key,
    required this.book,
    this.initialChapter,
  });

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage>
    with WidgetsBindingObserver {
  final EpubLibraryService _library = EpubLibraryService.instance;
  final WebViewController _web = WebViewController();

  late int _chapterIndex;
  SharedPreferences? _prefs;
  List<EpubHighlight> _highlights = const [];
  double _fontSize = 17;
  bool _dark = false;
  int _bgMode = 0;
  Set<int> _bookmarks = {};
  List<_Note> _notes = const [];
  bool _ready = false;
  bool _pageLoading = true;
  String? _error;
  String _lastSelection = '';
  DateTime _lastSelectionAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _selectionSheetOpen = false;

  EpubBook get _book => widget.book;

  EpubChapter get _chapter => _book.chapters[_chapterIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chapterIndex = widget.initialChapter ?? 0;
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _saveProgress();
  }

  Future<void> _bootstrap() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _fontSize = prefs.getDouble('epub_font_size') ?? 17;
    _bgMode = prefs.getInt('epub_bg_mode') ?? 0;
    _bookmarks = (prefs.getStringList('epub_bookmarks_${_book.id}') ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    _notes = _decodeNotes(prefs.getString('epub_notes_${_book.id}'));
    _dark = context.read<ThemeProvider>().currentSpec.isDark;
    _chapterIndex = (widget.initialChapter ??
            prefs.getInt('epub_progress_${_book.id}') ??
            0)
        .clamp(0, _book.chapters.length - 1);
    _highlights = await _library.highlightsFor(_book.id);
    _web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'FtReader',
        onMessageReceived: _handleJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _handlePageFinished(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _pageLoading = false;
                _error = '章节加载失败：${error.description}';
              });
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('file:')) {
              final path = Uri.tryParse(url)?.toFilePath();
              if (path == _chapter.filePath) {
                return NavigationDecision.navigate;
              }
              final found = _book.chapters
                  .indexWhere((chapter) => chapter.filePath == path);
              if (found >= 0) {
                _goToChapter(found);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            }
            if (url.startsWith('http://') || url.startsWith('https://')) {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    if (!mounted) return;
    if (_web.platform is AndroidWebViewController) {
      (_web.platform as AndroidWebViewController).setAllowFileAccess(true);
    }
    setState(() => _ready = true);
    await _loadChapter();
  }

  Future<void> _loadChapter() async {
    if (!mounted) return;
    setState(() {
      _pageLoading = true;
      _error = null;
    });
    await _saveProgress();
    try {
      final html = await _library.chapterHtml(
        _book,
        _chapter,
        fontSize: _fontSize,
        dark: _bgMode == 3 ? true : _dark,
        background: _bgColor(),
      );
      if (!mounted) return;
      await _web.loadHtmlString(
        html,
        baseUrl: Uri.directory(File(_chapter.filePath).parent.path).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pageLoading = false;
        _error = '无法打开这一章：$error';
      });
    }
  }

  Future<void> _handlePageFinished() async {
    if (!mounted) return;
    setState(() => _pageLoading = false);
    await _installSelectionListener();
    await _applyHighlights();
  }

  Future<void> _goToChapter(int index) async {
    if (index < 0 || index >= _book.chapters.length) return;
    if (index == _chapterIndex) return;
    setState(() => _chapterIndex = index);
    await _loadChapter();
  }

  Future<void> _saveProgress() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setInt('epub_progress_${_book.id}', _chapterIndex);
  }

  String? _bgColor() {
    switch (_bgMode) {
      case 1:
        return '#F6EFE3';
      case 2:
        return '#E8F0E3';
      case 3:
        return '#15181D';
      default:
        return null;
    }
  }

  Future<void> _setBgMode(int mode) async {
    setState(() => _bgMode = mode);
    await _prefs?.setInt('epub_bg_mode', mode);
    await _loadChapter();
  }

  bool get _isBookmarked => _bookmarks.contains(_chapterIndex);

  Future<void> _toggleBookmark() async {
    setState(() {
      if (_isBookmarked) {
        _bookmarks.remove(_chapterIndex);
      } else {
        _bookmarks.add(_chapterIndex);
      }
    });
    await _prefs?.setStringList(
      'epub_bookmarks_${_book.id}',
      _bookmarks.map((index) => index.toString()).toList(),
    );
    _snack(_isBookmarked ? '已添加书签' : '已移除书签');
  }

  List<_Note> _decodeNotes(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => _Note.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveNotes() async {
    await _prefs?.setString(
      'epub_notes_${_book.id}',
      jsonEncode(_notes.map((note) => note.toJson()).toList()),
    );
  }

  Future<void> _addNote(String quote) async {
    final spec = context.read<ThemeProvider>().currentSpec;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: spec.card,
          title: const Text('写小笺'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '写下你的想法…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _notes = [
        _Note(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          chapterIndex: _chapterIndex,
          chapterTitle: _chapter.title,
          quote: quote,
          text: text.trim(),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
        ..._notes,
      ];
    });
    await _saveNotes();
    _snack('已保存小笺');
  }

  Future<void> _removeNote(_Note note) async {
    setState(() => _notes = _notes.where((n) => n.id != note.id).toList());
    await _saveNotes();
  }

  Future<void> _clearHighlightsInPage() async {
    const script = r'''
(() => {
  document.querySelectorAll('mark.ft-highlight').forEach((mark) => {
    const parent = mark.parentNode;
    while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
    parent.removeChild(mark);
    parent.normalize();
  });
})();
''';
    try {
      await _web.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _installSelectionListener() async {
    const script = r'''
(() => {
  if (window.__ftSelectionInstalled) return;
  window.__ftSelectionInstalled = true;
  let timer = null;
  document.addEventListener('selectionchange', () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      const selection = window.getSelection();
      if (!selection) return;
      const text = selection.toString().replace(/\s+/g, ' ').trim();
      if (text.length >= 2) {
        FtReader.postMessage(JSON.stringify({type: 'selection', text: text}));
      }
    }, 520);
  });
})();
''';
    try {
      await _web.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _applyHighlights() async {
    final texts = _highlights
        .where((highlight) => highlight.chapterIndex == _chapterIndex)
        .map((highlight) => highlight.text)
        .where((text) => text.trim().isNotEmpty)
        .toList();
    if (texts.isEmpty) return;
    await _highlightTexts(texts);
  }

  Future<void> _highlightTexts(List<String> texts) async {
    final script = '''
(() => {
  const texts = ${jsonEncode(texts)};
  const walker = document.createTreeWalker(
    document.body,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        const parent = node.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;
        if (['SCRIPT', 'STYLE', 'MARK'].includes(parent.tagName)) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    }
  );
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  for (const text of texts) {
    if (!text || text.length < 2) continue;
    for (const node of nodes) {
      const value = node.nodeValue || '';
      const index = value.indexOf(text);
      if (index < 0) continue;
      const range = document.createRange();
      range.setStart(node, index);
      range.setEnd(node, index + text.length);
      const mark = document.createElement('mark');
      mark.className = 'ft-highlight';
      try {
        range.surroundContents(mark);
      } catch (error) {
        continue;
      }
      break;
    }
  }
})();
''';
    try {
      await _web.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _handleJsMessage(JavaScriptMessage message) async {
    if (message.message.isEmpty) return;
    dynamic data;
    try {
      data = jsonDecode(message.message);
    } catch (_) {
      return;
    }
    if (data is! Map || data['type'] != 'selection') return;
    final text = data['text']?.toString().trim() ?? '';
    if (text.length < 2 || _selectionSheetOpen) return;
    final now = DateTime.now();
    if (text == _lastSelection &&
        now.difference(_lastSelectionAt).inSeconds < 2) {
      return;
    }
    _lastSelection = text;
    _lastSelectionAt = now;
    if (mounted) await _showSelection(text);
  }

  Future<void> _showSelection(String rawText) async {
    final spec = context.read<ThemeProvider>().currentSpec;
    final text = rawText.length > 1400 ? rawText.substring(0, 1400) : rawText;
    _selectionSheetOpen = true;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: spec.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: spec.textPrimary.withValues(alpha: .08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: spec.textSecondary.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  '已选择文字',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 12.5,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, 'copy'),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('复制'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.pop(sheetContext, 'highlight'),
                        icon: const Icon(Icons.brush_rounded, size: 17),
                        label: const Text('划线'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.pop(sheetContext, 'note'),
                        icon: const Icon(Icons.sticky_note_2_rounded, size: 17),
                        label: const Text('小笺'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    _selectionSheetOpen = false;
    if (!mounted) return;
    try {
      await _web.runJavaScript('window.getSelection().removeAllRanges();');
    } catch (_) {}
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: rawText));
      _snack('已复制选中文字');
    } else if (action == 'highlight') {
      try {
        await _library.addHighlight(
          bookId: _book.id,
          chapterIndex: _chapterIndex,
          chapterTitle: _chapter.title,
          text: rawText,
        );
        final highlights = await _library.highlightsFor(_book.id);
        if (!mounted) return;
        setState(() => _highlights = highlights);
        await _highlightTexts([rawText]);
        _snack('已保存划线');
      } catch (error) {
        _snack('划线保存失败：$error');
      }
    } else if (action == 'note') {
      await _addNote(rawText);
    }
  }

  Future<void> _showToc() async {
    final spec = context.read<ThemeProvider>().currentSpec;
    final entries = _book.toc.isNotEmpty
        ? _book.toc
        : _book.chapters
            .map(
              (chapter) => EpubTocEntry(
                title: chapter.title,
                chapterIndex: chapter.index,
                level: 0,
              ),
            )
            .toList();
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: .82,
          child: Container(
            decoration: BoxDecoration(
              color: spec.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 12),
                      decoration: BoxDecoration(
                        color: spec.textSecondary.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '目录',
                                style: TextStyle(
                                  color: spec.textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_book.chapters.length} 章 · 当前第 ${_chapterIndex + 1} 章',
                                style: TextStyle(
                                  color: spec.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 22),
                      children: _buildTocTree(spec, sheetContext, entries),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result != null) await _goToChapter(result);
  }

  List<Widget> _buildTocTree(
    AppThemeSpec spec,
    BuildContext sheetContext,
    List<EpubTocEntry> entries,
  ) {
    final roots = <_TocNode>[];
    final stack = <_TocNode>[];
    for (final entry in entries) {
      final node = _TocNode(entry);
      while (stack.isNotEmpty && stack.last.entry.level >= entry.level) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        roots.add(node);
      } else {
        stack.last.children.add(node);
      }
      stack.add(node);
    }
    return roots.map((n) => _buildTocNode(spec, sheetContext, n, 0)).toList();
  }

  Widget _buildTocNode(
    AppThemeSpec spec,
    BuildContext sheetContext,
    _TocNode node,
    int depth,
  ) {
    final selected = node.entry.chapterIndex == _chapterIndex;
    if (node.children.isEmpty) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(left: 12 + depth * 18, right: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: selected ? spec.primary.withValues(alpha: .1) : null,
        title: Text(
          node.entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? spec.primary : spec.textPrimary,
            fontSize: 13,
            height: 1.4,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '第 ${node.entry.chapterIndex + 1} 章',
          style: TextStyle(color: spec.textSecondary, fontSize: 10.5),
        ),
        onTap: () => Navigator.pop(sheetContext, node.entry.chapterIndex),
      );
    }
    return Theme(
      data: Theme.of(sheetContext).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.only(left: 12 + depth * 18, right: 12),
        dense: true,
        title: Text(
          node.entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: spec.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          for (final child in node.children)
            _buildTocNode(spec, sheetContext, child, depth + 1),
        ],
      ),
    );
  }

  Future<void> _showSearch() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SearchSheet(book: _book),
    );
    if (result != null) await _goToChapter(result);
  }

  Future<void> _showHighlights() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HighlightsSheet(book: _book),
    );
    _highlights = await _library.highlightsFor(_book.id);
    if (!mounted) return;
    setState(() {});
    await _clearHighlightsInPage();
    await _applyHighlights();
    if (result != null) await _goToChapter(result);
  }

  Future<void> _showNotes() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotesSheet(
        notes: _notes,
        onDelete: _removeNote,
      ),
    );
    if (result != null) await _goToChapter(result);
  }

  Future<void> _showTextSettings() async {
    final spec = context.read<ThemeProvider>().currentSpec;
    var value = _fontSize;
    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: spec.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: spec.textSecondary.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      '阅读字号',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '正文会随字号重新排版',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'A',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: value,
                            min: 13,
                            max: 24,
                            divisions: 11,
                            onChanged: (next) =>
                                setSheetState(() => value = next),
                          ),
                        ),
                        Text(
                          'A',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, value),
                        child: const Text('应用字号'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (result == null || result == _fontSize) return;
    setState(() => _fontSize = result);
    await _prefs?.setDouble('epub_font_size', result);
    await _loadChapter();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _tapZone({required VoidCallback? onTap, required IconData icon}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 30,
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? const Color(0x22000000)
                : const Color(0x44000000),
          ),
        ),
      ),
    );
  }

  Future<void> _showBgSettings() async {
    final spec = context.read<ThemeProvider>().currentSpec;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: spec.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: spec.textSecondary.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '阅读底色',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '选择舒适的阅读背景',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _bgOption(sheetContext, 0, '默认', null, spec),
                    _bgOption(
                        sheetContext, 1, '米黄', const Color(0xFFF6EFE3), spec),
                    _bgOption(
                        sheetContext, 2, '护眼绿', const Color(0xFFE8F0E3), spec),
                    _bgOption(
                        sheetContext, 3, '夜间', const Color(0xFF15181D), spec),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null) await _setBgMode(result);
  }

  Widget _bgOption(
    BuildContext sheetContext,
    int mode,
    String label,
    Color? color,
    AppThemeSpec spec,
  ) {
    final active = _bgMode == mode;
    return GestureDetector(
      onTap: () => Navigator.pop(sheetContext, mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? spec.textPrimary.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                active ? spec.primary : spec.textPrimary.withValues(alpha: .08),
            width: active ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color == null
                ? spec.textPrimary
                : (color.computeLuminance() > .5
                    ? const Color(0xFF29231D)
                    : Colors.white),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    if (!_ready) {
      return Scaffold(
        backgroundColor: spec.background,
        body: Center(
          child: CircularProgressIndicator(color: spec.primary),
        ),
      );
    }
    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _book.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: spec.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '目录',
            onPressed: _showToc,
            icon: const Icon(Icons.format_list_bulleted_rounded),
          ),
          IconButton(
            tooltip: _isBookmarked ? '移除书签' : '添加书签',
            onPressed: _toggleBookmark,
            icon: Icon(
              _isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _isBookmarked ? spec.primary : null,
            ),
          ),
          IconButton(
            tooltip: '全书查找',
            onPressed: _showSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: '阅读设置',
            onSelected: (value) {
              if (value == 'highlights') _showHighlights();
              if (value == 'notes') _showNotes();
              if (value == 'font') _showTextSettings();
              if (value == 'bg') _showBgSettings();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'highlights',
                child: Text('我的划线'),
              ),
              PopupMenuItem(
                value: 'notes',
                child: Text('我的小笺'),
              ),
              PopupMenuItem(
                value: 'font',
                child: Text('调整字号'),
              ),
              PopupMenuItem(
                value: 'bg',
                child: Text('阅读底色'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: (_chapterIndex + 1) / _book.chapters.length,
              backgroundColor: spec.textPrimary.withValues(alpha: .05),
              color: spec.primary,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _tapZone(
                  onTap: _chapterIndex > 0
                      ? () => _goToChapter(_chapterIndex - 1)
                      : null,
                  icon: Icons.chevron_left_rounded,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WebViewWidget(controller: _web),
                      ),
                      if (_pageLoading)
                        Positioned.fill(
                          child: ColoredBox(
                            color: spec.background,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: spec.primary,
                                strokeWidth: 2.8,
                              ),
                            ),
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
                                      Icons.menu_book_rounded,
                                      size: 38,
                                      color: spec.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: spec.textSecondary,
                                        fontSize: 12,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: _loadChapter,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
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
                _tapZone(
                  onTap: _chapterIndex < _book.chapters.length - 1
                      ? () => _goToChapter(_chapterIndex + 1)
                      : null,
                  icon: Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 7),
              decoration: BoxDecoration(
                color: spec.background,
                border: Border(
                  top: BorderSide(
                    color: spec.textPrimary.withValues(alpha: .06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '上一章',
                    onPressed: _chapterIndex > 0
                        ? () => _goToChapter(_chapterIndex - 1)
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showToc,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_chapterIndex + 1} / ${_book.chapters.length}',
                              style: TextStyle(
                                color: spec.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '轻点查看目录',
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '下一章',
                    onPressed: _chapterIndex < _book.chapters.length - 1
                        ? () => _goToChapter(_chapterIndex + 1)
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  final EpubBook book;

  const _SearchSheet({required this.book});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final EpubLibraryService _library = EpubLibraryService.instance;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  List<EpubSearchResult> _results = const [];
  bool _searching = false;
  String _query = '';
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _query = query;
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final request = ++_requestId;
    setState(() {
      _query = query;
      _searching = true;
    });
    final results = await _library.search(widget.book, query);
    if (!mounted || request != _requestId) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return FractionallySizedBox(
      heightFactor: .9,
      child: Container(
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(
                    color: spec.textSecondary.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '全书查找',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      final query = value.trim();
                      if (query.length >= 2) _search(query);
                    },
                    decoration: InputDecoration(
                      hintText: '输入至少 2 个字，搜索全书',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                      filled: true,
                      fillColor: spec.textPrimary.withValues(alpha: .045),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_searching)
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: spec.primary,
                  ),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _searching
                                ? '正在逐章查找…'
                                : _query.length < 2
                                    ? '输入关键词开始查找'
                                    : '没有找到「$_query」',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: spec.textPrimary.withValues(alpha: .06),
                          ),
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return ListTile(
                              title: Text(
                                result.chapterTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: spec.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  result.snippet,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: spec.textSecondary,
                                    fontSize: 11.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              trailing: Text(
                                '${result.chapterIndex + 1}',
                                style: TextStyle(
                                  color: spec.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onTap: () => Navigator.pop(
                                context,
                                result.chapterIndex,
                              ),
                            );
                          },
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

class _HighlightsSheet extends StatefulWidget {
  final EpubBook book;

  const _HighlightsSheet({required this.book});

  @override
  State<_HighlightsSheet> createState() => _HighlightsSheetState();
}

class _HighlightsSheetState extends State<_HighlightsSheet> {
  final EpubLibraryService _library = EpubLibraryService.instance;
  List<EpubHighlight> _highlights = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final highlights = await _library.highlightsFor(widget.book.id);
    if (!mounted) return;
    setState(() {
      _highlights = highlights;
      _loading = false;
    });
  }

  Future<void> _delete(EpubHighlight highlight) async {
    await _library.removeHighlight(widget.book.id, highlight.id);
    final highlights = await _library.highlightsFor(widget.book.id);
    if (!mounted) return;
    setState(() => _highlights = highlights);
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return FractionallySizedBox(
      heightFactor: .72,
      child: Container(
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: spec.textSecondary.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '我的划线',
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_highlights.length} 条 · 仅保存在本机',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: spec.primary),
                      )
                    : _highlights.isEmpty
                        ? Center(
                            child: Text(
                              '还没有划线。长按选中正文后即可保存。',
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                            itemCount: _highlights.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: spec.textPrimary.withValues(alpha: .06),
                            ),
                            itemBuilder: (context, index) {
                              final highlight = _highlights[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                title: Text(
                                  highlight.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: spec.textPrimary,
                                    fontSize: 12.5,
                                    height: 1.5,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    highlight.chapterTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: spec.textSecondary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                                onTap: () => Navigator.pop(
                                  context,
                                  highlight.chapterIndex,
                                ),
                                trailing: IconButton(
                                  tooltip: '删除划线',
                                  onPressed: () => _delete(highlight),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: spec.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TocNode {
  final EpubTocEntry entry;
  final List<_TocNode> children = [];
  _TocNode(this.entry);
}

class _Note {
  final String id;
  final int chapterIndex;
  final String chapterTitle;
  final String quote;
  final String text;
  final int createdAt;

  const _Note({
    required this.id,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.quote,
    required this.text,
    required this.createdAt,
  });

  factory _Note.fromJson(Map<String, dynamic> json) {
    return _Note(
      id: json['id']?.toString() ?? '',
      chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterTitle: json['chapterTitle']?.toString() ?? '',
      quote: json['quote']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapterIndex': chapterIndex,
        'chapterTitle': chapterTitle,
        'quote': quote,
        'text': text,
        'createdAt': createdAt,
      };
}

class _NotesSheet extends StatelessWidget {
  final List<_Note> notes;
  final Future<void> Function(_Note) onDelete;

  const _NotesSheet({required this.notes, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return FractionallySizedBox(
      heightFactor: .72,
      child: Container(
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: spec.textSecondary.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '我的小笺',
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${notes.length} 条 · 选中文字后点「小笺」添加',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Text(
                          '还没有小笺。选中正文后点「小笺」写下想法。',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: spec.textPrimary.withValues(alpha: .06),
                        ),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            title: Text(
                              note.quote,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: spec.textPrimary,
                                      fontSize: 12.5,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    note.chapterTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: spec.textSecondary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () =>
                                Navigator.pop(context, note.chapterIndex),
                            trailing: IconButton(
                              tooltip: '删除小笺',
                              onPressed: () => onDelete(note),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: spec.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
