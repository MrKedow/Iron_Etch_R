import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exercise_library.dart';
import '../data/exercise_illustrations.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/exercise_illustration.dart';

class ExerciseLibraryPage extends StatefulWidget {
  final ExerciseKind? initialKind;
  final bool selectMode;

  const ExerciseLibraryPage({
    super.key,
    this.initialKind,
    this.selectMode = true,
  });

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final TextEditingController _search = TextEditingController();
  ExerciseKind? _kind;
  String? _group;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _search.addListener(() {
      if (!mounted) return;
      setState(() => _query = _search.text.trim());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ExerciseDefinition> get _results {
    return ExerciseLibrary.search(
      query: _query,
      kind: _kind,
      group: _group,
    );
  }

  List<String> get _groups {
    if (_kind == null) return ExerciseLibrary.groupOrder;
    return ExerciseLibrary.all
        .where((e) => e.kind == _kind)
        .map((e) => e.group)
        .toSet()
        .toList()
      ..sort((a, b) => ExerciseLibrary.groupOrder
          .indexOf(a)
          .compareTo(ExerciseLibrary.groupOrder.indexOf(b)));
  }

  void _selectKind(ExerciseKind? kind) {
    setState(() {
      _kind = _kind == kind ? null : kind;
      if (_group != null && !_groups.contains(_group)) _group = null;
    });
  }

  void _openDetail(ExerciseDefinition exercise) {
    showModalBottomSheet<ExerciseDefinition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        final group = ExerciseLibrary.groups[exercise.group];
        return FractionallySizedBox(
          heightFactor: .82,
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: spec.textSecondary.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    GradientIconBadge(
                      icon: _kindIcon(exercise.kind),
                      colors: [spec.primary, spec.secondary],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Pill(
                                label: exercise.kind.label,
                                icon: _kindIcon(exercise.kind),
                              ),
                              Pill(
                                label: exercise.group,
                                color: spec.secondary,
                              ),
                              Pill(
                                label: exercise.equipment,
                                color: spec.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Icon(
                        Icons.close_rounded,
                        color: spec.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 210,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        spec.primary.withValues(alpha: .12),
                        spec.secondary.withValues(alpha: .05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: spec.primary.withValues(alpha: .14),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 34),
                          child: _exerciseIllustration(exercise, spec),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: Pill(
                          label: exercise.pattern,
                          icon: Icons.sync_alt_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _detailSection(
                  spec,
                  '动作要领',
                  exercise.cue,
                  Icons.lightbulb_outline_rounded,
                ),
                const SizedBox(height: 12),
                _detailSection(
                  spec,
                  '动作模式',
                  '${exercise.pattern} · 难度 ${_difficultyLabel(exercise.difficulty)}',
                  Icons.sync_alt_rounded,
                ),
                if (group != null) ...[
                  const SizedBox(height: 12),
                  _muscleSection(spec, group, exercise),
                ],
                if (exercise.aliases.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailSection(
                    spec,
                    '常见别名',
                    exercise.aliases.join('、'),
                    Icons.tag_rounded,
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  ExerciseLibrary.source,
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                if (widget.selectMode)
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, exercise),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('使用这个动作'),
                  ),
              ],
            ),
          ),
        );
      },
    ).then((value) {
      if (value is ExerciseDefinition && mounted) {
        Navigator.pop(context, value);
      }
    });
  }

  Widget _exerciseIllustration(ExerciseDefinition exercise, AppThemeSpec spec) {
    final slug = exerciseImageSlugs[exercise.name];
    if (slug == null) {
      return ExerciseIllustration(
        pattern: exercise.pattern,
        equipment: exercise.equipment,
        color: spec.primary,
      );
    }
    Widget frame(int index, String label) {
      return Expanded(
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/exercises/${slug}_$index.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => ExerciseIllustration(
                    pattern: exercise.pattern,
                    equipment: exercise.equipment,
                    color: spec.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        frame(0, '起始'),
        const SizedBox(width: 10),
        frame(1, '结束'),
      ],
    );
  }

  Widget _detailSection(
    AppThemeSpec spec,
    String title,
    String body,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: spec.textPrimary.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: spec.textPrimary.withValues(alpha: .06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: spec.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _muscleSection(
    AppThemeSpec spec,
    MuscleGroup group,
    ExerciseDefinition exercise,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            spec.primary.withValues(alpha: .09),
            spec.secondary.withValues(alpha: .05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: spec.primary.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.accessibility_new_rounded,
                  size: 18, color: spec.primary),
              const SizedBox(width: 8),
              Text(
                '解剖肌群',
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '主要发力',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            group.primary.join('、'),
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (exercise.emphasis.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '本动作侧重：${exercise.emphasis.join('、')}',
              style: TextStyle(
                color: spec.primary,
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '协同肌群',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            group.secondary.join('、'),
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            group.note,
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final results = _results;
    final groups = _groups;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: spec.background.withValues(alpha: .9),
            title: Text(widget.selectMode ? '选择动作' : '动作库'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Pill(
                    label: '${ExerciseLibrary.all.length} 个动作',
                    icon: Icons.menu_book_rounded,
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                TextField(
                  controller: _search,
                  style: TextStyle(color: spec.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索动作、肌群或器械',
                    hintStyle: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => _search.clear(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _kindChip(null, '全部', spec),
                      for (final kind in ExerciseKind.values) ...[
                        const SizedBox(width: 7),
                        _kindChip(kind, kind.label, spec),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _groupChip(null, '全部部位', spec),
                      for (final group in groups) ...[
                        const SizedBox(width: 7),
                        _groupChip(group, group, spec),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${results.length} 个结果',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '点击查看解剖与要领',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ]),
            ),
          ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '没有找到匹配的动作',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final exercise = results[index];
                    return _exerciseCard(exercise, spec);
                  },
                  childCount: results.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kindChip(ExerciseKind? kind, String label, AppThemeSpec spec) {
    final active = _kind == kind;
    return GestureDetector(
      onTap: () => _selectKind(kind),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          kind == null ? label : '${kind.emoji} $label',
          style: TextStyle(
            color: active ? spec.primary : spec.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _groupChip(String? group, String label, AppThemeSpec spec) {
    final active = _group == group;
    return GestureDetector(
      onTap: () => setState(() => _group = _group == group ? null : group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? spec.secondary.withValues(alpha: .17)
              : spec.textPrimary.withValues(alpha: .025),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? spec.secondary.withValues(alpha: .4)
                : spec.textPrimary.withValues(alpha: .06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? spec.secondary : spec.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _exerciseCard(ExerciseDefinition exercise, AppThemeSpec spec) {
    final group = ExerciseLibrary.groups[exercise.group];
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      radius: 17,
      onTap: () => _openDetail(exercise),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: spec.primary.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ExerciseIllustration(
                pattern: exercise.pattern,
                equipment: exercise.equipment,
                color: spec.primary,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Pill(label: exercise.group, color: spec.secondary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.equipment} · ${exercise.pattern} · ${_difficultyLabel(exercise.difficulty)}'
                  '${group == null ? '' : ' · ${group.primary.first}'}',
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
          const SizedBox(width: 6),
          Icon(
            widget.selectMode
                ? Icons.add_circle_outline_rounded
                : Icons.chevron_right_rounded,
            size: 20,
            color: widget.selectMode ? spec.primary : spec.textSecondary,
          ),
        ],
      ),
    );
  }

  static IconData _kindIcon(ExerciseKind kind) {
    switch (kind) {
      case ExerciseKind.strength:
        return Icons.fitness_center_rounded;
      case ExerciseKind.cardio:
        return Icons.directions_run_rounded;
      case ExerciseKind.mobility:
        return Icons.self_improvement_rounded;
      case ExerciseKind.functional:
        return Icons.sports_gymnastics_rounded;
      case ExerciseKind.sport:
        return Icons.sports_basketball_rounded;
    }
  }

  static String _difficultyLabel(int difficulty) {
    if (difficulty <= 1) return '入门';
    if (difficulty == 2) return '进阶';
    return '高阶';
  }
}
