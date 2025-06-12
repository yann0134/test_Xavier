import 'package:scoped_model/scoped_model.dart';

mixin NavigationModel on Model {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}
