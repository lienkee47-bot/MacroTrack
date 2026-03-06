import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);

    if (user == null) {
      return const Center(child: Text("Please log in"));
    }

    String dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              'Good morning, ${user.displayName ?? 'User'}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DAILY STATUS',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: db.getUserTargets(user.uid),
              builder: (context, targetSnap) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: db.getDailyLog(user.uid, dateStr),
                  builder: (context, logSnap) {
                    int targetKcal = 2000, targetProt = 150, targetCarb = 200, targetFat = 65;
                    int consKcal = 0, consProt = 0, consCarb = 0, consFat = 0;

                    if (targetSnap.hasData && targetSnap.data!.exists) {
                      var data = targetSnap.data!.data() as Map<String, dynamic>?;
                      var targets = data?['dailyTargets'] ?? {};
                      targetKcal = (targets['kcal'] as num? ?? 2000).toInt();
                      targetProt = (targets['protein'] as num? ?? 150).toInt();
                      targetCarb = (targets['carbs'] as num? ?? 200).toInt();
                      targetFat = (targets['fat'] as num? ?? 65).toInt();
                    }

                    if (logSnap.hasData && logSnap.data!.exists) {
                      var logData = logSnap.data!.data() as Map<String, dynamic>? ?? {};
                      for (var meal in ['Breakfast', 'Lunch', 'Dinner', 'Snacks']) {
                        if (logData[meal] != null) {
                          for (var food in logData[meal]) {
                            consKcal += (food['kcal'] as num? ?? 0).toInt();
                            consProt += (food['protein'] as num? ?? 0).toInt();
                            consCarb += (food['carbs'] as num? ?? 0).toInt();
                            consFat += (food['fat'] as num? ?? 0).toInt();
                          }
                        }
                      }
                    }

                    return _buildDailyStatusCard(
                      targetKcal: targetKcal, consumedKcal: consKcal,
                      targetProt: targetProt, consumedProt: consProt,
                      targetCarb: targetCarb, consumedCarb: consCarb,
                      targetFat: targetFat, consumedFat: consFat,
                    );
                  }
                );
              }
            ),
            const SizedBox(height: 24),
            const Text(
              '7-DAY TREND',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildTrendCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildTopFoodCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildDistributionCard()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyStatusCard({
    required int targetKcal, required int consumedKcal,
    required int targetProt, required int consumedProt,
    required int targetCarb, required int consumedCarb,
    required int targetFat, required int consumedFat,
  }) {
    int leftKcal = targetKcal - consumedKcal;
    double progress = targetKcal > 0 ? consumedKcal / targetKcal : 0;
    progress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: leftKcal < 0 ? 'Over' : '${leftKcal.abs()}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: leftKcal < 0 ? Colors.red : Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: leftKcal < 0 ? ' goal!' : ' kcal left',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'of $targetKcal kcal goal',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(
                height: 64,
                width: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF006666),
                      strokeWidth: 8,
                    ),
                    const Center(
                      child: Icon(Icons.local_fire_department,
                          color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildMacroBar('Protein', consumedProt, targetProt, const Color(0xFFFF6700)),
          const SizedBox(height: 12),
          _buildMacroBar('Carbs', consumedCarb, targetCarb, const Color(0xFF006666)),
          const SizedBox(height: 12),
          _buildMacroBar('Fats', consumedFat, targetFat, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, int current, int total, Color color) {
    double progress = total > 0 ? current / total : 0;
    progress = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${current}g / ${total}g',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildTrendCard() {
    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 1000,
          maxY: 3000,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1000,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withValues(alpha: 0.2),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(color: Colors.grey, fontSize: 10);
                  String text;
                  switch (value.toInt()) {
                    case 0:
                      text = 'M';
                      break;
                    case 1:
                      text = 'T';
                      break;
                    case 2:
                      text = 'W';
                      break;
                    case 3:
                      text = 'T';
                      break;
                    case 4:
                      text = 'F';
                      break;
                    case 5:
                      text = 'S';
                      break;
                    case 6:
                      text = 'S';
                      break;
                    default:
                      text = '';
                      break;
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(text, style: style),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1000,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value / 1000).toInt()}k',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 2100),
                FlSpot(1, 2300),
                FlSpot(2, 1800),
                FlSpot(3, 2400),
                FlSpot(4, 2800),
                FlSpot(5, 2500),
                FlSpot(6, 2100),
              ],
              isCurved: true,
              color: const Color(0xFF006666),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF006666).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFoodCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP FOOD',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E6), // Light orange
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, color: Color(0xFFFF6700)),
          ),
          const SizedBox(height: 12),
          const Text('Chicken Breast',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('1.2 kg this week',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDistributionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISTRIBUTION',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              height: 60,
              width: 60,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 20,
                  sections: [
                    PieChartSectionData(
                      color: const Color(0xFFFF6700),
                      value: 40,
                      title: '',
                      radius: 8,
                    ),
                    PieChartSectionData(
                      color: const Color(0xFF006666),
                      value: 40,
                      title: '',
                      radius: 8,
                    ),
                    PieChartSectionData(
                      color: Colors.amber,
                      value: 20,
                      title: '',
                      radius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: Color(0xFFFF6700), size: 8),
              SizedBox(width: 4),
              Icon(Icons.circle, color: Color(0xFF006666), size: 8),
              SizedBox(width: 4),
              Icon(Icons.circle, color: Colors.amber, size: 8),
            ],
          ),
        ],
      ),
    );
  }
}
