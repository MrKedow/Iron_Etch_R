import 'dart:math' as math;

enum IronSex { male, female, unspecified }

class IronProfile {
  IronProfile._();

  static final IronProfile instance = IronProfile._();

  static const Map<String, double> travelFactors = {
    '肩': .235,
    '背': .250,
    '腿': .290,
    '胸': .255,
    '核心': .150,
    '手臂': .205,
    '前臂': .135,
    '臀': .275,
    '小腿': .190,
    '全身': .265,
  };

  static const Map<String, double> weightedBodyShares = {
    '肩': .12,
    '背': .18,
    '腿': .38,
    '胸': .14,
    '核心': .32,
    '手臂': .06,
    '前臂': .04,
    '臀': .32,
    '小腿': .30,
    '全身': .35,
  };

  static const Map<String, double> bodyweightShares = {
    '肩': .50,
    '背': .92,
    '腿': .82,
    '胸': .64,
    '核心': .56,
    '手臂': .62,
    '前臂': .18,
    '臀': .72,
    '小腿': .68,
    '全身': .78,
  };

  double bodyWeightKg = 70;
  double? heightCm;
  int? age;
  IronSex sex = IronSex.unspecified;
  double? bodyFatPercent;
  int? restingHeartRate;
  double? trainingYears;
  String experience = '进阶';
  String goal = '增肌';

  double get effectiveHeightCm => heightCm ?? 170;
  double get heightM => effectiveHeightCm / 100;
  int get effectiveAge => age ?? 30;
  int get effectiveRestingHeartRate => restingHeartRate ?? 65;
  String get sexLabel => switch (sex) {
        IronSex.male => '男',
        IronSex.female => '女',
        IronSex.unspecified => '未填写',
      };

  double get effectiveTrainingYears {
    if (trainingYears != null) return trainingYears!;
    return switch (experience) {
      '新手' => 0.5,
      '高阶' => 5,
      _ => 2,
    };
  }

  int get filledFieldCount {
    var count = 1;
    if (heightCm != null) count++;
    if (age != null) count++;
    if (sex != IronSex.unspecified) count++;
    if (bodyFatPercent != null) count++;
    if (restingHeartRate != null) count++;
    if (trainingYears != null) count++;
    count++;
    return count;
  }

  int get totalFieldCount => 8;

  double get completeness => filledFieldCount / totalFieldCount;

  double get leanMassKg {
    if (bodyFatPercent == null) return bodyWeightKg;
    return bodyWeightKg * (1 - bodyFatPercent!.clamp(3, 60) / 100);
  }

  double get basalMetabolicKcal {
    if (bodyFatPercent != null) {
      return 370 + 21.6 * leanMassKg;
    }
    final sexOffset = switch (sex) {
      IronSex.male => 5.0,
      IronSex.female => -161.0,
      IronSex.unspecified => -78.0,
    };
    return 10 * bodyWeightKg +
        6.25 * effectiveHeightCm -
        5 * effectiveAge +
        sexOffset;
  }

  double get maximumHeartRate => 208 - .7 * effectiveAge;

  void update({
    double? bodyWeightKg,
    double? heightCm,
    int? age,
    IronSex? sex,
    double? bodyFatPercent,
    int? restingHeartRate,
    double? trainingYears,
    String? experience,
    String? goal,
    bool clearHeight = false,
    bool clearAge = false,
    bool clearBodyFat = false,
    bool clearRestingHeartRate = false,
    bool clearTrainingYears = false,
  }) {
    if (bodyWeightKg != null) this.bodyWeightKg = bodyWeightKg;
    if (clearHeight) {
      this.heightCm = null;
    } else if (heightCm != null) {
      this.heightCm = heightCm;
    }
    if (clearAge) {
      this.age = null;
    } else if (age != null) {
      this.age = age;
    }
    if (sex != null) this.sex = sex;
    if (clearBodyFat) {
      this.bodyFatPercent = null;
    } else if (bodyFatPercent != null) {
      this.bodyFatPercent = bodyFatPercent;
    }
    if (clearRestingHeartRate) {
      this.restingHeartRate = null;
    } else if (restingHeartRate != null) {
      this.restingHeartRate = restingHeartRate;
    }
    if (clearTrainingYears) {
      this.trainingYears = null;
    } else if (trainingYears != null) {
      this.trainingYears = trainingYears;
    }
    if (experience != null) this.experience = experience;
    if (goal != null) this.goal = goal;
  }

  double estimateMechanicalWork({
    required String part,
    required double weight,
    required int sets,
    required int reps,
  }) {
    if (sets <= 0 || reps <= 0) return 0;
    final travel = heightM * (travelFactors[part] ?? .25);
    final isBodyweight = weight <= .01;
    final share = isBodyweight
        ? (bodyweightShares[part] ?? .65)
        : (weightedBodyShares[part] ?? .15);
    final effectiveLoad = math.max(0.0, weight + bodyWeightKg * share);
    return effectiveLoad * 9.80665 * travel * sets * reps;
  }

  double estimateStrengthCalories({
    required String part,
    required double weight,
    required int sets,
    required int reps,
    double durationMinutes = 0,
    int restSeconds = 90,
  }) {
    if (sets <= 0 || reps <= 0) return 0;
    final estimatedMinutes = sets * (reps * 3.0 + restSeconds) / 60;
    final minutes = durationMinutes > 0 ? durationMinutes : estimatedMinutes;
    final relativeLoad = weight <= .01 ? .42 : weight / (bodyWeightKg * 1.35);
    final experienceBoost = (effectiveTrainingYears / 20).clamp(0.0, .10);
    final partBoost = part == '腿' || part == '全身' || part == '背' ? .04 : 0.0;
    final intensity =
        (relativeLoad + experienceBoost + partBoost).clamp(.42, .88);
    final heartRate = (effectiveRestingHeartRate +
            intensity * (maximumHeartRate - effectiveRestingHeartRate))
        .clamp(70.0, maximumHeartRate);
    final male = (-55.0969 +
            0.6309 * heartRate +
            0.1988 * bodyWeightKg +
            0.2017 * effectiveAge) /
        4.184;
    final female = (-20.4022 +
            0.4472 * heartRate -
            0.1263 * bodyWeightKg +
            0.074 * effectiveAge) /
        4.184;
    final kcalPerMinute = switch (sex) {
      IronSex.male => male,
      IronSex.female => female,
      IronSex.unspecified => (male + female) / 2,
    };
    return math.max(0, kcalPerMinute) * minutes;
  }

  double estimateCardioCalories({
    required double met,
    required double minutes,
    double? bodyWeightOverride,
  }) {
    if (minutes <= 0) return 0;
    final weight = bodyWeightOverride ?? bodyWeightKg;
    return math.max(0, met) * 3.5 * weight / 200 * minutes;
  }
}
