import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/exercise_library.dart';
import '../main.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class HistoryPage extends StatefulWidget {
  final VoidCallback? onExport;
  final VoidCallback? onSync;

  const HistoryPage({super.key, this.onExport, this.onSync});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expanded = {};
  String _query = '';
  String _part = '全部';

  static const List<String> _parts = [
    '全部',
    '胸',
    '背',
    '肩',
    '手臂',
    '腿',
    '臀',
    '核心',
    '有氧',
    '柔韧',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WorkoutRecord> _filtered(List<WorkoutRecord> records) {
    final query = _query.trim().toLowerCase();
    return records.where((record) {
      final partMatch = _part == '全部' ||
          record.projects.any((project) => project.part == _part);
      if (!partMatch) return false;
      if (query.isEmpty) return true;
      final text = [
        ...record.projects.map((p) => p.name),
        ...record.projects.map((p) => p.part),
        ...record.projects.map((p) => p.feeling),
        ...record.projects.map((p) => p.supplement),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Future<void> _editRecord(WorkoutRecord record) async {
    final updated = await showModalBottomSheet<WorkoutRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: .93,
            child: Container(
              decoration: BoxDecoration(
                color: spec.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: spec.textPrimary.withValues(alpha: .08),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _EditRecordSheet(record: record),
            ),
          ),
        );
      },
    );
    if (updated == null || !mounted) return;
    context.read<WorkoutProvider>().updateRecord(record.id, updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('训练记录已更新')),
    );
  }

  Future<void> _deleteRecord(WorkoutRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这次训练？'),
        content: Text(
          '${DateFormat('yyyy年M月d日').format(record.date)} · 第 ${record.sessionNumber ?? '-'} 次训练\n'
          '该操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<WorkoutProvider>().deleteRecord(record.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除记录')),
    );
  }

  Future<void> _mergeRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('整合同日记录'),
        content: const Text('把同一天的多条记录合并为一条，动作会保留。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('整合'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<WorkoutProvider>().mergeSameDayRecords();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已整合同一天的记录')),
    );
  }

  Widget _partChip(String part, AppThemeSpec spec) {
    final active = _part == part;
    return GestureDetector(
      onTap: () => setState(() => _part = part),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? spec.primary.withValues(alpha: .18)
              : spec.textPrimary.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? spec.primary.withValues(alpha: .45)
                : spec.textPrimary.withValues(alpha: .07),
          ),
        ),
        child: Text(
          part,
          style: TextStyle(
            color: active ? spec.primary : spec.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _recordCard(WorkoutRecord record, AppThemeSpec spec) {
    final expanded = _expanded.contains(record.id);
    final recordProjects = dedupeWorkoutProjects(record.projects);
    final parts = recordProjects.map((p) => p.part).toSet().toList();
    final names = recordProjects
        .map((p) => p.name)
        .where((name) => name.trim().isNotEmpty)
        .toList();

    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      radius: 20,
      onTap: () {
        setState(() {
          if (expanded) {
            _expanded.remove(record.id);
          } else {
            _expanded.add(record.id);
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      spec.primary.withValues(alpha: .2),
                      spec.secondary.withValues(alpha: .12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${record.date.day}',
                      style: TextStyle(
                        color: spec.primary,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${record.date.month}月 · ${weekdayLabel(record.date)}',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxParts = constraints.maxWidth < 230 ? 2 : 3;
                        return Row(
                          children: [
                            Flexible(
                              flex: 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '第 ${record.sessionNumber ?? '-'} 次训练',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: spec.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              flex: 2,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final part in parts.take(maxParts))
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Pill(
                                          label: part,
                                          color: spec.secondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (!expanded) ...[
                              const SizedBox(width: 5),
                              Flexible(
                                flex: 2,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: StatusBattery(
                                    level: record.statusBattery,
                                    width: 58,
                                    height: 13,
                                    outlineColor: spec.isDark
                                        ? null
                                        : spec.textPrimary
                                            .withValues(alpha: .42),
                                    textColor:
                                        spec.isDark ? null : spec.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      names.isEmpty ? '暂无动作名称' : names.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          record.totalWork > 0
                              ? Icons.bolt_rounded
                              : Icons.timer_outlined,
                          size: 13,
                          color: spec.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          record.totalWork > 0
                              ? '${formatCompact(record.totalWork)} J'
                              : '${record.totalDurationMinutes.toStringAsFixed(0)} 分钟',
                          style: TextStyle(
                            color: spec.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          record.totalDistanceKm > 0
                              ? '${record.totalDistanceKm.toStringAsFixed(1)} km'
                              : '${recordProjects.length} 个动作',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '管理记录',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: spec.textSecondary,
                  size: 20,
                ),
                onSelected: (value) {
                  if (value == 'edit') _editRecord(record);
                  if (value == 'delete') _deleteRecord(record);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('编辑记录'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('删除记录', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12, right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: spec.textPrimary.withValues(alpha: .07)),
                  const SizedBox(height: 4),
                  for (final project in recordProjects)
                    _ProjectDetail(
                      project: project,
                      spec: spec,
                      battery: record.statusBattery,
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editRecord(record),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('编辑这次训练'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            foregroundColor: spec.primary,
                            side: BorderSide(
                              color: spec.primary.withValues(alpha: .3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final provider = context.watch<WorkoutProvider>();
    final filtered = _filtered(provider.sortedRecords);

    final groups = <String, List<WorkoutRecord>>{};
    for (final record in filtered) {
      final key = DateFormat('yyyy年M月').format(record.date);
      groups.putIfAbsent(key, () => []).add(record);
    }

    final totalWork =
        provider.records.fold<double>(0, (sum, r) => sum + r.totalWork);

    final children = <Widget>[
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: '累计训练',
              value: '${provider.totalSessions}',
              unit: '次',
              icon: Icons.fitness_center_rounded,
              accent: spec.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: '记录条数',
              value: '${provider.records.length}',
              unit: '条',
              icon: Icons.receipt_long_rounded,
              accent: spec.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: '累计做功',
              value: formatCompact(totalWork),
              unit: 'J',
              icon: Icons.bolt_rounded,
              accent: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: TextStyle(color: spec.textPrimary),
        decoration: InputDecoration(
          hintText: '搜索动作、部位或备注',
          prefixIcon:
              Icon(Icons.search_rounded, color: spec.textSecondary, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: Icon(Icons.close_rounded,
                      color: spec.textSecondary, size: 18),
                ),
          filled: true,
          fillColor: spec.textPrimary.withValues(alpha: .04),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide:
                BorderSide(color: spec.textPrimary.withValues(alpha: .07)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide:
                BorderSide(color: spec.textPrimary.withValues(alpha: .07)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: spec.primary.withValues(alpha: .65)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final part in _parts) _partChip(part, spec),
        ],
      ),
      const SizedBox(height: 8),
    ];

    if (filtered.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: EmptyState(
            icon: provider.records.isEmpty
                ? Icons.history_toggle_off_rounded
                : Icons.search_off_rounded,
            title: provider.records.isEmpty ? '还没有训练历史' : '没有匹配的记录',
            message: provider.records.isEmpty
                ? '完成第一次训练后，这里会按月份整理你的每一次进步。'
                : '换一个关键词或训练部位试试。',
          ),
        ),
      );
    } else {
      for (final entry in groups.entries) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
            child: Row(
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: spec.textPrimary.withValues(alpha: .07),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.length} 条',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
        for (final record in entry.value) {
          children.add(_recordCard(record, spec));
        }
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: spec.background.withValues(alpha: .82),
            title: const Text('训练历史'),
            actions: [
              if (widget.onSync != null)
                IconButton(
                  tooltip: '云同步',
                  onPressed: widget.onSync,
                  icon: const Icon(Icons.cloud_sync_outlined),
                ),
              if (widget.onExport != null)
                IconButton(
                  tooltip: '导出 Excel',
                  onPressed: widget.onExport,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: (value) {
                  if (value == 'merge') _mergeRecords();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'merge',
                    child: Row(
                      children: [
                        Icon(Icons.merge_type_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('整合同日记录'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(children),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetail extends StatelessWidget {
  final WorkoutProject project;
  final AppThemeSpec spec;
  final int battery;

  const _ProjectDetail({
    required this.project,
    required this.spec,
    required this.battery,
  });

  @override
  Widget build(BuildContext context) {
    final notes = [
      if (project.feeling.trim().isNotEmpty) '感受：${project.feeling.trim()}',
      if (project.supplement.trim().isNotEmpty)
        '备注：${project.supplement.trim()}',
    ];
    final metric = project.isTimeBased
        ? '${project.inputSummary}  ·  ${project.estimatedCalories().round()} kcal'
        : '${project.inputSummary}  ·  ${formatCompact(project.calculateWork())} J';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: spec.textPrimary.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: spec.textPrimary.withValues(alpha: .05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name.isEmpty ? '未命名动作' : project.name,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBattery(
                level: battery,
                width: 64,
                height: 13,
                outlineColor: spec.isDark
                    ? null
                    : spec.textPrimary.withValues(alpha: .42),
                textColor: spec.isDark ? null : spec.textPrimary,
              ),
              const SizedBox(width: 8),
              Pill(label: project.part, color: spec.secondary),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            metric,
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notes.join('  ·  '),
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditDraft {
  final TextEditingController name;
  final TextEditingController weight;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController feeling;
  final TextEditingController supplement;
  final TextEditingController duration;
  final TextEditingController distance;
  String part;

  _EditDraft({
    required this.name,
    required this.weight,
    required this.sets,
    required this.reps,
    required this.feeling,
    required this.supplement,
    required this.duration,
    required this.distance,
    required this.part,
  });

  factory _EditDraft.fromProject(WorkoutProject project) {
    return _EditDraft(
      name: TextEditingController(text: project.name),
      weight: TextEditingController(
        text: project.weight == 0 ? '' : project.weight.toString(),
      ),
      sets: TextEditingController(
        text: project.sets == 0 ? '' : project.sets.toString(),
      ),
      reps: TextEditingController(
        text: project.repsPerSet == 0 ? '' : project.repsPerSet.toString(),
      ),
      feeling: TextEditingController(text: project.feeling),
      supplement: TextEditingController(text: project.supplement),
      duration: TextEditingController(
        text: project.durationMinutes == 0
            ? ''
            : project.durationMinutes.toString(),
      ),
      distance: TextEditingController(
        text: project.distanceKm == 0 ? '' : project.distanceKm.toString(),
      ),
      part: project.part,
    );
  }

  factory _EditDraft.empty() {
    return _EditDraft(
      name: TextEditingController(),
      weight: TextEditingController(),
      sets: TextEditingController(),
      reps: TextEditingController(),
      feeling: TextEditingController(),
      supplement: TextEditingController(),
      duration: TextEditingController(),
      distance: TextEditingController(),
      part: '胸',
    );
  }

  void dispose() {
    name.dispose();
    weight.dispose();
    sets.dispose();
    reps.dispose();
    feeling.dispose();
    supplement.dispose();
    duration.dispose();
    distance.dispose();
  }
}

class _EditRecordSheet extends StatefulWidget {
  final WorkoutRecord record;

  const _EditRecordSheet({required this.record});

  @override
  State<_EditRecordSheet> createState() => _EditRecordSheetState();
}

class _EditRecordSheetState extends State<_EditRecordSheet> {
  static const List<String> _parts = [
    '胸',
    '背',
    '肩',
    '手臂',
    '腿',
    '臀',
    '核心',
    '有氧',
    '柔韧',
    '全身',
    '专项',
  ];

  late DateTime _date;
  late int _statusBattery;
  late final List<_EditDraft> _drafts;

  @override
  void initState() {
    super.initState();
    _date = widget.record.date;
    _statusBattery = widget.record.statusBattery.clamp(0, 100);
    _drafts = widget.record.projects.isEmpty
        ? [_EditDraft.empty()]
        : widget.record.projects.map(_EditDraft.fromProject).toList();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '修改训练日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  void _addDraft() {
    setState(() => _drafts.add(_EditDraft.empty()));
  }

  void _removeDraft(int index) {
    if (_drafts.length <= 1) return;
    setState(() {
      _drafts.removeAt(index).dispose();
    });
  }

  void _save() {
    final projects = <WorkoutProject>[];
    for (final draft in _drafts) {
      if (draft.name.text.trim().isEmpty) continue;
      final name = draft.name.text.trim();
      final definition = ExerciseLibrary.findByName(name);
      final category = definition?.kind.label ??
          (draft.part == '有氧'
              ? '有氧'
              : draft.part == '柔韧'
                  ? '柔韧'
                  : draft.part == '专项'
                      ? '专项'
                      : '力量');
      projects.add(WorkoutProject(
        name: name,
        part: draft.part,
        weight: double.tryParse(draft.weight.text) ?? 0,
        sets: int.tryParse(draft.sets.text) ?? 0,
        repsPerSet: int.tryParse(draft.reps.text) ?? 0,
        feeling: draft.feeling.text.trim(),
        supplement: draft.supplement.text.trim(),
        category: category,
        durationMinutes: double.tryParse(draft.duration.text.trim()) ?? 0,
        distanceKm: double.tryParse(draft.distance.text.trim()) ?? 0,
        met: definition?.met ?? 0,
      ));
    }
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个动作名称')),
      );
      return;
    }
    Navigator.pop(
      context,
      WorkoutRecord(
        id: widget.record.id,
        date: _date,
        sessionNumber: widget.record.sessionNumber,
        projects: projects,
        statusBattery: _statusBattery,
        timestamp: DateTime.now(),
      ),
    );
  }

  Widget _label(String text, AppThemeSpec spec) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: spec.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _field(
    AppThemeSpec spec,
    TextEditingController controller,
    String hint, {
    String? suffix,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      style: TextStyle(
        color: spec.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: spec.textSecondary, fontSize: 12),
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: spec.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: spec.textPrimary.withValues(alpha: .04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: spec.textPrimary.withValues(alpha: .08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: spec.textPrimary.withValues(alpha: .08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: spec.primary.withValues(alpha: .65)),
        ),
      ),
    );
  }

  void _updateBattery(double dx, double width) {
    final bodyWidth = width - 3.4;
    final fraction =
        ((dx - 1.9) / (bodyWidth - 2.8)).clamp(0.0, 1.0).toDouble();
    final value = (fraction * 100).round();
    if (value != _statusBattery) {
      setState(() => _statusBattery = value);
    }
  }

  Widget _batteryEditor(AppThemeSpec spec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: spec.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: spec.textPrimary.withValues(alpha: .07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.battery_charging_full_rounded,
                size: 34,
                iconSize: 17,
                colors: [spec.primary, spec.secondary],
              ),
              const SizedBox(width: 9),
              Text(
                '状态编辑',
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Pill(label: '电池', color: spec.secondary),
              const Spacer(),
              Text(
                '$_statusBattery%',
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final bodyWidth = width - 3.4;
              final fraction = _statusBattery / 100;
              final x = 1.9 + (bodyWidth - 2.8) * fraction;
              final maxLeft = (width - 8).clamp(0.0, width).toDouble();
              final pointerLeft = (x - 4).clamp(0.0, maxLeft).toDouble();
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _updateBattery(details.localPosition.dx, width),
                onHorizontalDragUpdate: (details) =>
                    _updateBattery(details.localPosition.dx, width),
                child: SizedBox(
                  height: 54,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: pointerLeft,
                        top: 0,
                        child: CustomPaint(
                          size: const Size(8, 54),
                          painter: _BatteryPointerPainter(
                            color: spec.primary,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        top: 14,
                        bottom: 14,
                        left: 0,
                        right: 0,
                        child: StatusBattery(
                          level: _statusBattery,
                          height: 26,
                          bodyColor: spec.card,
                          outlineColor: spec.isDark
                              ? null
                              : spec.textPrimary.withValues(alpha: .42),
                          textColor: spec.isDark ? null : spec.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            '左右拖动指针，调整这一天记录的状态电量',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftCard(_EditDraft draft, int index, AppThemeSpec spec) {
    return Container(
      key: ObjectKey(draft),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: spec.card.withValues(alpha: .66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: spec.textPrimary.withValues(alpha: .07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.fitness_center_rounded,
                size: 34,
                iconSize: 17,
                colors: [spec.primary, spec.secondary],
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '动作 ${index + 1}',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_drafts.length > 1)
                IconButton(
                  onPressed: () => _removeDraft(index),
                  tooltip: '删除动作',
                  icon: Icon(Icons.close_rounded,
                      size: 19, color: spec.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _label('动作名称', spec),
          _field(spec, draft.name, '例如：深蹲'),
          const SizedBox(height: 10),
          _label('锻炼部位', spec),
          DropdownButtonFormField<String>(
            initialValue: draft.part,
            isDense: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: spec.textPrimary.withValues(alpha: .04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: spec.textPrimary.withValues(alpha: .08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: spec.textPrimary.withValues(alpha: .08),
                ),
              ),
            ),
            items: [
              for (final part in _parts)
                DropdownMenuItem(value: part, child: Text(part)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => draft.part = value);
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('重量', spec),
                    _field(
                      spec,
                      draft.weight,
                      '0',
                      suffix: 'kg',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('组数', spec),
                    _field(
                      spec,
                      draft.sets,
                      '0',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('每组次数', spec),
                    _field(
                      spec,
                      draft.reps,
                      '0',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('时长（有氧/柔韧）', spec),
                    _field(
                      spec,
                      draft.duration,
                      '0',
                      suffix: '分钟',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('距离（有氧）', spec),
                    _field(
                      spec,
                      draft.distance,
                      '0',
                      suffix: 'km',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _label('训练感受', spec),
          _field(spec, draft.feeling, '状态、力竭程度…'),
          const SizedBox(height: 10),
          _label('补剂 / 备注', spec),
          _field(spec, draft.supplement, '可选'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '编辑训练记录',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '第 ${widget.record.sessionNumber ?? '-'} 次训练',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: spec.textSecondary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                decoration: BoxDecoration(
                  color: spec.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: spec.primary.withValues(alpha: .2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        size: 20, color: spec.primary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${DateFormat('yyyy年M月d日').format(_date)} · ${weekdayLabel(_date)}',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '修改日期',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            children: [
              _batteryEditor(spec),
              for (var i = 0; i < _drafts.length; i++)
                _draftCard(_drafts[i], i, spec),
              OutlinedButton.icon(
                onPressed: _addDraft,
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加动作'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: spec.primary,
                  side: BorderSide(
                    color: spec.primary.withValues(alpha: .3),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: GestureDetector(
              onTap: _save,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: spec.heroGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: spec.primary.withValues(alpha: .3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '保存修改',
                    style: TextStyle(
                      color: spec.onHero,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BatteryPointerPainter extends CustomPainter {
  final Color color;

  _BatteryPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .92));
  }

  @override
  bool shouldRepaint(covariant _BatteryPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}
