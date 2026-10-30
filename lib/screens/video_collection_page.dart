import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../services/bilibili_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'bilibili_player_page.dart';

class VideoCollectionPage extends StatefulWidget {
  const VideoCollectionPage({super.key});

  @override
  State<VideoCollectionPage> createState() => _VideoCollectionPageState();
}

class _VideoCollectionPageState extends State<VideoCollectionPage> {
  static const String _assetPath = 'assets/bili_list.json';
  static const String _introPreferenceKey = 'video_intro_hidden';
  static const String _customPreferenceKey = 'video_custom_state_v1';

  static const Map<String, String> _displayNames = {
    'chenbolin': '陈柏龄',
    'yangwang': '仰望尾迹云',
    'anna': '安娜 Growingannanas',
    'mizi': 'Mizi（一起健身吧MIZI）',
  };

  static const Map<String, String> _bilibiliMids = {
    'pamela': '604003146',
    'zhouliuye': '62540916',
    'jo': '1462582672',
    'hanxiaosi': '369750017',
    'ouyangchunxiao': '493570956',
    'shugui': '1531707',
    'maoshu': '13716885',
    'anna': '3493094769036225',
    'mizi': '287453675',
    'eleni': '3546961800072012',
    'haorensongsong': '2078781964',
    'kaishengwang': '2100737396',
    'zby': '236094881',
    'chenbolin': '401129886',
    'shuaisoserious': '66391032',
    'yangwang': '1879203169',
    'kongboshi': '356634017',
    'zuojiao': '524909826',
    'yisulin': '2923121',
    'coffee': '304020239',
    'chloeting': '417267978',
    'fanliyuan': '63486758',
    'yerenluosi': '1718577682',
    'baoge': '269380821',
    'yang': '432760219',
  };

  static const Map<String, String> _bilibiliBvids = {
    'pamela': 'BV15Bn469ETB',
    'zhouliuye': 'BV1sA411Q7R3',
    'jo': 'BV1kGxM64Epk',
    'hanxiaosi': 'BV18snq6VEkS',
    'ouyangchunxiao': 'BV1omny66E3C',
    'shugui': 'BV1RU4y1b7t4',
    'maoshu': 'BV1PrxL6DErs',
    'anna': 'BV1LUx368ErY',
    'eleni': 'BV1qrn96iEYg',
    'haorensongsong': 'BV1Hk4y187jF',
    'kaishengwang': 'BV1UFxM6vETD',
    'zby': 'BV1vcnb6oEeE',
    'chenbolin': 'BV18P4y147vJ',
    'shuaisoserious': 'BV1zLnn6LEkj',
    'yangwang': 'BV1iyxE6LEUd',
    'kongboshi': 'BV1dNn96cET5',
    'zuojiao': 'BV1NNXLBSEcf',
    'yisulin': 'BV1V7QLYMESC',
    'coffee': 'BV1F9nE6rEn3',
    'chloeting': 'BV1HT4y1M7tJ',
    'fanliyuan': 'BV1zDxL6kEaK',
    'yerenluosi': 'BV1Uent6LEDR',
    'baoge': 'BV1cW411p7nW',
    'yang': 'BV1PAJv6oEy7',
  };

  final BilibiliService _bilibili = BilibiliService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCreators = <String>{};
  final Set<String> _loadingAllCreators = <String>{};
  final Set<String> _collapsedCategories = <String>{};
  final Set<String> _refreshedCategoryOnTap = <String>{};
  final Set<int> _refreshedCreatorOnTap = <int>{};
  final Map<String, List<_CustomCreator>> _customItems = {};
  final Map<String, String> _customNames = {};
  List<String> _collectionOrder = <String>[];

  static bool _initialFullRefreshDone = false;
  static final Map<int, _CachedCreatorVideos> _videoCache =
      <int, _CachedCreatorVideos>{};

  List<_VideoCategory> _categories = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _addingUp = false;
  bool _introVisible = true;
  String? _error;
  String _selected = '全部';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bilibili.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _introVisible = !(prefs.getBool(_introPreferenceKey) ?? false);
    });
  }

  Future<void> _hideIntro() async {
    setState(() => _introVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introPreferenceKey, true);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final categories = <_VideoCategory>[];
      for (final rawCategory
          in (data['categories'] as List<dynamic>? ?? const [])) {
        final category = rawCategory as Map<String, dynamic>;
        final items = <_VideoCreator>[];
        for (final rawItem
            in (category['items'] as List<dynamic>? ?? const [])) {
          final item = rawItem as Map<String, dynamic>;
          final id = item['id'] as String;
          final mid = _bilibiliMids[id];
          final bvid = _bilibiliBvids[id];
          final midValue = int.tryParse(mid ?? '');
          if (mid == null || bvid == null || midValue == null) continue;
          final name = _displayNames[id] ?? item['name'] as String;
          items.add(
            _VideoCreator(
              id: id,
              name: name,
              tags: (item['tags'] as List<dynamic>? ?? const [])
                  .map((tag) => tag.toString())
                  .toList(),
              audience: item['audience'] as String? ?? '',
              mid: midValue,
              total: 1,
              fromSearch: true,
              videos: [
                BilibiliVideo(
                  bvid: bvid,
                  title: '精选跟练视频',
                  author: name,
                  duration: '',
                  play: 0,
                ),
              ],
            ),
          );
        }
        categories.add(
          _VideoCategory(
            id: category['id'] as String,
            name: category['name'] as String,
            items: items,
          ),
        );
      }
      await _loadCustomState();
      if (!mounted) return;
      _mergeCustomCollections(categories);
      _restoreCachedVideos(categories);
      setState(() {
        _categories = categories;
        _loading = false;
      });
      if (!_initialFullRefreshDone) {
        unawaited(_refreshVideos(_allCreators, fullRefresh: true));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '视频合集加载失败，请稍后重试。';
        _loading = false;
      });
    }
  }

  Future<void> _loadCustomState() async {
    _customItems.clear();
    _customNames.clear();
    _collectionOrder = <String>[];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customPreferenceKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _collectionOrder = (data['order'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList();
      for (final rawCollection
          in (data['collections'] as List<dynamic>? ?? const [])) {
        if (rawCollection is! Map) continue;
        final collection = Map<String, dynamic>.from(rawCollection);
        final id = collection['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        _customNames[id] = collection['name']?.toString() ?? '我的合集';
        final items = <_CustomCreator>[];
        for (final rawItem
            in (collection['items'] as List<dynamic>? ?? const [])) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem);
          final mid = (item['mid'] as num?)?.toInt();
          final name = item['name']?.toString() ?? '';
          if (mid == null || name.isEmpty) continue;
          items.add(
            _CustomCreator(
              id: item['id']?.toString() ?? 'custom_${mid}_${items.length}',
              name: name,
              mid: mid,
            ),
          );
        }
        _customItems[id] = items;
      }
    } catch (_) {}
  }

  void _mergeCustomCollections(List<_VideoCategory> categories) {
    final byId = {for (final category in categories) category.id: category};
    for (final entry in _customItems.entries) {
      final category = byId[entry.key];
      if (category != null) {
        for (final custom in entry.value) {
          if (category.items.any((item) => item.mid == custom.mid)) continue;
          category.items.add(_creatorFromCustom(custom));
        }
      } else {
        final newCategory = _VideoCategory(
          id: entry.key,
          name: _customNames[entry.key] ?? '我的合集',
          items: entry.value.map(_creatorFromCustom).toList(),
        );
        categories.add(newCategory);
        byId[entry.key] = newCategory;
      }
    }
    if (_collectionOrder.isEmpty) return;
    final order = <String, int>{
      for (var i = 0; i < _collectionOrder.length; i++) _collectionOrder[i]: i,
    };
    final fallback = <String, int>{
      for (var i = 0; i < categories.length; i++) categories[i].id: i,
    };
    categories.sort((a, b) {
      final aIndex =
          order[a.id] ?? _collectionOrder.length + (fallback[a.id] ?? 0);
      final bIndex =
          order[b.id] ?? _collectionOrder.length + (fallback[b.id] ?? 0);
      return aIndex.compareTo(bIndex);
    });
  }

  void _restoreCachedVideos(List<_VideoCategory> categories) {
    for (final category in categories) {
      for (final creator in category.items) {
        final cached = _videoCache[creator.mid];
        if (cached == null) continue;
        creator.videos = List<BilibiliVideo>.of(cached.videos);
        creator.total = cached.total;
        creator.fromSearch = cached.fromSearch;
      }
    }
  }

  void _cacheCreator(_VideoCreator creator) {
    if (creator.videos.isEmpty) return;
    _videoCache[creator.mid] = _CachedCreatorVideos(
      videos: List<BilibiliVideo>.of(creator.videos),
      total: creator.total,
      fromSearch: creator.fromSearch,
    );
  }

  _VideoCreator _creatorFromCustom(_CustomCreator custom) {
    return _VideoCreator(
      id: custom.id,
      name: custom.name,
      tags: const ['自定义'],
      audience: '',
      mid: custom.mid,
      total: 0,
      fromSearch: true,
      videos: <BilibiliVideo>[],
    );
  }

  Future<void> _saveCustomState() async {
    final collections = <Map<String, dynamic>>[];
    for (final category in _categories) {
      final items = category.items
          .where((creator) => creator.id.startsWith('custom_'))
          .map(
            (creator) => <String, dynamic>{
              'id': creator.id,
              'name': creator.name,
              'mid': creator.mid,
            },
          )
          .toList();
      final isCustomCollection = category.id.startsWith('custom_');
      if (items.isEmpty && !isCustomCollection) continue;
      collections.add(
        <String, dynamic>{
          'id': category.id,
          'name': category.name,
          'items': items,
        },
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customPreferenceKey,
      jsonEncode(
        <String, dynamic>{
          'order': _categories.map((category) => category.id).toList(),
          'collections': collections,
        },
      ),
    );
  }

  Future<void> _showAddUpDialog() async {
    if (_addingUp) return;
    final names = <String>[];
    for (final category in _categories) {
      if (!names.contains(category.name)) names.add(category.name);
    }
    final result = await showDialog<_UpSubmission>(
      context: context,
      builder: (_) => _AddUpDialog(collectionNames: names),
    );
    if (result == null || !mounted) return;
    await _addUp(result);
  }

  Future<void> _addUp(_UpSubmission submission) async {
    final upName = submission.upName.trim();
    final collectionName = submission.collectionName.trim();
    if (upName.isEmpty || collectionName.isEmpty) return;
    setState(() => _addingUp = true);
    try {
      final user = await _bilibili.findUserByName(upName);
      if (!mounted) return;
      if (user == null) {
        _snack('未找到该 UP 主，请检查名字是否准确无误。');
        return;
      }
      final page = await _bilibili.fetchCreatorVideos(
        query: user.name,
        mid: user.mid,
        page: 1,
        pageSize: 50,
      );
      if (!mounted) return;
      _VideoCategory? existing;
      for (final category in _categories) {
        if (category.name.trim().toLowerCase() ==
            collectionName.toLowerCase()) {
          existing = category;
          break;
        }
      }
      if (existing != null &&
          existing.items.any((creator) => creator.mid == user.mid)) {
        _snack('该 UP 主已在「${existing.name}」中。');
        return;
      }
      final target = existing;
      final collectionId =
          target?.id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}';
      final creator = _VideoCreator(
        id: 'custom_${user.mid}_${DateTime.now().microsecondsSinceEpoch}',
        name: user.name,
        tags: const ['自定义'],
        audience: '',
        mid: user.mid,
        total: page.total > 0 ? page.total : page.videos.length,
        fromSearch: page.fromSearch || page.videos.isEmpty,
        videos: page.videos,
      );
      setState(() {
        if (target == null) {
          _categories.insert(
            0,
            _VideoCategory(
              id: collectionId,
              name: collectionName,
              items: [creator],
            ),
          );
        } else {
          _categories.remove(target);
          target.items.insert(0, creator);
          _categories.insert(0, target);
        }
        _selected = '全部';
        _query = '';
        _searchController.clear();
        _collapsedCategories.remove(collectionId);
        _expandedCreators.add(creator.id);
      });
      _cacheCreator(creator);
      await _saveCustomState();
      _snack('已添加 ${user.name} 到「$collectionName」');
      if (page.videos.isEmpty) {
        unawaited(_refreshVideos([creator]));
      }
    } catch (_) {
      _snack('添加失败，请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _addingUp = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_VideoCreator> get _allCreators =>
      _categories.expand((category) => category.items).toList();

  int get _totalCreators =>
      _categories.fold(0, (sum, category) => sum + category.items.length);

  int get _totalVideos => _categories.fold(
        0,
        (sum, category) =>
            sum +
            category.items.fold(0, (inner, creator) => inner + creator.total),
      );

  List<_VideoCategory> get _visibleCategories {
    if (_selected == '全部') return _categories;
    return _categories.where((category) => category.id == _selected).toList();
  }

  Future<void> _refreshVideos(
    List<_VideoCreator> creators, {
    bool fullRefresh = false,
    bool preserveLoaded = false,
  }) async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);

    Future<void> refreshOne(_VideoCreator creator) async {
      if (!mounted) return;
      final page = await _bilibili.fetchCreatorVideos(
        query: creator.name,
        mid: creator.mid,
        page: 1,
        pageSize: 50,
      );
      if (!mounted) return;
      if (page.videos.isNotEmpty) {
        final keepLoaded =
            preserveLoaded && creator.videos.length > page.videos.length;
        setState(() {
          if (keepLoaded) {
            creator.total = page.total > 0 ? page.total : creator.total;
          } else {
            creator.videos = page.videos;
            creator.total = page.total > 0 ? page.total : page.videos.length;
            creator.fromSearch = page.fromSearch;
          }
        });
        _cacheCreator(creator);
      }
    }

    for (final creator in creators) {
      if (!mounted) return;
      await refreshOne(creator);
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }

    for (final creator
        in creators.where((creator) => creator.total <= 1).toList()) {
      if (!mounted) return;
      await refreshOne(creator);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    if (fullRefresh) _initialFullRefreshDone = true;
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _loadAllVideos(_VideoCreator creator) async {
    if (_loadingAllCreators.contains(creator.id)) return;
    setState(() => _loadingAllCreators.add(creator.id));
    final videos = await _bilibili.fetchAllCreatorVideos(mid: creator.mid);
    if (!mounted) return;
    setState(() {
      if (videos.isNotEmpty) {
        creator.videos = videos;
        creator.total = videos.length;
        creator.fromSearch = false;
        _expandedCreators.add(creator.id);
      }
      _loadingAllCreators.remove(creator.id);
    });
    if (videos.isNotEmpty) _cacheCreator(creator);
    if (videos.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载全部视频失败，请稍后重试')),
      );
    }
  }

  void _refreshAll() {
    if (_refreshing) return;
    unawaited(_refreshVideos(_allCreators, fullRefresh: true));
  }

  void _openVideo(_VideoCreator creator, BilibiliVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BilibiliPlayerPage(
          name: creator.name,
          bvid: video.bvid,
        ),
      ),
    );
  }

  void _showInfo(AppThemeSpec spec) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: spec.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '关于视频合集',
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '首次进入页面会全量刷新各 UP 主的视频列表，之后直接使用本次运行缓存，仅在点击合集或 UP 主时按需刷新该项；也可点击右上角刷新按钮手动全量刷新。点击视频即可在应用内由 B 站播放器直接播放，不缓存、不代理。',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 12.5,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '支持按 UP 主名称、标签或视频标题搜索。仅保留已确认可播放视频的 UP 主。',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 12.5,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ),
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
        title: const Text('视频合集'),
        actions: [
          IconButton(
            tooltip: '添加喜欢的 UP 主',
            onPressed: _addingUp ? null : () => _showAddUpDialog(),
            icon: const Icon(Icons.electrical_services_rounded),
          ),
          IconButton(
            tooltip: '刷新视频',
            onPressed: _refreshing || _addingUp ? null : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: '说明',
            onPressed: () => _showInfo(spec),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(spec)
              : _content(spec),
    );
  }

  Widget _errorView(AppThemeSpec spec) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.smart_display_outlined,
                color: spec.textSecondary,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AppThemeSpec spec) {
    final categories = _visibleCategories;
    final query = _query.trim().toLowerCase();
    final sections = <({_VideoCategory category, List<_VideoEntry> entries})>[];
    for (final category in categories) {
      final entries = <_VideoEntry>[];
      for (final creator in category.items) {
        final creatorText = [
          creator.name,
          ...creator.tags,
          creator.audience,
        ].join(' ').toLowerCase();
        final creatorMatches = query.isEmpty || creatorText.contains(query);
        final matchedVideos = creatorMatches
            ? creator.videos
            : creator.videos
                .where(
                  (video) =>
                      video.title.toLowerCase().contains(query) ||
                      video.author.toLowerCase().contains(query),
                )
                .toList();
        if (creatorMatches || matchedVideos.isNotEmpty) {
          entries.add(
            _VideoEntry(creator: creator, videos: matchedVideos),
          );
        }
      }
      if (entries.isNotEmpty) {
        sections.add((category: category, entries: entries));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (_introVisible) ...[
          GlassPanel(
            padding: const EdgeInsets.all(16),
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
                  icon: Icons.smart_display_rounded,
                  colors: [spec.primary, spec.secondary],
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'B 站跟练入口',
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_totalCreators 位 UP 主 · $_totalVideos 个视频',
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 11.5,
                          height: 1.5,
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
          const SizedBox(height: 12),
        ],
        _searchField(spec),
        const SizedBox(height: 12),
        Text(
          '按训练目标分类，点击视频在应用内播放。',
          style: TextStyle(
            color: spec.textSecondary,
            fontSize: 11.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(spec, '全部', '全部'),
              for (final category in _categories) ...[
                const SizedBox(width: 8),
                _filterChip(spec, category.id, category.name),
              ],
            ],
          ),
        ),
        if (_refreshing || _addingUp) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: spec.textPrimary.withValues(alpha: .05),
              color: spec.primary,
            ),
          ),
        ],
        const SizedBox(height: 4),
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: GlassPanel(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: spec.textSecondary,
                    size: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '没有找到相关 UP 主或视频',
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '试试更短的关键词，或清空搜索。',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final section in sections)
            _categorySection(
              spec,
              section.category,
              section.entries,
              searching: query.isNotEmpty,
            ),
      ],
    );
  }

  Widget _categorySection(
    AppThemeSpec spec,
    _VideoCategory category,
    List<_VideoEntry> entries, {
    required bool searching,
  }) {
    final collapsed = !searching && _collapsedCategories.contains(category.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: category.name,
          subtitle: collapsed
              ? '${entries.length} 位 UP 主 · 已折叠'
              : '${entries.length} 位 UP 主',
          padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
          trailing: IconButton(
            tooltip: collapsed ? '展开合集' : '折叠合集',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                if (collapsed) {
                  _collapsedCategories.remove(category.id);
                } else {
                  _collapsedCategories.add(category.id);
                }
              });
            },
            icon: Icon(
              collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              color: spec.textSecondary,
              size: 20,
            ),
          ),
        ),
        if (!collapsed)
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _creatorCard(
                spec,
                entry.creator,
                entry.videos,
                searching: searching,
              ),
            ),
      ],
    );
  }

  Widget _searchField(AppThemeSpec spec) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim()),
      style: TextStyle(
        color: spec.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: '搜索 UP 主 / 视频',
        hintStyle: TextStyle(color: spec.textSecondary, fontSize: 12),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: spec.textSecondary,
          size: 20,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                tooltip: '清空搜索',
                icon: Icon(
                  Icons.close_rounded,
                  color: spec.textSecondary,
                  size: 18,
                ),
              ),
        isDense: true,
        filled: true,
        fillColor: spec.textPrimary.withValues(alpha: .04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: spec.textPrimary.withValues(alpha: .08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: spec.textPrimary.withValues(alpha: .08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: spec.primary.withValues(alpha: .65)),
        ),
      ),
    );
  }

  void _refreshClickedCategory(String id) {
    if (id == '全部' || _refreshing) return;
    if (!_refreshedCategoryOnTap.add(id)) return;
    _VideoCategory? category;
    for (final item in _categories) {
      if (item.id == id) {
        category = item;
        break;
      }
    }
    if (category == null) return;
    unawaited(_refreshVideos(category.items, preserveLoaded: true));
  }

  Widget _filterChip(AppThemeSpec spec, String id, String label) {
    final selected = _selected == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selected = id);
        _refreshClickedCategory(id);
      },
      selectedColor: spec.primary.withValues(alpha: .16),
      labelStyle: TextStyle(
        color: selected ? spec.primary : spec.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? spec.primary.withValues(alpha: .45)
            : spec.textPrimary.withValues(alpha: .08),
      ),
      backgroundColor: spec.card.withValues(alpha: .8),
      showCheckmark: false,
    );
  }

  Widget _creatorCard(
    AppThemeSpec spec,
    _VideoCreator creator,
    List<BilibiliVideo> videos, {
    required bool searching,
  }) {
    final expanded = searching || _expandedCreators.contains(creator.id);
    final visible = expanded ? videos : videos.take(2).toList();
    final loadingAll = _loadingAllCreators.contains(creator.id);
    final total = creator.total > 0 ? creator.total : videos.length;
    final allLoaded = !creator.fromSearch && creator.videos.length >= total;
    final canExpand =
        !searching && (creator.fromSearch || videos.length > 2 || total > 2);
    final showLoadAll = creator.fromSearch || !allLoaded;
    final countLabel =
        creator.fromSearch ? '${creator.videos.length}+ 个视频' : '$total 个视频';
    final loadLabel = creator.fromSearch ? '加载全部视频' : '加载全部 $total 个视频';

    void toggleExpanded() {
      if (!canExpand) return;
      final willExpand = !expanded;
      setState(() {
        if (expanded) {
          _expandedCreators.remove(creator.id);
        } else {
          _expandedCreators.add(creator.id);
        }
      });
      if (!willExpand) return;
      if (showLoadAll) {
        _loadAllVideos(creator);
      } else if (!_refreshing && _refreshedCreatorOnTap.add(creator.mid)) {
        unawaited(_refreshVideos([creator], preserveLoaded: true));
      }
    }

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canExpand ? toggleExpanded : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: spec.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: spec.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final tag in creator.tags)
                            Pill(label: tag, color: spec.secondary),
                        ],
                      ),
                      if (creator.audience.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          '适合：${creator.audience}',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      countLabel,
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canExpand)
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: spec.textSecondary,
                        size: 19,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final video in visible) _videoTile(spec, creator, video),
            if (showLoadAll)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loadingAll ? null : () => _loadAllVideos(creator),
                  child: loadingAll
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: spec.primary,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '正在加载全部视频…',
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          loadLabel,
                          style: TextStyle(
                            color: spec.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              )
            else if (canExpand)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: toggleExpanded,
                  child: Text(
                    expanded ? '收起' : '展开全部 ${videos.length} 个视频',
                    style: TextStyle(
                      color: spec.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '正在后台获取视频…',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: loadingAll ? null : () => _loadAllVideos(creator),
                  child: Text(
                    loadingAll ? '获取中…' : '获取视频',
                    style: TextStyle(
                      color: spec.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _videoTile(
    AppThemeSpec spec,
    _VideoCreator creator,
    BilibiliVideo video,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openVideo(creator, video),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: spec.textPrimary.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: spec.textPrimary.withValues(alpha: .06),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: spec.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    video.title.isEmpty ? '未命名视频' : video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (video.duration.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    video.duration,
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomCreator {
  final String id;
  final String name;
  final int mid;

  const _CustomCreator({
    required this.id,
    required this.name,
    required this.mid,
  });
}

class _UpSubmission {
  final String collectionName;
  final String upName;

  const _UpSubmission({
    required this.collectionName,
    required this.upName,
  });
}

class _VideoCategory {
  final String id;
  final String name;
  final List<_VideoCreator> items;

  const _VideoCategory({
    required this.id,
    required this.name,
    required this.items,
  });
}

class _VideoCreator {
  final String id;
  final String name;
  final List<String> tags;
  final String audience;
  final int mid;
  int total;
  bool fromSearch;
  List<BilibiliVideo> videos;

  _VideoCreator({
    required this.id,
    required this.name,
    required this.tags,
    required this.audience,
    required this.mid,
    required this.total,
    required this.fromSearch,
    required this.videos,
  });
}

class _CachedCreatorVideos {
  final List<BilibiliVideo> videos;
  final int total;
  final bool fromSearch;

  const _CachedCreatorVideos({
    required this.videos,
    required this.total,
    required this.fromSearch,
  });
}

class _VideoEntry {
  final _VideoCreator creator;
  final List<BilibiliVideo> videos;

  const _VideoEntry({required this.creator, required this.videos});
}

class _AddUpDialog extends StatefulWidget {
  final List<String> collectionNames;

  const _AddUpDialog({required this.collectionNames});

  @override
  State<_AddUpDialog> createState() => _AddUpDialogState();
}

class _AddUpDialogState extends State<_AddUpDialog> {
  late final TextEditingController _collectionController;
  late final TextEditingController _upController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _collectionController = TextEditingController();
    _upController = TextEditingController();
  }

  @override
  void dispose() {
    _collectionController.dispose();
    _upController.dispose();
    super.dispose();
  }

  void _submit() {
    final collectionName = _collectionController.text.trim();
    final upName = _upController.text.trim();
    if (collectionName.isEmpty) {
      setState(() => _error = '请输入或选择合集名称');
      return;
    }
    if (upName.isEmpty) {
      setState(() => _error = '请输入 UP 主名称');
      return;
    }
    Navigator.pop(
      context,
      _UpSubmission(collectionName: collectionName, upName: upName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final dialogWidth =
        (MediaQuery.sizeOf(context).width - 96).clamp(240.0, 360.0);
    return AlertDialog(
      backgroundColor: spec.surface,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '添加喜欢的Up主',
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '一定要准确无误地输入TA的名字',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownMenu<String>(
                controller: _collectionController,
                width: dialogWidth,
                menuHeight: 220,
                enableFilter: true,
                requestFocusOnTap: true,
                label: Text(
                  '合集名称',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 12,
                  ),
                ),
                hintText: '选择已有合集或输入新名称',
                textStyle: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                dropdownMenuEntries: widget.collectionNames
                    .map(
                      (name) => DropdownMenuEntry<String>(
                        value: name,
                        label: name,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _upController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'UP 主名称',
                  hintText: '例如：帕梅拉PamelaReif',
                  labelStyle: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 12,
                  ),
                  hintStyle: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: spec.textPrimary.withValues(alpha: .04),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: spec.textPrimary.withValues(alpha: .08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: spec.textPrimary.withValues(alpha: .08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: spec.primary.withValues(alpha: .65),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(color: spec.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: spec.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('确认'),
        ),
      ],
    );
  }
}
