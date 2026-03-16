import 'package:google_mobile_ads/google_mobile_ads.dart';

const _interstitialUnitId = 'ca-app-pub-5309859983306685/9639208215';

class AdService {
  AdService._();
  static final instance = AdService._();

  // 将来の有料版対応: true にすると広告を非表示
  bool isPremium = false;

  InterstitialAd? _interstitial;
  int _sessionsSinceLastAd = 0;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (isPremium) return;
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              _loadInterstitial(); // 次回のためにプリロード
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
        },
      ),
    );
  }

  /// セッション保存後に呼ぶ。3回に1回表示。
  void showInterstitialIfReady() {
    if (isPremium) return;
    _sessionsSinceLastAd++;
    if (_sessionsSinceLastAd < 3) return;
    _sessionsSinceLastAd = 0;
    if (_interstitial == null) return;
    _interstitial!.show();
  }
}
