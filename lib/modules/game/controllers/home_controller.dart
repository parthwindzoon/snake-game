// lib/app/modules/home/controllers/home_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../data/service/score_service.dart';
import '../home/settings/settings_controller.dart';
import '../home/settings/settings_overlay.dart';

class HomeController extends GetxController {
  // A controller to manage the text input for the nickname.
  final TextEditingController nicknameController = TextEditingController();
  final ScoreService _scoreService = ScoreService();

  // A reactive variable to hold the high score.
  final RxInt highScore = 0.obs;
  final RxString currentUsernameRx = ''.obs;

  // 🆕 NEW: Add GetStorage for username persistence
  final GetStorage _box = GetStorage();
  static const String _usernameKey = 'savedUsername';

  @override
  void onInit() {
    super.onInit();
    // When the controller starts, load the high score.
    highScore.value = _scoreService.getHighScore();

    _loadUsername();
    _setupUsernameListener();
  }

  // 🆕 NEW: Load username from storage
  void _loadUsername() {
    final savedUsername = _box.read(_usernameKey);
    if (savedUsername != null && savedUsername.toString().isNotEmpty) {
      nicknameController.text = savedUsername.toString();
      currentUsernameRx.value = savedUsername.toString(); // Update reactive variable
      print('✅ Loaded saved username: $savedUsername');
    } else {
      currentUsernameRx.value = ''; // Update reactive variable
      print('📝 No saved username found');
    }
  }

  void _setupUsernameListener() {
    nicknameController.addListener(() {
      final currentText = nicknameController.text.trim();
      currentUsernameRx.value = currentText;

      // Always save or remove, even if empty
      _saveUsername(currentText);
    });
  }

  void _saveUsername(String username) {
    if (username.isNotEmpty) {
      _box.write(_usernameKey, username);
      print('💾 Username saved: $username');
    } else {
      _box.remove(_usernameKey);
      print('🗑️ Username removed from storage');
    }
  }

  // --- NEW METHOD ---
  void openSettings() {
    Get.put(SettingsController());
    Get.dialog(const SettingsOverlay());
  }

  @override
  void onClose() {
    nicknameController.dispose();
    super.onClose();
  }
}