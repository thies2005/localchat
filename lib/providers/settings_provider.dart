import 'package:flutter/foundation.dart';

class SettingsProvider extends ChangeNotifier {
  double temperature = 0.7;
  int topK = 40;
  int maxOutputTokens = 256;
  bool autoContinue = true;
  bool showTokenStats = true;

  void updateShowTokenStats(bool value) {
    showTokenStats = value;
    notifyListeners();
  }

  void updateTemperature(double value) {
    temperature = value;
    notifyListeners();
  }

  void updateTopK(int value) {
    topK = value;
    notifyListeners();
  }

  void updateMaxOutputTokens(int value) {
    maxOutputTokens = value;
    notifyListeners();
  }

  void updateAutoContinue(bool value) {
    autoContinue = value;
    notifyListeners();
  }

  void resetDefaults() {
    temperature = 0.7;
    topK = 40;
    maxOutputTokens = 256;
    autoContinue = true;
    showTokenStats = true;
    notifyListeners();
  }
}
