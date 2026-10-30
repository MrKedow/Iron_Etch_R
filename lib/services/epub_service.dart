import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

class EpubException implements Exception {
  final String message;
  const EpubException(this.message);

  @override
  String toString() => message;
}

class EpubChapter {
  final int index;
  final String id;
  final String filePath;
  final String title;

  const EpubChapter({
    required this.index,
    required this.id,
    required this.filePath,
    required this.title,
  });
}

class EpubTocEntry {
  final String title;
  final int chapterIndex;
  final int level;

  const EpubTocEntry({
    required this.title,
    required this.chapterIndex,
    required this.level,
  });
}

class EpubBook {
  final String id;
  final String title;
  final String author;
  final String rootPath;
  final List<EpubChapter> chapters;
  final List<EpubTocEntry> toc;
  final String? coverPath;

  const EpubBook({
    required this.id,
    required this.title,
    required this.author,
    required this.rootPath,
    required this.chapters,
    required this.toc,
    required this.coverPath,
  });

  String get displayTitle => title.trim().isEmpty ? '未命名书籍' : title.trim();
}

class EpubBookEntry {
  String id;
  String title;
  String author;
  String rootPath;
  bool builtIn;
  bool deleted;
  String? coverPath;
  int addedAt;

  EpubBookEntry({
    required this.id,
    required this.title,
    required this.author,
    required this.rootPath,
    required this.builtIn,
    required this.deleted,
    this.coverPath,
    required this.addedAt,
  });

  factory EpubBookEntry.fromJson(Map<String, dynamic> json) {
    return EpubBookEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      rootPath: json['rootPath']?.toString() ?? '',
      builtIn: json['builtIn'] == true,
      deleted: json['deleted'] == true,
      coverPath: json['coverPath']?.toString(),
      addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'rootPath': rootPath,
    'builtIn': builtIn,
    'deleted': deleted,
    'coverPath': coverPath,
    'addedAt': addedAt,
  };
}

class EpubHighlight {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String text;
  final int createdAt;

  const EpubHighlight({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.text,
    required this.createdAt,
  });

  factory EpubHighlight.fromJson(Map<String, dynamic> json) {
    return EpubHighlight(
      id: json['id']?.toString() ?? '',
      bookId: json['bookId']?.toString() ?? '',
      chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterTitle: json['chapterTitle']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'chapterIndex': chapterIndex,
    'chapterTitle': chapterTitle,
    'text': text,
    'createdAt': createdAt,
  };
}

class EpubSearchResult {
  final int chapterIndex;
  final String chapterTitle;
  final String snippet;

  const EpubSearchResult({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.snippet,
  });
}

class BookDownloadProgress {
  final double progress;
  final double speedBytesPerSecond;
  final DateTime updatedAt;

  const BookDownloadProgress({
    required this.progress,
    required this.speedBytesPerSecond,
    required this.updatedAt,
  });
}

class EpubLibraryService extends ChangeNotifier {
  EpubLibraryService._();

  static final EpubLibraryService instance = EpubLibraryService._();

  static const String defaultId = 'north_science_fitness';
  static const String defaultAssetPath =
      'flutter_assets/assets/books/iron_book.epub';
  /// Optional private/self-hosted book source. Configure at build time with
  /// `--dart-define=IRON_BOOK_URL=...`; no public distribution URL is shipped.
  static const String defaultDownloadUrl = String.fromEnvironment(
    'IRON_BOOK_URL',
    defaultValue:
        'https://media.githubusercontent.com/media/MrKedow/Iron_Etch_R/main/assets/books/iron_book.epub',
  );
  static const String _downloadFileName = 'iron_book.epub';
  static const MethodChannel _channel = MethodChannel('com.mrkedow.opensource.ironetch/epub');

  Directory? _baseDir;
  Directory? _coverDir;
  List<EpubBookEntry> _books = [];
  final Map<String, EpubBook> _bookCache = {};
  final Map<String, List<EpubHighlight>> _highlightCache = {};
  final Map<String, Map<int, String>> _searchIndexCache = {};
  Future<void>? _defaultExtraction;
  Future<void>? _defaultDownloadFuture;
  bool _loaded = false;
  bool _defaultDownloading = false;
  double _defaultDownloadProgress = 0;
  double _defaultDownloadSpeed = 0;
  final Map<String, BookDownloadProgress> _downloadProgressMap = {};
  final ValueNotifier<int> downloadCompleted = ValueNotifier<int>(0);

  List<EpubBookEntry> get books => List.unmodifiable(_books);
  bool get loaded => _loaded;
  bool get isDefaultDownloading => _defaultDownloading;
  double get defaultDownloadProgress => _defaultDownloadProgress;
  double get defaultDownloadSpeed => _defaultDownloadSpeed;
  BookDownloadProgress? downloadProgressFor(String bookId) =>
      _downloadProgressMap[bookId];

  EpubBookEntry? get defaultBook {
    for (final book in _books) {
      if (book.id == defaultId) return book;
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    final docs = await getApplicationDocumentsDirectory();
    _baseDir = Directory('${docs.path}/books');
    _coverDir = Directory('${_baseDir!.path}/covers');
    await _baseDir!.create(recursive: true);
    await _coverDir!.create(recursive: true);
    final libraryFile = File('${_baseDir!.path}/library.json');
    if (await libraryFile.exists()) {
      try {
        final data = jsonDecode(await libraryFile.readAsString());
        if (data is List) {
          _books = data
              .whereType<Map>()
              .map(
                (item) =>
                    EpubBookEntry.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.isNotEmpty)
              .toList();
        }
      } catch (_) {
        _books = [];
      }
    }
    if (defaultBook == null) {
      _books.insert(
        0,
        EpubBookEntry(
          id: defaultId,
          title: '北科·健身全书（全9册）',
          author: '北科健身编辑组',
          rootPath: '${_baseDir!.path}/$defaultId',
          builtIn: true,
          deleted: false,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _saveLibrary();
    }
    await _loadAllHighlights();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadAllHighlights() async {
    final file = File('${_baseDir!.path}/highlights.json');
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      for (final entry in data.entries) {
        final list = entry.value;
        if (entry.key is! String || list is! List) continue;
        _highlightCache[entry.key as String] = list
            .whereType<Map>()
            .map(
              (item) => EpubHighlight.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (_) {}
  }

  bool isExtracted(EpubBookEntry entry) {
    return File('${entry.rootPath}/.ft_extracted').existsSync() &&
        File('${entry.rootPath}/META-INF/container.xml').existsSync();
  }

  File _defaultEpubFile() => File('${_baseDir!.path}/$defaultId.epub');

  File _defaultDoneMarker() => File('${_baseDir!.path}/$defaultId.epub.done');

  bool get isDefaultDownloaded {
    final entry = defaultBook;
    if (entry == null) return false;
    if (isExtracted(entry)) return true;
    if (_defaultDownloading) return false;
    final epub = _defaultEpubFile();
    if (!epub.existsSync() || !_defaultDoneMarker().existsSync()) return false;
    return _looksLikeCompleteZip(epub);
  }

  /// 检查文件是否为一个完整的 ZIP（EPUB）容器：
  /// 头部为 PK\\x03\\x04，且尾部存在 ZIP 结束记录 PK\\x05\\x06。
  bool _looksLikeCompleteZip(File file) {
    try {
      if (!file.existsSync() || file.lengthSync() < 64 * 1024) return false;
      final raf = file.openSync();
      try {
        final head = raf.readSync(4);
        if (head.length < 4 ||
            head[0] != 0x50 ||
            head[1] != 0x4B ||
            head[2] != 0x03 ||
            head[3] != 0x04) {
          return false;
        }
        final length = raf.lengthSync();
        final tailLength = length < 66560 ? length : 66560;
        raf.setPositionSync(length - tailLength);
        final tail = raf.readSync(tailLength);
        for (var i = tail.length - 4; i >= 0; i--) {
          if (tail[i] == 0x50 &&
              tail[i + 1] == 0x4B &&
              tail[i + 2] == 0x05 &&
              tail[i + 3] == 0x06) {
            return true;
          }
        }
        return false;
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _markDefaultDownloaded() async {
    try {
      await _defaultDoneMarker().writeAsString('ok');
    } catch (_) {}
  }

  /// 后台下载（Android DownloadManager）完成但尚未导入时，复制到内部缓存。
  /// 只有确认外部文件是完整 EPUB 时才会采纳，避免把半截下载当成品。
  Future<void> adoptPendingDownload() async {
    if (!Platform.isAndroid) return;
    await load();
    if (_defaultDownloading || _defaultDownloadFuture != null) return;
    final epubFile = _defaultEpubFile();
    if (await epubFile.exists()) return;
    if (await _adoptExternal(epubFile)) {
      await _markDefaultDownloaded();
    }
  }

  Future<void> downloadDefaultBook({
    void Function(double progress)? onProgress,
    void Function(double progress, double speed)? onProgressWithSpeed,
  }) {
    final existing = _defaultDownloadFuture;
    if (existing != null) return existing;
    final future = _downloadDefaultBookInternal(
      onProgress: onProgress,
      onProgressWithSpeed: onProgressWithSpeed,
    );
    _defaultDownloadFuture = future;
    return future.whenComplete(() => _defaultDownloadFuture = null);
  }

  Future<void> _downloadDefaultBookInternal({
    void Function(double progress)? onProgress,
    void Function(double progress, double speed)? onProgressWithSpeed,
  }) async {
    await load();
    final entry = defaultBook;
    if (entry == null) throw const EpubException('默认书不存在');
    if (isExtracted(entry)) {
      await _markDefaultDownloaded();
      return;
    }
    _defaultDownloading = true;
    _defaultDownloadProgress = 0;
    _defaultDownloadSpeed = 0;
    _downloadProgressMap[defaultId] = BookDownloadProgress(
      progress: 0,
      speedBytesPerSecond: 0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    try {
      final epubFile = _defaultEpubFile();
      if (!await epubFile.exists() || !_looksLikeCompleteZip(epubFile)) {
        if (await epubFile.exists()) {
          try {
            await epubFile.delete();
          } catch (_) {}
        }
        await _retrieveEpub(
          epubFile,
          (progress) {
            _defaultDownloadProgress = progress;
            onProgress?.call(progress);
            _downloadProgressMap[defaultId] = BookDownloadProgress(
              progress: progress,
              speedBytesPerSecond: _defaultDownloadSpeed,
              updatedAt: DateTime.now(),
            );
            notifyListeners();
          },
          (speed) {
            _defaultDownloadSpeed = speed;
            onProgressWithSpeed?.call(_defaultDownloadProgress, speed);
            _downloadProgressMap[defaultId] = BookDownloadProgress(
              progress: _defaultDownloadProgress,
              speedBytesPerSecond: speed,
              updatedAt: DateTime.now(),
            );
            notifyListeners();
          },
        );
      }
      if (!_looksLikeCompleteZip(epubFile)) {
        try {
          await epubFile.delete();
        } catch (_) {}
        throw const EpubException('下载文件不完整，请重试');
      }
      await _markDefaultDownloaded();
      await _ensureExtracted(entry);
      EpubBook book;
      try {
        book = await _parseBook(entry);
      } catch (_) {
        await _extractFile(epubFile.path, entry.rootPath);
        book = await _parseBook(entry);
      }
      _bookCache[entry.id] = book;
      _applyMetadata(entry, book);
      _downloadProgressMap[defaultId] = BookDownloadProgress(
        progress: 1,
        speedBytesPerSecond: 0,
        updatedAt: DateTime.now(),
      );
      await _saveLibrary();
      downloadCompleted.value++;
    } finally {
      _defaultDownloading = false;
      _defaultDownloadProgress = 0;
      _defaultDownloadSpeed = 0;
      notifyListeners();
    }
  }

  Future<void> _ensureExtracted(EpubBookEntry entry) async {
    if (isExtracted(entry)) return;
    final epubFile = _defaultEpubFile();
    if (!await epubFile.exists()) {
      throw const EpubException('内置书尚未下载，请先下载');
    }
    await (_defaultExtraction ??= _extractFile(
      epubFile.path,
      entry.rootPath,
    ).whenComplete(() => _defaultExtraction = null));
    if (!isExtracted(entry)) {
      throw const EpubException('书籍解压失败，请重新下载');
    }
  }

  Future<void> _retrieveEpub(
    File epubFile,
    void Function(double)? onProgress,
    void Function(double speed)? onSpeed,
  ) async {
    if (await _adoptExternal(epubFile)) return;
    final downloadUrl = defaultDownloadUrl.trim();
    if (downloadUrl.isEmpty) {
      throw const EpubException('未配置书籍下载地址，请手动导入 EPUB');
    }
    final candidates = <String>[downloadUrl];
    final ranked = await _rankedUrls(candidates);
    final ordered = ranked.isEmpty ? candidates : ranked;
    Object? lastError;
    for (final url in ordered) {
      try {
        if (Platform.isAndroid &&
            await _nativeDownload(url, epubFile, onProgress, onSpeed)) {
          return;
        }
        await _dartDownload(url, epubFile, onProgress, onSpeed);
        return;
      } catch (error) {
        lastError = error;
        try {
          final part = File('${epubFile.path}.part');
          if (await part.exists()) await part.delete();
        } catch (_) {}
      }
    }
    throw EpubException('下载失败：${lastError ?? '所有下载源均不可用'}');
  }

  Future<bool> _adoptExternal(File epubFile) async {
    if (!Platform.isAndroid) return false;
    try {
      final path = await _channel.invokeMethod<String>('externalDownloadPath', {
        'fileName': _downloadFileName,
      });
      if (path == null) return false;
      final file = File(path);
      if (_looksLikeCompleteZip(file)) {
        await file.copy(epubFile.path);
        try {
          await file.delete();
        } catch (_) {}
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// 并行探测所有候选源，返回按实测速度从快到慢排序的可用链接。
  Future<List<String>> _rankedUrls(List<String> urls) async {
    final results = await Future.wait(urls.map(_probeUrl));
    final ranked = <MapEntry<String, int>>[];
    for (var i = 0; i < urls.length; i++) {
      final ms = results[i];
      if (ms != null) ranked.add(MapEntry(urls[i], ms));
    }
    ranked.sort((a, b) => a.value.compareTo(b.value));
    return ranked.map((entry) => entry.key).toList();
  }

  /// 返回响应耗时（毫秒）；失败、超时或内容不是 EPUB 时返回 null。
  Future<int?> _probeUrl(String url) async {
    http.Client? client;
    try {
      client = http.Client();
      final sw = Stopwatch()..start();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=0-4095';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200 && response.statusCode != 206) return null;
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 5),
      )) {
        bytes.addAll(chunk);
        if (bytes.length >= 512) break;
      }
      if (bytes.length < 4) return null;
      // EPUB 是 ZIP 容器，文件头必须是 "PK" (0x50 0x4B)。
      final isZip = bytes[0] == 0x50 && bytes[1] == 0x4B;
      if (!isZip) return null;
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    } finally {
      client?.close();
    }
  }

  Future<bool> _nativeDownload(
    String url,
    File epubFile,
    void Function(double)? onProgress,
    void Function(double speed)? onSpeed,
  ) async {
    try {
      final start = await _channel.invokeMapMethod<String, dynamic>(
        'enqueueDownload',
        {'url': url, 'fileName': _downloadFileName},
      );
      if (start == null) return false;
      final id = (start['id'] as num).toInt();
      final path = start['path'] as String;
      var lastBytes = 0;
      final speedWatch = Stopwatch()..start();
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final status = await _channel.invokeMapMethod<String, dynamic>(
          'downloadStatus',
          {'downloadId': id},
        );
        if (status == null) return false;
        final code = (status['status'] as num).toInt();
        final downloaded = (status['downloaded'] as num).toInt();
        final total = (status['total'] as num).toInt();
        if (speedWatch.elapsedMilliseconds >= 500) {
          final delta = downloaded - lastBytes;
          if (delta > 0) {
            onSpeed?.call(delta / speedWatch.elapsedMilliseconds * 1000.0);
          }
          lastBytes = downloaded;
          speedWatch.reset();
        }
        if (total > 0) {
          onProgress?.call((downloaded / total).clamp(0.0, 1.0));
        }
        if (code == 8) {
          final file = File(path);
          if (_looksLikeCompleteZip(file)) {
            await file.copy(epubFile.path);
            try {
              await file.delete();
            } catch (_) {}
            return true;
          }
          try {
            await file.delete();
          } catch (_) {}
          return false;
        }
        if (code == 16 || code == -1) return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _dartDownload(
    String url,
    File epubFile,
    void Function(double)? onProgress,
    void Function(double speed)? onSpeed,
  ) async {
    final partFile = File('${epubFile.path}.part');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw EpubException('下载失败：HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = partFile.openWrite();
      final sw = Stopwatch()..start();
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          sink.add(chunk);
          received += chunk.length;
          if (sw.elapsedMilliseconds > 300) {
            final speed = (received / sw.elapsedMilliseconds) * 1000.0;
            onSpeed?.call(speed);
          }
          if (total > 0) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          } else if (sw.elapsedMilliseconds > 500) {
            onProgress?.call((received / (1024 * 1024 * 50)).clamp(0.0, 0.99));
          }
        }
      } finally {
        await sink.close();
      }
      if (!_looksLikeCompleteZip(partFile)) {
        throw const EpubException('下载文件不完整，请重试');
      }
      await partFile.rename(epubFile.path);
    } catch (_) {
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<EpubBook> ensureDefaultReady() async {
    await load();
    final entry = defaultBook;
    if (entry == null) throw const EpubException('默认书不存在');
    if (entry.deleted) throw const EpubException('默认书已被删除，请重新下载');
    final cached = _bookCache[entry.id];
    if (cached != null && isExtracted(entry)) return cached;
    await _ensureExtracted(entry);
    EpubBook book;
    try {
      book = await _parseBook(entry);
    } catch (_) {
      await _extractFile(_defaultEpubFile().path, entry.rootPath);
      book = await _parseBook(entry);
    }
    _bookCache[entry.id] = book;
    _applyMetadata(entry, book);
    await _saveLibrary();
    notifyListeners();
    return book;
  }

  Future<EpubBookEntry> importBook(String sourcePath) async {
    await load();
    final source = File(sourcePath);
    if (!await source.exists()) throw const EpubException('找不到所选 EPUB 文件');
    if (!sourcePath.toLowerCase().endsWith('.epub')) {
      throw const EpubException('只支持导入 EPUB 文件');
    }
    final id = 'book_${DateTime.now().microsecondsSinceEpoch}';
    final root = '${_baseDir!.path}/$id';
    await _extractFile(sourcePath, root);
    final entry = EpubBookEntry(
      id: id,
      title: source.uri.pathSegments.last.replaceAll('.epub', ''),
      author: '',
      rootPath: root,
      builtIn: false,
      deleted: false,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      final book = await parseEntry(entry);
      _applyMetadata(entry, book);
    } catch (error) {
      try {
        await Directory(root).delete(recursive: true);
      } catch (_) {}
      throw EpubException('无法解析这本书：$error');
    }
    _books.add(entry);
    await _saveLibrary();
    notifyListeners();
    return entry;
  }

  Future<void> deleteBook(EpubBookEntry entry) async {
    await load();
    try {
      await Directory(entry.rootPath).delete(recursive: true);
    } catch (_) {}
    _bookCache.remove(entry.id);
    _searchIndexCache.remove(entry.id);
    if (entry.builtIn) {
      entry.deleted = true;
      entry.rootPath = '${_baseDir!.path}/$defaultId';
    } else {
      _books.removeWhere((item) => item.id == entry.id);
      _highlightCache.remove(entry.id);
      await _saveHighlights();
      if (entry.coverPath != null) {
        try {
          final cover = File(entry.coverPath!);
          if (await cover.exists()) await cover.delete();
        } catch (_) {}
      }
    }
    await _saveLibrary();
    notifyListeners();
  }

  Future<EpubBook> restoreDefault() async {
    await load();
    final entry = defaultBook;
    if (entry == null) throw const EpubException('默认书不存在');
    entry.deleted = false;
    entry.rootPath = '${_baseDir!.path}/$defaultId';
    await _saveLibrary();
    return ensureDefaultReady();
  }

  Future<EpubBook> parseEntry(EpubBookEntry entry) async {
    final cached = _bookCache[entry.id];
    if (cached != null && isExtracted(entry)) return cached;
    if (!isExtracted(entry)) {
      if (entry.builtIn) {
        final epub = _defaultEpubFile();
        if (await epub.exists() && _looksLikeCompleteZip(epub)) {
          try {
            await _ensureExtracted(entry);
          } catch (_) {}
        }
      }
      if (!isExtracted(entry)) {
        throw const EpubException('书籍文件尚未准备完成');
      }
    }
    final parsed = await _parseBook(entry);
    _bookCache[entry.id] = parsed;
    return parsed;
  }

  Future<List<EpubHighlight>> highlightsFor(String bookId) async {
    await load();
    if (_highlightCache.containsKey(bookId)) {
      return List.unmodifiable(_highlightCache[bookId]!);
    }
    final file = File('${_baseDir!.path}/highlights.json');
    if (!await file.exists()) {
      _highlightCache[bookId] = [];
      return const [];
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is Map) {
        final list = data[bookId];
        if (list is List) {
          _highlightCache[bookId] = list
              .whereType<Map>()
              .map(
                (item) =>
                    EpubHighlight.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
          return List.unmodifiable(_highlightCache[bookId]!);
        }
      }
    } catch (_) {}
    _highlightCache[bookId] = [];
    return const [];
  }

  Future<EpubHighlight> addHighlight({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required String text,
  }) async {
    await highlightsFor(bookId);
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const EpubException('请先选择文字');
    final highlight = EpubHighlight(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      text: trimmed.length > 600 ? trimmed.substring(0, 600) : trimmed,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _highlightCache[bookId] = [
      ...(_highlightCache[bookId] ?? const []),
      highlight,
    ];
    await _saveHighlights();
    notifyListeners();
    return highlight;
  }

  Future<void> removeHighlight(String bookId, String highlightId) async {
    await highlightsFor(bookId);
    _highlightCache[bookId] = (_highlightCache[bookId] ?? [])
        .where((item) => item.id != highlightId)
        .toList();
    await _saveHighlights();
    notifyListeners();
  }

  Future<List<EpubSearchResult>> search(
    EpubBook book,
    String query, {
    int limit = 60,
  }) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return const [];
    final lower = cleaned.toLowerCase();
    final index = await _searchIndex(book);
    final results = <EpubSearchResult>[];
    for (final chapter in book.chapters) {
      final text = index[chapter.index];
      if (text == null) continue;
      final lowerText = text.toLowerCase();
      var start = lowerText.indexOf(lower);
      while (start >= 0) {
        final from = (start - 48).clamp(0, text.length);
        final to = (start + cleaned.length + 72).clamp(0, text.length);
        results.add(
          EpubSearchResult(
            chapterIndex: chapter.index,
            chapterTitle: chapter.title,
            snippet: text.substring(from, to).replaceAll(RegExp(r'\s+'), ' '),
          ),
        );
        if (results.length >= limit) return results;
        start = lowerText.indexOf(lower, start + cleaned.length);
      }
    }
    return results;
  }

  Future<void> buildSearchIndex(EpubBook book) async {
    await _searchIndex(book);
  }

  Future<Map<int, String>> _searchIndex(EpubBook book) async {
    final cached = _searchIndexCache[book.id];
    if (cached != null) return cached;
    final file = File('${book.rootPath}/search_index.json');
    if (await file.exists()) {
      try {
        final data = jsonDecode(await file.readAsString());
        if (data is Map) {
          final loaded = <int, String>{};
          for (final entry in data.entries) {
            final chapterIndex = int.tryParse(entry.key.toString());
            if (chapterIndex != null && entry.value is String) {
              loaded[chapterIndex] = entry.value as String;
            }
          }
          _searchIndexCache[book.id] = loaded;
          return loaded;
        }
      } catch (_) {}
    }
    final built = <int, String>{};
    for (final chapter in book.chapters) {
      final chapterFile = File(chapter.filePath);
      if (!await chapterFile.exists()) continue;
      try {
        final document = html_parser.parse(await chapterFile.readAsString());
        final text =
            (document.body?.text ?? document.documentElement?.text ?? '')
                .replaceAll(RegExp(r'\s+'), ' ');
        built[chapter.index] = text;
      } catch (_) {}
    }
    _searchIndexCache[book.id] = built;
    try {
      await file.writeAsString(
        jsonEncode(built.map((key, value) => MapEntry(key.toString(), value))),
      );
    } catch (_) {}
    return built;
  }

  Future<String> chapterHtml(
    EpubBook book,
    EpubChapter chapter, {
    double fontSize = 17,
    bool dark = false,
    String? background,
  }) async {
    final file = File(chapter.filePath);
    var html = await file.readAsString();
    final textColor = dark ? '#F4EFE7' : '#29231D';
    final mutedColor = dark ? '#B9B0A4' : '#756B61';
    final bodyBackground = background ?? (dark ? 'transparent' : 'transparent');
    final themeStyles =
        '''
<style id="ft-reader-style">
  :root { color-scheme: ${dark ? 'dark' : 'light'}; }
  html, body { background: $bodyBackground !important; color: $textColor !important; }
  body {
    margin: 0 !important;
    padding: 18px 20px 64px !important;
    font-family: -apple-system, BlinkMacSystemFont, "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif !important;
    font-size: ${fontSize.toStringAsFixed(1)}px !important;
    line-height: 1.82 !important;
    word-break: break-word;
    -webkit-text-size-adjust: 100%;
  }
  p, li, div, span, section, article, td, th, blockquote {
    color: $textColor !important;
  }
  h1, h2, h3, h4, h5, h6 { color: $textColor !important; line-height: 1.4 !important; }
  img, svg, video { max-width: 100% !important; height: auto !important; }
  a { color: #d97706 !important; }
  hr { border-color: $mutedColor !important; opacity: .28; }
  pre, code { white-space: pre-wrap; word-break: break-word; }
  mark.ft-highlight { background: rgba(245, 158, 11, .36); color: inherit !important; border-radius: 3px; padding: 0 2px; }
  mark.ft-search { background: rgba(59, 130, 246, .38); color: inherit !important; border-radius: 3px; padding: 0 2px; }
  ::selection { background: rgba(245, 158, 11, .42); }
</style>
''';
    if (html.contains('</head>')) {
      html = html.replaceFirst('</head>', '$themeStyles</head>');
    } else {
      html = '$themeStyles$html';
    }
    return html;
  }

  Future<void> _extractFile(String sourcePath, String target) async {
    if (!Platform.isAndroid) {
      throw const EpubException('EPUB 导入目前仅支持 Android');
    }
    await _channel.invokeMethod<bool>('extractFile', {
      'filePath': sourcePath,
      'target': target,
    });
  }

  Future<EpubBook> _parseBook(EpubBookEntry entry) async {
    final containerFile = File('${entry.rootPath}/META-INF/container.xml');
    final container = XmlDocument.parse(await containerFile.readAsString());
    final rootfiles = container.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == 'rootfile')
        .toList();
    if (rootfiles.isEmpty) throw const EpubException('EPUB 缺少 OPF 文件');
    final opfRelative = rootfiles.first.getAttribute('full-path') ?? '';
    if (opfRelative.isEmpty) throw const EpubException('EPUB 的 OPF 路径为空');
    final opfFile = File(_resolve(entry.rootPath, opfRelative));
    if (!await opfFile.exists()) throw const EpubException('找不到 OPF 文件');
    final opf = XmlDocument.parse(await opfFile.readAsString());
    final opfDir = opfFile.parent.path;
    final metadata = _firstElement(opf, 'metadata');
    final title = _firstText(metadata, 'title') ?? entry.title;
    final author = _firstText(metadata, 'creator') ?? '';

    final manifest = <String, _ManifestItem>{};
    for (final element in _elements(opf, 'item')) {
      final id = element.getAttribute('id') ?? '';
      final href = element.getAttribute('href') ?? '';
      if (id.isEmpty || href.isEmpty) continue;
      manifest[id] = _ManifestItem(
        id: id,
        href: href,
        filePath: _resolve(opfDir, href),
        mediaType: element.getAttribute('media-type') ?? '',
        properties: element.getAttribute('properties') ?? '',
      );
    }

    final spine = _firstElement(opf, 'spine');
    final chapters = <EpubChapter>[];
    final chapterByPath = <String, int>{};
    for (final itemref in _elements(spine, 'itemref')) {
      final idref = itemref.getAttribute('idref') ?? '';
      final item = manifest[idref];
      if (item == null) continue;
      final type = item.mediaType.toLowerCase();
      final href = item.href.toLowerCase();
      final isHtml =
          type.contains('xhtml') ||
          type.contains('html') ||
          href.endsWith('.html') ||
          href.endsWith('.htm') ||
          href.endsWith('.xhtml');
      if (!isHtml) continue;
      final index = chapters.length;
      chapters.add(
        EpubChapter(
          index: index,
          id: item.id,
          filePath: item.filePath,
          title: '第 ${index + 1} 章',
        ),
      );
      chapterByPath[item.filePath] = index;
    }
    if (chapters.isEmpty) throw const EpubException('这本书没有可阅读的章节');

    final toc = <EpubTocEntry>[];
    final tocItem = manifest.values.firstWhere(
      (item) => item.properties.split(RegExp(r'\s+')).contains('nav'),
      orElse: () => manifest.values.firstWhere(
        (item) =>
            item.mediaType == 'application/x-dtbncx+xml' ||
            item.href.toLowerCase().endsWith('.ncx'),
        orElse: () => const _ManifestItem(
          id: '',
          href: '',
          filePath: '',
          mediaType: '',
          properties: '',
        ),
      ),
    );
    if (tocItem.filePath.isNotEmpty && await File(tocItem.filePath).exists()) {
      try {
        if (tocItem.mediaType.contains('xhtml') ||
            tocItem.href.toLowerCase().endsWith('.xhtml') ||
            tocItem.href.toLowerCase().endsWith('.html')) {
          toc.addAll(await _parseNavToc(tocItem.filePath, chapterByPath));
        } else {
          toc.addAll(await _parseNcxToc(tocItem.filePath, chapterByPath));
        }
      } catch (_) {}
    }

    final firstTitles = <int, String>{};
    for (final item in toc) {
      firstTitles.putIfAbsent(item.chapterIndex, () => item.title);
    }
    final titledChapters = <EpubChapter>[];
    for (final chapter in chapters) {
      titledChapters.add(
        EpubChapter(
          index: chapter.index,
          id: chapter.id,
          filePath: chapter.filePath,
          title: firstTitles[chapter.index] ?? chapter.title,
        ),
      );
    }

    String? coverPath;
    final coverId = _coverMetaId(metadata);
    _ManifestItem? coverItem;
    if (coverId != null) coverItem = manifest[coverId];
    if (coverItem == null) {
      for (final item in manifest.values) {
        if (item.properties.split(RegExp(r'\s+')).contains('cover-image')) {
          coverItem = item;
          break;
        }
      }
    }
    if (coverItem == null) {
      for (final item in manifest.values) {
        if (item.mediaType.startsWith('image/') &&
            item.href.toLowerCase().contains('cover')) {
          coverItem = item;
          break;
        }
      }
    }
    if (coverItem != null && await File(coverItem.filePath).exists()) {
      coverPath = await _cacheCover(entry.id, File(coverItem.filePath));
    }

    return EpubBook(
      id: entry.id,
      title: title,
      author: author,
      rootPath: entry.rootPath,
      chapters: titledChapters,
      toc: toc,
      coverPath: coverPath,
    );
  }

  Future<List<EpubTocEntry>> _parseNcxToc(
    String filePath,
    Map<String, int> chapterByPath,
  ) async {
    final doc = XmlDocument.parse(await File(filePath).readAsString());
    final base = File(filePath).parent.path;
    final result = <EpubTocEntry>[];
    for (final navPoint in doc.descendants.whereType<XmlElement>().where(
      (element) => element.localName == 'navPoint',
    )) {
      final label = _firstText(navPoint, 'text')?.trim() ?? '';
      final content = _firstElement(navPoint, 'content');
      final src = content?.getAttribute('src') ?? '';
      if (label.isEmpty || src.isEmpty) continue;
      final chapterIndex = chapterByPath[_resolve(base, src)];
      if (chapterIndex == null) continue;
      result.add(
        EpubTocEntry(
          title: label,
          chapterIndex: chapterIndex,
          level: _navLevel(navPoint),
        ),
      );
    }
    return result;
  }

  Future<List<EpubTocEntry>> _parseNavToc(
    String filePath,
    Map<String, int> chapterByPath,
  ) async {
    final document = html_parser.parse(await File(filePath).readAsString());
    final base = File(filePath).parent.path;
    var nav = document.querySelector('nav[epub\\:type="toc"]');
    nav ??= document.querySelector('nav');
    if (nav == null) return const [];
    final result = <EpubTocEntry>[];
    for (final link in nav.querySelectorAll('a[href]')) {
      final href = link.attributes['href'] ?? '';
      final title = link.text.trim();
      if (href.isEmpty || title.isEmpty) continue;
      final chapterIndex = chapterByPath[_resolve(base, href)];
      if (chapterIndex == null) continue;
      result.add(
        EpubTocEntry(title: title, chapterIndex: chapterIndex, level: 0),
      );
    }
    return result;
  }

  int _navLevel(XmlElement element) {
    var level = 0;
    XmlNode? parent = element.parent;
    while (parent != null) {
      if (parent is XmlElement && parent.localName == 'navPoint') level++;
      parent = parent.parent;
    }
    return level;
  }

  String? _coverMetaId(XmlElement? metadata) {
    if (metadata == null) return null;
    for (final element in _elements(metadata, 'meta')) {
      if (element.getAttribute('name') == 'cover') {
        return element.getAttribute('content');
      }
    }
    return null;
  }

  XmlElement? _firstElement(XmlNode? node, String localName) {
    if (node == null) return null;
    for (final element in node.descendants.whereType<XmlElement>()) {
      if (element.localName == localName) return element;
    }
    return null;
  }

  Iterable<XmlElement> _elements(XmlNode? node, String localName) {
    if (node == null) return const [];
    return node.descendants.whereType<XmlElement>().where(
      (element) => element.localName == localName,
    );
  }

  String? _firstText(XmlNode? node, String localName) {
    final element = _firstElement(node, localName);
    final text = element?.innerText.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _resolve(String base, String href) {
    final clean = Uri.decodeFull(href.split('#').first);
    final baseUri = Uri.directory(
      base.endsWith(Platform.pathSeparator)
          ? base
          : '$base${Platform.pathSeparator}',
    );
    return baseUri.resolve(clean).toFilePath();
  }

  Future<String> _cacheCover(String bookId, File cover) async {
    final extension = cover.path.toLowerCase().endsWith('.png')
        ? '.png'
        : '.jpg';
    final target = File('${_coverDir!.path}/$bookId$extension');
    await cover.copy(target.path);
    return target.path;
  }

  void _applyMetadata(EpubBookEntry entry, EpubBook book) {
    if (book.title.trim().isNotEmpty) entry.title = book.title.trim();
    if (book.author.trim().isNotEmpty) entry.author = book.author.trim();
    if (book.coverPath != null) entry.coverPath = book.coverPath;
    entry.deleted = false;
  }

  Future<void> _saveLibrary() async {
    final file = File('${_baseDir!.path}/library.json');
    await file.writeAsString(
      jsonEncode(_books.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveHighlights() async {
    final file = File('${_baseDir!.path}/highlights.json');
    await file.writeAsString(
      jsonEncode(
        _highlightCache.map(
          (key, value) =>
              MapEntry(key, value.map((item) => item.toJson()).toList()),
        ),
      ),
    );
  }
}

class _ManifestItem {
  final String id;
  final String href;
  final String filePath;
  final String mediaType;
  final String properties;

  const _ManifestItem({
    required this.id,
    required this.href,
    required this.filePath,
    required this.mediaType,
    required this.properties,
  });
}
