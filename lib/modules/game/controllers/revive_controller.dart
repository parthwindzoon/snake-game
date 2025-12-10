// lib/app/modules/game/controllers/revive_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/service/ad_service.dart';
import '../../../routes/app_routes.dart';
import '../views/game_screen.dart'; // Your SlitherGame class

class ReviveController extends GetxController with GetSingleTickerProviderStateMixin {
  final SlitherGame game;
  ReviveController({required this.game});

  // TODO: After live uncomment this
  final AdService _adService = Get.find<AdService>();

  late final Timer _timer;
  late final AnimationController animationController;

  final RxInt countdown = 10.obs;

  // NEW: Track if ad unavailable popup is showing
  final RxBool showingAdUnavailablePopup = false.obs;

  @override
  void onInit() {
    super.onInit();

    animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: countdown.value),
    )..reverse(from: 1.0);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown.value > 0) {
        countdown.value--;
      } else {
        timer.cancel();
        animationController.stop();
        onNext();
      }
    });
  }

  @override
  void onClose() {
    _timer.cancel();
    animationController.dispose();
    super.onClose();
  }

  // NEW: Show ad unavailable popup
  void _showAdUnavailablePopup() {
    if (showingAdUnavailablePopup.value) return; // Prevent multiple popups

    showingAdUnavailablePopup.value = true;

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // Prevent dismissal by back button
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ads unavailable currently!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please check your internet connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    // Auto-close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (Get.isDialogOpen ?? false) {
        Get.back(); // Close the dialog
      }
      showingAdUnavailablePopup.value = false;

      // Proceed to game over since revive failed
      onNext();
    });
  }

  // FIXED: Proper revive handling with ad unavailable fallback
  void onRevive() {
    _timer.cancel();
    animationController.stop();

    //TODO: After live uncomment this
    _adService.showRewardedAd(
      onReward: () {
        game.revivePlayer();
      },
      onAdUnavailable: () {
        // NEW: Show popup when ad is unavailable
        _showAdUnavailablePopup();
      },
    );
  }

  // FIXED: Handle revive failure gracefully
  void _handleReviveFailure() {
    print('Revive failed, showing game over...');
    Get.delete<ReviveController>();
    game.overlays.remove('revive');
    game.showGameOver();
  }

  void onNext() {
    _timer.cancel();
    Get.delete<ReviveController>();
    game.showGameOver();
  }

  void onHome() {
    _timer.cancel();
    Get.delete<ReviveController>();
    game.overlays.remove('revive');
    game.resumeEngine();
    Get.offAllNamed(Routes.HOME);
  }
}