enum ExerciseKind {
  strength('力量', '💪'),
  cardio('有氧', '🏃'),
  mobility('柔韧', '🧘'),
  functional('功能', '⚙️'),
  sport('专项', '🎯');

  const ExerciseKind(this.label, this.emoji);

  final String label;
  final String emoji;
}

class MuscleGroup {
  final String label;
  final List<String> primary;
  final List<String> secondary;
  final String note;

  const MuscleGroup({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.note,
  });
}

class ExerciseDefinition {
  final String name;
  final String group;
  final ExerciseKind kind;
  final String equipment;
  final String pattern;
  final int difficulty;
  final List<String> aliases;
  final List<String> emphasis;
  final String cue;
  final double met;

  const ExerciseDefinition({
    required this.name,
    required this.group,
    required this.kind,
    required this.equipment,
    required this.pattern,
    required this.difficulty,
    required this.aliases,
    required this.emphasis,
    required this.cue,
    required this.met,
  });

  bool get isTimeBased =>
      kind == ExerciseKind.cardio ||
      kind == ExerciseKind.mobility ||
      kind == ExerciseKind.sport;
}

class ExerciseLibrary {
  static const String source =
      '动作分类与肌群命名参考 ExRx.net 肌肉目录、ACE 动作库、NASM 矫正训练体系与 ACSM 运动测试与处方指南。';

  static const Map<String, MuscleGroup> groups = {
    '胸': MuscleGroup(
      label: '胸',
      primary: ['胸大肌（锁骨部、胸骨部、肋部）'],
      secondary: ['三角肌前束', '肱三头肌', '前锯肌'],
      note: '水平推、上斜推和夹胸分别侧重胸大肌不同纤维走向。',
    ),
    '背': MuscleGroup(
      label: '背',
      primary: ['背阔肌', '斜方肌中下部', '菱形肌'],
      secondary: ['三角肌后束', '肱二头肌', '竖脊肌'],
      note: '垂直拉与水平拉共同构建背部厚度和宽度。',
    ),
    '肩': MuscleGroup(
      label: '肩',
      primary: ['三角肌前束', '三角肌中束', '三角肌后束'],
      secondary: ['斜方肌上束', '冈上肌', '前锯肌'],
      note: '推举、侧平举和反向飞鸟分别覆盖三角肌三个束。',
    ),
    '手臂': MuscleGroup(
      label: '手臂',
      primary: ['肱二头肌', '肱肌', '肱三头肌'],
      secondary: ['肱桡肌', '前臂屈肌群', '前臂伸肌群'],
      note: '肘屈、肘伸和腕关节稳定共同决定手臂围度与力量。',
    ),
    '前臂': MuscleGroup(
      label: '前臂',
      primary: ['前臂屈肌群', '前臂伸肌群', '肱桡肌'],
      secondary: ['旋前圆肌', '旋后肌', '手内在肌'],
      note: '握力与腕关节稳定会限制绝大多数拉类动作的表现。',
    ),
    '腿': MuscleGroup(
      label: '腿',
      primary: ['股四头肌（股直肌、股外侧肌、股内侧肌、股中间肌）', '腘绳肌（股二头肌、半腱肌、半膜肌）'],
      secondary: ['臀大肌', '内收肌群', '小腿三头肌'],
      note: '膝主导与髋主导动作应同时安排，兼顾力量与关节健康。',
    ),
    '臀': MuscleGroup(
      label: '臀',
      primary: ['臀大肌', '臀中肌', '臀小肌'],
      secondary: ['腘绳肌', '内收肌群', '竖脊肌'],
      note: '髋伸、髋外展和髋外旋是臀部训练的三大方向。',
    ),
    '小腿': MuscleGroup(
      label: '小腿',
      primary: ['腓肠肌', '比目鱼肌'],
      secondary: ['胫骨后肌', '腓骨长肌', '腓骨短肌'],
      note: '直膝提踵偏向腓肠肌，屈膝提踵偏向比目鱼肌。',
    ),
    '核心': MuscleGroup(
      label: '核心',
      primary: ['腹直肌', '腹外斜肌', '腹内斜肌', '腹横肌'],
      secondary: ['竖脊肌', '多裂肌', '膈肌', '盆底肌'],
      note: '核心既负责产生动作，也负责把力量从下肢传到上肢。',
    ),
    '全身': MuscleGroup(
      label: '全身',
      primary: ['多关节肌群协同'],
      secondary: ['核心稳定肌群', '肩胛稳定肌群', '髋稳定肌群'],
      note: '复合动作对神经肌肉协调和能量消耗的要求更高。',
    ),
    '有氧': MuscleGroup(
      label: '有氧',
      primary: ['心肺系统', '下肢大肌群', '上肢大肌群'],
      secondary: ['核心稳定肌群', '呼吸肌'],
      note: 'ACSM 建议成年人每周累计至少 150 分钟中等强度有氧运动。',
    ),
    '柔韧': MuscleGroup(
      label: '柔韧',
      primary: ['关节活动度', '肌肉筋膜系统'],
      secondary: ['结缔组织', '神经控制'],
      note: '动态拉伸适合热身，静态拉伸更适合训练后或独立恢复时段。',
    ),
    '专项': MuscleGroup(
      label: '专项',
      primary: ['专项运动肌群', '心肺系统'],
      secondary: ['平衡与本体感觉', '核心稳定肌群'],
      note: '专项训练应服务于具体运动表现，并控制单次负荷与恢复。',
    ),
  };

  static const List<String> groupOrder = [
    '胸',
    '背',
    '肩',
    '手臂',
    '前臂',
    '腿',
    '臀',
    '小腿',
    '核心',
    '全身',
    '有氧',
    '柔韧',
    '专项',
  ];

  static const List<String> trainingParts = [
    '胸',
    '背',
    '肩',
    '手臂',
    '腿',
    '臀',
    '核心',
    '有氧',
  ];

  static final List<ExerciseDefinition> all = [
    ..._chest,
    ..._back,
    ..._shoulders,
    ..._arms,
    ..._forearms,
    ..._legs,
    ..._glutes,
    ..._calves,
    ..._core,
    ..._cardio,
    ..._mobility,
    ..._functional,
    ..._sport,
  ];

  static ExerciseDefinition? findByName(String name) {
    final key = _normalize(name);
    if (key.isEmpty) return null;
    for (final exercise in all) {
      if (_normalize(exercise.name) == key) return exercise;
      for (final alias in exercise.aliases) {
        if (_normalize(alias) == key) return exercise;
      }
    }
    return null;
  }

  static List<ExerciseDefinition> search({
    String query = '',
    ExerciseKind? kind,
    String? group,
  }) {
    final key = _normalize(query);
    return all.where((exercise) {
      if (kind != null && exercise.kind != kind) return false;
      if (group != null && group.isNotEmpty && exercise.group != group) {
        return false;
      }
      if (key.isEmpty) return true;
      if (_normalize(exercise.name).contains(key)) return true;
      if (_normalize(exercise.group).contains(key)) return true;
      if (_normalize(exercise.equipment).contains(key)) return true;
      if (_normalize(exercise.pattern).contains(key)) return true;
      if (exercise.aliases.any((a) => _normalize(a).contains(key))) {
        return true;
      }
      if (exercise.emphasis.any((m) => _normalize(m).contains(key))) {
        return true;
      }
      final muscles = groups[exercise.group];
      if (muscles != null) {
        if (muscles.primary.any((m) => _normalize(m).contains(key))) {
          return true;
        }
        if (muscles.secondary.any((m) => _normalize(m).contains(key))) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  static List<ExerciseDefinition> byKind(ExerciseKind kind) {
    return all.where((exercise) => exercise.kind == kind).toList();
  }

  static List<ExerciseDefinition> byGroup(String group) {
    return all.where((exercise) => exercise.group == group).toList();
  }

  static String _normalize(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .toLowerCase();
  }

  static const Map<String, String> _patternCues = {
    '水平推': '肩胛后缩下沉，手腕保持中立，离心阶段控制 2 秒。',
    '上斜推': '保持肩胛稳定，肘部略低于肩线，避免耸肩。',
    '垂直推': '核心收紧，肋骨下压，杠铃或哑铃沿头部两侧移动。',
    '夹胸': '肘部微屈并保持固定角度，用胸大肌完成内收。',
    '垂直拉': '先下沉肩胛，再用背阔肌把肘部拉向身体两侧。',
    '水平拉': '胸部挺起，肘部贴近身体，避免用腰部借力。',
    '肩伸': '保持躯干稳定，用背部带动上臂向后伸展。',
    '肘屈': '上臂固定，避免摆动，离心阶段充分控制。',
    '肘伸': '肘部保持稳定，只让前臂完成伸展。',
    '腕屈伸': '前臂贴稳支撑面，小幅度、慢速完成腕关节运动。',
    '膝主导': '膝盖与脚尖方向一致，脚掌均匀受力，保持脊柱中立。',
    '髋主导': '髋部向后移动，保持背部中立，感受腘绳肌与臀部张力。',
    '髋伸': '收紧臀部完成伸髋，避免腰椎过度伸展。',
    '髋外展': '骨盆保持水平，用臀中肌控制外展与回落。',
    '提踵': '在最高点停顿，缓慢下放到小腿充分拉伸的位置。',
    '核心抗伸展': '肋骨下压、骨盆后倾，保持自然呼吸。',
    '核心抗旋转': '抵抗旋转力量，保持躯干和骨盆稳定。',
    '卷腹': '用腹肌带动脊柱屈曲，避免用手拉扯颈部。',
    '步态': '保持身体直立，步频稳定，落地轻缓。',
    '周期': '保持稳定节奏与呼吸，先控制强度再增加时长。',
    '低强度持续': '强度以能说短句为宜，持续时间和频率优先于速度。',
    '间歇': '高强度段全力但不失动作质量，恢复段充分降低心率。',
    '动态活动度': '在可控范围内缓慢移动，不使用弹震式拉伸。',
    '静态拉伸': '呼吸放松，在轻微牵拉感处保持 20-40 秒。',
    '筋膜放松': '在敏感点缓慢加压，避免直接压迫骨点和关节。',
    '爆发': '先保证落地与躯干稳定，再追求速度和力量输出。',
    '旋转': '旋转来自髋部与胸椎，腰椎保持稳定。',
    '负重行走': '躯干直立、肩胛稳定，步幅小而稳。',
    '专项技术': '以技术质量和专项需求为先，控制总量与恢复。',
  };

  static ExerciseDefinition _e(
    String name, {
    required String group,
    required ExerciseKind kind,
    String equipment = '自重',
    String pattern = '力量',
    int difficulty = 2,
    List<String> aliases = const [],
    List<String> emphasis = const [],
    String cue = '',
    double met = 0,
  }) {
    return ExerciseDefinition(
      name: name,
      group: group,
      kind: kind,
      equipment: equipment,
      pattern: pattern,
      difficulty: difficulty,
      aliases: aliases,
      emphasis: emphasis,
      cue: cue.isEmpty ? (_patternCues[pattern] ?? '保持动作可控，优先保证关节对齐与呼吸。') : cue,
      met: met,
    );
  }

  static final List<ExerciseDefinition> _chest = [
    _e('杠铃卧推', group: '胸', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '水平推', difficulty: 2, aliases: ['卧推', '平板卧推'], emphasis: ['胸大肌胸骨部']),
    _e('上斜杠铃卧推', group: '胸', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '上斜推', difficulty: 2, aliases: ['上斜卧推'], emphasis: ['胸大肌锁骨部']),
    _e('下斜杠铃卧推', group: '胸', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '水平推', difficulty: 2, aliases: ['下斜卧推'], emphasis: ['胸大肌肋部']),
    _e('哑铃卧推', group: '胸', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '水平推', aliases: ['平板哑铃卧推']),
    _e('上斜哑铃卧推', group: '胸', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '上斜推', emphasis: ['胸大肌锁骨部']),
    _e('哑铃飞鸟', group: '胸', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '夹胸'),
    _e('上斜哑铃飞鸟', group: '胸', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '夹胸', emphasis: ['胸大肌锁骨部']),
    _e('绳索夹胸', group: '胸', kind: ExerciseKind.strength, equipment: '绳索', pattern: '夹胸', aliases: ['龙门架夹胸']),
    _e('上斜绳索夹胸', group: '胸', kind: ExerciseKind.strength, equipment: '绳索', pattern: '夹胸', emphasis: ['胸大肌锁骨部']),
    _e('蝴蝶机夹胸', group: '胸', kind: ExerciseKind.strength, equipment: '器械', pattern: '夹胸', aliases: ['蝴蝶机', '夹胸机']),
    _e('双杠臂屈伸（胸版）', group: '胸', kind: ExerciseKind.strength, equipment: '双杠', pattern: '水平推', difficulty: 3, aliases: ['双杠臂屈伸'], emphasis: ['胸大肌下部', '肱三头肌']),
    _e('俯卧撑', group: '胸', kind: ExerciseKind.strength, equipment: '自重', pattern: '水平推', difficulty: 1),
    _e('宽距俯卧撑', group: '胸', kind: ExerciseKind.strength, equipment: '自重', pattern: '水平推', difficulty: 1, emphasis: ['胸大肌']),
    _e('上斜俯卧撑', group: '胸', kind: ExerciseKind.strength, equipment: '自重', pattern: '上斜推', difficulty: 1),
    _e('器械推胸', group: '胸', kind: ExerciseKind.strength, equipment: '器械', pattern: '水平推', difficulty: 1),
    _e('史密斯卧推', group: '胸', kind: ExerciseKind.strength, equipment: '史密斯机', pattern: '水平推'),
    _e('地板卧推', group: '胸', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '水平推', difficulty: 2),
  ];

  static final List<ExerciseDefinition> _back = [
    _e('引体向上', group: '背', kind: ExerciseKind.strength, equipment: '单杠', pattern: '垂直拉', difficulty: 3, aliases: ['正手引体', 'pull-up']),
    _e('反手引体向上', group: '背', kind: ExerciseKind.strength, equipment: '单杠', pattern: '垂直拉', difficulty: 3, aliases: ['反手引体', 'chin-up'], emphasis: ['肱二头肌']),
    _e('高位下拉', group: '背', kind: ExerciseKind.strength, equipment: '绳索', pattern: '垂直拉', difficulty: 1, aliases: ['下拉', 'lat pulldown']),
    _e('窄距高位下拉', group: '背', kind: ExerciseKind.strength, equipment: '绳索', pattern: '垂直拉', difficulty: 1),
    _e('杠铃划船', group: '背', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '水平拉', difficulty: 2, aliases: ['俯身划船']),
    _e('潘德雷划船', group: '背', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '水平拉', difficulty: 3, aliases: ['Pendlay划船']),
    _e('单臂哑铃划船', group: '背', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '水平拉', difficulty: 1, aliases: ['哑铃划船']),
    _e('坐姿绳索划船', group: '背', kind: ExerciseKind.strength, equipment: '绳索', pattern: '水平拉', difficulty: 1, aliases: ['坐姿划船']),
    _e('T杠划船', group: '背', kind: ExerciseKind.strength, equipment: 'T杠', pattern: '水平拉', difficulty: 2),
    _e('胸支撑哑铃划船', group: '背', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '水平拉', difficulty: 1, aliases: ['胸支撑划船']),
    _e('直臂下压', group: '背', kind: ExerciseKind.strength, equipment: '绳索', pattern: '肩伸', difficulty: 1, aliases: ['直臂下拉']),
    _e('反向划船', group: '背', kind: ExerciseKind.strength, equipment: '自重', pattern: '水平拉', difficulty: 2, aliases: ['澳大利亚引体']),
    _e('面拉', group: '背', kind: ExerciseKind.strength, equipment: '绳索', pattern: '水平拉', difficulty: 1, aliases: ['face pull'], emphasis: ['三角肌后束', '肩袖']),
    _e('耸肩', group: '背', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '垂直拉', difficulty: 1, aliases: ['哑铃耸肩'], emphasis: ['斜方肌上束']),
    _e('山羊挺身', group: '背', kind: ExerciseKind.strength, equipment: '器械', pattern: '髋主导', difficulty: 1, aliases: ['背伸', '罗马椅挺身']),
    _e('架上拉', group: '背', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '髋主导', difficulty: 3, aliases: ['rack pull']),
    _e('负重引体向上', group: '背', kind: ExerciseKind.strength, equipment: '单杠', pattern: '垂直拉', difficulty: 3),
  ];

  static final List<ExerciseDefinition> _shoulders = [
    _e('站姿杠铃推举', group: '肩', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '垂直推', difficulty: 2, aliases: ['军事推举', '肩推']),
    _e('坐姿杠铃推举', group: '肩', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '垂直推', difficulty: 2),
    _e('坐姿哑铃推举', group: '肩', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '垂直推', difficulty: 1, aliases: ['哑铃肩推']),
    _e('阿诺德推举', group: '肩', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '垂直推', difficulty: 2),
    _e('哑铃侧平举', group: '肩', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '髋外展', difficulty: 1, aliases: ['侧平举'], emphasis: ['三角肌中束']),
    _e('绳索侧平举', group: '肩', kind: ExerciseKind.strength, equipment: '绳索', pattern: '髋外展', difficulty: 1, aliases: ['单臂绳索侧平举']),
    _e('器械侧平举', group: '肩', kind: ExerciseKind.strength, equipment: '器械', pattern: '髋外展', difficulty: 1),
    _e('俯身哑铃反向飞鸟', group: '肩', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '水平拉', difficulty: 1, aliases: ['反向飞鸟', '后束飞鸟'], emphasis: ['三角肌后束']),
    _e('反向蝴蝶机', group: '肩', kind: ExerciseKind.strength, equipment: '器械', pattern: '水平拉', difficulty: 1, aliases: ['蝴蝶机反向飞鸟']),
    _e('直立划船', group: '肩', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '垂直拉', difficulty: 2),
    _e('哑铃前平举', group: '肩', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '垂直推', difficulty: 1, emphasis: ['三角肌前束']),
    _e('器械肩推', group: '肩', kind: ExerciseKind.strength, equipment: '器械', pattern: '垂直推', difficulty: 1),
    _e('史密斯肩推', group: '肩', kind: ExerciseKind.strength, equipment: '史密斯机', pattern: '垂直推'),
    _e('倒立撑', group: '肩', kind: ExerciseKind.strength, equipment: '自重', pattern: '垂直推', difficulty: 3),
  ];

  static final List<ExerciseDefinition> _arms = [
    _e('杠铃弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '肘屈', difficulty: 1),
    _e('哑铃弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '肘屈', difficulty: 1),
    _e('锤式弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '肘屈', difficulty: 1, emphasis: ['肱桡肌', '肱肌']),
    _e('牧师凳弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '肘屈', difficulty: 2),
    _e('绳索弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '绳索', pattern: '肘屈', difficulty: 1),
    _e('集中弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '肘屈', difficulty: 1),
    _e('上斜哑铃弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '肘屈', difficulty: 2, emphasis: ['肱二头肌长头']),
    _e('窄距卧推', group: '手臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '水平推', difficulty: 2, emphasis: ['肱三头肌']),
    _e('仰卧杠铃臂屈伸', group: '手臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '肘伸', difficulty: 2, aliases: ['碎颅者', 'skull crusher']),
    _e('绳索下压', group: '手臂', kind: ExerciseKind.strength, equipment: '绳索', pattern: '肘伸', difficulty: 1, aliases: ['三头下压']),
    _e('单臂绳索下压', group: '手臂', kind: ExerciseKind.strength, equipment: '绳索', pattern: '肘伸', difficulty: 1),
    _e('哑铃颈后臂屈伸', group: '手臂', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '肘伸', difficulty: 1),
    _e('俯身哑铃臂屈伸', group: '手臂', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '肘伸', difficulty: 1),
    _e('双杠臂屈伸（三头版）', group: '手臂', kind: ExerciseKind.strength, equipment: '双杠', pattern: '肘伸', difficulty: 3, emphasis: ['肱三头肌']),
    _e('反握弯举', group: '手臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '肘屈', difficulty: 1, emphasis: ['肱桡肌']),
  ];

  static final List<ExerciseDefinition> _forearms = [
    _e('杠铃腕弯举', group: '前臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '腕屈伸', difficulty: 1),
    _e('杠铃反握腕弯举', group: '前臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '腕屈伸', difficulty: 1),
    _e('背后杠铃腕弯举', group: '前臂', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '腕屈伸', difficulty: 2),
    _e('农夫握持', group: '前臂', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '负重行走', difficulty: 1, aliases: ['静力握持']),
    _e('毛巾握持', group: '前臂', kind: ExerciseKind.strength, equipment: '毛巾', pattern: '负重行走', difficulty: 1),
  ];

  static final List<ExerciseDefinition> _legs = [
    _e('杠铃深蹲', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '膝主导', difficulty: 2, aliases: ['深蹲', 'squat']),
    _e('前蹲', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '膝主导', difficulty: 3, aliases: ['front squat']),
    _e('箱式深蹲', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '膝主导', difficulty: 2),
    _e('泽奇深蹲', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '膝主导', difficulty: 3, aliases: ['Zercher深蹲']),
    _e('史密斯深蹲', group: '腿', kind: ExerciseKind.strength, equipment: '史密斯机', pattern: '膝主导', difficulty: 1),
    _e('哈克深蹲', group: '腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '膝主导', difficulty: 1),
    _e('腿举', group: '腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '膝主导', difficulty: 1, aliases: ['倒蹬']),
    _e('保加利亚分腿蹲', group: '腿', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '膝主导', difficulty: 2, aliases: ['保加利亚蹲']),
    _e('哑铃箭步蹲', group: '腿', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '膝主导', difficulty: 1, aliases: ['箭步蹲']),
    _e('行走箭步蹲', group: '腿', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '膝主导', difficulty: 2),
    _e('反向箭步蹲', group: '腿', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '膝主导', difficulty: 1),
    _e('腿屈伸', group: '腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '膝主导', difficulty: 1, aliases: ['坐姿腿屈伸']),
    _e('俯卧腿弯举', group: '腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '髋主导', difficulty: 1),
    _e('坐姿腿弯举', group: '腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '髋主导', difficulty: 1),
    _e('罗马尼亚硬拉', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '髋主导', difficulty: 2, aliases: ['RDL']),
    _e('直腿硬拉', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '髋主导', difficulty: 2),
    _e('早安式', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '髋主导', difficulty: 2, aliases: ['good morning']),
    _e('传统硬拉', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '髋主导', difficulty: 3, aliases: ['硬拉', 'deadlift']),
    _e('相扑硬拉', group: '腿', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '髋主导', difficulty: 3),
    _e('单腿腿举', group: '腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '膝主导', difficulty: 2),
    _e('徒手深蹲', group: '腿', kind: ExerciseKind.strength, equipment: '自重', pattern: '膝主导', difficulty: 1),
    _e('靠墙静蹲', group: '腿', kind: ExerciseKind.strength, equipment: '自重', pattern: '膝主导', difficulty: 1),
  ];

  static final List<ExerciseDefinition> _glutes = [
    _e('杠铃臀推', group: '臀', kind: ExerciseKind.strength, equipment: '杠铃', pattern: '髋伸', difficulty: 2, aliases: ['臀推', 'hip thrust']),
    _e('单腿臀推', group: '臀', kind: ExerciseKind.strength, equipment: '自重', pattern: '髋伸', difficulty: 2),
    _e('臀桥', group: '臀', kind: ExerciseKind.strength, equipment: '自重', pattern: '髋伸', difficulty: 1, aliases: ['glute bridge']),
    _e('绳索后踢腿', group: '臀', kind: ExerciseKind.strength, equipment: '绳索', pattern: '髋伸', difficulty: 1),
    _e('髋外展', group: '臀', kind: ExerciseKind.strength, equipment: '器械', pattern: '髋外展', difficulty: 1, emphasis: ['臀中肌']),
    _e('髋内收', group: '臀', kind: ExerciseKind.strength, equipment: '器械', pattern: '髋外展', difficulty: 1, emphasis: ['内收肌群']),
    _e('侧向弹力带走', group: '臀', kind: ExerciseKind.strength, equipment: '弹力带', pattern: '髋外展', difficulty: 1, aliases: ['弹力带侧走']),
    _e('壶铃摆荡', group: '臀', kind: ExerciseKind.functional, equipment: '壶铃', pattern: '髋伸', difficulty: 2, aliases: ['kettlebell swing']),
    _e('弹力带臀推', group: '臀', kind: ExerciseKind.strength, equipment: '弹力带', pattern: '髋伸', difficulty: 1),
  ];

  static final List<ExerciseDefinition> _calves = [
    _e('站姿提踵', group: '小腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '提踵', difficulty: 1, emphasis: ['腓肠肌']),
    _e('坐姿提踵', group: '小腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '提踵', difficulty: 1, emphasis: ['比目鱼肌']),
    _e('驴式提踵', group: '小腿', kind: ExerciseKind.strength, equipment: '器械', pattern: '提踵', difficulty: 2),
    _e('单腿提踵', group: '小腿', kind: ExerciseKind.strength, equipment: '自重', pattern: '提踵', difficulty: 1),
  ];

  static final List<ExerciseDefinition> _core = [
    _e('平板支撑', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '核心抗伸展', difficulty: 1, aliases: ['plank']),
    _e('侧平板支撑', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '核心抗旋转', difficulty: 1, aliases: ['side plank']),
    _e('死虫', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '核心抗伸展', difficulty: 1, aliases: ['dead bug']),
    _e('鸟狗', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '核心抗旋转', difficulty: 1, aliases: ['bird dog']),
    _e('悬垂举腿', group: '核心', kind: ExerciseKind.strength, equipment: '单杠', pattern: '卷腹', difficulty: 3, aliases: ['悬垂抬腿']),
    _e('仰卧卷腹', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '卷腹', difficulty: 1, aliases: ['卷腹']),
    _e('绳索卷腹', group: '核心', kind: ExerciseKind.strength, equipment: '绳索', pattern: '卷腹', difficulty: 1),
    _e('健腹轮', group: '核心', kind: ExerciseKind.strength, equipment: '健腹轮', pattern: '核心抗伸展', difficulty: 3, aliases: ['腹肌轮']),
    _e('俄罗斯转体', group: '核心', kind: ExerciseKind.strength, equipment: '负重', pattern: '旋转', difficulty: 2),
    _e('帕洛夫推', group: '核心', kind: ExerciseKind.strength, equipment: '绳索', pattern: '核心抗旋转', difficulty: 1, aliases: ['Pallof press']),
    _e('反向卷腹', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '卷腹', difficulty: 1),
    _e('登山跑', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '核心抗伸展', difficulty: 2),
    _e('负重体侧屈', group: '核心', kind: ExerciseKind.strength, equipment: '哑铃', pattern: '旋转', difficulty: 1),
    _e('自行车卷腹', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '卷腹', difficulty: 1),
    _e('悬垂屈膝举腿', group: '核心', kind: ExerciseKind.strength, equipment: '单杠', pattern: '卷腹', difficulty: 2),
    _e('空心支撑', group: '核心', kind: ExerciseKind.strength, equipment: '自重', pattern: '核心抗伸展', difficulty: 2, aliases: ['hollow hold']),
  ];

  static final List<ExerciseDefinition> _cardio = [
    _e('跑步', group: '有氧', kind: ExerciseKind.cardio, equipment: '跑鞋', pattern: '步态', difficulty: 1, met: 8.3, aliases: ['慢跑', 'running']),
    _e('快走', group: '有氧', kind: ExerciseKind.cardio, equipment: '跑鞋', pattern: '步态', difficulty: 1, met: 4.3, aliases: ['walking']),
    _e('骑行', group: '有氧', kind: ExerciseKind.cardio, equipment: '自行车', pattern: '周期', difficulty: 1, met: 7.5, aliases: ['自行车', 'cycling']),
    _e('游泳（自由泳）', group: '有氧', kind: ExerciseKind.cardio, equipment: '泳池', pattern: '周期', difficulty: 2, met: 8.3, aliases: ['自由泳']),
    _e('游泳（蛙泳）', group: '有氧', kind: ExerciseKind.cardio, equipment: '泳池', pattern: '周期', difficulty: 2, met: 5.3, aliases: ['蛙泳']),
    _e('游泳（仰泳）', group: '有氧', kind: ExerciseKind.cardio, equipment: '泳池', pattern: '周期', difficulty: 2, met: 5.3, aliases: ['仰泳']),
    _e('游泳（蝶泳）', group: '有氧', kind: ExerciseKind.cardio, equipment: '泳池', pattern: '周期', difficulty: 3, met: 10.0, aliases: ['蝶泳']),
    _e('划船机', group: '有氧', kind: ExerciseKind.cardio, equipment: '划船机', pattern: '周期', difficulty: 2, met: 7.0, aliases: ['rowing']),
    _e('椭圆机', group: '有氧', kind: ExerciseKind.cardio, equipment: '椭圆机', pattern: '周期', difficulty: 1, met: 5.0),
    _e('爬楼机', group: '有氧', kind: ExerciseKind.cardio, equipment: '爬楼机', pattern: '周期', difficulty: 2, met: 8.8, aliases: ['登山机']),
    _e('跳绳', group: '有氧', kind: ExerciseKind.cardio, equipment: '跳绳', pattern: '间歇', difficulty: 2, met: 12.3, aliases: ['jump rope']),
    _e('开合跳', group: '有氧', kind: ExerciseKind.cardio, equipment: '自重', pattern: '间歇', difficulty: 1, met: 8.0, aliases: ['jumping jack']),
    _e('波比跳', group: '有氧', kind: ExerciseKind.cardio, equipment: '自重', pattern: '间歇', difficulty: 3, met: 10.0, aliases: ['burpee']),
    _e('高抬腿', group: '有氧', kind: ExerciseKind.cardio, equipment: '自重', pattern: '间歇', difficulty: 2, met: 8.0),
    _e('动感单车', group: '有氧', kind: ExerciseKind.cardio, equipment: '动感单车', pattern: '周期', difficulty: 2, met: 7.0, aliases: ['spinning']),
    _e('越野跑', group: '有氧', kind: ExerciseKind.cardio, equipment: '跑鞋', pattern: '步态', difficulty: 2, met: 9.0, aliases: ['trail running']),
    _e('爬坡走', group: '有氧', kind: ExerciseKind.cardio, equipment: '跑步机', pattern: '步态', difficulty: 1, met: 6.0),
    _e('HIIT', group: '有氧', kind: ExerciseKind.cardio, equipment: '自重', pattern: '间歇', difficulty: 3, met: 8.5, aliases: ['高强度间歇训练']),
    _e('间歇跑', group: '有氧', kind: ExerciseKind.cardio, equipment: '跑鞋', pattern: '间歇', difficulty: 3, met: 10.0),
    _e('低强度稳态有氧', group: '有氧', kind: ExerciseKind.cardio, equipment: '有氧器械', pattern: '低强度持续', difficulty: 1, met: 4.5, aliases: ['LISS']),
    _e('战绳', group: '有氧', kind: ExerciseKind.functional, equipment: '战绳', pattern: '间歇', difficulty: 2, met: 8.0, aliases: ['battle rope']),
    _e('跳箱', group: '有氧', kind: ExerciseKind.functional, equipment: '跳箱', pattern: '爆发', difficulty: 2, met: 8.0, aliases: ['box jump']),
  ];

  static final List<ExerciseDefinition> _mobility = [
    _e('动态热身', group: '柔韧', kind: ExerciseKind.mobility, equipment: '自重', pattern: '动态活动度', difficulty: 1, met: 3.0, aliases: ['热身']),
    _e('猫牛式', group: '柔韧', kind: ExerciseKind.mobility, equipment: '瑜伽垫', pattern: '动态活动度', difficulty: 1, aliases: ['cat cow']),
    _e('世界最佳拉伸', group: '柔韧', kind: ExerciseKind.mobility, equipment: '瑜伽垫', pattern: '动态活动度', difficulty: 2, aliases: ['world greatest stretch']),
    _e('髋屈肌拉伸', group: '柔韧', kind: ExerciseKind.mobility, equipment: '瑜伽垫', pattern: '静态拉伸', difficulty: 1),
    _e('胸椎旋转', group: '柔韧', kind: ExerciseKind.mobility, equipment: '瑜伽垫', pattern: '动态活动度', difficulty: 1),
    _e('肩袖外旋', group: '柔韧', kind: ExerciseKind.mobility, equipment: '弹力带', pattern: '动态活动度', difficulty: 1, aliases: ['肩外旋']),
    _e('弹力带肩绕环', group: '柔韧', kind: ExerciseKind.mobility, equipment: '弹力带', pattern: '动态活动度', difficulty: 1, aliases: ['肩绕环']),
    _e('站姿体前屈', group: '柔韧', kind: ExerciseKind.mobility, equipment: '自重', pattern: '静态拉伸', difficulty: 1),
    _e('鸽子式', group: '柔韧', kind: ExerciseKind.mobility, equipment: '瑜伽垫', pattern: '静态拉伸', difficulty: 2),
    _e('婴儿式', group: '柔韧', kind: ExerciseKind.mobility, equipment: '瑜伽垫', pattern: '静态拉伸', difficulty: 1, aliases: ['child pose']),
    _e('泡沫轴放松', group: '柔韧', kind: ExerciseKind.mobility, equipment: '泡沫轴', pattern: '筋膜放松', difficulty: 1),
    _e('筋膜球放松', group: '柔韧', kind: ExerciseKind.mobility, equipment: '筋膜球', pattern: '筋膜放松', difficulty: 1),
    _e('90/90髋部转换', group: '柔韧', kind: ExerciseKind.mobility, equipment: '瑜伽垫', pattern: '动态活动度', difficulty: 2),
    _e('踝关节背屈拉伸', group: '柔韧', kind: ExerciseKind.mobility, equipment: '弹力带', pattern: '静态拉伸', difficulty: 1),
  ];

  static final List<ExerciseDefinition> _functional = [
    _e('土耳其起立', group: '全身', kind: ExerciseKind.functional, equipment: '壶铃', pattern: '爆发', difficulty: 3, aliases: ['Turkish get-up']),
    _e('农夫行走', group: '全身', kind: ExerciseKind.functional, equipment: '哑铃', pattern: '负重行走', difficulty: 1, aliases: ['farmer carry']),
    _e('药球砸地', group: '全身', kind: ExerciseKind.functional, equipment: '药球', pattern: '爆发', difficulty: 2),
    _e('战绳甩动', group: '全身', kind: ExerciseKind.functional, equipment: '战绳', pattern: '间歇', difficulty: 2, met: 8.0, aliases: ['战绳']),
    _e('雪橇推', group: '全身', kind: ExerciseKind.functional, equipment: '雪橇', pattern: '爆发', difficulty: 2, aliases: ['sled push']),
    _e('雪橇拉', group: '全身', kind: ExerciseKind.functional, equipment: '雪橇', pattern: '负重行走', difficulty: 2, aliases: ['sled pull']),
    _e('跳深', group: '全身', kind: ExerciseKind.functional, equipment: '跳箱', pattern: '爆发', difficulty: 3, aliases: ['depth jump']),
    _e('药球旋转抛', group: '全身', kind: ExerciseKind.functional, equipment: '药球', pattern: '旋转', difficulty: 2),
    _e('单臂壶铃摆荡', group: '全身', kind: ExerciseKind.functional, equipment: '壶铃', pattern: '髋伸', difficulty: 2),
    _e('借力推举', group: '全身', kind: ExerciseKind.functional, equipment: '杠铃', pattern: '爆发', difficulty: 3, aliases: ['push press']),
  ];

  static final List<ExerciseDefinition> _sport = [
    _e('篮球', group: '专项', kind: ExerciseKind.sport, equipment: '篮球场', pattern: '专项技术', difficulty: 2, met: 8.0),
    _e('足球', group: '专项', kind: ExerciseKind.sport, equipment: '足球场', pattern: '专项技术', difficulty: 2, met: 7.0),
    _e('羽毛球', group: '专项', kind: ExerciseKind.sport, equipment: '球拍', pattern: '专项技术', difficulty: 2, met: 5.5),
    _e('网球', group: '专项', kind: ExerciseKind.sport, equipment: '球拍', pattern: '专项技术', difficulty: 2, met: 7.3),
    _e('乒乓球', group: '专项', kind: ExerciseKind.sport, equipment: '球拍', pattern: '专项技术', difficulty: 1, met: 4.0),
    _e('攀岩', group: '专项', kind: ExerciseKind.sport, equipment: '攀岩墙', pattern: '专项技术', difficulty: 3, met: 8.0),
    _e('拳击', group: '专项', kind: ExerciseKind.sport, equipment: '拳套', pattern: '专项技术', difficulty: 3, met: 7.8),
    _e('泰拳', group: '专项', kind: ExerciseKind.sport, equipment: '拳套', pattern: '专项技术', difficulty: 3, met: 10.0),
    _e('综合格斗', group: '专项', kind: ExerciseKind.sport, equipment: '拳套', pattern: '专项技术', difficulty: 3, met: 10.0, aliases: ['MMA']),
    _e('跳绳（双摇）', group: '专项', kind: ExerciseKind.sport, equipment: '跳绳', pattern: '专项技术', difficulty: 3, met: 12.3),
  ];
}
