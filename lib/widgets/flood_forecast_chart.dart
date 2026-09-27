import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:silag/models/hydrograph_model.dart';

class FloodForecastChart extends StatelessWidget {
  final HydrographModel hydrograph;

  const FloodForecastChart({super.key, required this.hydrograph});

  @override
  Widget build(BuildContext context) {
    if (hydrograph.points.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
          ),
        ),
      );
    }

    final splitIndex = hydrograph.points.indexWhere((p) => p.isForecast);
    final presentIndex = splitIndex > 0 ? splitIndex - 1 : hydrograph.points.length - 1;
    final totalIndex = hydrograph.points.length - 1;

    final xTickIndexes = [
      0,
      (totalIndex * 0.25).round(),
      presentIndex >= 0 ? presentIndex : (totalIndex * 0.5).round(),
      (totalIndex * 0.75).round(),
      totalIndex
    ];

    final xTickLabels = {
      xTickIndexes[0]: "-12 Hours",
      xTickIndexes[1]: "-6 Hours",
      xTickIndexes[2]: "Present",
      xTickIndexes[3]: "+6 Hours",
      xTickIndexes[4]: "+12 Hours",
    };

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final p in hydrograph.points) {
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }
    double yPadding = (maxY - minY) * 0.12;
    if (yPadding < 0.1) yPadding = 0.1;
    minY = (minY - yPadding).clamp(0.0, double.infinity);
    maxY = maxY + yPadding;

    List<FlSpot> recordedSpots = [];
    List<FlSpot> forecastSpots = [];

    for (int i = 0; i <= (splitIndex > 0 ? splitIndex : totalIndex); i++) {
      recordedSpots.add(FlSpot(i.toDouble(), hydrograph.points[i].value));
    }
    if (splitIndex > 0) {
      for (int i = splitIndex - 1; i < hydrograph.points.length; i++) {
        forecastSpots.add(FlSpot(i.toDouble(), hydrograph.points[i].value));
      }
    } else {
      for (int i = 0; i < hydrograph.points.length; i++) {
        if (hydrograph.points[i].isForecast) {
           forecastSpots.add(FlSpot(i.toDouble(), hydrograph.points[i].value));
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16224A),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Recorded', const Color(0xFF4A90E2)),
              const SizedBox(width: 20),
              _buildLegendItem('Forecast', const Color(0xFF4A90E2).withOpacity(0.5), isDashed: true),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: totalIndex.toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            '${value.toStringAsFixed(1)} ft',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (xTickLabels.containsKey(index)) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              xTickLabels[index]!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (recordedSpots.isNotEmpty)
                    LineChartBarData(
                      spots: recordedSpots,
                      isCurved: true,
                      color: const Color(0xFF4A90E2),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF4A90E2).withOpacity(0.15),
                      ),
                    ),
                  if (forecastSpots.isNotEmpty)
                    LineChartBarData(
                      spots: forecastSpots,
                      isCurved: true,
                      color: const Color(0xFF4A90E2).withOpacity(0.6),
                      barWidth: 3,
                      dashArray: [6, 5],
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF4A90E2).withOpacity(0.08),
                      ),
                    ),
                ],
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    if (presentIndex >= 0)
                      VerticalLine(
                        x: presentIndex.toDouble(),
                        color: Colors.white38,
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, top: -10),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                          labelResolver: (line) => 'NOW',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (hydrograph.predictedRiseFt != null && hydrograph.predictedRiseFt! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.5)),
                ),
                child: Text(
                  'Predicted rain-driven rise: ${hydrograph.predictedRiseFt!.toStringAsFixed(2)} ft',
                  style: const TextStyle(
                    color: Color(0xFF4A90E2),
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isDashed = false}) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: isDashed
                ? List.generate(
                    4,
                    (index) => Container(width: 3, height: 3, color: color),
                  )
                : [Container(width: 20, height: 3, color: color)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
