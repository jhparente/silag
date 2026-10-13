import 'package:flutter/material.dart';

/// Represents one of the 7 flood water alert templates defined for SILAG,
/// plus baseline/normal for levels below 1.0 ft.
///
/// Palette specification (matching home & sensor list 7 thresholds):
/// - Level 0: Safe (< 1.00 ft) — Green (#00E676 / greenAccent)
/// - Level 1: Low (1.00 – 1.99 ft) — Amber/Yellow (#FFC107)
/// - Level 2: High (2.00 – 2.99 ft) — Orange (#FF9800)
/// - Level 3: Critical (3.00 – 3.99 ft) — Bright Red (#F44336)
/// - Level 4: Severe (4.00 – 4.99 ft) — Dark Red (#B71C1C)
/// - Level 5: Extreme (5.00 – 5.99 ft) — Purple (#9C27B0)
/// - Level 6: Dangerous (6.00 – 6.99 ft) — Deep Purple (#311B92)
/// - Level 7: Catastrophic (≥ 7.00 ft) — Black (#121212)
class FloodLevelTemplate {
  final int level;
  final String name;
  final String fullBadge;
  final String rangeDescription;
  final String humanImpact;
  final String advisoryText;

  // Text Colors
  final Color textColorLight;
  final Color textColorDark;

  // Background Colors
  final Color backgroundColorLight;
  final Color backgroundColorDark;

  // Water & Wave Colors
  final Color waterColor;
  final Color waterDeepColor;
  final Color waterCrestColor;

  // Ambient backdrop glow
  final Color glowColor;

  const FloodLevelTemplate({
    required this.level,
    required this.name,
    required this.fullBadge,
    required this.rangeDescription,
    required this.humanImpact,
    required this.advisoryText,
    required this.textColorLight,
    required this.textColorDark,
    required this.backgroundColorLight,
    required this.backgroundColorDark,
    required this.waterColor,
    required this.waterDeepColor,
    required this.waterCrestColor,
    required this.glowColor,
  });

  /// Level 0: Baseline / Safe (< 1.00 ft)
  static const level0 = FloodLevelTemplate(
    level: 0,
    name: 'Safe',
    fullBadge: 'Safe — Normal Baseline',
    rangeDescription: '0.00 – 0.99 ft',
    humanImpact: 'Ground / Ankle clearance. Zero to minimal water accumulation.',
    advisoryText: 'Water levels are within normal safe range. Normal passage permitted.',
    textColorLight: Color(0xFF00E676),
    textColorDark: Color(0xFF69F0AE),
    backgroundColorLight: Color(0xFFE8FDF3),
    backgroundColorDark: Color(0xFF00381E),
    waterColor: Color(0xFF00E676),
    waterDeepColor: Color(0xFF00C853),
    waterCrestColor: Color(0xFFB9F6CA),
    glowColor: Color(0xFF00E676),
  );

  /// Level 1: Low (1.00 – 1.99 ft)
  static const level1 = FloodLevelTemplate(
    level: 1,
    name: 'Low',
    fullBadge: 'Level 1 FT — Low',
    rangeDescription: '1.00 – 1.99 ft (0.30 – 0.60 m)',
    humanImpact: 'Ankle to Shin depth. Passable for all vehicles with caution.',
    advisoryText: 'Low flood advisory in effect. Monitor local weather bulletins and creek levels.',
    textColorLight: Color(0xFFFFC107),
    textColorDark: Color(0xFFFFD54F),
    backgroundColorLight: Color(0xFFFFFDE7),
    backgroundColorDark: Color(0xFF3E2723),
    waterColor: Color(0xFFFFC107),
    waterDeepColor: Color(0xFFFFA000),
    waterCrestColor: Color(0xFFFFE082),
    glowColor: Color(0xFFFFC107),
  );

  /// Level 2: High (2.00 – 2.99 ft)
  static const level2 = FloodLevelTemplate(
    level: 2,
    name: 'High',
    fullBadge: 'Level 2 FT — High',
    rangeDescription: '2.00 – 2.99 ft (0.61 – 0.91 m)',
    humanImpact: 'Knee depth. Hazardous for light sedans and small motorcycles.',
    advisoryText: 'Water is steadily rising. Low-lying residents should prepare flood barriers.',
    textColorLight: Color(0xFFFF9800),
    textColorDark: Color(0xFFFFB74D),
    backgroundColorLight: Color(0xFFFFF3E0),
    backgroundColorDark: Color(0xFFE65100),
    waterColor: Color(0xFFFF9800),
    waterDeepColor: Color(0xFFF57C00),
    waterCrestColor: Color(0xFFFFCC80),
    glowColor: Color(0xFFFF9800),
  );

  /// Level 3: Critical (3.00 – 3.99 ft)
  static const level3 = FloodLevelTemplate(
    level: 3,
    name: 'Critical',
    fullBadge: 'Level 3 FT — Critical',
    rangeDescription: '3.00 – 3.99 ft (0.91 – 1.21 m)',
    humanImpact: 'Waist depth. Impassable for light vehicles. Strong water flow.',
    advisoryText: 'Flood warning! Move electrical appliances and valuables to upper floors.',
    textColorLight: Color(0xFFF44336),
    textColorDark: Color(0xFFE57373),
    backgroundColorLight: Color(0xFFFFEBEE),
    backgroundColorDark: Color(0xFFB71C1C),
    waterColor: Color(0xFFF44336),
    waterDeepColor: Color(0xFFD32F2F),
    waterCrestColor: Color(0xFFEF9A9A),
    glowColor: Color(0xFFF44336),
  );

  /// Level 4: Severe (4.00 – 4.99 ft)
  static const level4 = FloodLevelTemplate(
    level: 4,
    name: 'Severe',
    fullBadge: 'Level 4 FT — Severe',
    rangeDescription: '4.00 – 4.99 ft (1.22 – 1.52 m)',
    humanImpact: 'Chest depth. Impassable for all standard vehicles. High hazard.',
    advisoryText: 'Flood alert! Preemptive evacuation underway for vulnerable sectors.',
    textColorLight: Color(0xFFB71C1C),
    textColorDark: Color(0xFFEF5350),
    backgroundColorLight: Color(0xFFFFCDD2),
    backgroundColorDark: Color(0xFF4A0E0E),
    waterColor: Color(0xFFB71C1C),
    waterDeepColor: Color(0xFF880E4F),
    waterCrestColor: Color(0xFFE57373),
    glowColor: Color(0xFFB71C1C),
  );

  /// Level 5: Extreme (5.00 – 5.99 ft)
  static const level5 = FloodLevelTemplate(
    level: 5,
    name: 'Extreme',
    fullBadge: 'Level 5 FT — Extreme',
    rangeDescription: '5.00 – 5.99 ft (1.52 – 1.82 m)',
    humanImpact: 'Neck / Head level. Dangerous current. Life hazard.',
    advisoryText: 'Extreme flood danger! Mandatory evacuation in affected sectors.',
    textColorLight: Color(0xFF9C27B0),
    textColorDark: Color(0xFFBA68C8),
    backgroundColorLight: Color(0xFFF3E5F5),
    backgroundColorDark: Color(0xFF4A148C),
    waterColor: Color(0xFF9C27B0),
    waterDeepColor: Color(0xFF7B1FA2),
    waterCrestColor: Color(0xFFCE93D8),
    glowColor: Color(0xFF9C27B0),
  );

  /// Level 6: Dangerous (6.00 – 6.99 ft)
  static const level6 = FloodLevelTemplate(
    level: 6,
    name: 'Dangerous',
    fullBadge: 'Level 6 FT — Dangerous',
    rangeDescription: '6.00 – 6.99 ft (1.83 – 2.13 m)',
    humanImpact: 'Overhead flood depth. Structures submerged. Extreme currents.',
    advisoryText: 'Dangerous flood emergency! Seek immediate rescue or highest elevation.',
    textColorLight: Color(0xFF311B92),
    textColorDark: Color(0xFF7E57C2),
    backgroundColorLight: Color(0xFFEDE7F6),
    backgroundColorDark: Color(0xFF1A237E),
    waterColor: Color(0xFF311B92),
    waterDeepColor: Color(0xFF1A237E),
    waterCrestColor: Color(0xFF9575CD),
    glowColor: Color(0xFF311B92),
  );

  /// Level 7: Catastrophic (>= 7.00 ft)
  static const level7 = FloodLevelTemplate(
    level: 7,
    name: 'Catastrophic',
    fullBadge: 'Level 7 FT — Catastrophic',
    rangeDescription: '7.00+ ft (2.13+ m)',
    humanImpact: 'Catastrophic submergence. Sensor clearance threshold breached.',
    advisoryText: 'Catastrophic flood disaster! Full emergency mobilization and rescue.',
    textColorLight: Color(0xFF121212),
    textColorDark: Color(0xFF424242),
    backgroundColorLight: Color(0xFFE0E0E0),
    backgroundColorDark: Color(0xFF000000),
    waterColor: Color(0xFF121212),
    waterDeepColor: Color(0xFF000000),
    waterCrestColor: Color(0xFF616161),
    glowColor: Color(0xFF121212),
  );

  /// Returns the corresponding [FloodLevelTemplate] for a given water level in feet.
  static FloodLevelTemplate fromWaterLevel(double waterLevelFt) {
    if (waterLevelFt >= 7.0) return level7;
    if (waterLevelFt >= 6.0) return level6;
    if (waterLevelFt >= 5.0) return level5;
    if (waterLevelFt >= 4.0) return level4;
    if (waterLevelFt >= 3.0) return level3;
    if (waterLevelFt >= 2.0) return level2;
    if (waterLevelFt >= 1.0) return level1;
    return level0;
  }

  /// Returns the corresponding [FloodLevelTemplate] by integer level (1..7, or 0).
  static FloodLevelTemplate fromLevelNumber(int level) {
    switch (level) {
      case 1:
        return level1;
      case 2:
        return level2;
      case 3:
        return level3;
      case 4:
        return level4;
      case 5:
        return level5;
      case 6:
        return level6;
      case 7:
        return level7;
      default:
        return level0;
    }
  }

  /// List of all official levels 1 through 7
  static const List<FloodLevelTemplate> allOfficialLevels = [
    level1,
    level2,
    level3,
    level4,
    level5,
    level6,
    level7,
  ];
}
