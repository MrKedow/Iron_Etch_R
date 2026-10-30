import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../providers/app_providers.dart';
import '../services/ai_coach_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/status_banner.dart';
import 'iron_card_page.dart';
import 'theme_gallery_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _testingAi = false;

  Future<void> _editNickname(SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(
            hintText: '铁友',
            counterText: '',
          ),
        ),
        actions: [
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
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setNickname(result);
  }

  Future<void> _chooseAvatar(SettingsProvider settings) async {
    if (!settings.hasAvatar) {
      await _pickAvatar(settings);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: spec.textSecondary.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading:
                      Icon(Icons.photo_library_outlined, color: spec.primary),
                  title: const Text('更换头像'),
                  onTap: () => Navigator.pop(sheetContext, 'pick'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444)),
                  title: const Text(
                    '移除头像',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'pick') {
      await _pickAvatar(settings);
    } else if (action == 'remove') {
      final previousPath = settings.avatarPath;
      await settings.clearAvatar();
      if (previousPath != null && previousPath.isNotEmpty) {
        try {
          final previousFile = File(previousPath);
          if (await previousFile.exists()) await previousFile.delete();
        } catch (_) {}
      }
      if (mounted) _showSnack('头像已移除');
    }
  }

  Future<void> _pickAvatar(SettingsProvider settings) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      final dot = picked.name.lastIndexOf('.');
      final extension =
          dot >= 0 ? picked.name.substring(dot).toLowerCase() : '.jpg';
      final target = File(
        '${directory.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await File(picked.path).copy(target.path);
      final previousPath = settings.avatarPath;
      await settings.setAvatarPath(target.path);
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != target.path) {
        try {
          final previousFile = File(previousPath);
          if (await previousFile.exists()) await previousFile.delete();
        } catch (_) {}
      }
      if (mounted) _showSnack('头像已更新');
    } catch (error) {
      if (mounted) _showSnack('头像设置失败：$error');
    }
  }

  Future<String?> _showChoiceDialog({
    required String title,
    required List<String> options,
    required String current,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final spec = dialogContext.watch<ThemeProvider>().currentSpec;
        return AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(dialogContext, option),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
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
  }

  Future<double?> _showSliderDialog({
    required String title,
    required String description,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String Function(double) labelBuilder,
  }) {
    var current = value;
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final spec = context.watch<ThemeProvider>().currentSpec;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    labelBuilder(current),
                    style: TextStyle(
                      color: spec.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Slider(
                  value: current,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: labelBuilder(current),
                  onChanged: (newValue) =>
                      setDialogState(() => current = newValue),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, current),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editGoal(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: '训练目标',
      current: settings.trainingGoal,
      options: const ['增肌', '减脂', '力量', '塑形', '健康'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setTrainingGoal(result);
  }

  Future<void> _editExperience(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: '训练经验',
      current: settings.experience,
      options: const ['新手', '进阶', '高阶'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setExperience(result);
  }

  Future<void> _editWeeklyGoal(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: '每周训练目标',
      description: 'AI 教练与首页会按这个目标评估你的训练频率。',
      value: settings.weeklyGoal.toDouble(),
      min: 1,
      max: 7,
      divisions: 6,
      labelBuilder: (v) => '${v.round()} 天 / 周',
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setWeeklyGoal(value.round());
  }

  Future<void> _editBodyWeight(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: '体重',
      description: '用于估算训练做功与热量消耗。',
      value: settings.bodyWeight,
      min: 30,
      max: 200,
      divisions: 340,
      labelBuilder: (v) => '${v.toStringAsFixed(1)} kg',
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setBodyWeight(value);
  }

  Future<void> _editRestSeconds(SettingsProvider settings) async {
    final value = await _showSliderDialog(
      title: '默认组间休息',
      description: '记录训练时参考用的默认休息时间。',
      value: settings.restSeconds.toDouble(),
      min: 15,
      max: 300,
      divisions: 19,
      labelBuilder: (v) => '${v.round()} 秒',
    );
    if (value == null || !mounted) return;
    await context.read<SettingsProvider>().setRestSeconds(value.round());
  }

  Future<void> _editWeightUnit(SettingsProvider settings) async {
    final result = await _showChoiceDialog(
      title: '重量单位',
      current: settings.weightUnit,
      options: const ['kg', 'lb'],
    );
    if (result == null || !mounted) return;
    await context.read<SettingsProvider>().setWeightUnit(result);
  }

  Future<void> _pickReminderTime(SettingsProvider settings) async {
    final parts = settings.reminderTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: '选择提醒时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await context.read<SettingsProvider>().setReminderTime(text);
  }

  Future<void> _editAiConfig(SettingsProvider settings) async {
    final endpointController = TextEditingController(text: settings.aiEndpoint);
    final modelController = TextEditingController(text: settings.aiModel);
    final keyController = TextEditingController(text: settings.aiApiKey);
    var obscureKey = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final spec = context.watch<ThemeProvider>().currentSpec;
          return AlertDialog(
            title: const Text('AI 配置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: spec.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '默认使用 BlockRun 的免费 GPT-OSS 通道；失败时自动回退到 '
                      'Pollinations 与 OpenCode Zen。'
                      '也可以填写任意 OpenAI 兼容服务的 API Key。',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 11.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('BlockRun 免费'),
                        onPressed: () {
                          endpointController.text =
                              SettingsProvider.defaultAiEndpoint;
                          modelController.text =
                              SettingsProvider.defaultAiModel;
                          setDialogState(() {});
                        },
                      ),
                      ActionChip(
                        label: const Text('Pollinations 免费'),
                        onPressed: () {
                          endpointController.text =
                              SettingsProvider.legacyPollinationsEndpoint;
                          modelController.text = 'gpt-oss-20b';
                          setDialogState(() {});
                        },
                      ),
                      ActionChip(
                        label: const Text('OpenCode Zen'),
                        onPressed: () {
                          endpointController.text =
                              SettingsProvider.legacyAiEndpoint;
                          modelController.text = 'big-pickle';
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: endpointController,
                    decoration: const InputDecoration(
                      labelText: '接口地址',
                      hintText: SettingsProvider.defaultAiEndpoint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      hintText: SettingsProvider.defaultAiModel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyController,
                    obscureText: obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key（可选）',
                      hintText: 'sk-...',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialogState(() => obscureKey = !obscureKey),
                        icon: Icon(
                          obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      await context.read<SettingsProvider>().setAiConfig(
            endpoint: endpointController.text,
            model: modelController.text,
            apiKey: keyController.text,
          );
    }
    endpointController.dispose();
    modelController.dispose();
    keyController.dispose();
  }

  Future<void> _editAiPrompt(SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.aiPrompt);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final spec = dialogContext.watch<ThemeProvider>().currentSpec;
        return AlertDialog(
          title: const Text('AI 提示词'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置后会作为系统提示词应用到「让 AI 教练分析我的训练」。留空则使用内置默认提示词。',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: '例如：你是一位严谨的力量举教练，只输出中文结论，不要输出思考过程…',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = '';
              },
              child: const Text('清空'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (saved == true && mounted) {
      await context.read<SettingsProvider>().setAiPrompt(controller.text);
    }
    controller.dispose();
  }

  Future<void> _testAi(SettingsProvider settings) async {
    if (!settings.aiEnabled) {
      _showSnack('AI 建议当前已关闭，请先开启。');
      return;
    }
    setState(() => _testingAi = true);
    final reply = await AiCoachService.testConnection(
      endpoint: settings.aiEndpoint,
      model: settings.aiModel,
      apiKey: settings.aiApiKey,
    );
    if (!mounted) return;
    setState(() => _testingAi = false);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              reply.success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: reply.success ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(reply.success ? '连接成功' : '连接未成功'),
          ],
        ),
        content: Text(
          reply.success
              ? '${reply.content}\n\n模型：${settings.aiModel}'
              : '${reply.error ?? '未知错误'}\n\n提示：免费通道可能限流，可在配置中填写 API Key 或稍后重试。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final provider = context.read<WorkoutProvider>();
    if (provider.records.isEmpty) {
      _showSnack('还没有可导出的训练记录');
      return;
    }
    try {
      final path = await ExcelExportService().exportToExcel(provider.records);
      if (path == null) {
        _showSnack('导出失败，请稍后重试');
        return;
      }
      await Share.shareXFiles([XFile(path)], text: '铁镌训练数据');
    } catch (e) {
      if (mounted) _showSnack('导出失败：$e');
    }
  }

  Future<void> _mergeData() async {
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
    _showSnack('已整合同一天的记录');
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空全部训练记录？'),
        content: const Text('所有训练历史都会被删除，且无法恢复。建议先导出备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<WorkoutProvider>().clearRecords();
    _showSnack('训练记录已清空');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showAbout() {
    final spec = context.watch<ThemeProvider>().currentSpec;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: spec.heroGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.fitness_center_rounded,
                  size: 18, color: spec.onHero),
            ),
            const SizedBox(width: 10),
            const Text('关于铁镌'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '铁镌 · 镌刻每一次撸铁',
              style: TextStyle(
                color: spec.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '版本 3.2.2（Android）',
              style: TextStyle(color: spec.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Text(
              '一个专注训练记录、数据洞察与 AI 教练的健身工具。',
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('mailto:Ethocas@outlook.com'),
              ),
              child: const Text(
                '邮箱 · Ethocas@outlook.com',
                style: TextStyle(color: Colors.blue, fontSize: 12.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAcknowledgments() {
    final spec = context.watch<ThemeProvider>().currentSpec;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('鸣谢'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ackItem(
              spec,
              'free-exercise-db',
              '动作教学示意图（约 876 个动作的开源动作库）',
              'https://github.com/yuhonas/free-exercise-db',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'ExRx.net',
              '动作分类与肌群命名参考',
              'https://exrx.net',
            ),
            const SizedBox(height: 12),
            _ackItem(
              spec,
              'ACE / NASM / ACSM',
              '动作库、矫正训练体系与运动测试处方参考',
              'https://www.acefitness.org',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _ackItem(
    AppThemeSpec spec,
    String name,
    String description,
    String url,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => launchUrl(Uri.parse(url)),
          child: Text(
            name,
            style: TextStyle(
              color: spec.primary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: TextStyle(
            color: spec.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _profileAvatar(SettingsProvider settings, AppThemeSpec spec) {
    final path = settings.avatarPath;
    final avatarFile =
        path != null && path.trim().isNotEmpty && File(path).existsSync()
            ? File(path)
            : null;
    final nickname = settings.nickname.trim();
    final initial = nickname.isEmpty ? '铁' : nickname.characters.first;
    return GestureDetector(
      onTap: () => _chooseAvatar(settings),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: spec.heroGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: avatarFile != null
                ? Image.file(
                    avatarFile,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: spec.onHero,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: spec.onHero,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: spec.primary,
                shape: BoxShape.circle,
                border: Border.all(color: spec.background, width: 2),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 12,
                color: spec.isDark ? spec.background : spec.onHero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCloudSync(NutstoreService nutstore) async {
    if (!nutstore.isConnected) {
      await _showCloudLogin(nutstore);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
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
                  '坚果云同步',
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '已连接：${nutstore.username}',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Icon(Icons.upload_rounded, color: spec.primary),
                  title: const Text('同步配置到云端'),
                  onTap: () => Navigator.pop(sheetContext, 'upload'),
                ),
                ListTile(
                  leading: Icon(Icons.download_rounded, color: spec.secondary),
                  title: const Text('从云端恢复配置'),
                  onTap: () => Navigator.pop(sheetContext, 'download'),
                ),
                ListTile(
                  leading: Icon(Icons.link_off_rounded,
                      color: const Color(0xFFF97316)),
                  title: const Text('断开连接'),
                  onTap: () => Navigator.pop(sheetContext, 'disconnect'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'upload') {
      await _uploadConfig(nutstore);
    } else if (action == 'download') {
      await _downloadConfig(nutstore);
    } else if (action == 'disconnect') {
      await nutstore.clearCredentials();
      _snack('已断开坚果云连接');
    }
  }

  Future<void> _showCloudLogin(NutstoreService nutstore) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('连接坚果云'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '在坚果云网页端「安全选项」生成应用密码后填写。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: '坚果云账号',
                  hintText: '邮箱地址',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '应用密码',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await nutstore.connect(
                username: usernameController.text.trim(),
                password: passwordController.text.trim(),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
    usernameController.dispose();
    passwordController.dispose();
    if (!mounted) return;
    _snack(result == true ? '坚果云连接成功' : '坚果云连接失败');
  }

  Future<Map<String, dynamic>> _dumpPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value == null) continue;
      if (value is List<String>) {
        map[key] = {'t': 'list', 'v': value};
      } else if (value is bool) {
        map[key] = {'t': 'bool', 'v': value};
      } else if (value is int) {
        map[key] = {'t': 'int', 'v': value};
      } else if (value is double) {
        map[key] = {'t': 'double', 'v': value};
      } else {
        map[key] = {'t': 'string', 'v': value.toString()};
      }
    }
    return map;
  }

  Future<void> _applyPrefs(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final type = value['t']?.toString();
      final v = value['v'];
      switch (type) {
        case 'list':
          if (v is List) {
            await prefs.setStringList(
                entry.key, v.map((e) => e.toString()).toList());
          }
        case 'bool':
          if (v is bool) await prefs.setBool(entry.key, v);
        case 'int':
          if (v is int) await prefs.setInt(entry.key, v);
        case 'double':
          if (v is num) await prefs.setDouble(entry.key, v.toDouble());
        case 'string':
          await prefs.setString(entry.key, v?.toString() ?? '');
      }
    }
  }

  Future<void> _uploadConfig(NutstoreService nutstore) async {
    final map = await _dumpPrefs();
    final ok = await nutstore.uploadConfig(jsonEncode(map));
    _snack(ok ? '配置已同步到云端' : '上传失败，请检查网络');
  }

  Future<void> _downloadConfig(NutstoreService nutstore) async {
    final raw = await nutstore.downloadConfig();
    if (raw == null) {
      _snack('云端暂无配置或下载失败');
      return;
    }
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        await _applyPrefs(data);
        _snack('配置已恢复，重启应用后生效');
      } else {
        _snack('配置格式错误');
      }
    } catch (_) {
      _snack('配置解析失败');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final spec = context.watch<ThemeProvider>().currentSpec;
    final themeProvider = context.watch<ThemeProvider>();
    final nutstore = context.watch<NutstoreService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: spec.background.withValues(alpha: .82),
            title: const Text('设置'),
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
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _profileAvatar(settings, spec),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    settings.nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: spec.textPrimary,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => _editNickname(settings),
                                  tooltip: '修改昵称',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.edit_rounded,
                                      size: 17, color: spec.textSecondary),
                                ),
                              ],
                            ),
                            Text(
                              '${settings.trainingGoal} · ${settings.experience} · ${settings.bodyWeight.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Pill(
                                  label: '每周 ${settings.weeklyGoal} 练',
                                  icon: Icons.flag_rounded,
                                ),
                                Pill(
                                  label: settings.hasAiKey
                                      ? 'AI 已配置 Key'
                                      : 'AI 免费通道',
                                  icon: Icons.auto_awesome_rounded,
                                  color: settings.hasAiKey
                                      ? const Color(0xFF22C55E)
                                      : spec.secondary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader(
                  title: '个人档案',
                  subtitle: '让 AI 更懂你的训练背景',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.account_circle_outlined,
                      title: '头像',
                      subtitle: settings.hasAvatar
                          ? '已设置 · 点击更换或移除'
                          : '未设置 · 点击从相册选择',
                      onTap: () => _chooseAvatar(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.flag_rounded,
                      title: '训练目标',
                      subtitle: settings.trainingGoal,
                      onTap: () => _editGoal(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.trending_up_rounded,
                      title: '训练经验',
                      subtitle: settings.experience,
                      onTap: () => _editExperience(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.monitor_weight_outlined,
                      title: '体重',
                      subtitle: '${settings.bodyWeight.toStringAsFixed(1)} kg',
                      onTap: () => _editBodyWeight(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.badge_outlined,
                      title: '铁卡',
                      subtitle: settings.heightCm == null
                          ? '可选填写身高、年龄、体脂与静息心率'
                          : '完整度 ${(settings.ironProfile.completeness * 100).round()}% · 点击完善',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IronCardPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SectionHeader(
                  title: '训练偏好',
                  subtitle: '这些设置会影响记录与 AI 分析',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.calendar_view_week_rounded,
                      title: '每周训练目标',
                      subtitle: '${settings.weeklyGoal} 天 / 周',
                      onTap: () => _editWeeklyGoal(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.straighten_rounded,
                      title: '重量单位',
                      subtitle: settings.weightUnit,
                      onTap: () => _editWeightUnit(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.timer_outlined,
                      title: '默认组间休息',
                      subtitle: '${settings.restSeconds} 秒',
                      onTap: () => _editRestSeconds(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.vibration_rounded,
                      title: '触感反馈',
                      subtitle: '保存与切换时提供轻触反馈',
                      trailing: Switch.adaptive(
                        value: settings.haptics,
                        onChanged: (value) =>
                            context.read<SettingsProvider>().setHaptics(value),
                      ),
                      onTap: () => context
                          .read<SettingsProvider>()
                          .setHaptics(!settings.haptics),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      title: '训练提醒',
                      subtitle: settings.remindersEnabled
                          ? '每天 ${settings.reminderTime} 提醒'
                          : '关闭',
                      trailing: Switch.adaptive(
                        value: settings.remindersEnabled,
                        onChanged: (value) => context
                            .read<SettingsProvider>()
                            .setRemindersEnabled(value),
                      ),
                      onTap: () => context
                          .read<SettingsProvider>()
                          .setRemindersEnabled(!settings.remindersEnabled),
                    ),
                    if (settings.remindersEnabled)
                      _SettingsTile(
                        icon: Icons.schedule_rounded,
                        title: '提醒时间',
                        subtitle: settings.reminderTime,
                        onTap: () => _pickReminderTime(settings),
                      ),
                  ],
                ),
                const SectionHeader(
                  title: 'AI 教练',
                  subtitle: '免费多通道 · 自动回退 · 真实大模型驱动',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      title: '启用 AI 建议',
                      subtitle: settings.aiEnabled ? '已开启' : '已关闭',
                      trailing: Switch.adaptive(
                        value: settings.aiEnabled,
                        onChanged: (value) => context
                            .read<SettingsProvider>()
                            .setAiEnabled(value),
                      ),
                      onTap: () => context
                          .read<SettingsProvider>()
                          .setAiEnabled(!settings.aiEnabled),
                    ),
                    _SettingsTile(
                      icon: Icons.link_rounded,
                      title: '接口地址',
                      subtitle: settings.aiEndpoint,
                      onTap: () => _editAiConfig(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.memory_rounded,
                      title: '模型',
                      subtitle: settings.aiModel,
                      onTap: () => _editAiConfig(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.key_rounded,
                      title: 'API Key',
                      subtitle:
                          settings.hasAiKey ? '已保存 · 点击修改' : '未填写 · 使用免费通道',
                      onTap: () => _editAiConfig(settings),
                    ),
                    _SettingsTile(
                      icon: _testingAi
                          ? Icons.hourglass_top_rounded
                          : Icons.network_check_rounded,
                      title: '测试连接',
                      subtitle: _testingAi ? '正在测试 AI 通道…' : '检查免费通道或 Key 是否可用',
                      trailing: _testingAi
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.chevron_right_rounded,
                              color: spec.textSecondary),
                      onTap: _testingAi ? null : () => _testAi(settings),
                    ),
                    _SettingsTile(
                      icon: Icons.edit_note_rounded,
                      title: 'AI 提示词',
                      subtitle: settings.aiPrompt.trim().isEmpty
                          ? '使用内置默认提示词 · 点击自定义'
                          : settings.aiPrompt,
                      onTap: () => _editAiPrompt(settings),
                    ),
                  ],
                ),
                const SectionHeader(
                  title: '外观与个性',
                  subtitle: '主题会改变整页配色、卡片与背景',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: '主题工坊',
                      subtitle: '${spec.emoji} ${spec.name} · ${spec.subtitle}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ThemeGalleryPage(),
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.bolt_rounded,
                      title: '我的状态',
                      subtitle:
                          '${settings.statusEmoji} ${settings.statusText}',
                      onTap: () => showStatusEditor(context),
                    ),
                    _SettingsTile(
                      icon: Icons.wb_sunny_outlined,
                      title: '今日格言',
                      subtitle: settings.todayQuote,
                    ),
                    if (themeProvider.hasCustomBackground)
                      _SettingsTile(
                        icon: Icons.image_outlined,
                        title: '自定义背景',
                        subtitle: '已应用 · 可在主题工坊中移除',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ThemeGalleryPage(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SectionHeader(
                  title: '数据管理',
                  subtitle: '本地记录与导出备份',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.ios_share_rounded,
                      title: '导出 Excel',
                      subtitle:
                          '${context.watch<WorkoutProvider>().records.length} 条记录',
                      onTap: _exportData,
                    ),
                    _SettingsTile(
                      icon: Icons.merge_type_rounded,
                      title: '整合同日记录',
                      subtitle: '合并同一天的多次训练',
                      onTap: _mergeData,
                    ),
                    _SettingsTile(
                      icon: Icons.delete_sweep_outlined,
                      title: '清空训练记录',
                      subtitle: '建议先导出备份',
                      danger: true,
                      onTap: _clearData,
                    ),
                  ],
                ),
                const SectionHeader(
                  title: '云同步',
                  subtitle: '配置与训练数据同步到坚果云',
                ),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.cloud_sync_rounded,
                      title: '坚果云同步',
                      subtitle: nutstore.isConnected
                          ? '已连接 · ${nutstore.username}'
                          : '未配置 · 点击配置',
                      onTap: () => _showCloudSync(nutstore),
                    ),
                  ],
                ),
                const SectionHeader(title: '关于'),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.fitness_center_rounded,
                      title: '铁镌',
                      subtitle: '版本 3.2.2 · 镌刻每一次撸铁',
                      onTap: _showAbout,
                    ),
                    _SettingsTile(
                      icon: Icons.volunteer_activism_rounded,
                      title: '鸣谢',
                      subtitle: '动作示意图与动作分类参考来源',
                      onTap: _showAcknowledgments,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final tone = danger ? const Color(0xFFEF4444) : spec.primary;
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
                  color: tone.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: tone),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color:
                            danger ? const Color(0xFFEF4444) : spec.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: spec.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    color: spec.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
