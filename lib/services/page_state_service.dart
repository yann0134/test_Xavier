import 'package:rxdart/rxdart.dart';

class PageStateService {
  static final PageStateService _instance = PageStateService._internal();
  factory PageStateService() => _instance;
  PageStateService._internal();

  final _pageController = BehaviorSubject<int>();
  Stream<int> get pageStream => _pageController.stream;

  void refreshPage(int index) {
    _pageController.add(index);
  }

  void dispose() {
    _pageController.close();
  }
}
