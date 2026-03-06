import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  String? _userId;
  DateTime _selectedDate = DateTime.now();

  String? get userId => _userId;
  DateTime get selectedDate => _selectedDate;

  void setUserId(String? id) {
    _userId = id;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }
}
