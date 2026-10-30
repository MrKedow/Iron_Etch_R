import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class BilibiliVideo {
  final String bvid;
  final String title;
  final String author;
  final String duration;
  final int play;

  const BilibiliVideo({
    required this.bvid,
    required this.title,
    required this.author,
    required this.duration,
    required this.play,
  });
}

class BilibiliVideoPage {
  final List<BilibiliVideo> videos;
  final int total;
  final bool fromSearch;

  const BilibiliVideoPage({
    required this.videos,
    required this.total,
    this.fromSearch = false,
  });
}

class BilibiliUser {
  final int mid;
  final String name;
  final String sign;
  final int fans;

  const BilibiliUser({
    required this.mid,
    required this.name,
    required this.sign,
    required this.fans,
  });
}

class BilibiliService {
  static const String _userAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';
  static const int _pageSize = 50;
  static const int _maxPages = 50;

  static const List<int> _mixinKeyEncTab = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  final Map<String, Cookie> _cookies = <String, Cookie>{};

  String? _mixinKey;
  DateTime? _mixinKeyAt;

  Future<BilibiliVideoPage> fetchCreatorVideos({
    required String query,
    required int mid,
    int page = 1,
    int pageSize = _pageSize,
  }) async {
    final space = await _fetchSpacePage(
      mid: mid,
      page: page,
      pageSize: pageSize,
    );
    if (space != null && space.videos.isNotEmpty) return space;

    final search = await _fetchSearchVideos(
      query: '$query 健身',
      mid: mid,
    );
    return BilibiliVideoPage(
      videos: search,
      total: search.length,
      fromSearch: true,
    );
  }

  Future<List<BilibiliVideo>> fetchAllCreatorVideos({
    required int mid,
    int pageSize = _pageSize,
  }) async {
    final videos = <BilibiliVideo>[];
    final seen = <String>{};
    var page = 1;
    var total = 0;

    while (page <= _maxPages) {
      final result = await _fetchSpacePage(
        mid: mid,
        page: page,
        pageSize: pageSize,
      );
      if (result == null) break;
      total = result.total;
      for (final video in result.videos) {
        if (seen.add(video.bvid)) videos.add(video);
      }
      if (result.videos.isEmpty || (total > 0 && videos.length >= total)) {
        break;
      }
      page++;
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
    return videos;
  }

  Future<BilibiliUser?> findUserByName(String name) async {
    final query = name.trim();
    if (query.isEmpty) return null;
    await _warmup();
    await _ensureFingerprint();
    final uri = Uri.https(
      'api.bilibili.com',
      '/x/web-interface/search/type',
      {
        'search_type': 'bili_user',
        'keyword': query,
        'page': '1',
      },
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      final decoded = await _requestJson(
        uri,
        referer: 'https://search.bilibili.com/',
      );
      final code = (decoded?['code'] as num?)?.toInt() ?? -1;
      if (code == 0) {
        final data = decoded?['data'];
        final rawList = data is Map ? data['result'] : null;
        if (rawList is! List) return null;
        BilibiliUser? best;
        for (final raw in rawList) {
          if (raw is! Map) continue;
          final uname = _cleanTitle(raw['uname']?.toString() ?? '');
          if (uname != query) continue;
          final mid =
              (raw['mid'] as num?)?.toInt() ?? int.tryParse('${raw['mid']}');
          if (mid == null) continue;
          final user = BilibiliUser(
            mid: mid,
            name: uname,
            sign: _cleanTitle(raw['usign']?.toString() ?? ''),
            fans: (raw['fans'] as num?)?.toInt() ?? 0,
          );
          if (best == null || user.fans > best.fans) best = user;
        }
        return best;
      }
      if (decoded == null || code == -1) {
        await Future<void>.delayed(
          Duration(milliseconds: 1200 * (attempt + 1)),
        );
        continue;
      }
      if (code == -352 || code == -412) {
        await _ensureFingerprint();
        await Future<void>.delayed(
          Duration(milliseconds: 1500 * (attempt + 1)),
        );
        continue;
      }
      return null;
    }
    return null;
  }

  void dispose() {
    _client.close(force: true);
  }

  Future<BilibiliVideoPage?> _fetchSpacePage({
    required int mid,
    required int page,
    required int pageSize,
  }) async {
    await _warmup();
    await _ensureFingerprint();
    for (var attempt = 0; attempt < 3; attempt++) {
      final mixinKey = await _getMixinKey(refresh: attempt > 0);
      if (mixinKey == null) return null;
      final wts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final query = _sign(
        {
          'mid': '$mid',
          'pn': '$page',
          'ps': '$pageSize',
          'order': 'pubdate',
          'platform': 'web',
          'web_location': '1550101',
          'wts': '$wts',
        },
        mixinKey,
      );
      final decoded = await _requestJson(
        Uri.parse(
          'https://api.bilibili.com/x/space/wbi/arc/search?$query',
        ),
        referer: 'https://space.bilibili.com/$mid/video',
      );
      final code = (decoded?['code'] as num?)?.toInt() ?? -1;
      if (code == 0) {
        return _parseSpacePage(decoded!);
      }
      if (decoded == null || code == -1) {
        await Future<void>.delayed(
          Duration(milliseconds: 1200 * (attempt + 1)),
        );
        continue;
      }
      if (code == -352 || code == -412 || code == -799) {
        _mixinKey = null;
        _mixinKeyAt = null;
        await Future<void>.delayed(
          Duration(milliseconds: 1800 * (attempt + 1)),
        );
        await _ensureFingerprint();
        continue;
      }
      return null;
    }
    return null;
  }

  BilibiliVideoPage? _parseSpacePage(Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (data is! Map) return null;
    final pageData = data['page'];
    final total =
        pageData is Map ? (pageData['count'] as num?)?.toInt() ?? 0 : 0;
    final list = data['list'];
    final rawList = list is Map ? list['vlist'] : null;
    if (rawList is! List) return null;
    final videos = <BilibiliVideo>[];
    for (final raw in rawList) {
      if (raw is! Map) continue;
      final video = _videoFromMap(raw);
      if (video != null) videos.add(video);
    }
    return BilibiliVideoPage(videos: videos, total: total);
  }

  Future<List<BilibiliVideo>> _fetchSearchVideos({
    required String query,
    required int mid,
  }) async {
    final uri = Uri.https(
      'api.bilibili.com',
      '/x/web-interface/search/type',
      {
        'search_type': 'video',
        'keyword': query,
        'page': '1',
        'order': 'totalrank',
      },
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      final decoded = await _requestJson(
        uri,
        referer: 'https://search.bilibili.com/',
      );
      if (decoded != null && (decoded['code'] as num?)?.toInt() == 0) {
        final data = decoded['data'];
        final rawList = data is Map ? data['result'] : null;
        if (rawList is! List) return const [];
        final videos = <BilibiliVideo>[];
        final seen = <String>{};
        for (final raw in rawList) {
          if (raw is! Map) continue;
          final itemMid = int.tryParse('${raw['mid']}');
          if (itemMid != mid) continue;
          final video = _videoFromMap(raw);
          if (video == null || !seen.add(video.bvid)) continue;
          videos.add(video);
        }
        return videos;
      }
      await Future<void>.delayed(
        Duration(milliseconds: 1200 * (attempt + 1)),
      );
    }
    return const [];
  }

  BilibiliVideo? _videoFromMap(Map raw) {
    final bvid = raw['bvid']?.toString() ?? '';
    if (bvid.isEmpty) return null;
    return BilibiliVideo(
      bvid: bvid,
      title: _cleanTitle(raw['title']?.toString() ?? ''),
      author: raw['author']?.toString() ?? '',
      duration: (raw['length'] ?? raw['duration'])?.toString() ?? '',
      play: (raw['play'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>?> _requestJson(
    Uri uri, {
    required String referer,
  }) async {
    try {
      final request = await _client.getUrl(uri);
      _applyHeaders(request, referer);
      _applyCookies(request);
      final response = await request.close();
      _captureCookies(response);
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> _warmup() async {
    if (_cookies.isNotEmpty) return;
    try {
      final request = await _client.getUrl(
        Uri.parse('https://www.bilibili.com/'),
      );
      _applyHeaders(request, 'https://www.bilibili.com/');
      final response = await request.close();
      _captureCookies(response);
      await response.drain<void>();
    } catch (_) {}
  }

  Future<void> _ensureFingerprint() async {
    if (_cookies['buvid3']?.value.isNotEmpty == true) return;
    try {
      final decoded = await _requestJson(
        Uri.parse('https://api.bilibili.com/x/frontend/finger/spi'),
        referer: 'https://www.bilibili.com/',
      );
      final data = decoded?['data'];
      if (data is! Map) return;
      final b3 = data['b_3']?.toString() ?? '';
      final b4 = data['b_4']?.toString() ?? '';
      if (b3.isEmpty) return;
      _cookies['buvid3'] = Cookie('buvid3', b3);
      if (b4.isNotEmpty) {
        _cookies['buvid4'] = Cookie('buvid4', b4);
      }
      _cookies['b_nut'] = Cookie(
        'b_nut',
        '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      );
    } catch (_) {}
  }

  Future<String?> _getMixinKey({bool refresh = false}) async {
    final cachedAt = _mixinKeyAt;
    if (!refresh &&
        _mixinKey != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 30)) {
      return _mixinKey;
    }
    final decoded = await _requestJson(
      Uri.parse('https://api.bilibili.com/x/web-interface/nav'),
      referer: 'https://www.bilibili.com/',
    );
    final data = decoded?['data'];
    final wbi = data is Map ? data['wbi_img'] : null;
    if (wbi is! Map) return null;
    final imgKey = _keyFromUrl(wbi['img_url']?.toString() ?? '');
    final subKey = _keyFromUrl(wbi['sub_url']?.toString() ?? '');
    if (imgKey.isEmpty || subKey.isEmpty) return null;
    final original = imgKey + subKey;
    final mixed = _mixinKeyEncTab
        .map((index) => index < original.length ? original[index] : '')
        .join();
    _mixinKey = mixed.substring(0, mixed.length < 32 ? mixed.length : 32);
    _mixinKeyAt = DateTime.now();
    return _mixinKey;
  }

  String _keyFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final name = uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : url.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String _sign(Map<String, String> params, String mixinKey) {
    final filtered = <String, String>{};
    params.forEach((key, value) {
      filtered[key] = value.replaceAll(RegExp(r"[!'()*]"), '');
    });
    final keys = filtered.keys.toList()..sort();
    final query = keys
        .map((key) => '$key=${Uri.encodeComponent(filtered[key]!)}')
        .join('&');
    final wRid = md5.convert(utf8.encode(query + mixinKey)).toString();
    return '$query&w_rid=$wRid';
  }

  void _applyHeaders(HttpClientRequest request, String referer) {
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers
        .set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
    request.headers.set(HttpHeaders.refererHeader, referer);
  }

  void _applyCookies(HttpClientRequest request) {
    if (_cookies.isEmpty) return;
    request.headers.set(
      HttpHeaders.cookieHeader,
      _cookies.values
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join('; '),
    );
  }

  void _captureCookies(HttpClientResponse response) {
    for (final cookie in response.cookies) {
      final expired = cookie.maxAge == 0 ||
          (cookie.expires != null && cookie.expires!.isBefore(DateTime.now()));
      if (expired) {
        _cookies.remove(cookie.name);
      } else {
        _cookies[cookie.name] = cookie;
      }
    }
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
