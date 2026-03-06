import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  void _showAddFoodModal(BuildContext context, String mealType, String uid, FirestoreService db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Add to $mealType', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.grey),
                      hintText: 'Search food database...',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: db.getFoods(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Center(child: Text("No custom foods found. Add some in the Database!"));
                      
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var food = docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(food['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${food['kcal']} kcal • ${food['protein']}p • ${food['carbs']}c • ${food['fat']}f'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFFFF6700)),
                              onPressed: () {
                                db.addFoodToLog(uid, _dateStr, mealType, food);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food['name']} added to $mealType', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF006666)));
                              },
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = Provider.of<FirestoreService>(context, listen: false);

    if (user == null) return const Center(child: Text('Please log in'));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: InkWell(
          onTap: () {
            setState(() {
              _isCalendarExpanded = !_isCalendarExpanded;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Meal Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    DateFormat('EEEE, MMM d').format(_selectedDate),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Icon(_isCalendarExpanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isCalendarExpanded) _buildCalendar(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: db.getDailyLog(user.uid, _dateStr),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                Map<String, dynamic> logData = {};
                if (snapshot.hasData && snapshot.data!.exists) {
                  logData = snapshot.data!.data() as Map<String, dynamic>;
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                     _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.wb_sunny_outlined,
                      title: 'Breakfast',
                      foods: List<Map<String, dynamic>>.from(logData['Breakfast'] ?? []),
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),
                    _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.restaurant,
                      title: 'Lunch',
                      foods: List<Map<String, dynamic>>.from(logData['Lunch'] ?? []),
                    ),
                    const SizedBox(height: 16),
                    _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.nightlight_round,
                      title: 'Dinner',
                      foods: List<Map<String, dynamic>>.from(logData['Dinner'] ?? []),
                    ),
                    const SizedBox(height: 16),
                    _buildMealCategorySection(
                      context: context,
                      uid: user.uid,
                      db: db,
                      icon: Icons.fastfood_outlined,
                      title: 'Snacks',
                      foods: List<Map<String, dynamic>>.from(logData['Snacks'] ?? []),
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodModal(context, 'Snacks', user.uid, db), // Defaulting FAB to snacks
        backgroundColor: const Color(0xFFFF6700),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      color: Colors.white,
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDate,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
            _focusedDate = focusedDay;
            _isCalendarExpanded = false;
          });
        },
        calendarFormat: CalendarFormat.week,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: Color(0xFFFF6700),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Color(0xFF006666),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildMealCategorySection({
    required BuildContext context,
    required String uid,
    required FirestoreService db,
    required IconData icon,
    required String title,
    required List<Map<String, dynamic>> foods,
    bool isExpanded = false,
  }) {
    int totalKcal = foods.fold(0, (sum, item) => sum + (item['kcal'] as num? ?? 0).toInt());

    List<Widget> logItems = foods.map((food) {
      return _buildLogItem(
        food['name'] ?? 'Unknown',
        '${food['protein']}p • ${food['carbs']}c • ${food['fat']}f',
        (food['kcal'] as num? ?? 0).toInt(),
      );
    }).toList();

    return Container(
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          iconColor: Colors.grey,
          collapsedIconColor: Colors.grey,
          title: Row(
            children: [
              Icon(icon, color: const Color(0xFFFF6700), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$totalKcal kcal',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  if (logItems.isNotEmpty) ...logItems,
                  if (logItems.isEmpty) const Text("No food logged yet", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddFoodModal(context, title, uid, db),
                      icon: const Icon(Icons.add, color: Color(0xFFFF6700), size: 18),
                      label: const Text(
                        'Add Food',
                        style: TextStyle(color: Color(0xFFFF6700)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF6700)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(String name, String details, int macros) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(details, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Text('$macros kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

