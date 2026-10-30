// ==================== main.dart (JSON存储 + 云同步) ====================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' hide Border;
import 'package:fitness_tracker/data/exercise_library.dart';
import 'package:fitness_tracker/screens/book_library_page.dart';
import 'package:fitness_tracker/screens/settings_page.dart';
import 'package:fitness_tracker/screens/coach_analysis_page.dart';
import 'package:fitness_tracker/screens/exercise_library_page.dart';
import 'package:fitness_tracker/screens/history_page.dart';
import 'package:fitness_tracker/screens/splash_screen.dart';
import 'package:fitness_tracker/screens/theme_gallery_page.dart';
import 'package:fitness_tracker/screens/video_collection_page.dart';
import 'package:fitness_tracker/providers/app_providers.dart';
import 'package:fitness_tracker/services/epub_service.dart';
import 'package:fitness_tracker/services/work_energy.dart';
import 'package:fitness_tracker/theme/app_theme.dart';
import 'package:fitness_tracker/widgets/app_ui.dart';
import 'package:fitness_tracker/widgets/book_download_toast.dart';
import 'package:fitness_tracker/widgets/status_banner.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedThemeId = prefs.getString('selected_theme_id');
  final savedThemeMode = prefs.getString('theme_mode');
  final initialThemeMode = AppThemeMode.values.firstWhere(
    (mode) => mode.name == savedThemeMode,
    orElse: () => AppThemeMode.light,
  );
  final legacyThemeIndex = prefs.getInt('selected_theme') ?? 0;
  final initialThemeId = savedThemeId ??
      (legacyThemeIndex >= 0 && legacyThemeIndex < AppThemes.all.length
          ? AppThemes.all[legacyThemeIndex].id
          : AppThemes.ironForge.id);

  runApp(
    MultiProvider(
      providers: [
        // 1. 先注册 JsonStorageService（普通 Provider，不监听变化）
        Provider(create: (_) => JsonStorageService()),
        // 2. 再注册 WorkoutProvider（依赖 JsonStorageService）
        ChangeNotifierProvider(
          create: (context) => WorkoutProvider(
            jsonService: context.read<JsonStorageService>(),
          ),
        ),
        // 3. 其他提供者
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            initialThemeId,
            initialMode: initialThemeMode,
          ),
        ),
        ChangeNotifierProvider(create: (_) => NutstoreService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => EpubLibraryService.instance),
      ],
      child: const FitnessApp(),
    ),
  );
}

// ==================== 数据模型 ====================
class WorkoutRecord {
  final String id;
  DateTime date;
  int? sessionNumber;
  List<WorkoutProject> projects;
  int statusBattery;
  final DateTime timestamp;

  WorkoutRecord({
    required this.id,
    required this.date,
    required this.sessionNumber,
    required this.projects,
    this.statusBattery = 80,
    required this.timestamp,
  });

  double get totalWork {
    return projects.fold(0.0, (sum, project) => sum + project.calculateWork());
  }

  double get totalDurationMinutes =>
      projects.fold(0.0, (sum, project) => sum + project.durationMinutes);

  double get totalDistanceKm =>
      projects.fold(0.0, (sum, project) => sum + project.distanceKm);

  double get totalCalories =>
      projects.fold(0.0, (sum, project) => sum + project.estimatedCalories());
}

class WorkoutProject {
  String name;
  String part;
  double weight;
  int sets;
  int repsPerSet;
  String feeling;
  String supplement;
  String category;
  double durationMinutes;
  double distanceKm;
  double met;

  WorkoutProject({
    required this.name,
    required this.part,
    required this.weight,
    required this.sets,
    required this.repsPerSet,
    required this.feeling,
    required this.supplement,
    this.category = '力量',
    this.durationMinutes = 0,
    this.distanceKm = 0,
    this.met = 0,
  });

  factory WorkoutProject.empty() {
    return WorkoutProject(
      name: '',
      part: '胸',
      weight: 0,
      sets: 0,
      repsPerSet: 0,
      feeling: '',
      supplement: '',
    );
  }

  factory WorkoutProject.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final part = json['part']?.toString() ?? '胸';
    final definition = ExerciseLibrary.findByName(name);
    return WorkoutProject(
      name: name,
      part: part,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      sets: (json['sets'] as num?)?.toInt() ?? 0,
      repsPerSet: (json['repsPerSet'] as num?)?.toInt() ?? 0,
      feeling: json['feeling']?.toString() ?? '',
      supplement: json['supplement']?.toString() ?? '',
      category: json['category']?.toString() ??
          definition?.kind.label ??
          (part == '有氧'
              ? '有氧'
              : part == '柔韧'
                  ? '柔韧'
                  : part == '专项'
                      ? '专项'
                      : '力量'),
      durationMinutes: (json['durationMinutes'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      met: (json['met'] as num?)?.toDouble() ?? definition?.met ?? 0,
    );
  }

  WorkoutProject copy() {
    return WorkoutProject(
      name: name,
      part: part,
      weight: weight,
      sets: sets,
      repsPerSet: repsPerSet,
      feeling: feeling,
      supplement: supplement,
      category: category,
      durationMinutes: durationMinutes,
      distanceKm: distanceKm,
      met: met,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'part': part,
      'weight': weight,
      'sets': sets,
      'repsPerSet': repsPerSet,
      'feeling': feeling,
      'supplement': supplement,
      'category': category,
      'durationMinutes': durationMinutes,
      'distanceKm': distanceKm,
      'met': met,
    };
  }

  bool get isCardio => category == '有氧' || category == '专项';

  bool get isTimeBased => isCardio || category == '柔韧';

  bool get usesDistance => isCardio;

  double get volumeLoad => weight * sets * repsPerSet;

  double calculateWork() {
    if (category == '有氧' || category == '柔韧' || category == '专项') {
      return 0;
    }
    return IronProfile.instance.estimateMechanicalWork(
      part: part,
      weight: weight,
      sets: sets,
      reps: repsPerSet,
    );
  }

  double estimatedCalories({double bodyWeight = 70}) {
    final profile = IronProfile.instance;
    if ((isCardio || category == '柔韧' || category == '功能') &&
        durationMinutes > 0) {
      final intensity = met > 0 ? met : (category == '柔韧' ? 2.5 : 6.5);
      return profile.estimateCardioCalories(
        met: intensity,
        minutes: durationMinutes,
        bodyWeightOverride: bodyWeight == 70 ? null : bodyWeight,
      );
    }
    if (category == '力量' || category == '功能') {
      return profile.estimateStrengthCalories(
        part: part,
        weight: weight,
        sets: sets,
        reps: repsPerSet,
        durationMinutes: durationMinutes,
      );
    }
    return 0;
  }

  String get inputSummary {
    if (isCardio) {
      final parts = <String>[];
      if (durationMinutes > 0) {
        parts.add('${_trimNumber(durationMinutes)} 分钟');
      }
      if (distanceKm > 0) {
        parts.add('${_trimNumber(distanceKm)} km');
      }
      if (parts.isEmpty) parts.add('有氧训练');
      return parts.join(' · ');
    }
    if (category == '柔韧' || category == '功能') {
      final minutes = durationMinutes > 0
          ? '${_trimNumber(durationMinutes)} 分钟'
          : '$sets 组 × $repsPerSet 次';
      if (weight > 0) {
        return '$minutes · ${_trimNumber(weight)} kg';
      }
      return minutes;
    }
    final weightText =
        weight % 1 == 0 ? weight.toStringAsFixed(0) : weight.toStringAsFixed(1);
    return '$weightText kg × $sets 组 × $repsPerSet 次';
  }

  static String _trimNumber(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String get fingerprint => [
        name.trim(),
        part,
        weight.toStringAsFixed(3),
        sets,
        repsPerSet,
        feeling.trim(),
        supplement.trim(),
        category,
        durationMinutes.toStringAsFixed(2),
        distanceKm.toStringAsFixed(3),
        met.toStringAsFixed(2),
      ].join('|');
}

/// 同一天多次保存或云同步时可能把相同动作重复合并，展示与统计前统一去重。
List<WorkoutProject> dedupeWorkoutProjects(Iterable<WorkoutProject> projects) {
  final seen = <String>{};
  final result = <WorkoutProject>[];
  for (final project in projects) {
    if (seen.add(project.fingerprint)) result.add(project);
  }
  return result;
}

List<WorkoutRecord> normalizeWorkoutRecords(Iterable<WorkoutRecord> records) {
  final seenIds = <String>{};
  final seenContent = <String>{};
  final result = <WorkoutRecord>[];
  for (final record in records) {
    final projects = dedupeWorkoutProjects(record.projects);
    final id = record.id.trim();
    if (id.isNotEmpty && !seenIds.add(id)) continue;
    final contentKey = [
      DateFormat('yyyy-MM-dd').format(record.date),
      ...projects.map((project) => project.fingerprint),
    ].join('||');
    if (!seenContent.add(contentKey)) continue;
    result.add(WorkoutRecord(
      id: record.id,
      date: record.date,
      sessionNumber: record.sessionNumber,
      projects: projects,
      statusBattery: record.statusBattery,
      timestamp: record.timestamp,
    ));
  }
  return result;
}

// ==================== JSON 存储服务 ====================
class JsonStorageService {
  static const String fileName = 'workout_data.json';

  Future<String?> saveRecords(List<WorkoutRecord> records) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      final map = {
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'records': records.map((r) => _recordToJson(r)).toList(),
      };
      await file.writeAsString(jsonEncode(map));
      return file.path;
    } catch (e) {
      debugPrint('保存 JSON 失败: $e');
      return null;
    }
  }

  Future<List<WorkoutRecord>> loadRecords() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) return [];
      return await _parseRecordsFile(file);
    } catch (e) {
      debugPrint('加载 JSON 失败: $e');
      return [];
    }
  }

  Future<List<WorkoutRecord>> loadRecordsFromPath(String path) async {
    return _parseRecordsFile(File(path));
  }

  Future<List<WorkoutRecord>> _parseRecordsFile(File file) async {
    final content = await file.readAsString();
    final map = jsonDecode(content);
    final list = (map['records'] as List?) ?? [];
    return list.map((item) => _recordFromJson(item)).toList();
  }

  Map<String, dynamic> _recordToJson(WorkoutRecord r) {
    return {
      'id': r.id,
      'date': r.date.toIso8601String(),
      'sessionNumber': r.sessionNumber,
      'projects': r.projects.map((p) => p.toJson()).toList(),
      'statusBattery': r.statusBattery,
      'timestamp': r.timestamp.toIso8601String(),
    };
  }

  WorkoutRecord _recordFromJson(Map<String, dynamic> json) {
    final battery = (json['statusBattery'] as num?)?.toInt() ?? 80;
    return WorkoutRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      sessionNumber: json['sessionNumber'],
      projects: (json['projects'] as List)
          .map((p) => WorkoutProject.fromJson(
                Map<String, dynamic>.from(p as Map),
              ))
          .toList(),
      statusBattery: battery.clamp(0, 100).toInt(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// ==================== 状态管理 ====================
class WorkoutProvider extends ChangeNotifier {
  List<WorkoutRecord> _records = [];
  String? _lastExportPath;
  final JsonStorageService? _jsonService;

  WorkoutProvider({JsonStorageService? jsonService})
      : _jsonService = jsonService;

  List<WorkoutRecord> get records => _records;
  String? get lastExportPath => _lastExportPath;

  void setLastExportPath(String path) {
    _lastExportPath = path;
    _saveLastExportPath(path);
    notifyListeners();
  }

  Future<void> _saveLastExportPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_export_path', path);
  }

  Future<void> loadLastExportPath() async {
    final prefs = await SharedPreferences.getInstance();
    _lastExportPath = prefs.getString('last_export_path');
    notifyListeners();
  }

  void addRecord(WorkoutRecord newRecord) {
    final existingIndex =
        _records.indexWhere((r) => isSameDay(r.date, newRecord.date));
    if (existingIndex != -1) {
      final existing = _records[existingIndex];
      final mergedProjects = dedupeWorkoutProjects([
        ...existing.projects,
        ...newRecord.projects,
      ]);
      final updatedRecord = WorkoutRecord(
        id: existing.id,
        date: existing.date,
        sessionNumber: existing.sessionNumber,
        projects: mergedProjects,
        statusBattery: newRecord.statusBattery,
        timestamp: DateTime.now(),
      );
      _records[existingIndex] = updatedRecord;
    } else {
      _records.add(WorkoutRecord(
        id: newRecord.id,
        date: newRecord.date,
        sessionNumber: newRecord.sessionNumber,
        projects: dedupeWorkoutProjects(newRecord.projects),
        statusBattery: newRecord.statusBattery,
        timestamp: newRecord.timestamp,
      ));
    }
    recalculateSessionNumbers();
  }

  void updateRecord(String id, WorkoutRecord updatedRecord) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index != -1) {
      _records[index] = WorkoutRecord(
        id: updatedRecord.id,
        date: updatedRecord.date,
        sessionNumber: updatedRecord.sessionNumber,
        projects: dedupeWorkoutProjects(updatedRecord.projects),
        statusBattery: updatedRecord.statusBattery,
        timestamp: updatedRecord.timestamp,
      );
      recalculateSessionNumbers();
    }
  }

  void deleteRecord(String id) {
    _records.removeWhere((record) => record.id == id);
    recalculateSessionNumbers();
  }

  void loadRecords(List<WorkoutRecord> newRecords) {
    _records = normalizeWorkoutRecords(newRecords);
    recalculateSessionNumbers();
  }

  void clearRecords() {
    _records.clear();
    _saveRecords();
    notifyListeners();
  }

  /// 根据训练日期自动计算“第几次训练”，并保持记录按时间排序。
  void recalculateSessionNumbers() {
    _records.sort((a, b) => a.date.compareTo(b.date));
    final uniqueDates = <String>[];
    for (final record in _records) {
      final key = DateFormat('yyyy-MM-dd').format(record.date);
      if (!uniqueDates.contains(key)) uniqueDates.add(key);
    }
    for (final record in _records) {
      final key = DateFormat('yyyy-MM-dd').format(record.date);
      record.sessionNumber = uniqueDates.indexOf(key) + 1;
    }
    _saveRecords();
    notifyListeners();
  }

  int sessionNumberForDate(DateTime date) {
    final keys = _records
        .map((r) => DateFormat('yyyy-MM-dd').format(r.date))
        .toSet()
        .toList();
    final key = DateFormat('yyyy-MM-dd').format(date);
    if (!keys.contains(key)) keys.add(key);
    keys.sort();
    return keys.indexOf(key) + 1;
  }

  int get totalSessions => _records
      .map((r) => DateFormat('yyyy-MM-dd').format(r.date))
      .toSet()
      .length;

  List<WorkoutRecord> get sortedRecords => List<WorkoutRecord>.from(_records)
    ..sort((a, b) => b.date.compareTo(a.date));

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void mergeSameDayRecords() {
    final Map<String, WorkoutRecord> merged = {};
    for (var record in _records) {
      final key = DateFormat('yyyy-MM-dd').format(record.date);
      if (merged.containsKey(key)) {
        final existing = merged[key]!;
        existing.projects = dedupeWorkoutProjects([
          ...existing.projects,
          ...record.projects,
        ]);
        if (record.sessionNumber != null &&
            (existing.sessionNumber == null ||
                record.sessionNumber! > existing.sessionNumber!)) {
          existing.sessionNumber = record.sessionNumber;
        }
        if (record.timestamp.isAfter(existing.timestamp)) {
          existing.statusBattery = record.statusBattery;
        }
      } else {
        merged[key] = WorkoutRecord(
          id: record.id,
          date: record.date,
          sessionNumber: record.sessionNumber,
          projects: List.from(record.projects),
          statusBattery: record.statusBattery,
          timestamp: record.timestamp,
        );
      }
    }
    _records = merged.values.toList();
    recalculateSessionNumbers();
  }

  Future<void> _saveRecords() async {
    if (_jsonService != null) {
      try {
        final path = await _jsonService!.saveRecords(_records);
        if (path == null) {
          debugPrint('保存 JSON 失败：返回路径为空');
        } else {
          debugPrint('保存 JSON 成功：$path');
        }
      } catch (e) {
        debugPrint('保存 JSON 异常：$e');
        // 尝试备用存储（如 SharedPreferences）
        await _saveRecordsToSharedPrefs();
      }
    } else {
      await _saveRecordsToSharedPrefs();
    }
  }

  Future<void> _saveRecordsToSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final recordsJson = _records
          .map((record) => {
                'id': record.id,
                'date': record.date.toIso8601String(),
                'sessionNumber': record.sessionNumber,
                'statusBattery': record.statusBattery,
                'projects': record.projects
                    .map((project) => {
                          'name': project.name,
                          'part': project.part,
                          'weight': project.weight,
                          'sets': project.sets,
                          'repsPerSet': project.repsPerSet,
                          'feeling': project.feeling,
                          'supplement': project.supplement,
                        })
                    .toList(),
                'timestamp': record.timestamp.toIso8601String(),
              })
          .toList();
      final jsonString = json.encode(recordsJson);
      await prefs.setString('workout_records', jsonString);
      debugPrint('SharedPreferences 保存成功');
    } catch (e) {
      debugPrint('SharedPreferences 保存失败：$e');
    }
  }

  Future<void> loadSavedRecords() async {
    if (_jsonService != null) {
      final records = await _jsonService!.loadRecords();
      _records = normalizeWorkoutRecords(records);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getString('workout_records');
      if (recordsJson != null) {
        try {
          final List<dynamic> data = json.decode(recordsJson);
          _records = data.map((item) {
            final battery = (item['statusBattery'] as num?)?.toInt() ?? 80;
            return WorkoutRecord(
              id: item['id'],
              date: DateTime.parse(item['date']),
              sessionNumber: item['sessionNumber'],
              projects: (item['projects'] as List)
                  .map((project) => WorkoutProject.fromJson(
                        Map<String, dynamic>.from(project as Map),
                      ))
                  .toList(),
              statusBattery: battery.clamp(0, 100).toInt(),
              timestamp: DateTime.parse(item['timestamp']),
            );
          }).toList();
        } catch (e) {
          debugPrint('加载保存的记录失败: $e');
        }
      }
    }
    _records = normalizeWorkoutRecords(_records);
    recalculateSessionNumbers();
  }
}

// ==================== Excel 导出服务（仅用于手动导出） ====================
class ExcelExportService {
  static const String _defaultFilename = '健身数据实时表.xlsx';

  Future<String?> exportToExcel(List<WorkoutRecord> records) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['健身记录'];

      final headers = [
        '日期',
        '第几次健身',
        '项目名称',
        '锻炼部位',
        '重量(kg)',
        '组数',
        '每组数量',
        '做功(J)',
        '感受',
        '补剂',
        '记录时间'
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (int i = 0; i < headers.length; i++) {
        final cell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      final sortedRecords = List<WorkoutRecord>.from(records)
        ..sort((a, b) => a.date.compareTo(b.date));

      for (var record in sortedRecords) {
        final dateStr = DateFormat('yyyy-MM-dd').format(record.date);
        for (var project in record.projects) {
          if (project.name.isEmpty) continue;
          final row = <CellValue?>[
            TextCellValue(dateStr),
            record.sessionNumber != null
                ? IntCellValue(record.sessionNumber!)
                : TextCellValue(''),
            TextCellValue(project.name),
            TextCellValue(project.part),
            DoubleCellValue(project.weight),
            IntCellValue(project.sets),
            IntCellValue(project.repsPerSet),
            DoubleCellValue(project.calculateWork()),
            TextCellValue(project.feeling),
            TextCellValue(project.supplement),
            TextCellValue(record.timestamp.toIso8601String()),
          ];
          sheet.appendRow(row);
        }
      }

      int currentRow = 1;
      while (currentRow < sheet.rows.length) {
        final currentDate = sheet.rows[currentRow][0]?.value?.toString();
        if (currentDate == null) break;
        int endRow = currentRow;
        while (endRow + 1 < sheet.rows.length &&
            sheet.rows[endRow + 1][0]?.value?.toString() == currentDate) {
          endRow++;
        }
        if (endRow > currentRow) {
          final startCell =
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow);
          final endCell =
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: endRow);
          sheet.merge(startCell, endCell);
          for (int r = currentRow; r <= endRow; r++) {
            final cell = sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
            cell.cellStyle = CellStyle(
              horizontalAlign: HorizontalAlign.Center,
              verticalAlign: VerticalAlign.Center,
            );
          }
        } else {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
          );
        }
        currentRow = endRow + 1;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_defaultFilename';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      debugPrint('Excel文件已保存到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('导出Excel失败: $e');
      rethrow;
    }
  }
}

// ==================== 坚果云服务（支持 JSON） ====================
class NutstoreService extends ChangeNotifier {
  static const String _baseUrl = 'https://dav.jianguoyun.com/dav/';
  static const String _cloudFolder = '健身数据管理系统';
  static const String _defaultFilename = 'workout_data.json'; // 改为 JSON
  static const String _configFilename = 'app_config.json';

  String? _username;
  String? _password;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  String? get username => _username;

  String _getAuthHeader() {
    if (_username == null || _password == null) {
      throw Exception('未设置用户名或密码');
    }
    final credentials = '$_username:$_password';
    final encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $encoded';
  }

  Future<bool> connect({
    required String username,
    required String password,
    bool saveCredentials = true,
  }) async {
    try {
      _username = username;
      _password = password;
      final client = http.Client();
      final url = Uri.parse(_baseUrl);
      final request = http.Request('PROPFIND', url);
      request.headers['Authorization'] = _getAuthHeader();
      request.headers['Depth'] = '0';
      final response =
          await client.send(request).timeout(const Duration(seconds: 15));
      final responseBody = await http.Response.fromStream(response);
      client.close();
      if (responseBody.statusCode == 207) {
        _isConnected = true;
        await _ensureCloudFolder();
        if (saveCredentials) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('nutstore_username', username);
          await prefs.setString('nutstore_password', password);
        }
        notifyListeners();
        return true;
      } else {
        debugPrint('连接坚果云失败: 状态码 ${responseBody.statusCode}');
        _isConnected = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('连接坚果云失败: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('nutstore_username');
      final password = prefs.getString('nutstore_password');
      if (username == null || password == null) return false;
      return await connect(
          username: username, password: password, saveCredentials: false);
    } catch (e) {
      debugPrint('加载保存的配置失败: $e');
      return false;
    }
  }

  Future<void> _ensureCloudFolder() async {
    try {
      final folderUrl =
          Uri.parse('$_baseUrl${Uri.encodeComponent(_cloudFolder)}');
      final client = http.Client();
      final checkReq = http.Request('PROPFIND', Uri.parse('$folderUrl/'));
      checkReq.headers['Authorization'] = _getAuthHeader();
      checkReq.headers['Depth'] = '1';
      final checkResp = await client.send(checkReq);
      final checkResponse = await http.Response.fromStream(checkResp);
      client.close();
      if (checkResponse.statusCode == 207) return;
      final mkcolClient = http.Client();
      final mkcolReq = http.Request('MKCOL', folderUrl);
      mkcolReq.headers['Authorization'] = _getAuthHeader();
      final mkcolResp = await mkcolClient.send(mkcolReq);
      final mkcolResponse = await http.Response.fromStream(mkcolResp);
      mkcolClient.close();
      if (mkcolResponse.statusCode == 201) {
        debugPrint('云文件夹创建成功: $_cloudFolder');
      } else {
        debugPrint('云文件夹创建失败: 状态码${mkcolResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('确保云文件夹存在失败: $e');
    }
  }

  Future<bool> uploadFile(String localFilePath) async {
    try {
      final file = File(localFilePath);
      if (!await file.exists()) return false;
      final remotePath =
          '$_baseUrl${Uri.encodeComponent(_cloudFolder)}/$_defaultFilename';
      final bytes = await file.readAsBytes();
      final url = Uri.parse(remotePath);
      final client = http.Client();
      final response = await client.put(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: bytes,
      );
      client.close();
      return response.statusCode == 201 || response.statusCode == 204;
    } catch (e) {
      debugPrint('上传文件失败: $e');
      rethrow;
    }
  }

  Future<bool> downloadFile(String savePath) async {
    try {
      final remotePath =
          '$_baseUrl${Uri.encodeComponent(_cloudFolder)}/$_defaultFilename';
      final url = Uri.parse(remotePath);
      final client = http.Client();
      final response = await client.get(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
        },
      );
      client.close();
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('下载文件失败: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> downloadFileWithInfo(String savePath) async {
    try {
      final remotePath =
          '$_baseUrl${Uri.encodeComponent(_cloudFolder)}/$_defaultFilename';
      final url = Uri.parse(remotePath);
      final client = http.Client();
      final response = await client.get(
        url,
        headers: {'Authorization': _getAuthHeader()},
      );
      client.close();
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return {
          'success': true,
          'statusCode': 200,
          'bodyBytes': response.bodyBytes
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'bodyBytes': null,
          'error': 'HTTP ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'statusCode': null,
        'bodyBytes': null,
        'error': e.toString()
      };
    }
  }

  Future<bool> uploadConfig(String json) async {
    try {
      final remotePath =
          '$_baseUrl${Uri.encodeComponent(_cloudFolder)}/$_configFilename';
      final url = Uri.parse(remotePath);
      final client = http.Client();
      final response = await client.put(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: utf8.encode(json),
      );
      client.close();
      return response.statusCode == 201 || response.statusCode == 204;
    } catch (e) {
      debugPrint('上传配置失败: $e');
      return false;
    }
  }

  Future<String?> downloadConfig() async {
    try {
      final remotePath =
          '$_baseUrl${Uri.encodeComponent(_cloudFolder)}/$_configFilename';
      final url = Uri.parse(remotePath);
      final client = http.Client();
      final response = await client.get(
        url,
        headers: {'Authorization': _getAuthHeader()},
      );
      client.close();
      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      }
      return null;
    } catch (e) {
      debugPrint('下载配置失败: $e');
      return null;
    }
  }

  Future<bool> checkConnection() async {
    try {
      final client = http.Client();
      final url = Uri.parse(_baseUrl);
      final request = http.Request('PROPFIND', url);
      request.headers['Authorization'] = _getAuthHeader();
      request.headers['Depth'] = '0';
      final response =
          await client.send(request).timeout(const Duration(seconds: 10));
      final responseBody = await http.Response.fromStream(response);
      client.close();
      return responseBody.statusCode == 207;
    } catch (e) {
      return false;
    }
  }

  void disconnect() {
    _isConnected = false;
    _username = null;
    _password = null;
    notifyListeners();
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nutstore_username');
    await prefs.remove('nutstore_password');
    disconnect();
    notifyListeners();
  }

  static String getHelpMessage() {
    return '''
坚果云 WebDAV 配置说明：

📌 重要提示：
1. 登录坚果云网页版 (https://www.jianguoyun.com)
2. 点击右上角账户名称 → 账户信息
3. 进入「安全选项」页面
4. 在「第三方应用管理」中点击「添加应用」
5. 输入应用名称（如：健身管理系统）
6. 生成并复制「应用密码」

🔧 连接配置：
服务器地址：https://dav.jianguoyun.com/dav
用户名：您的坚果云注册邮箱
密码：生成的应用密码（不是登录密码）

⚠️ 注意：
• 请使用应用密码，不要使用登录密码
• 确保坚果云账户有足够存储空间
• 如遇连接问题，请检查网络和防火墙设置
''';
  }
}

// ==================== 主应用 ====================
class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: '铁镌',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          themeAnimationDuration: const Duration(milliseconds: 650),
          themeAnimationCurve: Curves.easeOutCubic,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => AppBackdrop(
            child: Stack(
              children: [
                if (child != null) Positioned.fill(child: child),
                const BookDownloadToastHost(),
              ],
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ==================== 主界面 ====================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  DateTime selectedDate = DateTime.now();
  final List<WorkoutProject> projects = [WorkoutProject.empty()];

  final TextEditingController dateController = TextEditingController();
  final List<TextEditingController> nameControllers = [];
  final List<TextEditingController> weightControllers = [];
  final List<TextEditingController> setsControllers = [];
  final List<TextEditingController> repsControllers = [];
  final List<TextEditingController> feelingControllers = [];
  final List<TextEditingController> supplementControllers = [];
  final List<TextEditingController> durationControllers = [];
  final List<TextEditingController> distanceControllers = [];
  final List<ValueNotifier<String>> partNotifiers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate);
    _initializeControllers();
    _loadData();
  }

  void _loadData() async {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    final nutstore = Provider.of<NutstoreService>(context, listen: false);
    await provider.loadSavedRecords();
    await provider.loadLastExportPath();
    await nutstore.loadSavedConfig();
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final provider = context.read<WorkoutProvider>();
    await provider.loadSavedRecords();
    if (mounted) setState(() {});
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _jumpToDate(DateTime date) {
    setState(() {
      selectedDate = date;
      dateController.text = DateFormat('yyyy-MM-dd').format(date);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '选择训练日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && !_isSameDay(picked, selectedDate)) {
      _jumpToDate(picked);
    }
  }

  void _saveWorkout(BuildContext context) {
    final validProjects = <WorkoutProject>[];
    for (var i = 0; i < projects.length; i++) {
      if (nameControllers[i].text.trim().isNotEmpty) {
        final name = nameControllers[i].text.trim();
        final definition = ExerciseLibrary.findByName(name);
        final category = definition?.kind.label ??
            (partNotifiers[i].value == '有氧'
                ? '有氧'
                : partNotifiers[i].value == '柔韧'
                    ? '柔韧'
                    : partNotifiers[i].value == '专项'
                        ? '专项'
                        : '力量');
        validProjects.add(WorkoutProject(
          name: name,
          part: partNotifiers[i].value,
          weight: double.tryParse(weightControllers[i].text) ?? 0,
          sets: int.tryParse(setsControllers[i].text) ?? 0,
          repsPerSet: int.tryParse(repsControllers[i].text) ?? 0,
          feeling: feelingControllers[i].text.trim(),
          supplement: supplementControllers[i].text.trim(),
          category: category,
          durationMinutes:
              double.tryParse(durationControllers[i].text.trim()) ?? 0,
          distanceKm: double.tryParse(distanceControllers[i].text.trim()) ?? 0,
          met: definition?.met ?? 0,
        ));
      }
    }
    if (validProjects.isEmpty) {
      _showToast('请至少填写一个动作名称', isError: true);
      return;
    }

    final provider = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final record = WorkoutRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: selectedDate,
      sessionNumber: provider.sessionNumberForDate(selectedDate),
      projects: validProjects,
      statusBattery: settings.statusBattery,
      timestamp: DateTime.now(),
    );
    provider.addRecord(record);

    setState(() {
      projects
        ..clear()
        ..add(WorkoutProject.empty());
      _initializeControllers();
    });
    _showToast('已保存到第 ${provider.sessionNumberForDate(selectedDate)} 次训练');
  }

  @override
  void dispose() {
    dateController.dispose();
    _clearControllers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _exportToExcel(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    setState(() => _isLoading = true);
    try {
      final filePath =
          await ExcelExportService().exportToExcel(provider.records);
      if (filePath == null) {
        if (mounted) _showToast('导出失败', isError: true);
        return;
      }
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '铁镌训练数据',
      );
    } catch (e) {
      if (mounted) _showToast('导出失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncWithCloud(BuildContext context) async {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    final nutstore = Provider.of<NutstoreService>(context, listen: false);
    final jsonService = Provider.of<JsonStorageService>(context, listen: false);

    if (!nutstore.isConnected) {
      _showCloudLoginDialog(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isStillConnected = await nutstore.checkConnection();
      if (!isStillConnected) {
        _showToast('云服务认证已过期，请重新登录', isError: true);
        await nutstore.clearCredentials();
        if (context.mounted) _showCloudLoginDialog(context);
        return;
      }

      List<WorkoutRecord> cloudRecords = [];
      bool cloudFileExists = false;
      final tempPath =
          '${(await getApplicationDocumentsDirectory()).path}/temp_cloud.json';

      final downloadResult = await nutstore.downloadFileWithInfo(tempPath);
      if (downloadResult['success'] == true) {
        cloudFileExists = true;
        try {
          final loaded = await jsonService.loadRecordsFromPath(tempPath);
          cloudRecords = loaded;
        } catch (e) {
          debugPrint('解析云端数据失败: $e');
        }
      }

      if (!context.mounted) return;

      if (!cloudFileExists) {
        await _uploadCurrentData(context, provider, nutstore);
        return;
      }

      final hasLocal = provider.records.isNotEmpty;
      if (!hasLocal) {
        provider.loadRecords(cloudRecords);
        _showToast('已将云端 ${cloudRecords.length} 条记录下载到本地');
        return;
      }

      if (!context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发现云端训练数据'),
          content: Text(
            '云端有 ${cloudRecords.length} 条记录，本地有 ${provider.records.length} 条记录。\n请选择处理方式。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'upload'),
              child: const Text('用本地覆盖云端'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'merge'),
              child: const Text('合并两边记录'),
            ),
          ],
        ),
      );

      if (!context.mounted) return;
      if (choice == 'upload') {
        await _uploadCurrentData(context, provider, nutstore);
      } else if (choice == 'merge') {
        final merged = <WorkoutRecord>[];
        final seen = <String>{};
        for (final record in [...provider.records, ...cloudRecords]) {
          final key = DateFormat('yyyy-MM-dd').format(record.date);
          if (seen.add(key)) {
            merged.add(record);
          } else {
            final index = merged.indexWhere(
              (r) => DateFormat('yyyy-MM-dd').format(r.date) == key,
            );
            if (index != -1) {
              final existing = merged[index];
              final useIncoming = record.timestamp.isAfter(existing.timestamp);
              merged[index] = WorkoutRecord(
                id: existing.id,
                date: existing.date,
                sessionNumber: existing.sessionNumber,
                projects: dedupeWorkoutProjects([
                  ...existing.projects,
                  ...record.projects,
                ]),
                statusBattery:
                    useIncoming ? record.statusBattery : existing.statusBattery,
                timestamp: DateTime.now(),
              );
            }
          }
        }
        provider.loadRecords(merged);
        await _uploadCurrentData(context, provider, nutstore);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadCurrentData(
    BuildContext context,
    WorkoutProvider provider,
    NutstoreService nutstore,
  ) async {
    final jsonService = context.read<JsonStorageService>();
    final path = await jsonService.saveRecords(provider.records);
    if (path == null) {
      if (mounted) _showToast('保存本地数据失败', isError: true);
      return;
    }
    final ok = await nutstore.uploadFile(path);
    if (!mounted) return;
    _showToast(ok ? '云端数据已更新' : '上传失败，请稍后重试', isError: !ok);
  }

  void _showCloudLoginDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isConnecting = false;
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('连接坚果云'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '使用坚果云 WebDAV 同步训练数据。请在坚果云网页端「安全选项」中生成应用密码。',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: '坚果云账号',
                    hintText: '邮箱地址',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '应用密码',
                    hintText: '不是登录密码',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isConnecting ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: isConnecting
                  ? null
                  : () async {
                      if (usernameController.text.trim().isEmpty ||
                          passwordController.text.isEmpty) {
                        setDialogState(() => error = '请填写账号和应用密码');
                        return;
                      }
                      setDialogState(() {
                        isConnecting = true;
                        error = null;
                      });
                      final nutstore = context.read<NutstoreService>();
                      final ok = await nutstore.connect(
                        username: usernameController.text.trim(),
                        password: passwordController.text,
                      );
                      if (!dialogContext.mounted) return;
                      if (ok) {
                        Navigator.pop(dialogContext);
                        _showToast('坚果云连接成功');
                      } else {
                        setDialogState(() {
                          isConnecting = false;
                          error = '连接失败，请检查账号或应用密码';
                        });
                      }
                    },
              child: isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloudMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('立即同步'),
              onTap: () {
                Navigator.pop(sheetContext);
                _syncWithCloud(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('断开连接', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await context.read<NutstoreService>().clearCredentials();
                if (mounted) _showToast('已断开坚果云连接');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordDetail(BuildContext context, WorkoutRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final spec = sheetContext.watch<ThemeProvider>().currentSpec;
        final projects = dedupeWorkoutProjects(record.projects)
            .where((project) => project.name.trim().isNotEmpty)
            .toList();
        return FractionallySizedBox(
          heightFactor: .78,
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
            child: Column(
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
                              '${DateFormat('M月d日').format(record.date)} · ${weekdayLabel(record.date)}',
                              style: TextStyle(
                                color: spec.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '第 ${record.sessionNumber ?? '—'} 次训练 · '
                              '${projects.length} 个动作'
                              '${record.totalDurationMinutes > 0 ? ' · ${record.totalDurationMinutes.toStringAsFixed(0)} 分钟' : ''}',
                              style: TextStyle(
                                color: spec.textSecondary,
                                fontSize: 12,
                              ),
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
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                    children: [
                      for (final project in projects)
                        GlassPanel(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(14),
                          radius: 17,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      project.name,
                                      style: TextStyle(
                                        color: spec.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBattery(
                                    level: record.statusBattery,
                                    width: 64,
                                    height: 13,
                                    outlineColor: spec.isDark
                                        ? null
                                        : spec.textPrimary
                                            .withValues(alpha: .42),
                                    textColor:
                                        spec.isDark ? null : spec.textPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Pill(
                                    label: project.part,
                                    color: spec.secondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                project.inputSummary,
                                style: TextStyle(
                                  color: spec.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                project.isTimeBased
                                    ? '估算消耗 ${project.estimatedCalories().round()} kcal'
                                    : '做功 ${formatCompact(project.calculateWork())} J'
                                        ' · 估算 ${project.estimatedCalories().round()} kcal',
                                style: TextStyle(
                                  color: spec.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (project.feeling.trim().isNotEmpty ||
                                  project.supplement.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  [
                                    if (project.feeling.trim().isNotEmpty)
                                      '感受：${project.feeling.trim()}',
                                    if (project.supplement.trim().isNotEmpty)
                                      '备注：${project.supplement.trim()}',
                                  ].join('  ·  '),
                                  style: TextStyle(
                                    color: spec.textSecondary,
                                    fontSize: 11,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (projects.isEmpty)
                        Text(
                          '这条记录还没有动作明细。',
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showHistory(context);
                      },
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('查看全部训练记录'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: spec.primary,
                        side: BorderSide(
                          color: spec.primary.withValues(alpha: .3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPage(
          onExport: () => _exportToExcel(context),
          onSync: () {
            final nutstore = context.read<NutstoreService>();
            if (nutstore.isConnected) {
              _showCloudMenu(context);
            } else {
              _showCloudLoginDialog(context);
            }
          },
        ),
      ),
    );
  }

  void _showThemeGallery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ThemeGalleryPage()),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildProjectCard(int index) {
    return _ProjectCard(
      key: ValueKey('project_$index'),
      index: index,
      partNotifier: partNotifiers[index],
      nameController: nameControllers[index],
      weightController: weightControllers[index],
      setsController: setsControllers[index],
      repsController: repsControllers[index],
      feelingController: feelingControllers[index],
      supplementController: supplementControllers[index],
      durationController: durationControllers[index],
      distanceController: distanceControllers[index],
      canRemove: projects.length > 1,
      onRemove: () => _removeProjectAt(index),
    );
  }

  void _addProject() {
    setState(() {
      projects.add(WorkoutProject.empty());
      nameControllers.add(TextEditingController());
      weightControllers.add(TextEditingController());
      setsControllers.add(TextEditingController());
      repsControllers.add(TextEditingController());
      feelingControllers.add(TextEditingController());
      supplementControllers.add(TextEditingController());
      durationControllers.add(TextEditingController());
      distanceControllers.add(TextEditingController());
      partNotifiers.add(ValueNotifier<String>('胸'));
    });
  }

  void _removeProjectAt(int index) {
    if (projects.length <= 1) return;
    setState(() {
      projects.removeAt(index);
      nameControllers.removeAt(index).dispose();
      weightControllers.removeAt(index).dispose();
      setsControllers.removeAt(index).dispose();
      repsControllers.removeAt(index).dispose();
      feelingControllers.removeAt(index).dispose();
      supplementControllers.removeAt(index).dispose();
      durationControllers.removeAt(index).dispose();
      distanceControllers.removeAt(index).dispose();
      partNotifiers.removeAt(index).dispose();
    });
  }

  void _initializeControllers() {
    _clearControllers();
    for (final project in projects) {
      nameControllers.add(TextEditingController(text: project.name));
      weightControllers.add(TextEditingController(
        text: project.weight == 0 ? '' : project.weight.toString(),
      ));
      setsControllers.add(TextEditingController(
        text: project.sets == 0 ? '' : project.sets.toString(),
      ));
      repsControllers.add(TextEditingController(
        text: project.repsPerSet == 0 ? '' : project.repsPerSet.toString(),
      ));
      feelingControllers.add(TextEditingController(text: project.feeling));
      supplementControllers
          .add(TextEditingController(text: project.supplement));
      durationControllers.add(TextEditingController(
        text: project.durationMinutes == 0
            ? ''
            : project.durationMinutes.toString(),
      ));
      distanceControllers.add(TextEditingController(
        text: project.distanceKm == 0 ? '' : project.distanceKm.toString(),
      ));
      partNotifiers.add(ValueNotifier<String>(project.part));
    }
  }

  void _clearControllers() {
    for (final c in nameControllers) {
      c.dispose();
    }
    for (final c in weightControllers) {
      c.dispose();
    }
    for (final c in setsControllers) {
      c.dispose();
    }
    for (final c in repsControllers) {
      c.dispose();
    }
    for (final c in feelingControllers) {
      c.dispose();
    }
    for (final c in supplementControllers) {
      c.dispose();
    }
    for (final c in durationControllers) {
      c.dispose();
    }
    for (final c in distanceControllers) {
      c.dispose();
    }
    for (final n in partNotifiers) {
      n.dispose();
    }
    nameControllers.clear();
    weightControllers.clear();
    setsControllers.clear();
    repsControllers.clear();
    feelingControllers.clear();
    supplementControllers.clear();
    durationControllers.clear();
    distanceControllers.clear();
    partNotifiers.clear();
  }

  Widget _quickDateChip(String label, int daysAgo, AppThemeSpec spec) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    final active = _isSameDay(date, selectedDate);
    return Expanded(
      child: GestureDetector(
        onTap: () => _jumpToDate(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? spec.primary.withValues(alpha: .18)
                : spec.textPrimary.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? spec.primary.withValues(alpha: .45)
                  : spec.textPrimary.withValues(alpha: .06),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? spec.primary : spec.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateCard(
    BuildContext context,
    WorkoutProvider provider,
    AppThemeSpec spec,
  ) {
    final hasRecord =
        provider.records.any((r) => _isSameDay(r.date, selectedDate));
    final sessionNumber = provider.sessionNumberForDate(selectedDate);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.event_available_rounded,
                colors: [spec.primary, spec.secondary],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '训练日期',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${DateFormat('yyyy年M月d日').format(selectedDate)} · ${weekdayLabel(selectedDate)}',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 138),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Pill(
                    label: hasRecord
                        ? '第 $sessionNumber 次 · 合并'
                        : '第 $sessionNumber 次',
                    icon: Icons.tag_rounded,
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _selectDate(context),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: spec.textPrimary.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: spec.primary.withValues(alpha: .28),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: spec.primary, size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: TextStyle(
                          color: spec.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '更换日期',
                      style: TextStyle(
                        color: spec.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: spec.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _quickDateChip('今天', 0, spec),
              const SizedBox(width: 8),
              _quickDateChip('昨天', 1, spec),
              const SizedBox(width: 8),
              _quickDateChip('前天', 2, spec),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<WorkoutProvider>();
    final now = DateTime.now();
    final weekSessions = provider.records.where((r) {
      final diff = now.difference(r.date).inDays;
      return diff >= 0 && diff < 7;
    }).length;
    final totalWork =
        provider.records.fold<double>(0, (sum, r) => sum + r.totalWork);
    final recent = provider.sortedRecords.take(3).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '铁镌',
              style: TextStyle(
                color: spec.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            Text(
              'IRON ETCH',
              style: TextStyle(
                color: spec.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AI 训练舱',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoachAnalysisPage()),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          IconButton(
            tooltip: '视频合集',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VideoCollectionPage(),
                ),
              );
            },
            icon: const Icon(Icons.tv_rounded),
          ),
          IconButton(
            tooltip: '阅读器',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookLibraryPage()),
              );
            },
            icon: const Icon(Icons.menu_book_rounded),
          ),
          IconButton(
            tooltip: '训练历史',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showHistory(context),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: '主题工坊',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showThemeGallery(context),
            icon: const Icon(Icons.palette_outlined),
          ),
          IconButton(
            tooltip: '设置',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                18,
                6,
                18,
                34 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                StatusBanner(startedAt: settings.streakStart),
                const SizedBox(height: 10),
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
                        label: '本周训练',
                        value: '$weekSessions',
                        unit: '次',
                        icon: Icons.local_fire_department_rounded,
                        accent: const Color(0xFFF97316),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: '累计做功',
                        value: formatCompact(totalWork),
                        unit: 'J',
                        icon: Icons.bolt_rounded,
                        accent: spec.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '记录今天的铁',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: spec.textPrimary,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Pill(
                        label: '${projects.length} 个动作',
                        icon: Icons.list_alt_rounded,
                      ),
                    ],
                  ),
                ),
                _dateCard(context, provider, spec),
                const SizedBox(height: 14),
                for (var i = 0; i < projects.length; i++) _buildProjectCard(i),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addProject,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('添加动作'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(
                            color: spec.primary.withValues(alpha: .32),
                          ),
                          foregroundColor: spec.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => _saveWorkout(context),
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: spec.heroGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: spec.primary.withValues(alpha: .34),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: spec.onHero, size: 22),
                        const SizedBox(width: 9),
                        Text(
                          '保存训练记录',
                          style: TextStyle(
                            color: spec.onHero,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 34, 2, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '最近训练',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: spec.textPrimary,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '快速回看最近的训练节奏',
                              style: TextStyle(
                                fontSize: 12,
                                color: spec.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showHistory(context),
                        child: const Text('全部记录'),
                      ),
                    ],
                  ),
                ),
                if (recent.isEmpty)
                  GlassPanel(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(Icons.self_improvement_rounded,
                            color: spec.primary, size: 34),
                        const SizedBox(height: 10),
                        Text(
                          '还没有训练记录',
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '填写上方的动作和重量，保存你的第一次铁镌。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: spec.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final record in recent)
                    _RecentRecordCard(
                      record: record,
                      onTap: () => _showRecordDetail(context, record),
                    ),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: spec.background.withValues(alpha: .55),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  final WorkoutRecord record;
  final VoidCallback onTap;

  const _RecentRecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final parts = record.projects.map((p) => p.part).toSet().toList();
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 18,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: spec.primary.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${record.date.day}',
                  style: TextStyle(
                    color: spec.primary,
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${record.date.month}月',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 9,
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
                    final maxParts = constraints.maxWidth < 200 ? 1 : 2;
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
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
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
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Pill(
                                      label: part,
                                      color: spec.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          flex: 2,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: StatusBattery(
                              level: record.statusBattery,
                              width: 52,
                              height: 12,
                              outlineColor: spec.isDark
                                  ? null
                                  : spec.textPrimary.withValues(alpha: .42),
                              textColor: spec.isDark ? null : spec.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 3),
                Text(
                  record.projects
                      .map((p) => p.name)
                      .where((n) => n.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.totalWork > 0
                    ? formatCompact(record.totalWork)
                    : record.totalDurationMinutes.toStringAsFixed(0),
                style: TextStyle(
                  color: spec.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                record.totalWork > 0
                    ? '焦耳'
                    : record.totalDistanceKm > 0
                        ? '分钟 · ${record.totalDistanceKm.toStringAsFixed(1)} km'
                        : '分钟',
                style: TextStyle(color: spec.textSecondary, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== 项目卡片组件 ====================
class _ProjectCard extends StatefulWidget {
  final int index;
  final ValueNotifier<String> partNotifier;
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController feelingController;
  final TextEditingController supplementController;
  final TextEditingController durationController;
  final TextEditingController distanceController;
  final bool canRemove;
  final VoidCallback onRemove;

  const _ProjectCard({
    super.key,
    required this.index,
    required this.partNotifier,
    required this.nameController,
    required this.weightController,
    required this.setsController,
    required this.repsController,
    required this.feelingController,
    required this.supplementController,
    required this.durationController,
    required this.distanceController,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  late String _part;
  ExerciseDefinition? _definition;

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

  @override
  void initState() {
    super.initState();
    _part = widget.partNotifier.value;
    _definition = ExerciseLibrary.findByName(widget.nameController.text);
    widget.partNotifier.addListener(_onPartChanged);
    widget.nameController.addListener(_onNameChanged);
    widget.weightController.addListener(_refresh);
    widget.setsController.addListener(_refresh);
    widget.repsController.addListener(_refresh);
    widget.durationController.addListener(_refresh);
    widget.distanceController.addListener(_refresh);
  }

  void _onPartChanged() {
    if (!mounted) return;
    setState(() => _part = widget.partNotifier.value);
  }

  void _onNameChanged() {
    if (!mounted) return;
    final definition = ExerciseLibrary.findByName(widget.nameController.text);
    setState(() {
      _definition = definition;
      if (definition != null && definition.group != _part) {
        _part = definition.group;
        widget.partNotifier.value = definition.group;
      }
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.partNotifier.removeListener(_onPartChanged);
    widget.nameController.removeListener(_onNameChanged);
    widget.weightController.removeListener(_refresh);
    widget.setsController.removeListener(_refresh);
    widget.repsController.removeListener(_refresh);
    widget.durationController.removeListener(_refresh);
    widget.distanceController.removeListener(_refresh);
    super.dispose();
  }

  String get _category =>
      _definition?.kind.label ??
      (_part == '有氧'
          ? '有氧'
          : _part == '柔韧'
              ? '柔韧'
              : '力量');

  bool get _isCardio => _category == '有氧' || _category == '专项';

  bool get _isTimeBased => _isCardio || _category == '柔韧';

  double _calculateWork() {
    if (_category == '有氧' || _category == '柔韧' || _category == '专项') {
      return 0;
    }
    final weight = double.tryParse(widget.weightController.text) ?? 0;
    final sets = int.tryParse(widget.setsController.text) ?? 0;
    final reps = int.tryParse(widget.repsController.text) ?? 0;
    return IronProfile.instance.estimateMechanicalWork(
      part: _part,
      weight: weight,
      sets: sets,
      reps: reps,
    );
  }

  Future<void> _pickExercise() async {
    final selected = await Navigator.push<ExerciseDefinition>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryPage(initialKind: _definition?.kind),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _definition = selected;
      _part = selected.group;
      widget.partNotifier.value = selected.group;
      widget.nameController.text = selected.name;
    });
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

  Widget _numberField(
    AppThemeSpec spec,
    TextEditingController controller,
    String label,
    String hint, {
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, spec),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: spec.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
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
                const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: spec.textPrimary.withValues(alpha: .08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: spec.textPrimary.withValues(alpha: .08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: spec.primary.withValues(alpha: .7),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _textField(
    AppThemeSpec spec,
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, spec),
        TextField(
          controller: controller,
          style: TextStyle(color: spec.textPrimary, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: spec.textSecondary, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: spec.textPrimary.withValues(alpha: .04),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: spec.textPrimary.withValues(alpha: .08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: spec.textPrimary.withValues(alpha: .08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: spec.primary.withValues(alpha: .7),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _partChip(String part, AppThemeSpec spec) {
    final active = part == _part;
    return GestureDetector(
      onTap: () {
        widget.partNotifier.value = part;
        setState(() => _part = part);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? spec.primary.withValues(alpha: .18)
              : spec.textPrimary.withValues(alpha: .035),
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

  @override
  Widget build(BuildContext context) {
    final spec = context.watch<ThemeProvider>().currentSpec;
    final work = _calculateWork();
    final duration = double.tryParse(widget.durationController.text) ?? 0;
    final met = _definition?.met ?? 0;
    final kcal = IronProfile.instance.estimateCardioCalories(
      met: met > 0 ? met : 6.5,
      minutes: duration,
    );
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: spec.heroGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      color: spec.onHero,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.nameController,
                  textCapitalization: TextCapitalization.none,
                  style: TextStyle(
                    color: spec.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: '动作名称，例如：卧推',
                    hintStyle: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: spec.textPrimary.withValues(alpha: .04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: spec.textPrimary.withValues(alpha: .08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: spec.textPrimary.withValues(alpha: .08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: spec.primary.withValues(alpha: .7),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _pickExercise,
                tooltip: '从动作库选择',
                icon: Icon(
                  Icons.menu_book_rounded,
                  color: spec.primary,
                  size: 20,
                ),
              ),
              if (widget.canRemove) ...[
                const SizedBox(width: 2),
                IconButton(
                  onPressed: widget.onRemove,
                  tooltip: '删除这个动作',
                  icon: Icon(
                    Icons.close_rounded,
                    color: spec.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          if (_definition != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Pill(
                    label: _definition!.kind.label,
                    icon: Icons.category_rounded),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _definition!.equipment,
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickExercise,
                  icon: const Icon(Icons.search_rounded, size: 15),
                  label: const Text('动作库'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final part in _parts) _partChip(part, spec),
            ],
          ),
          const SizedBox(height: 14),
          if (_isTimeBased)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numberField(
                    spec,
                    widget.durationController,
                    '时长',
                    '0',
                    suffix: '分钟',
                  ),
                ),
                const SizedBox(width: 8),
                if (_isCardio)
                  Expanded(
                    child: _numberField(
                      spec,
                      widget.distanceController,
                      '距离',
                      '0',
                      suffix: 'km',
                    ),
                  ),
                if (_category == '柔韧')
                  Expanded(
                    child: _numberField(
                      spec,
                      widget.repsController,
                      '呼吸次数',
                      '0',
                    ),
                  ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numberField(
                    spec,
                    widget.weightController,
                    '重量',
                    '0',
                    suffix: 'kg',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    spec,
                    widget.setsController,
                    '组数',
                    '0',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    spec,
                    widget.repsController,
                    '每组次数',
                    '0',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _textField(
                  spec,
                  widget.feelingController,
                  '训练感受',
                  '状态、力竭程度…',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textField(
                  spec,
                  widget.supplementController,
                  '补剂 / 备注',
                  '可选',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: spec.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isTimeBased
                      ? Icons.local_fire_department_rounded
                      : Icons.bolt_rounded,
                  size: 16,
                  color: spec.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  _isTimeBased ? '估算消耗' : '预计做功',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _isTimeBased
                      ? '${kcal.toStringAsFixed(0)} kcal'
                      : '${formatCompact(work)} J',
                  style: TextStyle(
                    color: spec.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
