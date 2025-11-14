import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdService extends GetxService {
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  final RxBool isRewardedAdReady = false.obs;
  final RxBool isBannerAdReady = false.obs;

  // Use test ad unit IDs for development
  static String get rewardedAdUnitId {
    if (kDebugMode) {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; //test
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; //test
    } else {
      // For non-mobile platforms
      throw UnsupportedError("Unsupported Platform.");
    }
  } else {
      // REPLACE THESE WITH YOUR REAL AD UNIT IDs FOR PRODUCTION
      if (Platform.isAndroid) {
        // return 'ca-app-pub-3940256099942544/5224354917';
        return 'ca-app-pub-4288009468041362/7648098339';  //real
      } else if (Platform.isIOS) {
        // return 'ca-app-pub-3940256099942544/1712485313';
        return 'ca-app-pub-4288009468041362/5444853933';  //real
      } else {
        throw UnsupportedError("Unsupported Platform.");
      }
    }
  }

  // Banner ad unit IDs
  static String get bannerAdUnitId {
    // Use test ads in debug mode, real ads in release mode
    if (kDebugMode) {
      // Test banner ad unit IDs
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; //test
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; //test
      } else {
        throw UnsupportedError("Unsupported Platform.");
      }
    } else {
      // REPLACE THESE WITH YOUR REAL AD UNIT IDs FOR PRODUCTION
      if (Platform.isAndroid) {
        // return 'ca-app-pub-3940256099942544/6300978111';
        print('<><><>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Android - Release');
        return 'ca-app-pub-4288009468041362/1808861257';  //real
      } else if (Platform.isIOS) {
        // return 'ca-app-pub-3940256099942544/2934735716';
        return 'ca-app-pub-4288009468041362/9000955560';  //real
      } else {
        throw UnsupportedError("Unsupported Platform.");
      }
    }
  }

  // Method to load a rewarded ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          isRewardedAdReady.value = true;
          debugPrint('Rewarded ad loaded.');
        },
        onAdFailedToLoad: (error) {
          isRewardedAdReady.value = false;
          debugPrint('Failed to load a rewarded ad: ${error.message}');
        },
      ),
    );
  }

  // Method to load a banner ad
  void loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          isBannerAdReady.value = true;
          debugPrint('Banner ad loaded.');
        },
        onAdFailedToLoad: (ad, error) {
          isBannerAdReady.value = false;
          ad.dispose();
          debugPrint('Failed to load a banner ad: ${error.message}');
        },
        onAdOpened: (ad) {
          debugPrint('Banner ad opened.');
        },
        onAdClosed: (ad) {
          debugPrint('Banner ad closed.');
        },
      ),
    );

    _bannerAd!.load();
  }

  // Method to get the banner ad widget
  Widget? getBannerAdWidget() {
    if (_bannerAd != null && isBannerAdReady.value) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }

  // Method to dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    isBannerAdReady.value = false;
  }


  void showRewardedAd({required VoidCallback onReward}) {
    if (!isRewardedAdReady.value || _rewardedAd == null) {
      debugPrint('Tried to show ad but it was not ready.');
      loadRewardedAd(); // Try to load another one for next time
      return;
    }

    // Track if reward was earned to handle proper game resume
    bool rewardEarned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        isRewardedAdReady.value = false;
        debugPrint('Ad dismissed. Reward earned: $rewardEarned');

        // FIXED: Only call onReward if user actually earned the reward
        if (rewardEarned) {
          onReward();
        }

        loadRewardedAd(); // Pre-load the next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        isRewardedAdReady.value = false;
        debugPrint('Failed to show the ad: $error');
        loadRewardedAd(); // Pre-load the next ad
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        rewardEarned = true;
        // Note: Don't call onReward here immediately, wait for ad dismissal
        // This ensures proper timing and prevents multiple calls
      },
    );
    _rewardedAd = null;
  }

  @override
  void onInit() {
    super.onInit();
    // Load both types of ads on initialization
    loadBannerAd();
    loadRewardedAd();
  }

  @override
  void onClose() {
    _rewardedAd?.dispose();
    disposeBannerAd();
    super.onClose();
  }
}