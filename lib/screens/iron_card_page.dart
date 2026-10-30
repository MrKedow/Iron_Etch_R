import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../services/work_energy.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class IronCardPage extends StatelessWidget {
  const IronCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final spec = context.watch<ThemeProvider>().currentSpec;
    final profile = settings.ironProfile;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: spec.background.withValues(alpha: .84),
            title: const Text('铁卡'),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              34 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _IronHero(settings: settings, profile: profile, spec: spec),
                const SizedBox(height: 8),
                const SectionHeader(
                  title: '身体数据',
                  subtitle: '全部可选填，填得越多，做工与热量估算越准',
                ),
                _IronGroup(
                  children: [
                    _IronTile(
                      icon: Icons.straighten_rounded,
                      title: '身高',
                      value: settings.heightCm == null
                          ? '未填写'
                          : '${settings.heightCm!.toStringAsFixed(1)} cm',
                      filled: settings.heightCm != null,
                      onTap: () => _editNumber(
                        context,
                        title: '身高',
                        unit: 'cm',
                        current: settings.heightCm,
                        min: 100,
                        max: 250,
                        decimals: 1,
                        onSave: settings.setHeightCm,
                        onClear: () => settings.setHeightCm(null),
                      ),
                    ),
                    _IronTile(
                      icon: Icons.monitor_weight_outlined,
                      title: '体重',
                      value: '${settings.bodyWeight.toStringAsFixed(1)} kg',
                      filled: true,
                      onTap: () => _editNumber(
                        context,
                        title: '体重',
                        unit: 'kg',
                        current: settings.bodyWeight,
                        min: 30,
                        max: 250,
                        decimals: 1,
                        onSave: settings.setBodyWeight,
                      ),
                    ),
                    _IronTile(
                      icon: Icons.cake_outlined,
                      title: '年龄',
                      value: settings.age == null ? '未填写' : '${settings.age} 岁',
                      filled: settings.age != null,
                      onTap: () => _editNumber(
                        context,
                        title: '年龄',
                        unit: '岁',
                        current: settings.age?.toDouble(),
                        min: 10,
                        max: 100,
                        decimals: 0,
                        onSave: (value) => settings.setAge(value.round()),
                        onClear: () => settings.setAge(null),
                      ),
                    ),
                    _IronTile(
                      icon: Icons.wc_rounded,
                      title: '性别',
                      value: settings.sex,
                      filled: settings.sex != '未填写',
                      onTap: () => _chooseOption(
                        context,
                        title: '性别',
                        current: settings.sex,
                        options: const ['男', '女', '未填写'],
                        onSelected: settings.setSex,
                      ),
                    ),
                    _IronTile(
                      icon: Icons.percent_rounded,
                      title: '体脂率',
                      value: settings.bodyFatPercent == null
                          ? '未填写'
                          : '${settings.bodyFatPercent!.toStringAsFixed(1)}%',
                      filled: settings.bodyFatPercent != null,
                      onTap: () => _editNumber(
                        context,
                        title: '体脂率',
                        unit: '%',
                        current: settings.bodyFatPercent,
                        min: 3,
                        max: 60,
                        decimals: 1,
                        onSave: settings.setBodyFatPercent,
                        onClear: () => settings.setBodyFatPercent(null),
                      ),
                    ),
                    _IronTile(
                      icon: Icons.favorite_border_rounded,
                      title: '静息心率',
                      value: settings.restingHeartRate == null
                          ? '未填写'
                          : '${settings.restingHeartRate} bpm',
                      filled: settings.restingHeartRate != null,
                      onTap: () => _editNumber(
                        context,
                        title: '静息心率',
                        unit: 'bpm',
                        current: settings.restingHeartRate?.toDouble(),
                        min: 30,
                        max: 120,
                        decimals: 0,
                        onSave: (value) =>
                            settings.setRestingHeartRate(value.round()),
                        onClear: () => settings.setRestingHeartRate(null),
                      ),
                    ),
                    _IronTile(
                      icon: Icons.timeline_rounded,
                      title: '训练年限',
                      value: settings.trainingYears == null
                          ? '未填写'
                          : '${settings.trainingYears!.toStringAsFixed(1)} 年',
                      filled: settings.trainingYears != null,
                      onTap: () => _editNumber(
                        context,
                        title: '训练年限',
                        unit: '年',
                        current: settings.trainingYears,
                        min: 0,
                        max: 60,
                        decimals: 1,
                        onSave: settings.setTrainingYears,
                        onClear: () => settings.setTrainingYears(null),
                      ),
                    ),
                  ],
                ),
                const SectionHeader(
                  title: '训练背景',
                  subtitle: '用于调整强度与代谢估算',
                ),
                _IronGroup(
                  children: [
                    _IronTile(
                      icon: Icons.flag_rounded,
                      title: '训练目标',
                      value: settings.trainingGoal,
                      filled: true,
                      onTap: () => _chooseOption(
                        context,
                        title: '训练目标',
                        current: settings.trainingGoal,
                        options: const ['增肌', '减脂', '力量', '塑形', '健康'],
                        onSelected: settings.setTrainingGoal,
                      ),
                    ),
                    _IronTile(
                      icon: Icons.trending_up_rounded,
                      title: '训练经验',
                      value: settings.experience,
                      filled: true,
                      onTap: () => _chooseOption(
                        context,
                        title: '训练经验',
                        current: settings.experience,
                        options: const ['新手', '进阶', '高阶'],
                        onSelected: settings.setExperience,
                      ),
                    ),
                  ],
                ),
                const SectionHeader(
                  title: '科学估算',
                  subtitle: '力学功与代谢消耗',
                ),
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: '基础代谢',
                              value:
                                  '${profile.basalMetabolicKcal.round()} kcal',
                              hint: settings.bodyFatPercent != null
                                  ? 'Katch-McArdle'
                                  : 'Mifflin-St Jeor',
                              color: spec.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Metric(
                              label: '最大心率',
                              value: '${profile.maximumHeartRate.round()} bpm',
                              hint: 'Tanaka 公式',
                              color: spec.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FormulaNote(
                        icon: Icons.bolt_rounded,
                        title: '机械功',
                        body: '有效负荷 × 9.80665 × 动作行程 × 组数 × 次数。动作行程按身高比例计算，'
                            '负荷会自动计入该部位承担的体重比例。',
                        color: spec.primary,
                      ),
                      const SizedBox(height: 10),
                      _FormulaNote(
                        icon: Icons.local_fire_department_rounded,
                        title: '热量',
                        body: '力量训练按 Keytel 心率方程估算，心率由年龄、性别、静息心率、'
                            '相对负荷与训练年限推导；有氧仍按 MET 与体重计算。',
                        color: spec.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '以上均为训练科学估算，用于观察趋势，不替代医学或实验室测试。',
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 10.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _IronHero extends StatelessWidget {
  final SettingsProvider settings;
  final IronProfile profile;
  final AppThemeSpec spec;

  const _IronHero({
    required this.settings,
    required this.profile,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (profile.completeness * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: spec.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: spec.primary.withValues(alpha: .22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .22),
                  ),
                ),
                child: Icon(Icons.badge_outlined, color: spec.onHero, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IRON CARD',
                      style: TextStyle(
                        color: spec.onHero.withValues(alpha: .72),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    Text(
                      settings.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: spec.onHero,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '完整度 $percent%',
                  style: TextStyle(
                    color: spec.onHero,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: profile.completeness,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: .14),
              valueColor: AlwaysStoppedAnimation<Color>(
                spec.onHero.withValues(alpha: .85),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _HeroChip(
                label: '${profile.effectiveHeightCm.toStringAsFixed(0)} cm',
                filled: settings.heightCm != null,
                color: spec.onHero,
              ),
              _HeroChip(
                label: '${profile.bodyWeightKg.toStringAsFixed(1)} kg',
                filled: true,
                color: spec.onHero,
              ),
              _HeroChip(
                label: '${profile.effectiveAge} 岁',
                filled: settings.age != null,
                color: spec.onHero,
              ),
              _HeroChip(
                label: profile.sexLabel,
                filled: settings.sex != '未填写',
                color: spec.onHero,
              ),
              _HeroChip(
                label: settings.bodyFatPercent == null
                    ? '体脂未填'
                    : '体脂 ${settings.bodyFatPercent!.toStringAsFixed(1)}%',
                filled: settings.bodyFatPercent != null,
                color: spec.onHero,
              ),
              _HeroChip(
                label: settings.restingHeartRate == null
                    ? '静息心率未填'
                    : '静息 ${settings.restingHeartRate} bpm',
                filled: settings.restingHeartRate != null,
                color: spec.onHero,
              ),
              _HeroChip(
                label: settings.trainingYears == null
                    ? '训练年限未填'
                    : '训练 ${settings.trainingYears!.toStringAsFixed(1)} 年',
                filled: settings.trainingYears != null,
                color: spec.onHero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final bool filled;
  final Color color;

  const _HeroChip({
    required this.label,
    required this.filled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? .18 : .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: filled ? .22 : .1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: filled ? .95 : .52),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: spec.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: TextStyle(color: spec.textSecondary, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _FormulaNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _FormulaNote({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: spec.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  color: spec.textSecondary,
                  fontSize: 10.8,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IronGroup extends StatelessWidget {
  final List<Widget> children;

  const _IronGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 58,
                endIndent: 14,
                color: spec.textPrimary.withValues(alpha: .055),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _IronTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool filled;
  final VoidCallback onTap;

  const _IronTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: spec.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: spec.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: filled ? spec.textPrimary : spec.textSecondary,
                  fontSize: 12.5,
                  fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: spec.textSecondary,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _editNumber(
  BuildContext context, {
  required String title,
  required String unit,
  required double? current,
  required double min,
  required double max,
  required int decimals,
  required Future<void> Function(double) onSave,
  Future<void> Function()? onClear,
}) async {
  final controller = TextEditingController(
    text: current == null
        ? ''
        : current.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.0$'), ''),
  );
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final spec = dialogContext.watch<ThemeProvider>().currentSpec;
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '可选填',
                suffixText: unit,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '范围 $min - $max $unit，留空或点“清除”表示暂不填写。',
              style: TextStyle(color: spec.textSecondary, fontSize: 10.5),
            ),
          ],
        ),
        actions: [
          if (current != null && onClear != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('清除'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (result == null || !context.mounted) return;
  if (result.isEmpty) {
    if (onClear != null) await onClear();
    return;
  }
  final value = double.tryParse(result);
  if (value == null || value < min || value > max) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('请输入 $min - $max 之间的数值'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  await onSave(value);
}

Future<void> _chooseOption(
  BuildContext context, {
  required String title,
  required String current,
  required List<String> options,
  required Future<void> Function(String) onSelected,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final spec = dialogContext.watch<ThemeProvider>().currentSpec;
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(dialogContext, option),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: option == current
                          ? spec.primary.withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              color: spec.textPrimary,
                              fontWeight: option == current
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (option == current)
                          Icon(Icons.check_circle_rounded,
                              color: spec.primary, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
  if (result == null) return;
  await onSelected(result);
}
