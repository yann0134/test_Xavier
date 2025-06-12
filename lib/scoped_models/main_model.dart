import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import '../views/caisse_ia/caisse_ia_page.dart';

class MainModel extends Model {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}
