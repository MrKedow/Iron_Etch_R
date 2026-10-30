import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/exercise_library.dart';
import '../main.dart';
import '../providers/app_providers.dart';
import '../services/coach_insights.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

enum InsightRange { week, month, year, custom }

extension InsightRangeLabel on InsightRange {
  String get label {
    switch (this) {
      case InsightRange.week:
        return '一周';
      case InsightRange.month:
        return '一月';
      case InsightRange.year:
        return '年度';
      case InsightRange.custom:
        return '自定义';
    }
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _startOfWeek(DateTime date) {
  final day = _dateOnly(date);
  return day.subtract(Duration(days: day.weekday - 1));
}

DateTimeRange _resolveRange(InsightRange range, DateTimeRange? custom) {
  final now = _dateOnly(DateTime.now());
  switch (range) {
    case InsightRange.week:
      return DateTimeRange(
        start: now.subtract(const Duration(days: 6)),
        end: now,
      );
    case InsightRange.month:
      return DateTimeRange(
        start: now.subtract(const Duration(days: 29)),
        end: now,
      );
    case InsightRange.year:
      return DateTimeRange(
        start: now.subtract(const Duration(days: 364)),
        end: now,
      );
    case InsightRange.custom:
      final selected = custom ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 29)),
            end: now,
          );
      return DateTimeRange(
        start: _dateOnly(selected.start),
        end: _dateOnly(selected.end),
      );
  }
}

List<WorkoutRecord> _recordsInRange(
  List<WorkoutRecord> records,
  DateTimeRange range,
) {
  final start = _dateOnly(range.start);
  final end = _dateOnly(range.end);
  return records.where((record) {
    final date = _dateOnly(record.date);
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList();
}

String _rangeCaption(InsightRange range, DateTimeRange resolved) {
  final fmt = DateFormat('yyyy/M/d');
  if (range == InsightRange.custom) {
    return '${fmt.format(resolved.start)} - ${fmt.format(resolved.end)}';
  }
  return '${fmt.format(resolved.start)} - ${fmt.format(resolved.end)} · 共 ${resolved.end.difference(resolved.start).inDays + 1} 天';
}

class InsightRangeSelector extends StatelessWidget {
  final InsightRange value;
  final DateTimeRange? customRange;
  final ValueChanged<InsightRange> onChanged;

  const InsightRangeSelector({
    super.key,
    required this.value,
    required this.customRange,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final resolved = _resolveRange(value, customRange);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in InsightRange.values)
              ChoiceChip(
                label: Text(option.label),
                selected: value == option,
                onSelected: (_) => onChanged(option),
                selectedColor: spec.primary.withValues(alpha: .16),
                labelStyle: TextStyle(
                  color: value == option ? spec.primary : spec.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: value == option
                      ? spec.primary.withValues(alpha: .35)
                      : spec.textPrimary.withValues(alpha: .08),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 14,
              color: spec.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _rangeCaption(value, resolved),
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WeeklyTrainingDaysPage extends StatelessWidget {
  const WeeklyTrainingDaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final records = context.watch<WorkoutProvider>().records;
    final settings = context.watch<SettingsProvider>();
    final insights = CoachInsights(records);
    final weekStart = _startOfWeek(DateTime.now());
    final days =
        List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final trainedDays = days
        .where((day) => records.any((record) {
              return _dateOnly(record.date) == day;
            }))
        .length;
    final progress =
        (trainedDays / settings.weeklyGoal).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('本周目标'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(18),
            gradient: LinearGradient(
              colors: [
                spec.primary.withValues(alpha: .16),
                spec.secondary.withValues(alpha: .06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GradientIconBadge(
                      icon: Icons.flag_rounded,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$trainedDays / ${settings.weeklyGoal} 次',
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '本周已训练 $trainedDays 天 · 累计 ${insights.thisWeekSessions} 次',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Pill(
                      label:
                          trainedDays >= settings.weeklyGoal ? '目标完成' : '进行中',
                      icon: trainedDays >= settings.weeklyGoal
                          ? Icons.check_circle_rounded
                          : Icons.timelapse_rounded,
                      color: trainedDays >= settings.weeklyGoal
                          ? const Color(0xFF22C55E)
                          : spec.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: spec.textPrimary.withValues(alpha: .07),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  trainedDays >= settings.weeklyGoal
                      ? '本周目标已完成，接下来把重点放在恢复与动作质量。'
                      : '还差 ${settings.weeklyGoal - trainedDays} 天达成目标，优先补齐未训练的部位。',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: '本周训练日',
            subtitle: '周一至周日的训练安排',
          ),
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WeekDayCard(day: day, records: records),
            ),
        ],
      ),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  final DateTime day;
  final List<WorkoutRecord> records;

  const _WeekDayCard({required this.day, required this.records});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final dayRecords = records.where((record) {
      return _dateOnly(record.date) == day;
    }).toList();
    final projects = dayRecords.expand((record) => record.projects).toList();
    final totalWork = dayRecords.fold<double>(
      0,
      (sum, record) => sum + record.totalWork,
    );
    final totalSets =
        projects.fold<int>(0, (sum, project) => sum + project.sets);
    final isToday = _dateOnly(DateTime.now()) == day;
    final trained = dayRecords.isNotEmpty;

    return GlassPanel(
      padding: const EdgeInsets.all(15),
      border: isToday
          ? Border.all(color: spec.primary.withValues(alpha: .42), width: 1.2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: trained
                      ? spec.primary.withValues(alpha: .13)
                      : spec.textPrimary.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: trained ? spec.primary : spec.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weekdayLabel(day),
                      style: TextStyle(
                        color: trained ? spec.primary : spec.textSecondary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
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
                    Row(
                      children: [
                        Text(
                          trained ? '已训练' : '休息日',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Pill(
                            label: '今天',
                            color: spec.primary,
                            filled: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trained
                          ? '${DateFormat('M月d日').format(day)} · ${projects.length} 个动作 · $totalSets 组'
                          : '${DateFormat('M月d日').format(day)} · 恢复与准备',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (trained)
                Text(
                  '${(totalWork / 1000).toStringAsFixed(1)} kJ',
                  style: TextStyle(
                    color: spec.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (trained) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final project in projects)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: spec.textPrimary.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      project.name.trim().isEmpty
                          ? project.part
                          : '${project.name} · ${project.inputSummary}',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 10,
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
}

class PartBalanceDetailPage extends StatelessWidget {
  const PartBalanceDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final records = context.watch<WorkoutProvider>().records;
    final insights = CoachInsights(records);
    final stats = insights.partStats;
    final totalWork = stats.fold<double>(0, (sum, stat) => sum + stat.work);
    final totalSets = stats.fold<int>(0, (sum, stat) => sum + stat.sets);
    final maxWork = stats.isEmpty
        ? 1.0
        : stats
            .map((stat) => stat.work)
            .reduce(math.max)
            .clamp(1.0, double.infinity);
    final trainedParts = stats.map((stat) => stat.part).toSet();
    final missingParts = ExerciseLibrary.trainingParts
        .where((part) => !trainedParts.contains(part))
        .toList();
    final top = stats.isEmpty ? null : stats.first;

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('部位均衡'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(18),
            gradient: LinearGradient(
              colors: [
                spec.secondary.withValues(alpha: .14),
                spec.primary.withValues(alpha: .05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GradientIconBadge(
                      icon: Icons.balance_rounded,
                      colors: [spec.secondary, spec.primary],
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            top == null ? '还没有部位数据' : '你最常训练「${top.part}」',
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            top == null
                                ? '记录训练后，这里会显示每个部位的训练量与占比。'
                                : '${top.sessions} 次 · ${top.sets} 组 · ${(top.work / 1000).toStringAsFixed(1)} kJ',
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SummaryMetric(
                      value: '${insights.totalSessions}',
                      label: '训练天数',
                      spec: spec,
                    ),
                    _SummaryDivider(spec: spec),
                    _SummaryMetric(
                      value: '${stats.length}',
                      label: '覆盖部位',
                      spec: spec,
                    ),
                    _SummaryDivider(spec: spec),
                    _SummaryMetric(
                      value: (totalWork / 1000).toStringAsFixed(1),
                      label: '总容量 kJ',
                      spec: spec,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: '部位训练量',
            subtitle: '按累计训练容量从高到低排列',
          ),
          if (stats.isEmpty)
            GlassPanel(
              child: EmptyState(
                icon: Icons.balance_rounded,
                title: '暂无部位数据',
                message: '完成一次训练后，这里会展示各部位的训练次数、组数与容量占比。',
              ),
            )
          else
            for (final stat in stats)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PartStatCard(
                  stat: stat,
                  maxWork: maxWork,
                  totalWork: totalWork,
                  totalSets: totalSets,
                ),
              ),
          const SectionHeader(
            title: '待补齐部位',
            subtitle: '让全身发展更均衡',
          ),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missingParts.isEmpty
                      ? '八大训练部位已经全部覆盖，继续保持当前分配。'
                      : '还没有训练记录的部位：${missingParts.join('、')}。可以在下一个训练日加入 1-2 个动作。',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 12,
                    height: 1.65,
                  ),
                ),
                if (missingParts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final part in missingParts)
                        Pill(
                          label: part,
                          icon: Icons.add_rounded,
                          color: spec.secondary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartStatCard extends StatelessWidget {
  final PartStat stat;
  final double maxWork;
  final double totalWork;
  final int totalSets;

  const _PartStatCard({
    required this.stat,
    required this.maxWork,
    required this.totalWork,
    required this.totalSets,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final share = totalWork > 0
        ? stat.work / totalWork
        : (totalSets > 0 ? stat.sets / totalSets : 0.0);
    final ratio = (stat.work / maxWork).clamp(0.0, 1.0);

    return GlassPanel(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: spec.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  stat.part,
                  style: TextStyle(
                    color: spec.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${stat.sessions} 次 · ${stat.sets} 组',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(share * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: spec.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: spec.textPrimary.withValues(alpha: .06),
              color: stat.part == '腿' ? const Color(0xFFFF9500) : spec.primary,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '累计容量 ${(stat.work / 1000).toStringAsFixed(1)} kJ'
            '${stat.minutes > 0 ? ' · 时长 ${stat.minutes.toStringAsFixed(0)} 分钟' : ''}',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class VolumeTrendPage extends StatefulWidget {
  const VolumeTrendPage({super.key});

  @override
  State<VolumeTrendPage> createState() => _VolumeTrendPageState();
}

class _VolumeTrendPageState extends State<VolumeTrendPage> {
  InsightRange _range = InsightRange.week;
  DateTimeRange? _customRange;

  Future<void> _selectRange(InsightRange range) async {
    if (range != InsightRange.custom) {
      setState(() => _range = range);
      return;
    }
    final records = context.read<WorkoutProvider>().records;
    final now = _dateOnly(DateTime.now());
    final earliest = records.isEmpty
        ? now.subtract(const Duration(days: 365))
        : records
            .map((record) => _dateOnly(record.date))
            .reduce((a, b) => a.isBefore(b) ? a : b);
    final initial = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: earliest.isBefore(initial.start) ? earliest : initial.start,
      lastDate: now,
      helpText: '选择容量统计范围',
      saveText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = InsightRange.custom;
      _customRange = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final records = context.watch<WorkoutProvider>().records;
    final resolved = _resolveRange(_range, _customRange);
    final filtered = _recordsInRange(records, resolved);
    final buckets = _buildVolumeBuckets(filtered, resolved);
    final totalWork =
        filtered.fold<double>(0, (sum, record) => sum + record.totalWork);
    final totalSets = filtered.fold<int>(
      0,
      (sum, record) =>
          sum +
          record.projects
              .fold<int>(0, (projectSum, item) => projectSum + item.sets),
    );
    final trainingDays = filtered
        .map((record) => DateFormat('yyyy-MM-dd').format(record.date))
        .toSet()
        .length;
    final activeBuckets = buckets.where((bucket) => bucket.work > 0).toList();

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('容量趋势'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
        children: [
          InsightRangeSelector(
            value: _range,
            customRange: _customRange,
            onChanged: _selectRange,
          ),
          const SizedBox(height: 14),
          GlassPanel(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded,
                        size: 18, color: spec.primary),
                    const SizedBox(width: 7),
                    Text(
                      '训练容量直方图',
                      style: TextStyle(
                        color: spec.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Pill(
                      label: '$trainingDays 个训练日',
                      icon: Icons.calendar_today_rounded,
                      color: spec.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        '所选范围内还没有训练记录',
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  )
                else
                  _VolumeBarChart(buckets: buckets, spec: spec),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: spec.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: spec.primary.withValues(alpha: .12),
                    ),
                  ),
                  child: Row(
                    children: [
                      _SummaryMetric(
                        value: (totalWork / 1000).toStringAsFixed(1),
                        label: '总容量 kJ',
                        spec: spec,
                      ),
                      _SummaryDivider(spec: spec),
                      _SummaryMetric(
                        value: '$totalSets',
                        label: '总组数',
                        spec: spec,
                      ),
                      _SummaryDivider(spec: spec),
                      _SummaryMetric(
                        value: totalWork <= 0
                            ? '0'
                            : (totalWork / 1000 / math.max(1, trainingDays))
                                .toStringAsFixed(1),
                        label: '日均 kJ',
                        spec: spec,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: '容量明细',
            subtitle: '有训练记录的日期',
          ),
          if (activeBuckets.isEmpty)
            GlassPanel(
              child: EmptyState(
                icon: Icons.bar_chart_rounded,
                title: '暂无容量数据',
                message: '换一个时间范围，或者先记录一次训练。',
              ),
            )
          else
            for (final bucket in activeBuckets.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: spec.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bucket.fullLabel,
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${bucket.sessions} 次训练',
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 66,
                        child: Text(
                          '${(bucket.work / 1000).toStringAsFixed(1)} kJ',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: spec.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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

class _VolumeBucket {
  final DateTime date;
  final String label;
  final String fullLabel;
  double work = 0;
  int sessions = 0;

  _VolumeBucket({
    required this.date,
    required this.label,
    required this.fullLabel,
  });
}

List<_VolumeBucket> _buildVolumeBuckets(
  List<WorkoutRecord> records,
  DateTimeRange range,
) {
  final spanDays = range.end.difference(range.start).inDays + 1;
  final monthSpan = (range.end.year - range.start.year) * 12 +
      range.end.month -
      range.start.month +
      1;
  final mode = spanDays <= 35
      ? _VolumeMode.day
      : monthSpan <= 36
          ? _VolumeMode.month
          : _VolumeMode.year;

  final buckets = <String, _VolumeBucket>{};
  if (mode == _VolumeMode.day) {
    for (var i = 0; i < spanDays; i++) {
      final date = range.start.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      buckets[key] = _VolumeBucket(
        date: date,
        label:
            spanDays <= 7 ? weekdayLabel(date) : DateFormat('M/d').format(date),
        fullLabel:
            '${DateFormat('yyyy年M月d日').format(date)} · ${weekdayLabel(date)}',
      );
    }
  } else if (mode == _VolumeMode.month) {
    var cursor = DateTime(range.start.year, range.start.month);
    final end = DateTime(range.end.year, range.end.month);
    while (!cursor.isAfter(end)) {
      final key = DateFormat('yyyy-MM').format(cursor);
      buckets[key] = _VolumeBucket(
        date: cursor,
        label: DateFormat('M月').format(cursor),
        fullLabel: DateFormat('yyyy年M月').format(cursor),
      );
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
  } else {
    for (var year = range.start.year; year <= range.end.year; year++) {
      final date = DateTime(year);
      final key = '$year';
      buckets[key] = _VolumeBucket(
        date: date,
        label: '$year',
        fullLabel: '$year 年',
      );
    }
  }

  for (final record in records) {
    final date = _dateOnly(record.date);
    final key = mode == _VolumeMode.day
        ? DateFormat('yyyy-MM-dd').format(date)
        : mode == _VolumeMode.month
            ? DateFormat('yyyy-MM').format(date)
            : '${date.year}';
    final bucket = buckets[key];
    if (bucket == null) continue;
    bucket.work += record.totalWork;
    bucket.sessions += 1;
  }
  return buckets.values.toList();
}

enum _VolumeMode { day, month, year }

class _VolumeBarChart extends StatelessWidget {
  final List<_VolumeBucket> buckets;
  final AppThemeSpec spec;

  const _VolumeBarChart({required this.buckets, required this.spec});

  @override
  Widget build(BuildContext context) {
    final maxWork =
        buckets.map((bucket) => bucket.work).fold<double>(0, math.max);
    final labelEvery = math.max(1, (buckets.length / 7).ceil());
    final compact = buckets.length > 18;

    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < buckets.length; i++)
            Expanded(
              child: Tooltip(
                message: '${buckets[i].fullLabel}\n'
                    '${(buckets[i].work / 1000).toStringAsFixed(1)} kJ · '
                    '${buckets[i].sessions} 次训练',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final ratio = maxWork <= 0
                                ? 0.0
                                : (buckets[i].work / maxWork).clamp(0.0, 1.0);
                            final height = buckets[i].work <= 0
                                ? 2.0
                                : math.max(4.0, constraints.maxHeight * ratio);
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                height: height,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: buckets[i].work <= 0
                                        ? [
                                            spec.textPrimary
                                                .withValues(alpha: .08),
                                            spec.textPrimary
                                                .withValues(alpha: .04),
                                          ]
                                        : [
                                            spec.primary,
                                            spec.primary.withValues(alpha: .26),
                                          ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    compact ? 3 : 4,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 14,
                        child: Text(
                          i % labelEvery == 0 ? buckets[i].label : '',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: compact ? 7.5 : 8.5,
                          ),
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

class PersonalRecordsPage extends StatefulWidget {
  const PersonalRecordsPage({super.key});

  @override
  State<PersonalRecordsPage> createState() => _PersonalRecordsPageState();
}

class _PersonalRecordsPageState extends State<PersonalRecordsPage> {
  InsightRange _range = InsightRange.week;
  DateTimeRange? _customRange;

  Future<void> _selectRange(InsightRange range) async {
    if (range != InsightRange.custom) {
      setState(() => _range = range);
      return;
    }
    final records = context.read<WorkoutProvider>().records;
    final now = _dateOnly(DateTime.now());
    final earliest = records.isEmpty
        ? now.subtract(const Duration(days: 365))
        : records
            .map((record) => _dateOnly(record.date))
            .reduce((a, b) => a.isBefore(b) ? a : b);
    final initial = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: earliest.isBefore(initial.start) ? earliest : initial.start,
      lastDate: now,
      helpText: '选择个人记录范围',
      saveText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = InsightRange.custom;
      _customRange = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final records = context.watch<WorkoutProvider>().records;
    final resolved = _resolveRange(_range, _customRange);
    final filtered = _recordsInRange(records, resolved);
    final insights = CoachInsights(filtered);
    final bests = _exerciseBests(filtered);
    final recent = List<WorkoutRecord>.from(filtered)
      ..sort((a, b) => b.date.compareTo(a.date));
    final maxPartWork = insights.partStats.isEmpty
        ? 1.0
        : insights.partStats
            .map((stat) => stat.work)
            .reduce(math.max)
            .clamp(1.0, double.infinity);

    return Scaffold(
      backgroundColor: spec.background,
      appBar: AppBar(
        backgroundColor: spec.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('个人记录'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
        children: [
          InsightRangeSelector(
            value: _range,
            customRange: _customRange,
            onChanged: _selectRange,
          ),
          const SizedBox(height: 14),
          GlassPanel(
            padding: const EdgeInsets.all(17),
            gradient: LinearGradient(
              colors: [
                spec.primary.withValues(alpha: .14),
                spec.secondary.withValues(alpha: .055),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GradientIconBadge(
                      icon: Icons.emoji_events_rounded,
                      colors: [const Color(0xFFFFD166), spec.primary],
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '训练数据总览',
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${insights.totalSessions} 个训练日 · 累计 ${(insights.totalWork / 1000).toStringAsFixed(1)} kJ',
                            style: TextStyle(
                              color: spec.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _SummaryMetric(
                      value: '${insights.totalSessions}',
                      label: '训练天数',
                      spec: spec,
                    ),
                    _SummaryDivider(spec: spec),
                    _SummaryMetric(
                      value: '${insights.totalSets}',
                      label: '总组数',
                      spec: spec,
                    ),
                    _SummaryDivider(spec: spec),
                    _SummaryMetric(
                      value: '${insights.totalCalories}',
                      label: '消耗 kcal',
                      spec: spec,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '有氧时长',
                  value: insights.totalDurationMinutes.toStringAsFixed(0),
                  unit: '分钟',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: '有氧距离',
                  value: insights.totalDistanceKm.toStringAsFixed(1),
                  unit: 'km',
                  icon: Icons.route_rounded,
                  accent: const Color(0xFF4FD1C5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '平均容量',
                  value: (insights.averageWork / 1000).toStringAsFixed(1),
                  unit: 'kJ',
                  icon: Icons.insights_rounded,
                  accent: const Color(0xFFFFA24C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: '单次最高',
                  value: insights.bestRecord == null
                      ? '0'
                      : (insights.bestRecord!.totalWork / 1000)
                          .toStringAsFixed(1),
                  unit: 'kJ',
                  icon: Icons.local_fire_department_rounded,
                  accent: const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SectionHeader(
            title: '个人最佳',
            subtitle: '所选范围内的最强单次与动作重量',
          ),
          if (insights.bestRecord != null) ...[
            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GradientIconBadge(
                    icon: Icons.military_tech_rounded,
                    colors: [const Color(0xFFFFD166), spec.primary],
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '单次最高容量',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(insights.bestRecord!.totalWork / 1000).toStringAsFixed(1)} kJ',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('yyyy年M月d日').format(insights.bestRecord!.date)} · 第 ${insights.bestRecord!.sessionNumber ?? '—'} 次训练',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (bests.isEmpty)
            GlassPanel(
              child: EmptyState(
                icon: Icons.emoji_events_rounded,
                title: '暂无动作重量记录',
                message: '记录带重量的力量训练后，这里会生成个人最佳榜单。',
              ),
            )
          else
            GlassPanel(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < bests.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: spec.textPrimary.withValues(alpha: .055),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color:
                                    i < 3 ? spec.primary : spec.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bests[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: spec.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${bests[i].part} · ${DateFormat('M月d日').format(bests[i].date)} · ${bests[i].sets} 组 × ${bests[i].reps} 次',
                                  style: TextStyle(
                                    color: spec.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${bests[i].weight.toStringAsFixed(bests[i].weight % 1 == 0 ? 0 : 1)} kg',
                            style: TextStyle(
                              color: spec.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SectionHeader(
            title: '部位分布',
            subtitle: '所选范围内的训练量占比',
          ),
          if (insights.partStats.isEmpty)
            GlassPanel(
              child: EmptyState(
                icon: Icons.balance_rounded,
                title: '暂无部位数据',
                message: '当前范围内还没有训练记录。',
              ),
            )
          else
            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final stat in insights.partStats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(
                              stat.part,
                              style: TextStyle(
                                color: spec.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    (stat.work / maxPartWork).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor:
                                    spec.textPrimary.withValues(alpha: .06),
                                color: stat.part == '腿'
                                    ? const Color(0xFFFF9500)
                                    : spec.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '${(stat.work / 1000).toStringAsFixed(1)} kJ',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          SectionHeader(
            title: '训练记录',
            subtitle: '共 ${recent.length} 次 · 按时间倒序',
          ),
          if (recent.isEmpty)
            GlassPanel(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: '当前范围没有训练',
                message: '换一个时间范围，或者先记录一次训练。',
              ),
            )
          else
            for (final record in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _RecordSummaryCard(record: record),
              ),
        ],
      ),
    );
  }
}

class _ExerciseBest {
  final String name;
  final String part;
  final double weight;
  final DateTime date;
  final int sets;
  final int reps;

  const _ExerciseBest({
    required this.name,
    required this.part,
    required this.weight,
    required this.date,
    required this.sets,
    required this.reps,
  });
}

List<_ExerciseBest> _exerciseBests(List<WorkoutRecord> records) {
  final bests = <String, _ExerciseBest>{};
  for (final record in records) {
    for (final project in record.projects) {
      if (project.name.trim().isEmpty ||
          project.weight <= 0 ||
          project.isTimeBased) {
        continue;
      }
      final key = '${project.name.trim()}·${project.part}';
      final current = bests[key];
      if (current == null || project.weight > current.weight) {
        bests[key] = _ExerciseBest(
          name: project.name.trim(),
          part: project.part,
          weight: project.weight,
          date: record.date,
          sets: project.sets,
          reps: project.repsPerSet,
        );
      }
    }
  }
  final result = bests.values.toList()
    ..sort((a, b) => b.weight.compareTo(a.weight));
  return result;
}

class _RecordSummaryCard extends StatelessWidget {
  final WorkoutRecord record;

  const _RecordSummaryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final projects = record.projects
        .where((project) => project.name.trim().isNotEmpty)
        .toList();
    final sets = projects.fold<int>(0, (sum, project) => sum + project.sets);

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${DateFormat('M月d日').format(record.date)} · ${weekdayLabel(record.date)}',
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Pill(
                label: '第 ${record.sessionNumber ?? '—'} 次',
                color: spec.secondary,
              ),
              const Spacer(),
              Text(
                '${(record.totalWork / 1000).toStringAsFixed(1)} kJ',
                style: TextStyle(
                  color: spec.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${projects.length} 个动作 · $sets 组'
            '${record.totalDurationMinutes > 0 ? ' · 有氧 ${record.totalDurationMinutes.toStringAsFixed(0)} 分钟' : ''}',
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 10.5,
            ),
          ),
          if (projects.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              projects.map((project) => project.name).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String value;
  final String label;
  final AppThemeSpec spec;

  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: spec.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  final AppThemeSpec spec;

  const _SummaryDivider({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: spec.textPrimary.withValues(alpha: .08),
    );
  }
}
