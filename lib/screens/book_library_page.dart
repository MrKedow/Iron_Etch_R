import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../services/epub_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/book_download_dialog.dart';
import 'epub_reader_page.dart';

class BookLibraryPage extends StatefulWidget {
  const BookLibraryPage({super.key});

  @override
  State<BookLibraryPage> createState() => _BookLibraryPageState();
}

class _BookLibraryPageState extends State<BookLibraryPage> {
  final EpubLibraryService _library = EpubLibraryService.instance;
  bool _busy = false;
  bool _preparing = true;
  String _busyMessage = '正在准备书库…';
  String? _warning;
  bool _gridView = true;
  int _shelfMaterial = 1;
  bool _introVisible = true;

  static const List<String> _shelfMaterials = [
    '玻璃',
    '木质',
    '钢质',
    '瓷质',
    '镂空',
    '藤质',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _prepareLibrary();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gridView = prefs.getBool('library_grid_view') ?? true;
      _shelfMaterial =
          (prefs.getInt('library_shelf_material') ?? 1).clamp(0, 5);
      _introVisible = !(prefs.getBool('library_intro_hidden') ?? false);
    });
  }

  Future<void> _hideIntro() async {
    setState(() => _introVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('library_intro_hidden', true);
  }

  Future<void> _toggleView() async {
    setState(() => _gridView = !_gridView);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('library_grid_view', _gridView);
  }

  Future<void> _pickMaterial() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                const SizedBox(height: 14),
                Text(
                  '书架材质',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_shelfMaterials.length, (index) {
                    final active = _shelfMaterial == index;
                    return GestureDetector(
                      onTap: () => Navigator.pop(sheetContext, index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? spec.primary.withValues(alpha: .18)
                              : spec.textPrimary.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? spec.primary
                                : spec.textPrimary.withValues(alpha: .1),
                          ),
                        ),
                        child: Text(
                          _shelfMaterials[index],
                          style: TextStyle(
                            color: active ? spec.primary : spec.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _shelfMaterial = selected);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('library_shelf_material', selected);
  }

  Future<void> _prepareLibrary() async {
    try {
      await _library.load();
      await _library.adoptPendingDownload();
      final defaultBook = _library.defaultBook;
      if (defaultBook != null &&
          !defaultBook.deleted &&
          !_library.isExtracted(defaultBook) &&
          _library.isDefaultDownloaded) {
        if (mounted) {
          setState(() {
            _busyMessage = '正在解压内置书，请稍候…';
          });
        }
        final book = await _library.ensureDefaultReady();
        unawaited(_library.buildSearchIndex(book));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _warning = '内置书准备失败：$error');
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _downloadDefault() async {
    if (_library.isDefaultDownloaded) {
      final entry = _library.defaultBook;
      if (entry != null) await _openBook(entry);
      return;
    }
    final dialog = showBookDownloadDialog(context);
    try {
      await _library.downloadDefaultBook();
    } catch (error) {
      if (mounted) _showMessage('下载失败：$error');
    }
    await dialog;
    if (mounted) setState(() {});
  }

  Future<void> _openBook(EpubBookEntry entry) async {
    if (entry.deleted) {
      await _restoreBook(entry);
      return;
    }
    if (entry.builtIn && !_library.isDefaultDownloaded) {
      await _downloadDefault();
      return;
    }
    setState(() {
      _busy = true;
      _busyMessage = '正在打开《${entry.title}》…';
    });
    try {
      final book = entry.builtIn
          ? await _library.ensureDefaultReady()
          : await _library.parseEntry(entry);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('epub_progress_${entry.id}');
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpubReaderPage(
            book: book,
            initialChapter: saved,
          ),
        ),
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (error.toString().contains('正在准备中')) {
        _showMessage('书籍文件尚未准备完成');
        return;
      }
      _showMessage('打开失败：$error');
    }
  }

  Future<void> _restoreBook(EpubBookEntry entry) async {
    if (!_library.isDefaultDownloaded) {
      await _downloadDefault();
      return;
    }
    setState(() {
      _busy = true;
      _busyMessage = '正在恢复《${entry.title}》…';
    });
    try {
      final book = await _library.restoreDefault();
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpubReaderPage(book: book),
        ),
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('恢复失败：$error');
    }
  }

  Future<void> _importBook() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _showMessage('无法读取所选文件，请换一个 EPUB 试试。');
        return;
      }
      setState(() {
        _busy = true;
        _busyMessage = '正在导入并解析 EPUB…';
      });
      final entry = await _library.importBook(path);
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('已导入《${entry.title}》');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('导入失败：$error');
    }
  }

  Future<void> _deleteBook(EpubBookEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final spec = dialogContext.watch<ThemeProvider>().currentSpec;
        return AlertDialog(
          backgroundColor: spec.card,
          title: Text(entry.builtIn ? '删除内置书？' : '删除这本书？'),
          content: Text(
            entry.builtIn ? '封面会保留为灰色，之后可以随时恢复内置副本。' : '书籍文件和阅读划线将被移除，此操作不可撤销。',
            style: TextStyle(color: spec.textSecondary, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _busyMessage = '正在移除书籍…';
    });
    try {
      await _library.deleteBook(entry);
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(entry.builtIn ? '已删除，可点击灰色封面恢复' : '已删除');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('删除失败：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('铁镌书库'),
        actions: [
          IconButton(
            tooltip: _gridView ? '切换为列表' : '切换为网格',
            onPressed: _busy ? null : _toggleView,
            icon: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            tooltip: '书架材质',
            onPressed: _busy ? null : _pickMaterial,
            icon: const Icon(Icons.format_paint_rounded),
          ),
          IconButton(
            tooltip: '导入 EPUB',
            onPressed: _busy ? null : _importBook,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _busy || _preparing ? null : _prepareLibrary,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _ShelfBackground(material: _shelfMaterial),
          ),
          AnimatedBuilder(
            animation: _library,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                children: [
                  if (_introVisible)
                    GlassPanel(
                      padding: const EdgeInsets.all(17),
                      gradient: LinearGradient(
                        colors: [
                          spec.primary.withValues(alpha: .16),
                          spec.secondary.withValues(alpha: .06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Row(
                        children: [
                          GradientIconBadge(
                            icon: Icons.menu_book_rounded,
                            colors: [spec.primary, spec.secondary],
                            size: 44,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '让训练有迹可循',
                                  style: TextStyle(
                                    color: spec.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '内置《北科·健身全书》全 9 册，也可导入自己的 EPUB。',
                                  style: TextStyle(
                                    color: spec.textSecondary,
                                    fontSize: 11.5,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _hideIntro,
                            tooltip: '关闭',
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: spec.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_warning != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF97316).withValues(alpha: .22),
                        ),
                      ),
                      child: Text(
                        _warning!,
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  SectionHeader(
                    title: '书架',
                    subtitle: '轻点封面开始阅读，长按管理书籍',
                    trailing: Pill(
                      label: '${_library.books.length} 本',
                      icon: Icons.auto_stories_rounded,
                    ),
                    padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
                  ),
                  if (_library.books.isEmpty)
                    GlassPanel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.import_contacts_rounded,
                            size: 36,
                            color: spec.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '书架还是空的',
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '点击右上角 + 导入一本 EPUB。',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_gridView)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _library.books.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 20,
                        childAspectRatio: .5,
                      ),
                      itemBuilder: (context, index) {
                        final entry = _library.books[index];
                        return _BookCard(
                          entry: entry,
                          material: _shelfMaterial,
                          needsDownload:
                              entry.builtIn && !_library.isDefaultDownloaded,
                          onTap: _busy ? null : () => _openBook(entry),
                          onDelete: _busy ? null : () => _deleteBook(entry),
                        );
                      },
                    )
                  else
                    Column(
                      children: [
                        for (var index = 0;
                            index < _library.books.length;
                            index++)
                          _BookListTile(
                            entry: _library.books[index],
                            needsDownload: _library.books[index].builtIn &&
                                !_library.isDefaultDownloaded,
                            onTap: _busy
                                ? null
                                : () => _openBook(_library.books[index]),
                            onDelete: _busy
                                ? null
                                : () => _deleteBook(_library.books[index]),
                          ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Text(
                    '支持 EPUB 2 / EPUB 3。划线、目录、全书查找和阅读进度会自动保存在本机。',
                    style: TextStyle(
                      color: spec.textSecondary.withValues(alpha: .75),
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ],
              );
            },
          ),
          if (_busy || _preparing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: .46),
                alignment: Alignment.center,
                child: Container(
                  width: 246,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  decoration: BoxDecoration(
                    color: spec.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: spec.textPrimary.withValues(alpha: .08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .25),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.2,
                          color: spec.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _busyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final EpubBookEntry entry;
  final int material;
  final bool needsDownload;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _BookCard({
    required this.entry,
    required this.material,
    required this.needsDownload,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final library = context.watch<EpubLibraryService>();
    final coverFile = entry.coverPath == null ? null : File(entry.coverPath!);
    final hasCover = coverFile != null && coverFile.existsSync();
    final downloadInfo = library.downloadProgressFor(entry.id);

    Widget cover = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            spec.primary.withValues(alpha: .82),
            spec.secondary.withValues(alpha: .66),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -20,
            top: -16,
            child: Icon(
              Icons.menu_book_rounded,
              size: 112,
              color: Colors.white.withValues(alpha: .14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const Spacer(),
                if (downloadInfo == null) ...[
                  Text(
                    entry.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  if (entry.author.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      entry.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (entry.builtIn)
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '内置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (hasCover) {
      final fallback = cover;
      cover = Container(
        color: Colors.black.withValues(alpha: .16),
        child: Image.file(
          coverFile,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    if (entry.deleted) {
      cover = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: cover,
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0016)
                      ..rotateX(-0.42),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: spec.textPrimary.withValues(alpha: .1),
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                cover,
                                if (needsDownload && downloadInfo != null)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withValues(alpha: .36),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 54,
                                            height: 54,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  value: downloadInfo.progress
                                                      .clamp(0.0, 1.0),
                                                  strokeWidth: 4,
                                                  color: Colors.white,
                                                  backgroundColor: Colors.white
                                                      .withValues(alpha: .24),
                                                ),
                                                Text(
                                                  '${(downloadInfo.progress * 100).toStringAsFixed(0)}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            formatDownloadSpeed(
                                                downloadInfo
                                                    .speedBytesPerSecond),
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                  alpha: .86),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (entry.deleted)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.black.withValues(alpha: .28),
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .48),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: .28),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '点击恢复',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (needsDownload && downloadInfo == null)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.black.withValues(alpha: .28),
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .48),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: .28),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.download_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '点击下载',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 3,
                          top: 3,
                          child: Material(
                            color: Colors.black.withValues(alpha: .28),
                            shape: const CircleBorder(),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: PopupMenuButton<String>(
                                tooltip: '管理书籍',
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                onSelected: (_) => onDelete?.call(),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除书籍'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 8,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _shelfSpecs[material.clamp(0, _shelfSpecs.length - 1)]
                            .boardEdge,
                        _shelfSpecs[material.clamp(0, _shelfSpecs.length - 1)]
                            .board,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.deleted
                ? '已删除 · 可恢复'
                : (entry.author.isEmpty ? 'EPUB' : entry.author),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  entry.deleted ? const Color(0xFFF97316) : spec.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ShelfMaterial { glass, wood, steel, porcelain, lattice, rattan }

class _ShelfSpec {
  final _ShelfMaterial type;
  final List<Color> gradient;
  final Color board;
  final Color boardEdge;
  const _ShelfSpec(this.type, this.gradient, this.board, this.boardEdge);
}

const List<_ShelfSpec> _shelfSpecs = [
  _ShelfSpec(_ShelfMaterial.glass, [Color(0xFF33556A), Color(0xFF1B2C38)],
      Color(0xFF5B7D92), Color(0xFF33556A)),
  _ShelfSpec(_ShelfMaterial.wood, [Color(0xFF8A5A2B), Color(0xFF4E2E12)],
      Color(0xFF9A6A38), Color(0xFF5C3A1A)),
  _ShelfSpec(_ShelfMaterial.steel, [Color(0xFF4A515C), Color(0xFF22262C)],
      Color(0xFF6A737F), Color(0xFF3A4048)),
  _ShelfSpec(_ShelfMaterial.porcelain, [Color(0xFFF2ECE2), Color(0xFFD8CEBC)],
      Color(0xFFFBF6EC), Color(0xFFC9BEA9)),
  _ShelfSpec(_ShelfMaterial.lattice, [Color(0xFF23272E), Color(0xFF12151A)],
      Color(0xFF3A3230), Color(0xFF221D1B)),
  _ShelfSpec(_ShelfMaterial.rattan, [Color(0xFF4E6B3A), Color(0xFF2C3E1F)],
      Color(0xFF6B8A52), Color(0xFF39502A)),
];

class _ShelfBackground extends StatelessWidget {
  final int material;
  const _ShelfBackground({required this.material});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          _ShelfPainter(_shelfSpecs[material.clamp(0, _shelfSpecs.length - 1)]),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  final _ShelfSpec spec;
  _ShelfPainter(this.spec);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: spec.gradient,
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    switch (spec.type) {
      case _ShelfMaterial.wood:
        _paintWood(canvas, size);
      case _ShelfMaterial.steel:
        _paintSteel(canvas, size);
      case _ShelfMaterial.glass:
        _paintGlass(canvas, size);
      case _ShelfMaterial.porcelain:
        _paintPorcelain(canvas, size);
      case _ShelfMaterial.lattice:
        _paintLattice(canvas, size);
      case _ShelfMaterial.rattan:
        _paintRattan(canvas, size);
    }

    _paintBoards(canvas, size);
  }

  void _paintBoards(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .18)
      ..strokeWidth = 3;
    final light = Paint()
      ..color = Colors.white.withValues(alpha: .10)
      ..strokeWidth = 1.5;
    for (double y = 0; y < size.height; y += 240) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), shadow);
      canvas.drawLine(Offset(0, y + 3), Offset(size.width, y + 3), light);
    }
  }

  void _paintWood(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final grain = Paint()..strokeWidth = 1;
    for (double y = 6; y < size.height; y += 5 + rnd.nextDouble() * 6) {
      grain.color =
          Colors.black.withValues(alpha: .05 + rnd.nextDouble() * .07);
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 48) {
        path.lineTo(x, y + math.sin(x * .018 + y) * 2.6);
      }
      canvas.drawPath(path, grain);
    }
    final knot = Paint()
      ..color = Colors.black.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 4; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = rnd.nextDouble() * size.height;
      for (var r = 3.0; r <= 12; r += 3) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r),
          knot,
        );
      }
    }
  }

  void _paintSteel(Canvas canvas, Size size) {
    final brush = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brush);
    }
    final band = Paint();
    for (double y = 0; y < size.height; y += 48) {
      band.color =
          Colors.white.withValues(alpha: ((y ~/ 48) % 2 == 0) ? .04 : 0);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 24), band);
    }
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .14),
          Colors.transparent,
          Colors.white.withValues(alpha: .05),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, highlight);
  }

  void _paintGlass(Canvas canvas, Size size) {
    final tint = Paint()
      ..color = const Color(0xFF9CC6E0).withValues(alpha: .08);
    canvas.drawRect(Offset.zero & size, tint);
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: .10)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    for (double x = -size.height; x < size.width; x += size.width / 4) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), streak);
    }
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Offset.zero & size, edge);
  }

  void _paintPorcelain(Canvas canvas, Size size) {
    final highlight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.4, -.6),
        radius: 1.3,
        colors: [
          Colors.white.withValues(alpha: .55),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, highlight);
  }

  void _paintLattice(Canvas canvas, Size size) {
    final carve = Paint()
      ..color = const Color(0xFF5C4638).withValues(alpha: .55)
      ..strokeWidth = 2;
    const step = 30.0;
    for (double y = -size.height; y < size.height * 2; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width), carve);
      canvas.drawLine(Offset(0, y), Offset(size.width, y - size.width), carve);
    }
    final hole = Paint()
      ..color = Colors.black.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 4, hole);
      }
    }
  }

  void _paintRattan(Canvas canvas, Size size) {
    const step = 22.0;
    final h = Paint()
      ..color = const Color(0xFF4E6B3A)
      ..strokeWidth = 3;
    final v = Paint()
      ..color = const Color(0xFF2C3E1F)
      ..strokeWidth = 3;
    for (double y = step / 2; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), h);
    }
    for (double x = step / 2; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), v);
    }
    final hl = Paint()
      ..color = const Color(0xFF7FA060).withValues(alpha: .45)
      ..strokeWidth = 1.5;
    for (double y = step / 2; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hl);
    }
  }

  @override
  bool shouldRepaint(covariant _ShelfPainter oldDelegate) =>
      oldDelegate.spec != spec;
}

class _BookListTile extends StatelessWidget {
  final EpubBookEntry entry;
  final bool needsDownload;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _BookListTile({
    required this.entry,
    required this.needsDownload,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final library = context.watch<EpubLibraryService>();
    final coverFile = entry.coverPath == null ? null : File(entry.coverPath!);
    final hasCover = coverFile != null && coverFile.existsSync();
    final downloadInfo = library.downloadProgressFor(entry.id);

    Widget thumb = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            spec.primary.withValues(alpha: .82),
            spec.secondary.withValues(alpha: .66),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.auto_stories_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
    if (hasCover) {
      thumb = Image.file(
        coverFile,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => thumb,
      );
    }
    if (entry.deleted) {
      thumb = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: thumb,
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: spec.textPrimary.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: spec.textPrimary.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumb,
                    if (needsDownload && downloadInfo != null)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: .36),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  value:
                                      downloadInfo.progress.clamp(0.0, 1.0),
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: .24),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                formatDownloadSpeed(
                                    downloadInfo.speedBytesPerSecond),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.deleted
                        ? '已删除 · 可恢复'
                        : needsDownload
                            ? (downloadInfo != null
                                ? '下载中 ${(downloadInfo.progress * 100).toStringAsFixed(0)}% · ${formatDownloadSpeed(downloadInfo.speedBytesPerSecond)}'
                                : '未下载 · 点击下载')
                            : (entry.author.isEmpty ? 'EPUB' : entry.author),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: entry.deleted || needsDownload
                          ? const Color(0xFFF97316)
                          : spec.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: spec.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
