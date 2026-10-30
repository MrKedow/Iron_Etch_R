import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class KnowledgeArticle {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String url;
  final String category;
  final DateTime? publishedAt;
  final List<String> authors;
  final String? abstractText;

  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.category,
    this.publishedAt,
    this.authors = const [],
    this.abstractText,
  });

  bool get isPubMed => id.startsWith('pmid:');

  String get pmid => isPubMed ? id.substring(5) : '';

  KnowledgeArticle copyWith({
    String? summary,
    String? abstractText,
  }) {
    return KnowledgeArticle(
      id: id,
      title: title,
      summary: summary ?? this.summary,
      source: source,
      url: url,
      category: category,
      publishedAt: publishedAt,
      authors: authors,
      abstractText: abstractText ?? this.abstractText,
    );
  }
}

class KnowledgeTopic {
  final String id;
  final String label;
  final String query;

  const KnowledgeTopic({
    required this.id,
    required this.label,
    required this.query,
  });
}

class KnowledgeBundle {
  final List<KnowledgeArticle> articles;
  final List<String> failures;

  const KnowledgeBundle({
    required this.articles,
    required this.failures,
  });

  bool get isEmpty => articles.isEmpty;
}

class _FeedResult {
  final List<KnowledgeArticle> articles;
  final String? error;

  const _FeedResult({required this.articles, this.error});
}

class _CacheEntry {
  final DateTime time;
  final List<KnowledgeArticle> articles;

  const _CacheEntry({required this.time, required this.articles});

  bool get fresh =>
      DateTime.now().difference(time) < const Duration(minutes: 30);
}

class KnowledgeService {
  static const String _pubmedBase =
      'https://eutils.ncbi.nlm.nih.gov/entrez/eutils';
  static const String _userAgent =
      'TieJuan/1.2 (Android fitness tracker; contact: Ethocas@outlook.com)';

  static const List<String> whoFeeds = [
    'https://www.who.int/rss-feeds/news-english.xml',
    'https://www.who.int/feeds/entity/news/en/rss.xml',
  ];

  static const List<KnowledgeTopic> topics = [
    KnowledgeTopic(
      id: 'strength',
      label: '力量增肌',
      query:
          '(resistance training[Title/Abstract] OR strength training[Title/Abstract]) AND (muscle hypertrophy[Title/Abstract] OR muscle strength[Title/Abstract])',
    ),
    KnowledgeTopic(
      id: 'cardio',
      label: '有氧耐力',
      query:
          '(aerobic exercise[Title/Abstract] OR endurance training[Title/Abstract]) AND (cardiorespiratory fitness[Title/Abstract] OR VO2max[Title/Abstract])',
    ),
    KnowledgeTopic(
      id: 'nutrition',
      label: '营养恢复',
      query:
          '(dietary protein[Title/Abstract] OR protein intake[Title/Abstract]) AND (resistance training[Title/Abstract] OR muscle protein synthesis[Title/Abstract])',
    ),
    KnowledgeTopic(
      id: 'health',
      label: '运动健康',
      query:
          'exercise[Title/Abstract] AND (health[Title/Abstract] OR mortality[Title/Abstract] OR prevention[Title/Abstract])',
    ),
    KnowledgeTopic(
      id: 'who',
      label: 'WHO 动态',
      query: '',
    ),
  ];

  static final Map<String, _CacheEntry> _cache = {};

  static Future<KnowledgeBundle> fetchAll({int limitPerTopic = 5}) async {
    final results = <_FeedResult>[];
    for (var i = 0; i < topics.length; i++) {
      final topic = topics[i];
      results.add(await _fetchTopicResult(topic, limit: limitPerTopic));
      if (topic.id != 'who' && i < topics.length - 1) {
        // NCBI 匿名请求限制为每秒 3 次，串行 + 间隔可避免 429。
        await Future.delayed(const Duration(milliseconds: 450));
      }
    }

    final articles = <KnowledgeArticle>[];
    final failures = <String>[];
    for (var i = 0; i < topics.length; i++) {
      articles.addAll(results[i].articles);
      final error = results[i].error;
      if (error != null) failures.add('${topics[i].label}：$error');
    }
    articles.sort((a, b) {
      final left = a.publishedAt;
      final right = b.publishedAt;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return KnowledgeBundle(articles: articles, failures: failures);
  }

  static Future<List<KnowledgeArticle>> fetchTopic(
    KnowledgeTopic topic, {
    int limit = 6,
  }) async {
    final result = await _fetchTopicResult(topic, limit: limit);
    return result.articles;
  }

  static Future<_FeedResult> _fetchTopicResult(
    KnowledgeTopic topic, {
    required int limit,
  }) async {
    final cacheKey = '${topic.id}:$limit';
    final cached = _cache[cacheKey];
    if (cached != null && cached.fresh) {
      return _FeedResult(articles: cached.articles);
    }

    _FeedResult result;
    if (topic.id == 'who') {
      result = await _fetchWho(limit: limit);
    } else {
      result = await _searchPubMed(
        topic.query,
        category: topic.label,
        limit: limit,
      );
    }

    if (result.articles.isNotEmpty) {
      _cache[cacheKey] = _CacheEntry(
        time: DateTime.now(),
        articles: result.articles,
      );
    }
    return result;
  }

  static Future<_FeedResult> _searchPubMed(
    String term, {
    required String category,
    required int limit,
  }) async {
    try {
      final searchUri = Uri.parse('$_pubmedBase/esearch.fcgi').replace(
        queryParameters: {
          'db': 'pubmed',
          'term': term,
          'retmode': 'json',
          'retmax': '$limit',
          'sort': 'pub+date',
          'tool': 'TieJuan',
          'email': 'Ethocas@outlook.com',
        },
      );
      final searchResponse = await _get(searchUri);
      if (searchResponse == null) {
        return const _FeedResult(articles: [], error: 'PubMed 连接失败');
      }
      if (searchResponse.statusCode != 200) {
        return _FeedResult(
          articles: const [],
          error: 'PubMed HTTP ${searchResponse.statusCode}',
        );
      }

      final searchJson =
          jsonDecode(utf8.decode(searchResponse.bodyBytes)) as Map;
      final searchResult = searchJson['esearchresult'];
      final rawIds = searchResult is Map ? searchResult['idlist'] : null;
      final ids = rawIds is List
          ? rawIds.map((id) => id.toString()).toList()
          : const <String>[];
      if (ids.isEmpty) {
        return const _FeedResult(articles: []);
      }

      await Future.delayed(const Duration(milliseconds: 350));
      final summaryUri = Uri.parse('$_pubmedBase/esummary.fcgi').replace(
        queryParameters: {
          'db': 'pubmed',
          'id': ids.join(','),
          'retmode': 'json',
        },
      );
      final summaryResponse = await _get(summaryUri);
      if (summaryResponse == null || summaryResponse.statusCode != 200) {
        return const _FeedResult(articles: [], error: 'PubMed 摘要获取失败');
      }

      final summaryJson =
          jsonDecode(utf8.decode(summaryResponse.bodyBytes)) as Map;
      final result = summaryJson['result'];
      if (result is! Map) {
        return const _FeedResult(articles: []);
      }

      final articles = <KnowledgeArticle>[];
      for (final id in ids) {
        final raw = result[id];
        if (raw is! Map) continue;
        final title = _cleanText(raw['title']?.toString() ?? '');
        if (title.isEmpty) continue;
        final source = _cleanText(
          (raw['fulljournalname'] ?? raw['source'] ?? 'PubMed').toString(),
        );
        final authorsRaw = raw['authors'];
        final authors = authorsRaw is List
            ? authorsRaw
                .take(3)
                .map((item) => _cleanText(
                      item is Map ? (item['name'] ?? '').toString() : '',
                    ))
                .where((name) => name.isNotEmpty)
                .toList()
            : const <String>[];
        articles.add(KnowledgeArticle(
          id: 'pmid:$id',
          title: title,
          summary: source.isEmpty ? 'PubMed 收录的最新研究' : '来源：$source',
          source: source.isEmpty ? 'PubMed' : source,
          url: 'https://pubmed.ncbi.nlm.nih.gov/$id/',
          category: category,
          publishedAt: _parseDate(raw['pubdate']?.toString()),
          authors: authors,
        ));
      }
      return _FeedResult(articles: articles);
    } on TimeoutException {
      return const _FeedResult(articles: [], error: 'PubMed 请求超时');
    } catch (e) {
      return _FeedResult(articles: const [], error: _shortError(e));
    }
  }

  static Future<_FeedResult> _fetchWho({required int limit}) async {
    Object? lastError;
    for (final feed in whoFeeds) {
      try {
        final response = await _get(Uri.parse(feed));
        if (response == null || response.statusCode != 200) {
          lastError = 'HTTP ${response?.statusCode ?? '无响应'}';
          continue;
        }
        final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
        final items = document.findAllElements('item').take(limit);
        final articles = <KnowledgeArticle>[];
        for (final item in items) {
          final title = _cleanText(_childText(item, 'title'));
          if (title.isEmpty) continue;
          final link = _cleanText(_childText(item, 'link'));
          final description = _cleanText(_childText(item, 'description'));
          articles.add(KnowledgeArticle(
            id: 'who:${_cleanText(_childText(item, 'guid'))}-$title',
            title: title,
            summary: description.isEmpty
                ? '世界卫生组织最新发布'
                : _truncate(description, 280),
            source: 'WHO',
            url: link.isEmpty ? 'https://www.who.int/news-room' : link,
            category: 'WHO 动态',
            publishedAt: _parseDate(_childText(item, 'pubDate')),
          ));
        }
        if (articles.isNotEmpty) {
          return _FeedResult(articles: articles);
        }
        lastError = 'RSS 内容为空';
      } on TimeoutException {
        lastError = '请求超时';
      } catch (e) {
        lastError = _shortError(e);
      }
    }
    return _FeedResult(articles: const [], error: '$lastError');
  }

  static Future<String?> fetchAbstract(String pmid) async {
    if (pmid.isEmpty) return null;
    try {
      final uri = Uri.parse('$_pubmedBase/efetch.fcgi').replace(
        queryParameters: {
          'db': 'pubmed',
          'id': pmid,
          'retmode': 'xml',
          'rettype': 'abstract',
        },
      );
      final response = await _get(uri);
      if (response == null || response.statusCode != 200) return null;
      final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
      final parts = <String>[];
      for (final element in document.findAllElements('AbstractText')) {
        final label = element.getAttribute('Label');
        final text = _cleanText(element.innerText);
        if (text.isEmpty) continue;
        parts.add(
            label == null || label.trim().isEmpty ? text : '$label: $text');
      }
      if (parts.isNotEmpty) return parts.join('\n\n');
      final title = document.findAllElements('ArticleTitle');
      return title.isEmpty ? null : _cleanText(title.first.innerText);
    } catch (_) {
      return null;
    }
  }

  static Future<http.Response?> _get(Uri uri) async {
    final client = http.Client();
    try {
      return await client.get(
        uri,
        headers: const {
          'Accept': 'application/json, application/xml, text/xml, */*',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 22));
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static String _childText(XmlElement item, String name) {
    final children = item.findElements(name);
    return children.isEmpty ? '' : children.first.innerText;
  }

  static String _cleanText(String raw) {
    var text = raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    text = text.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) => String.fromCharCode(int.parse(match.group(1)!)),
    );
    text = text.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
    return text.trim();
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim();
    final direct = DateTime.tryParse(normalized);
    if (direct != null) return direct;
    try {
      return HttpDate.parse(normalized);
    } catch (_) {
      // PubMed 常见格式：2026 Oct 20
    }
    final match = RegExp(r'^(\d{4})\s+([A-Za-z]{3})(?:\s+(\d{1,2}))?')
        .firstMatch(normalized);
    if (match != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = months[match.group(2)!.toLowerCase()];
      if (month != null) {
        return DateTime(
          int.parse(match.group(1)!),
          month,
          int.tryParse(match.group(3) ?? '') ?? 1,
        );
      }
    }
    return null;
  }

  static String _truncate(String text, int max) {
    return text.length <= max ? text : '${text.substring(0, max)}…';
  }

  static String _shortError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }
}
