import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/work_energy.dart';
import '../theme/app_theme.dart';

/// 内置 AI 模型预设：选择后自动填入接口地址与模型 ID。
class AiModelPreset {
  final String label;
  final String endpoint;
  final String model;

  const AiModelPreset(this.label, this.endpoint, this.model);
}

const List<AiModelPreset> builtInAiModels = [
  AiModelPreset(
    '铁镌推荐 · GPT-OSS 20B',
    'https://blockrun.ai/api/v1/chat/completions',
    'nvidia/gpt-oss-20b',
  ),
  AiModelPreset(
    'GPT-OSS 120B（更强推理）',
    'https://blockrun.ai/api/v1/chat/completions',
    'nvidia/gpt-oss-120b',
  ),
  AiModelPreset(
    'Pollinations · GPT-OSS 20B',
    'https://text.pollinations.ai/openai',
    'gpt-oss-20b',
  ),
  AiModelPreset(
    'Pollinations · GPT-OSS 20B（v1）',
    'https://text.pollinations.ai/openai/v1/chat/completions',
    'gpt-oss-20b',
  ),
  AiModelPreset(
    'OpenCode Zen · Big Pickle',
    'https://opencode.ai/inference/openai/v1/chat/completions',
    'big-pickle',
  ),
  AiModelPreset(
    '自定义（手动填写上方字段）',
    '',
    '',
  ),
];

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeProvider(
    String initialThemeId, {
    AppThemeMode initialMode = AppThemeMode.light,
  })  : _themeId = AppThemes.byId(initialThemeId).id,
        _mode = initialMode,
        _platformBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness {
    WidgetsBinding.instance.addObserver(this);
    _loadCustomBackground();
  }

  String _themeId;
  AppThemeMode _mode;
  Brightness _platformBrightness;
  String? _customBackgroundPath;

  String get themeId => _themeId;
  AppThemeMode get mode => _mode;
  AppThemeSpec get currentSpec => specFor(_themeId);
  AppThemeSpec specFor(String id) => AppThemes.byId(id).specFor(
        mode: _mode,
        platformBrightness: _platformBrightness,
      );
  String? get customBackgroundPath => _customBackgroundPath;
  bool get hasCustomBackground =>
      _customBackgroundPath != null && _customBackgroundPath!.trim().isNotEmpty;

  ThemeData get currentTheme =>
      currentSpec.toThemeData(transparentBackground: hasCustomBackground);

  Future<void> setTheme(String id) async {
    if (_themeId == id) return;
    _themeId = AppThemes.byId(id).id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme_id', _themeId);
    await prefs.remove('selected_theme');
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  @override
  void didChangePlatformBrightness() {
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next == _platformBrightness) return;
    _platformBrightness = next;
    if (_mode == AppThemeMode.system) notifyListeners();
  }

  Future<void> _loadCustomBackground() async {
    final prefs = await SharedPreferences.getInstance();
    _customBackgroundPath = prefs.getString('theme_custom_background');
    notifyListeners();
  }

  Future<void> setCustomBackground(String path) async {
    _customBackgroundPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_custom_background', path);
    notifyListeners();
  }

  Future<void> clearCustomBackground() async {
    _customBackgroundPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('theme_custom_background');
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class SettingsProvider extends ChangeNotifier {
  static const String defaultAiEndpoint =
      'https://blockrun.ai/api/v1/chat/completions';
  static const String defaultAiModel = 'nvidia/gpt-oss-20b';
  static const String legacyAiEndpoint =
      'https://opencode.ai/inference/openai/v1/chat/completions';
  static const String legacyAiModel = 'big-pickle';
  static const String legacyPollinationsEndpoint =
      'https://text.pollinations.ai/openai';

  static const List<String> quotes = [
    '每一次努力都值得记录',
    '杠铃不会说谎，时间会给你答案',
    '汗水是肌肉写给未来的情书',
    '今天多举一公斤，明天多一分底气',
    '把自律刻进骨子里，把力量举过头顶',
    '训练没有捷径，只有一次次重复',
    '你举起的不只是重量，还有更好的自己',
    '别等状态，开始训练状态就来了',
    '铁片冰冷，身体滚烫',
    '慢一点没关系，别停下来',
    '动作标准，比数字漂亮更重要',
    '坚持不是口号，是今天真的来了',
  ];

  static const List<String> statusEmojis = [
    '🔥',
    '💪',
    '🏋️',
    '⚡',
    '🦾',
    '🥇',
    '🌙',
    '🌿',
    '☕',
    '🧊',
    '🚀',
    '🎯',
    '🏃',
    '🧗',
    '🚴',
    '🏊',
    '🥊',
    '⛹️',
    '🎾',
    '⚽',
    '🏀',
    '🥩',
    '🥦',
    '🍗',
    '💤',
    '⏰',
    '📈',
    '🧠',
    '❤️',
    '🐺',
    '🦁',
    '🐯',
    '🦅',
    '⚔️',
    '🛡️',
    '👑',
    '💎',
    '🌊',
    '🗻',
    '🎸',
    '🎮',
    '📚',
    '🎓',
    '🧭',
    '🔨',
    '🪓',
    '⚙️',
    '🧲',
  ];

  String _nickname = '铁友';
  String _trainingGoal = '增肌';
  String _experience = '进阶';
  double _bodyWeight = 70;
  double? _heightCm;
  int? _age;
  String _sex = '未填写';
  double? _bodyFatPercent;
  int? _restingHeartRate;
  double? _trainingYears;
  DateTime _streakStart = DateTime(2025, 6, 9, 18, 29);
  int _weeklyGoal = 4;
  String _weightUnit = 'kg';
  int _restSeconds = 90;
  bool _haptics = true;
  bool _remindersEnabled = false;
  String _reminderTime = '20:00';

  bool _aiEnabled = true;
  String _aiEndpoint = defaultAiEndpoint;
  String _aiModel = defaultAiModel;
  String _aiApiKey = '';
  String _aiPrompt = '';

  String _statusEmoji = '🔥';
  String _statusText = '今天的铁，也要镌刻进身体里';
  String? _statusImagePath;
  int _statusTone = 0;
  int _statusMotion = 0;
  int _statusBattery = 80;
  String? _avatarPath;

  String get nickname => _nickname;
  String get trainingGoal => _trainingGoal;
  String get experience => _experience;
  double get bodyWeight => _bodyWeight;
  double? get heightCm => _heightCm;
  int? get age => _age;
  String get sex => _sex;
  double? get bodyFatPercent => _bodyFatPercent;
  int? get restingHeartRate => _restingHeartRate;
  double? get trainingYears => _trainingYears;
  DateTime get streakStart => _streakStart;
  bool get hasStreakStart => _streakStart.isAfter(DateTime(2020, 1, 1));
  IronProfile get ironProfile => IronProfile.instance;
  int get weeklyGoal => _weeklyGoal;
  String get weightUnit => _weightUnit;
  int get restSeconds => _restSeconds;
  bool get haptics => _haptics;
  bool get remindersEnabled => _remindersEnabled;
  String get reminderTime => _reminderTime;

  bool get aiEnabled => _aiEnabled;
  String get aiEndpoint => _aiEndpoint;
  String get aiModel => _aiModel;
  String get aiApiKey => _aiApiKey;
  String get aiPrompt => _aiPrompt;
  bool get hasAiKey => _aiApiKey.trim().isNotEmpty;

  String get statusEmoji => _statusEmoji;
  String get statusText => _statusText;
  String? get statusImagePath => _statusImagePath;
  int get statusTone => _statusTone;
  int get statusMotion => _statusMotion;
  int get statusBattery => _statusBattery;
  String? get avatarPath => _avatarPath;
  bool get hasAvatar => _avatarPath != null && _avatarPath!.trim().isNotEmpty;

  String get todayQuote {
    final index =
        DateTime.now().difference(DateTime(2020)).inDays % quotes.length;
    return quotes[index.abs() % quotes.length];
  }

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString('profile_nickname') ?? '铁友';
    _trainingGoal = prefs.getString('profile_goal') ?? '增肌';
    _experience = prefs.getString('profile_experience') ?? '进阶';
    _bodyWeight = prefs.getDouble('profile_body_weight') ?? 70;
    _heightCm = prefs.getDouble('profile_height_cm');
    _age = prefs.getInt('profile_age');
    _sex = prefs.getString('profile_sex') ?? '未填写';
    _bodyFatPercent = prefs.getDouble('profile_body_fat');
    _restingHeartRate = prefs.getInt('profile_resting_hr');
    _trainingYears = prefs.getDouble('profile_training_years');
    final savedStreakStart = prefs.getString('first_workout_date');
    if (savedStreakStart != null) {
      _streakStart = DateTime.tryParse(savedStreakStart) ?? _streakStart;
    }
    _weeklyGoal = prefs.getInt('training_weekly_goal') ?? 4;
    _weightUnit = prefs.getString('training_weight_unit') ?? 'kg';
    _restSeconds = prefs.getInt('training_rest_seconds') ?? 90;
    _haptics = prefs.getBool('training_haptics') ?? true;
    _remindersEnabled = prefs.getBool('reminder_enabled') ?? false;
    _reminderTime = prefs.getString('reminder_time') ?? '20:00';

    _aiEnabled = prefs.getBool('ai_enabled') ?? true;
    var savedEndpoint = prefs.getString('ai_endpoint');
    var savedModel = prefs.getString('ai_model');
    final defaultsVersion = prefs.getInt('ai_defaults_version') ?? 0;
    if (defaultsVersion < 4) {
      final endpointMigrated = savedEndpoint == null ||
          savedEndpoint == legacyAiEndpoint ||
          savedEndpoint == legacyPollinationsEndpoint;
      if (endpointMigrated) {
        savedEndpoint = defaultAiEndpoint;
        await prefs.setString('ai_endpoint', savedEndpoint);
      }
      if (endpointMigrated ||
          savedModel == null ||
          savedModel == legacyAiModel ||
          savedModel == 'openai' ||
          savedModel == 'gpt-oss-20b') {
        savedModel = defaultAiModel;
        await prefs.setString('ai_model', savedModel);
      }
      await prefs.setInt('ai_defaults_version', 4);
    }
    _aiEndpoint = savedEndpoint ?? defaultAiEndpoint;
    _aiModel = savedModel ?? defaultAiModel;
    _aiApiKey = prefs.getString('ai_api_key') ?? '';
    _aiPrompt = prefs.getString('ai_prompt') ?? '';

    _statusEmoji = prefs.getString('status_emoji') ?? '🔥';
    _statusText = prefs.getString('status_text') ?? '今天的铁，也要镌刻进身体里';
    _statusImagePath = prefs.getString('status_image_path');
    _statusTone = prefs.getInt('status_tone') ?? 0;
    _statusMotion = prefs.getInt('status_motion') ?? 0;
    _statusBattery = (prefs.getInt('status_battery') ?? 80).clamp(0, 100);
    _avatarPath = prefs.getString('profile_avatar_path');
    _syncIronProfile();
    notifyListeners();
  }

  void _syncIronProfile() {
    IronProfile.instance.update(
      bodyWeightKg: _bodyWeight,
      heightCm: _heightCm,
      age: _age,
      sex: switch (_sex) {
        '男' => IronSex.male,
        '女' => IronSex.female,
        _ => IronSex.unspecified,
      },
      bodyFatPercent: _bodyFatPercent,
      restingHeartRate: _restingHeartRate,
      trainingYears: _trainingYears,
      experience: _experience,
      goal: _trainingGoal,
      clearHeight: _heightCm == null,
      clearAge: _age == null,
      clearBodyFat: _bodyFatPercent == null,
      clearRestingHeartRate: _restingHeartRate == null,
      clearTrainingYears: _trainingYears == null,
    );
  }

  Future<void> _persist(String key, Object? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  Future<void> setNickname(String value) async {
    _nickname = value.trim().isEmpty ? '铁友' : value.trim();
    await _persist('profile_nickname', _nickname);
    notifyListeners();
  }

  Future<void> setTrainingGoal(String value) async {
    _trainingGoal = value;
    await _persist('profile_goal', value);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setExperience(String value) async {
    _experience = value;
    await _persist('profile_experience', value);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setBodyWeight(double value) async {
    _bodyWeight = value.clamp(20, 350);
    await _persist('profile_body_weight', _bodyWeight);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setHeightCm(double? value) async {
    _heightCm = value?.clamp(100, 250);
    await _persist('profile_height_cm', _heightCm);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setAge(int? value) async {
    _age = value?.clamp(10, 100);
    await _persist('profile_age', _age);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setSex(String value) async {
    _sex = ['男', '女'].contains(value) ? value : '未填写';
    await _persist('profile_sex', _sex);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setBodyFatPercent(double? value) async {
    _bodyFatPercent = value?.clamp(3, 60);
    await _persist('profile_body_fat', _bodyFatPercent);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setRestingHeartRate(int? value) async {
    _restingHeartRate = value?.clamp(30, 120);
    await _persist('profile_resting_hr', _restingHeartRate);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setTrainingYears(double? value) async {
    _trainingYears = value?.clamp(0, 60);
    await _persist('profile_training_years', _trainingYears);
    _syncIronProfile();
    notifyListeners();
  }

  Future<void> setStreakStart(DateTime value) async {
    _streakStart = value;
    await _persist('first_workout_date', value.toIso8601String());
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int value) async {
    _weeklyGoal = value.clamp(1, 14);
    await _persist('training_weekly_goal', _weeklyGoal);
    notifyListeners();
  }

  Future<void> setWeightUnit(String value) async {
    _weightUnit = value;
    await _persist('training_weight_unit', value);
    notifyListeners();
  }

  Future<void> setRestSeconds(int value) async {
    _restSeconds = value.clamp(15, 600);
    await _persist('training_rest_seconds', _restSeconds);
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    await _persist('training_haptics', value);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool value) async {
    _remindersEnabled = value;
    await _persist('reminder_enabled', value);
    notifyListeners();
  }

  Future<void> setReminderTime(String value) async {
    _reminderTime = value;
    await _persist('reminder_time', value);
    notifyListeners();
  }

  Future<void> setAiEnabled(bool value) async {
    _aiEnabled = value;
    await _persist('ai_enabled', value);
    notifyListeners();
  }

  Future<void> setAiConfig({
    String? endpoint,
    String? model,
    String? apiKey,
  }) async {
    if (endpoint != null) {
      _aiEndpoint =
          endpoint.trim().isEmpty ? defaultAiEndpoint : endpoint.trim();
      await _persist('ai_endpoint', _aiEndpoint);
    }
    if (model != null) {
      _aiModel = model.trim().isEmpty ? defaultAiModel : model.trim();
      await _persist('ai_model', _aiModel);
    }
    if (apiKey != null) {
      _aiApiKey = apiKey.trim();
      await _persist('ai_api_key', _aiApiKey);
    }
    notifyListeners();
  }

  Future<void> setAiPrompt(String value) async {
    _aiPrompt = value.trim();
    await _persist('ai_prompt', _aiPrompt);
    notifyListeners();
  }

  Future<void> setStatus({
    String? emoji,
    String? text,
    String? imagePath,
    bool clearImage = false,
    int? tone,
    int? motion,
    int? battery,
  }) async {
    if (emoji != null) {
      _statusEmoji = emoji;
      await _persist('status_emoji', emoji);
    }
    if (text != null) {
      _statusText = text.trim().isEmpty ? todayQuote : text.trim();
      await _persist('status_text', _statusText);
    }
    if (clearImage) {
      _statusImagePath = null;
      await _persist('status_image_path', null);
    } else if (imagePath != null) {
      _statusImagePath = imagePath;
      await _persist('status_image_path', imagePath);
    }
    if (tone != null) {
      _statusTone = tone;
      await _persist('status_tone', tone);
    }
    if (motion != null) {
      _statusMotion = motion;
      await _persist('status_motion', motion);
    }
    if (battery != null) {
      _statusBattery = battery.clamp(0, 100);
      await _persist('status_battery', _statusBattery);
    }
    notifyListeners();
  }

  Future<void> setStatusBattery(int value) async {
    _statusBattery = value.clamp(0, 100);
    await _persist('status_battery', _statusBattery);
    notifyListeners();
  }

  Future<void> setAvatarPath(String path) async {
    _avatarPath = path.trim().isEmpty ? null : path.trim();
    await _persist('profile_avatar_path', _avatarPath);
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    _avatarPath = null;
    await _persist('profile_avatar_path', null);
    notifyListeners();
  }
}
