import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_providers.dart';
import '../services/ai_coach_service.dart';
import '../services/knowledge_service.dart';
import '../widgets/ai_message_text.dart';
import '../widgets/app_ui.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  List<KnowledgeArticle> _articles = const [];
  List<String> _failures = const [];
  bool _loading = true;
  String _topic = '全部';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bundle = await KnowledgeService.fetchAll(limitPerTopic: 6);
    if (!mounted) return;
    setState(() {
      _articles = bundle.articles;
      _failures = bundle.failures;
      _loading = false;
    });
  }

  List<KnowledgeArticle> get _filtered {
    if (_topic == '全部') return _articles;
    return _articles.where((article) => article.category == _topic).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final filtered = _filtered;
    final topics = ['全部', ...KnowledgeService.topics.map((t) => t.label)];

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('知识补给'),
        actions: [
          IconButton(
            tooltip: '刷新实时资讯',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: [
            GlassPanel(
              padding: const EdgeInsets.all(16),
              gradient: LinearGradient(
                colors: [
                  spec.primary.withValues(alpha: .14),
                  spec.secondary.withValues(alpha: .06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Row(
                children: [
                  GradientIconBadge(
                    icon: Icons.public_rounded,
                    colors: [spec.primary, spec.secondary],
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '实时同步 PubMed 与 WHO',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _loading
                              ? '正在获取最新运动科学与健康资讯…'
                              : '已获取 ${_articles.length} 条最新资讯 · 下拉刷新',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 11.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final topic in topics)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(topic),
                        selected: _topic == topic,
                        onSelected: (_) => setState(() => _topic = topic),
                        selectedColor: spec.primary.withValues(alpha: .16),
                        labelStyle: TextStyle(
                          color: _topic == topic
                              ? spec.primary
                              : spec.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: _topic == topic
                              ? spec.primary.withValues(alpha: .45)
                              : spec.textPrimary.withValues(alpha: .08),
                        ),
                        backgroundColor: spec.card.withValues(alpha: .8),
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              GlassPanel(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: spec.textSecondary,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '暂时没有获取到实时资讯',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _failures.isEmpty ? '请检查网络后下拉刷新。' : _failures.join('\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11,
                        height: 1.5,
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
              )
            else
              for (final article in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: KnowledgeArticleCard(article: article),
                ),
            if (!_loading && _failures.isNotEmpty && filtered.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '部分来源暂时不可用：${_failures.join('；')}',
                style: TextStyle(
                  color: spec.textSecondary.withValues(alpha: .8),
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KnowledgeArticleCard extends StatelessWidget {
  final KnowledgeArticle article;

  const KnowledgeArticleCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final date = article.publishedAt == null
        ? '最新'
        : DateFormat('yyyy-MM-dd').format(article.publishedAt!);
    return GlassPanel(
      padding: const EdgeInsets.all(15),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => KnowledgeDetailPage(article: article),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                label: article.category,
                color: article.source == 'WHO'
                    ? const Color(0xFF38BDF8)
                    : spec.primary,
                icon: article.source == 'WHO'
                    ? Icons.public_rounded
                    : Icons.science_rounded,
              ),
              const Spacer(),
              Text(
                date,
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            article.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            article.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  article.authors.isEmpty
                      ? article.source
                      : '${article.authors.first} 等 · ${article.source}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: spec.primary.withValues(alpha: .8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class KnowledgeDetailPage extends StatefulWidget {
  final KnowledgeArticle article;

  const KnowledgeDetailPage({super.key, required this.article});

  @override
  State<KnowledgeDetailPage> createState() => _KnowledgeDetailPageState();
}

class _KnowledgeDetailPageState extends State<KnowledgeDetailPage> {
  String? _abstract;
  bool _loadingAbstract = false;
  bool _aiLoading = false;
  String? _aiReply;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _abstract = widget.article.abstractText;
    if (_abstract == null && widget.article.isPubMed) {
      _loadAbstract();
    }
  }

  Future<void> _loadAbstract() async {
    setState(() => _loadingAbstract = true);
    final text = await KnowledgeService.fetchAbstract(widget.article.pmid);
    if (!mounted) return;
    setState(() {
      _abstract = text;
      _loadingAbstract = false;
    });
  }

  Future<void> _interpret(SettingsProvider settings) async {
    if (_aiLoading) return;
    if (!settings.aiEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 建议已在设置中关闭。')),
      );
      return;
    }
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiReply = null;
    });

    final article = widget.article;
    final reply = await AiCoachService.chat(
      endpoint: settings.aiEndpoint,
      model: settings.aiModel,
      apiKey: settings.aiApiKey,
      messages: [
        {
          'role': 'system',
          'content': '你是「铁镌」App 的运动科学解读助手。请用自然、易懂的中文把研究讲清楚。'
              '输出格式：第一行一句不超过 20 字的结论；随后依次用“研究发现：”“对你的意义：”“注意：”三个短标题各写 1-2 句；'
              '不使用 Markdown 符号（#、*、`、>、|）、表格或制表符；不超过 420 字；'
              '只输出最终中文回答，不要输出思考过程或英文草稿。不要做医疗诊断，证据不足时明确说明。',
        },
        {
          'role': 'user',
          'content':
              '标题：${article.title}\n来源：${article.source}\n摘要：${_abstract ?? article.summary}\n请解读这项资讯。',
        },
      ],
    );

    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      if (reply.success) {
        _aiReply = reply.content;
      } else {
        _aiError = reply.error ?? 'AI 暂时不可用';
      }
    });
  }

  Future<void> _openSource() async {
    final uri = Uri.tryParse(widget.article.url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开原文链接。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final settings = context.watch<SettingsProvider>();
    final article = widget.article;
    final date = article.publishedAt == null
        ? ''
        : DateFormat('yyyy年M月d日').format(article.publishedAt!);

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('资讯详情'),
        actions: [
          IconButton(
            tooltip: '打开原文',
            onPressed: _openSource,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Row(
            children: [
              Pill(
                label: article.category,
                color: article.source == 'WHO'
                    ? const Color(0xFF38BDF8)
                    : spec.primary,
                icon: article.source == 'WHO'
                    ? Icons.public_rounded
                    : Icons.science_rounded,
              ),
              const SizedBox(width: 8),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            article.title,
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 21,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            [
              article.source,
              if (article.authors.isNotEmpty) article.authors.join('、'),
            ].join(' · '),
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '摘要',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loadingAbstract)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SelectableText(
                    _abstract ?? article.summary,
                    style: TextStyle(
                      color: spec.textPrimary,
                      fontSize: 13,
                      height: 1.75,
                    ),
                  ),
                if (_abstract == null && article.isPubMed) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadAbstract,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('重新获取摘要'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openSource,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('阅读原文'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _aiLoading ? null : () => _interpret(settings),
                  icon: _aiLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(_aiLoading ? '解读中…' : 'AI 解读'),
                ),
              ),
            ],
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(14),
              child: Text(
                'AI 解读暂不可用：$_aiError',
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (_aiReply != null) ...[
            const SizedBox(height: 16),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              gradient: LinearGradient(
                colors: [
                  spec.primary.withValues(alpha: .09),
                  spec.card.withValues(alpha: .96),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: spec.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'AI 科学解读',
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AiMessageText(
                    text: _aiReply!,
                    spec: spec,
                    selectable: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI 解读仅供参考，不替代医生或专业教练意见。',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            article.source == 'WHO'
                ? '来源：世界卫生组织官方 RSS。'
                : '来源：PubMed / NCBI E-utilities 实时检索。',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
