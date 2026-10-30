import 'package:flutter/material.dart';

/// 动作库教学示意图：按「动作模式」绘制侧视小人 + 器械提示。
/// 29 种动作模式覆盖全部 176 个动作。
class ExerciseIllustration extends StatelessWidget {
  const ExerciseIllustration({
    super.key,
    required this.pattern,
    required this.color,
    this.equipment = '',
    this.backgroundColor = Colors.transparent,
  });

  final String pattern;
  final Color color;
  final String equipment;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final pose = _poses[pattern] ?? const _Pose();
    return CustomPaint(
      painter: _ExerciseFigurePainter(
        pose: pose,
        color: color,
        equipment: equipment,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _Pose {
  final Offset head;
  final Offset neck;
  final Offset shoulder;
  final Offset elbow;
  final Offset hand;
  final Offset hip;
  final Offset knee;
  final Offset foot;
  final bool bench;

  const _Pose({
    this.head = const Offset(56, 11),
    this.neck = const Offset(54, 19),
    this.shoulder = const Offset(52, 26),
    this.elbow = const Offset(48, 38),
    this.hand = const Offset(45, 51),
    this.hip = const Offset(52, 48),
    this.knee = const Offset(50, 69),
    this.foot = const Offset(50, 91),
    this.bench = false,
  });
}

final Map<String, _Pose> _poses = {
  // 水平推：仰卧卧推
  '水平推': const _Pose(
    head: Offset(23, 44),
    neck: Offset(29, 44),
    shoulder: Offset(35, 44),
    elbow: Offset(39, 38),
    hand: Offset(43, 33),
    hip: Offset(66, 44),
    knee: Offset(84, 46),
    foot: Offset(91, 50),
    bench: true,
  ),
  // 上斜推
  '上斜推': const _Pose(
    head: Offset(23, 37),
    neck: Offset(29, 38),
    shoulder: Offset(35, 39),
    elbow: Offset(39, 33),
    hand: Offset(43, 29),
    hip: Offset(66, 46),
    knee: Offset(84, 49),
    foot: Offset(91, 53),
    bench: true,
  ),
  // 垂直推：站姿推举
  '垂直推': const _Pose(
    head: Offset(54, 10),
    neck: Offset(53, 18),
    shoulder: Offset(52, 25),
    elbow: Offset(50, 30),
    hand: Offset(54, 22),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 夹胸：飞鸟
  '夹胸': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(43, 33),
    hand: Offset(41, 41),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
    bench: true,
  ),
  // 垂直拉：引体/下拉
  '垂直拉': const _Pose(
    head: Offset(54, 15),
    neck: Offset(53, 22),
    shoulder: Offset(52, 28),
    elbow: Offset(47, 33),
    hand: Offset(53, 20),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 水平拉：划船
  '水平拉': const _Pose(
    head: Offset(56, 15),
    neck: Offset(54, 22),
    shoulder: Offset(50, 30),
    elbow: Offset(43, 38),
    hand: Offset(39, 44),
    hip: Offset(52, 49),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 肩伸：直臂下压
  '肩伸': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(47, 36),
    hand: Offset(44, 55),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 肘屈：弯举
  '肘屈': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(50, 37),
    hand: Offset(47, 27),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 肘伸：臂屈伸
  '肘伸': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(52, 28),
    hand: Offset(50, 44),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 腕屈伸
  '腕屈伸': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(48, 38),
    hand: Offset(44, 44),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 膝主导：深蹲
  '膝主导': const _Pose(
    head: Offset(55, 13),
    neck: Offset(53, 20),
    shoulder: Offset(51, 27),
    elbow: Offset(44, 36),
    hand: Offset(45, 40),
    hip: Offset(50, 54),
    knee: Offset(56, 72),
    foot: Offset(55, 90),
  ),
  // 髋主导：硬拉
  '髋主导': const _Pose(
    head: Offset(56, 18),
    neck: Offset(54, 25),
    shoulder: Offset(50, 32),
    elbow: Offset(46, 40),
    hand: Offset(45, 52),
    hip: Offset(55, 51),
    knee: Offset(51, 70),
    foot: Offset(50, 91),
  ),
  // 髋伸：臀推/臀桥
  '髋伸': const _Pose(
    head: Offset(27, 42),
    neck: Offset(33, 42),
    shoulder: Offset(39, 42),
    elbow: Offset(41, 38),
    hand: Offset(42, 34),
    hip: Offset(53, 36),
    knee: Offset(64, 44),
    foot: Offset(70, 60),
    bench: true,
  ),
  // 髋外展
  '髋外展': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(49, 38),
    hand: Offset(46, 51),
    hip: Offset(52, 48),
    knee: Offset(56, 68),
    foot: Offset(60, 90),
  ),
  // 提踵
  '提踵': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(48, 38),
    hand: Offset(45, 51),
    hip: Offset(52, 48),
    knee: Offset(50, 68),
    foot: Offset(50, 88),
  ),
  // 核心抗伸展：平板支撑
  '核心抗伸展': const _Pose(
    head: Offset(23, 45),
    neck: Offset(29, 45),
    shoulder: Offset(35, 45),
    elbow: Offset(34, 52),
    hand: Offset(31, 54),
    hip: Offset(62, 45),
    knee: Offset(78, 45),
    foot: Offset(90, 47),
  ),
  // 核心抗旋转：帕洛夫推
  '核心抗旋转': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(46, 36),
    hand: Offset(42, 40),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 卷腹
  '卷腹': const _Pose(
    head: Offset(30, 38),
    neck: Offset(35, 42),
    shoulder: Offset(39, 46),
    elbow: Offset(42, 42),
    hand: Offset(44, 40),
    hip: Offset(58, 50),
    knee: Offset(70, 60),
    foot: Offset(77, 57),
  ),
  // 步态：跑/走
  '步态': const _Pose(
    head: Offset(56, 12),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(47, 33),
    hand: Offset(43, 40),
    hip: Offset(52, 48),
    knee: Offset(49, 64),
    foot: Offset(44, 72),
  ),
  // 周期：骑行/划船
  '周期': const _Pose(
    head: Offset(55, 16),
    neck: Offset(53, 23),
    shoulder: Offset(51, 30),
    elbow: Offset(45, 38),
    hand: Offset(44, 46),
    hip: Offset(54, 50),
    knee: Offset(58, 62),
    foot: Offset(64, 68),
    bench: true,
  ),
  // 低强度持续
  '低强度持续': const _Pose(
    head: Offset(56, 12),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(48, 36),
    hand: Offset(45, 44),
    hip: Offset(52, 48),
    knee: Offset(49, 66),
    foot: Offset(46, 86),
  ),
  // 间歇
  '间歇': const _Pose(
    head: Offset(56, 13),
    neck: Offset(54, 20),
    shoulder: Offset(52, 27),
    elbow: Offset(46, 32),
    hand: Offset(42, 39),
    hip: Offset(52, 48),
    knee: Offset(48, 63),
    foot: Offset(44, 71),
  ),
  // 动态活动度
  '动态活动度': const _Pose(
    head: Offset(56, 12),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(45, 34),
    hand: Offset(43, 43),
    hip: Offset(52, 48),
    knee: Offset(55, 66),
    foot: Offset(60, 82),
  ),
  // 静态拉伸
  '静态拉伸': const _Pose(
    head: Offset(56, 16),
    neck: Offset(54, 23),
    shoulder: Offset(51, 30),
    elbow: Offset(47, 36),
    hand: Offset(44, 56),
    hip: Offset(54, 50),
    knee: Offset(50, 70),
    foot: Offset(50, 91),
  ),
  // 筋膜放松
  '筋膜放松': const _Pose(
    head: Offset(26, 42),
    neck: Offset(32, 42),
    shoulder: Offset(38, 42),
    elbow: Offset(40, 37),
    hand: Offset(42, 33),
    hip: Offset(62, 44),
    knee: Offset(76, 46),
    foot: Offset(88, 50),
    bench: true,
  ),
  // 爆发：跳箱/跳深
  '爆发': const _Pose(
    head: Offset(54, 14),
    neck: Offset(52, 21),
    shoulder: Offset(50, 28),
    elbow: Offset(42, 34),
    hand: Offset(41, 42),
    hip: Offset(50, 52),
    knee: Offset(55, 70),
    foot: Offset(54, 90),
  ),
  // 旋转
  '旋转': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(45, 34),
    hand: Offset(41, 40),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 负重行走：农夫行走
  '负重行走': const _Pose(
    head: Offset(56, 11),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(49, 38),
    hand: Offset(46, 52),
    hip: Offset(52, 48),
    knee: Offset(50, 69),
    foot: Offset(50, 91),
  ),
  // 专项技术
  '专项技术': const _Pose(
    head: Offset(56, 12),
    neck: Offset(54, 19),
    shoulder: Offset(52, 26),
    elbow: Offset(45, 34),
    hand: Offset(41, 43),
    hip: Offset(52, 48),
    knee: Offset(49, 66),
    foot: Offset(45, 84),
  ),
};

class _ExerciseFigurePainter extends CustomPainter {
  _ExerciseFigurePainter({
    required this.pose,
    required this.color,
    required this.equipment,
    required this.backgroundColor,
  });

  final _Pose pose;
  final Color color;
  final String equipment;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != Colors.transparent) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = backgroundColor,
      );
    }

    // 留白后归一化到 0..1，再按画布缩放。
    final scale = size.shortestSide / 100.0;
    final dx = (size.width - 100.0 * scale) / 2;
    final dy = (size.height - 100.0 * scale) / 2;
    Offset pt(Offset p) => Offset(dx + p.dx * scale, dy + p.dy * scale);

    final limb = Paint()
      ..color = color
      ..strokeWidth = 4.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final joint = Paint()..color = color;

    // 地面
    if (!pose.bench) {
      canvas.drawLine(
        pt(Offset(14, 94)),
        pt(Offset(86, 94)),
        Paint()
          ..color = color.withValues(alpha: .16)
          ..strokeWidth = 1.6 * scale,
      );
    }

    // 卧具 / 座椅
    if (pose.bench) {
      final benchRect = Rect.fromLTWH(
        pt(const Offset(20, 42)).dx,
        pt(const Offset(20, 42)).dy,
        (86 - 20) * scale,
        5.5 * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(benchRect, Radius.circular(2.5 * scale)),
        Paint()..color = color.withValues(alpha: .18),
      );
    }

    // 器械（依据 equipment 关键字）
    _paintEquipment(canvas, size, pt, limb);

    // 腿：hip -> knee -> foot
    canvas.drawLine(pt(pose.hip), pt(pose.knee), limb);
    canvas.drawLine(pt(pose.knee), pt(pose.foot), limb);

    // 躯干：neck -> hip
    canvas.drawLine(pt(pose.neck), pt(pose.hip), limb);

    // 手臂：shoulder -> elbow -> hand
    canvas.drawLine(pt(pose.shoulder), pt(pose.elbow), limb);
    canvas.drawLine(pt(pose.elbow), pt(pose.hand), limb);

    // 头
    canvas.drawCircle(pt(pose.head), 6.0 * scale, joint);

    // 关节
    for (final j in [
      pose.shoulder,
      pose.elbow,
      pose.hip,
      pose.knee,
    ]) {
      canvas.drawCircle(pt(j), 2.4 * scale, joint);
    }
  }

  void _paintEquipment(
    Canvas canvas,
    Size size,
    Offset Function(Offset) pt,
    Paint limb,
  ) {
    final scale = size.shortestSide / 100.0;
    final hasBarbell = equipment.contains('杠铃') || equipment.contains('史密斯');
    final hasDumbbell = equipment.contains('哑铃') || equipment.contains('壶铃');
    final hasCable = equipment.contains('绳索') || equipment.contains('弹力带');
    final hasBar = equipment.contains('单杠');
    final hasMachine = equipment.contains('器械');

    if (hasBar) {
      canvas.drawLine(
        pt(const Offset(30, 14)),
        pt(const Offset(74, 14)),
        Paint()
          ..color = color.withValues(alpha: .55)
          ..strokeWidth = 3.2 * scale
          ..strokeCap = StrokeCap.round,
      );
    }

    if (hasCable) {
      canvas.drawLine(
        pt(pose.hand),
        pt(Offset(pose.hand.dx, 10)),
        Paint()
          ..color = color.withValues(alpha: .5)
          ..strokeWidth = 1.6 * scale
          ..strokeCap = StrokeCap.round,
      );
    }

    if (hasBarbell) {
      final barY = pose.hand.dy - 3;
      canvas.drawLine(
        pt(Offset(pose.hand.dx - 9, barY)),
        pt(Offset(pose.hand.dx + 9, barY)),
        Paint()
          ..color = color.withValues(alpha: .85)
          ..strokeWidth = 3.4 * scale
          ..strokeCap = StrokeCap.round,
      );
      for (final side in [-1.0, 1.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              pt(Offset(pose.hand.dx + side * 10 - 2, barY - 4)).dx,
              pt(Offset(pose.hand.dx + side * 10 - 2, barY - 4)).dy,
              4 * scale,
              8 * scale,
            ),
            Radius.circular(1.2 * scale),
          ),
          Paint()..color = color.withValues(alpha: .6),
        );
      }
    }

    if (hasDumbbell) {
      canvas.drawCircle(
        pt(pose.hand),
        4.2 * scale,
        Paint()..color = color.withValues(alpha: .85),
      );
    }

    if (hasMachine) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            pt(Offset(64, 46)).dx,
            pt(Offset(64, 46)).dy,
            14 * scale,
            34 * scale,
          ),
          Radius.circular(3 * scale),
        ),
        Paint()..color = color.withValues(alpha: .16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseFigurePainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.color != color ||
        oldDelegate.equipment != equipment ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
