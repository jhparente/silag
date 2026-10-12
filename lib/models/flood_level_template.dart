import 'package:flutter/material.dart';

/// Represents one of the 7 flood water alert templates defined for SILAG,
/// plus baseline/normal for levels below 1.0 ft.
///
/// Palette specification:
/// - Level 1 FT — Advisory:
///     Text: sky-600 (#0284c7) / Dark Mode: sky-400 (#38bdf8)
///     Background: sky-50 (#f0f9ff) / Dark Mode: sky-900 (#0c4a6e with opacity)
/// - Level 2 FT — Rising:
///     Text: blue-600 (#2563eb) / Dark Mode: blue-400 (#60a5fa)
///     Background: blue-50 (#eff6ff) / Dark Mode: blue-900 (#1e3a8a with opacity)
/// - Level 3 FT — Warning:
///     Text: yellow-600 (#ca8a04) / Dark Mode: yellow-400 (#facc15)
///     Background: yellow-50 (#fefce8) / Dark Mode: yellow-900 (#713f12 with opacity)
/// - Level 4 FT — Alert:
///     Text: orange-600 (#ea580c) / Dark Mode: orange-400 (#fb923c)
///     Background: orange-50 (#fff7ed) / Dark Mode: orange-900 (#7c2d12 with opacity)
/// - Level 5 FT — Serious:
///     Text: red-500 (#ef4444) / Dark Mode: red-400 (#f87171)
///     Background: red-50 (#fef2f2) / Dark Mode: red-900 (#7f1d1d with opacity)
/// - Level 6 FT — Severe:
///     Text: red-700 (#b91c1c) / Dark Mode: red-300 (#fca5a5)
///     Background: red-100 (#fee2e2) / Dark Mode: red-900 (#7f1d1d with opacity)
/// - Level 7 FT — Critical:
///     Text: rose-800 (#9f1239) / Dark Mode: rose-200 (#fecdd3)
///     Background: rose-100 (#ffe4e6) / Dark Mode: rose-900 (#881337 with opacity)
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

  /// Level 0: Baseline / Normal (< 1.00 ft)
  static const level0 = FloodLevelTemplate(
    level: 0,
    name: 'Normal',
    fullBadge: 'Normal — Baseline',
    rangeDescription: '0.00 – 0.99 ft',
    humanImpact: 'Ground / Ankle clearance. Zero to minimal water accumulation.',
    advisoryText: 'Water levels are within normal baseline range. Normal passage permitted.',
    textColorLight: Color(0xFF0284C7),
    textColorDark: Color(0xFF38BDF8),
    backgroundColorLight: Color(0xFFF0F9FF),
    backgroundColorDark: Color(0xFF0C4A6E),
    waterColor: Color(0xFF0284C7),
    waterDeepColor: Color(0xFF075985),
    waterCrestColor: Color(0xFF7DD3FC),
    glowColor: Color(0xFF0C4A6E),
  );

  /// Level 1: Advisory (1.00 – 1.99 ft)
  static const level1 = FloodLevelTemplate(
    level: 1,
    name: 'Advisory',
    fullBadge: 'Level 1 FT — Advisory',
    rangeDescription: '1.00 – 1.99 ft (0.30 – 0.60 m)',
    humanImpact: 'Ankle to Shin depth. Passable for all vehicles with caution.',
    advisoryText: 'Low flood advisory in effect. Monitor local weather bulletins and creek levels.',
    textColorLight: Color(0xFF0284C7),
    textColorDark: Color(0xFF38BDF8),
    backgroundColorLight: Color(0xFFF0F9FF),
    backgroundColorDark: Color(0xFF0C4A6E),
    waterColor: Color(0xFF0284C7),
    waterDeepColor: Color(0xFF075985),
    waterCrestColor: Color(0xFF38BDF8),
    glowColor: Color(0xFF0C4A6E),
  );

  /// Level 2: Rising (2.00 – 2.99 ft)
  static const level2 = FloodLevelTemplate(
    level: 2,
    name: 'Rising',
    fullBadge: 'Level 2 FT — Rising',
    rangeDescription: '2.00 – 2.99 ft (0.61 – 0.91 m)',
    humanImpact: 'Knee depth. Hazardous for light sedans and small motorcycles.',
    advisoryText: 'Water is steadily rising. Low-lying residents should prepare flood barriers.',
    textColorLight: Color(0xFF2563EB),
    textColorDark: Color(0xFF60A5FA),
    backgroundColorLight: Color(0xFFEFF6FF),
    backgroundColorDark: Color(0xFF1E3A8A),
    waterColor: Color(0xFF2563EB),
    waterDeepColor: Color(0xFF1E40AF),
    waterCrestColor: Color(0xFF60A5FA),
    glowColor: Color(0xFF1E3A8A),
  );

  /// Level 3: Warning (3.00 – 3.99 ft)
  static const level3 = FloodLevelTemplate(
    level: 3,
    name: 'Warning',
    fullBadge: 'Level 3 FT — Warning',
    rangeDescription: '3.00 – 3.99 ft (0.91 – 1.21 m)',
    humanImpact: 'Waist depth. Impassable for light vehicles. Strong water flow.',
    advisoryText: 'Flood warning! Move electrical appliances and valuables to upper floors.',
    textColorLight: Color(0xFFCA8A04),
    textColorDark: Color(0xFFFACC15),
    backgroundColorLight: Color(0xFFFEFCE8),
    backgroundColorDark: Color(0xFF713F12),
    waterColor: Color(0xFFCA8A04),
    waterDeepColor: Color(0xFF854D0E),
    waterCrestColor: Color(0xFFFACC15),
    glowColor: Color(0xFF713F12),
  );

  /// Level 4: Alert (4.00 – 4.99 ft)
  static const level4 = FloodLevelTemplate(
    level: 4,
    name: 'Alert',
    fullBadge: 'Level 4 FT — Alert',
    rangeDescription: '4.00 – 4.99 ft (1.22 – 1.52 m)',
    humanImpact: 'Chest depth. Impassable for all standard vehicles. High hazard.',
    advisoryText: 'Flood alert! Preemptive evacuation underway for vulnerable sectors.',
    textColorLight: Color(0xFFEA580C),
    textColorDark: Color(0xFFFB923C),
    backgroundColorLight: Color(0xFFFFF7ED),
    backgroundColorDark: Color(0xFF7C2D12),
    waterColor: Color(0xFFEA580C),
    waterDeepColor: Color(0xFF9A3412),
    waterCrestColor: Color(0xFFFB923C),
    glowColor: Color(0xFF7C2D12),
  );

  /// Level 5: Serious (5.00 – 5.99 ft)
  static const level5 = FloodLevelTemplate(
    level: 5,
    name: 'Serious',
    fullBadge: 'Level 5 FT — Serious',
    rangeDescription: '5.00 – 5.99 ft (1.52 – 1.82 m)',
    humanImpact: 'Neck / Head level. Dangerous current. Life hazard.',
    advisoryText: 'Serious flood danger! Mandatory evacuation in affected sectors.',
    textColorLight: Color(0xFFEF4444),
    textColorDark: Color(0xFFF87171),
    backgroundColorLight: Color(0xFFFEF2F2),
    backgroundColorDark: Color(0xFF7F1D1D),
    waterColor: Color(0xFFEF4444),
    waterDeepColor: Color(0xFF991B1B),
    waterCrestColor: Color(0xFFF87171),
    glowColor: Color(0xFF7F1D1D),
  );

  /// Level 6: Severe (6.00 – 6.99 ft)
  static const level6 = FloodLevelTemplate(
    level: 6,
    name: 'Severe',
    fullBadge: 'Level 6 FT — Severe',
    rangeDescription: '6.00 – 6.99 ft (1.83 – 2.13 m)',
    humanImpact: 'Overhead flood depth. Structures submerged. Extreme currents.',
    advisoryText: 'Severe flood emergency! Seek immediate rescue or highest elevation.',
    textColorLight: Color(0xFFB91C1C),
    textColorDark: Color(0xFFFCA5A5),
    backgroundColorLight: Color(0xFFFEE2E2),
    backgroundColorDark: Color(0xFF7F1D1D),
    waterColor: Color(0xFFB91C1C),
    waterDeepColor: Color(0xFF7F1D1D),
    waterCrestColor: Color(0xFFFCA5A5),
    glowColor: Color(0xFF7F1D1D),
  );

  /// Level 7: Critical (>= 7.00 ft)
  static const level7 = FloodLevelTemplate(
    level: 7,
    name: 'Critical',
    fullBadge: 'Level 7 FT — Critical',
    rangeDescription: '7.00+ ft (2.13+ m)',
    humanImpact: 'Catastrophic submergence. Sensor clearance threshold breached.',
    advisoryText: 'Critical catastrophic flood! Full emergency mobilization and rescue.',
    textColorLight: Color(0xFF9F1239),
    textColorDark: Color(0xFFFECDD3),
    backgroundColorLight: Color(0xFFFFE4E6),
    backgroundColorDark: Color(0xFF881337),
    waterColor: Color(0xFF9F1239),
    waterDeepColor: Color(0xFF4C0519),
    waterCrestColor: Color(0xFFFECDD3),
    glowColor: Color(0xFF881337),
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
