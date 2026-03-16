import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<DateTime> _last7Days = [];
  final Map<String, List<Map<String, dynamic>>> _weeklyLogs = {};
  final List<StreamSubscription> _subscriptions = [];
  String _pieChartFilter = 'kcal';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      _last7Days.add(now.subtract(Duration(days: i)));
    }
  }

  void _setupSubscriptions(String uid, FirestoreService db) {
    if (_subscriptions.isNotEmpty) return;

    for (var date in _last7Days) {
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      var sub = db.getDailyLogEntries(uid, dateStr).listen((snapshot) {
        List<Map<String, dynamic>> dayLogs = [];
        for (var doc in snapshot.docs) {
          dayLogs.add(doc.data() as Map<String, dynamic>);
        }
        if (mounted) {
          setState(() {
            _weeklyLogs[dateStr] = dayLogs;
          });
        }
      });
      _subscriptions.add(sub);
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);

    if (user == null) {
      return const Center(child: Text("Please log in"));
    }

    _setupSubscriptions(user.uid, db);

    String dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: StreamBuilder<DocumentSnapshot>(
          stream: db.getUserProfile(user.uid),
          builder: (context, profileSnap) {
            String userName = user.displayName ?? 'User';
            if (profileSnap.hasData && profileSnap.data!.exists) {
              var data = profileSnap.data!.data() as Map<String, dynamic>?;
              userName = data?['name'] ?? userName;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Good morning, $userName',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            );
          }
        ),
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
                int targetKcal = 2000, targetProt = 150, targetCarb = 200, targetFat = 65;
                if (targetSnap.hasData && targetSnap.data!.exists) {
                  var data = targetSnap.data!.data() as Map<String, dynamic>?;
                  var targets = data?['dailyTargets'] ?? {};
                  targetKcal = (targets['kcal'] as num? ?? 2000).toInt();
                  targetProt = (targets['protein'] as num? ?? 150).toInt();
                  targetCarb = (targets['carbs'] as num? ?? 200).toInt();
                  targetFat = (targets['fat'] as num? ?? 65).toInt();
                }

                int consKcal = 0, consProt = 0, consCarb = 0, consFat = 0;
                var todayLogs = _weeklyLogs[dateStr] ?? [];
                for (var food in todayLogs) {
                  consKcal += (food['kcal'] as num? ?? 0).toInt();
                  consProt += (food['protein'] as num? ?? 0).toInt();
                  consCarb += (food['carbs'] as num? ?? 0).toInt();
                  consFat += (food['fat'] as num? ?? 0).toInt();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDailyStatusCard(
                      targetKcal: targetKcal, consumedKcal: consKcal,
                      targetProt: targetProt, consumedProt: consProt,
                      targetCarb: targetCarb, consumedCarb: consCarb,
                      targetFat: targetFat, consumedFat: consFat,
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
                    _buildTrendCard(targetKcal),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildDistributionCard()),
                      ],
                    ),
                  ],
                );
              }
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
                          color: Color(0xFFFF6700)),
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

  Widget _buildTrendCard(int targetKcal) {
    List<FlSpot> spots = [];
    double maxY = targetKcal.toDouble() + 500;
    
    for (int i = 0; i < _last7Days.length; i++) {
        String dateStr = DateFormat('yyyy-MM-dd').format(_last7Days[i]);
        var dayLogs = _weeklyLogs[dateStr] ?? [];
        double dailyKcal = 0;
        for (var log in dayLogs) {
           dailyKcal += (log['kcal'] as num? ?? 0).toDouble();
        }
        if (dailyKcal > maxY) maxY = dailyKcal + 500;
        spots.add(FlSpot(i.toDouble(), dailyKcal));
    }

    return Container(
      height: 230,
      padding: const EdgeInsets.only(top: 16, right: 20, left: 10, bottom: 10),
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
          const Padding(
            padding: EdgeInsets.only(left: 32),
            child: Text('Calorie (kcal)', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 2000 ? 2000 : maxY,
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
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: targetKcal.toDouble(),
                color: const Color(0xFFFF6700),
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
            ],
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
                  if (value.toInt() < 0 || value.toInt() >= _last7Days.length) return const SizedBox();
                  String text = DateFormat('d-MMM').format(_last7Days[value.toInt()]);
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
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
              spots: spots,
              isCurved: true,
              color: const Color(0xFF006666),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFb2d8d8).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard() {
    Map<String, double> totals = {
      'Breakfast': 0,
      'Lunch': 0,
      'Dinner': 0,
      'Snacks': 0,
    };

    double totalMetric = 0;

    for (var dateLogs in _weeklyLogs.values) {
      for (var log in dateLogs) {
        String meal = log['mealType'] as String? ?? '';
        if (totals.containsKey(meal)) {
           double val = (log[_pieChartFilter] as num? ?? 0).toDouble();
           totals[meal] = totals[meal]! + val;
           totalMetric += val;
        }
      }
    }

    double bPct = totalMetric > 0 ? (totals['Breakfast']! / totalMetric) * 100 : 0;
    double lPct = totalMetric > 0 ? (totals['Lunch']! / totalMetric) * 100 : 0;
    double dPct = totalMetric > 0 ? (totals['Dinner']! / totalMetric) * 100 : 0;
    double sPct = totalMetric > 0 ? (totals['Snacks']! / totalMetric) * 100 : 0;

    List<PieChartSectionData> sections = [];
    if (totalMetric == 0) {
      sections = [PieChartSectionData(color: Colors.grey[200]!, value: 100, title: '', radius: 16)];
    } else {
      if (bPct > 0) sections.add(PieChartSectionData(color: const Color(0xFFFF6700), value: bPct, title: '${bPct.toInt()}%', radius: 16, titlePositionPercentageOffset: 2.2, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)));
      if (lPct > 0) sections.add(PieChartSectionData(color: const Color(0xFFFFC100), value: lPct, title: '${lPct.toInt()}%', radius: 16, titlePositionPercentageOffset: 2.2, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)));
      if (dPct > 0) sections.add(PieChartSectionData(color: const Color(0xFF006666), value: dPct, title: '${dPct.toInt()}%', radius: 16, titlePositionPercentageOffset: 2.2, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)));
      if (sPct > 0) sections.add(PieChartSectionData(color: const Color(0xFFb2d8d8), value: sPct, title: '${sPct.toInt()}%', radius: 16, titlePositionPercentageOffset: 2.2, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)));
    }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MACRO DISTRIBUTION',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6700),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButton<String>(
                  value: _pieChartFilter,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                  underline: const SizedBox(),
                  isDense: true,
                  dropdownColor: Colors.white,
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      {'value': 'kcal', 'label': 'Kcal'},
                      {'value': 'protein', 'label': 'Protein'},
                      {'value': 'carbs', 'label': 'Carbs'},
                      {'value': 'fat', 'label': 'Fat'},
                    ].map<Widget>((Map<String, String> item) {
                      return Center(
                        child: Text(
                          item['label']!,
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList();
                  },
                  items: const [
                    DropdownMenuItem(value: 'kcal', child: Text('Kcal', style: TextStyle(color: Colors.black87, fontSize: 12))),
                    DropdownMenuItem(value: 'protein', child: Text('Protein', style: TextStyle(color: Colors.black87, fontSize: 12))),
                    DropdownMenuItem(value: 'carbs', child: Text('Carbs', style: TextStyle(color: Colors.black87, fontSize: 12))),
                    DropdownMenuItem(value: 'fat', child: Text('Fat', style: TextStyle(color: Colors.black87, fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pieChartFilter = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 160,
              width: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: sections,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                 _LegendItem(color: Color(0xFFFF6700), label: 'Breakfast'),
                 _LegendItem(color: Color(0xFFFFC100), label: 'Lunch'),
                 _LegendItem(color: Color(0xFF006666), label: 'Dinner'),
                 _LegendItem(color: Color(0xFFb2d8d8), label: 'Snacks'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 8),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
