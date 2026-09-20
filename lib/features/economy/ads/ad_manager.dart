import 'dart:async';
import 'package:flutter/material.dart';

import '../models/economy_types.dart';
import 'admob_service.dart';

export 'admob_service.dart' show RewardedAdResult;

/// Ad placement configuration with timing and targeting
final class AdPlacementStrategy {
  const AdPlacementStrategy({
    required this.placement,
    this.enabled = true,
    this.format = AdMobFormat.banner,
    this.frequencyPerDay = 3,
    this.cooldown = const Duration(minutes: 5),
    this.premiumExcluded = true,
    this.minTimeBetweenRequests = const Duration(seconds: 30),
    this.showAfterContentItems = 3, // Show after N content items in feeds
    this.neverShowDuring = const <String>[], // Screen names to never show
  });

  final AdPlacement placement;
  final bool enabled;
  final AdMobFormat format;
  final int frequencyPerDay;
  final Duration cooldown;
  final bool premiumExcluded;
  final Duration minTimeBetweenRequests;
  final int showAfterContentItems;
  final List<String> neverShowDuring;
}

/// Result of an ad placement decision
final class AdPlacementDecision {
  const AdPlacementDecision({
    required this.shouldShow,
    required this.placement,
    required this.format,
    this.reason,
  });

  final bool shouldShow;
  final AdPlacement placement;
  final AdMobFormat format;
  final String? reason;

  static AdPlacementDecision allow(AdPlacement placement, AdMobFormat format) =>
      AdPlacementDecision(
        shouldShow: true,
        placement: placement,
        format: format,
      );

  static AdPlacementDecision deny(
    AdPlacement placement,
    AdMobFormat format,
    String reason,
  ) => AdPlacementDecision(
    shouldShow: false,
    placement: placement,
    format: format,
    reason: reason,
  );
}

/// Central ad manager that coordinates ad placement decisions and show logic
final class AdManager {
  AdManager({
    required AdPlacementStrategy Function(AdPlacement) strategyProvider,
    required bool Function() isAdFree,
    required void Function(AdPlacement) onImpressionLogged,
  }) : _admob = AdMobService(),
       _strategyProvider = strategyProvider,
       _isAdFree = isAdFree,
       _onImpressionLogged = onImpressionLogged;

  final AdMobService _admob;
  final AdPlacementStrategy Function(AdPlacement) _strategyProvider;
  final bool Function() _isAdFree;
  final void Function(AdPlacement) _onImpressionLogged;

  // Track last request time per placement
  final Map<AdPlacement, DateTime> _lastRequestTime = <AdPlacement, DateTime>{};

  // Track content items shown since last ad in feeds
  final Map<String, int> _itemsSinceLastAd = <String, int>{};

  // Screen tracking
  String? _currentScreen;

  /// Initialize the ad manager
  Future<void> initialize() async {
    await _admob.initialize();

    // Preload common ads
    await _admob.loadInterstitial(
      placement: AdPlacement.groupEntryInterstitial,
    );
    await _admob.loadRewarded();

    // Preload the non-intrusive banner placement used on safe pages
    await _admob.loadBanner(placement: AdPlacement.bannerNonIntrusive);
  }

  /// Set current screen for context-aware ad decisions
  void setCurrentScreen(String? screenName) {
    _currentScreen = screenName;
  }

  /// Increment content item counter for a feed
  void incrementContentItems(String feedKey) {
    _itemsSinceLastAd[feedKey] = (_itemsSinceLastAd[feedKey] ?? 0) + 1;
  }

  /// Reset content counter (e.g., when ad is shown)
  void resetContentItems(String feedKey) {
    _itemsSinceLastAd[feedKey] = 0;
  }

  /// Decide whether to show an ad for a placement
  AdPlacementDecision shouldShowAd(AdPlacement placement) {
    final strategy = _strategyProvider(placement);

    if (!strategy.enabled) {
      return AdPlacementDecision.deny(placement, strategy.format, 'Disabled');
    }

    if (_isAdFree() && strategy.premiumExcluded) {
      return AdPlacementDecision.deny(
        placement,
        strategy.format,
        'Premium user',
      );
    }

    // Check if current screen is in never-show list
    if (_currentScreen != null &&
        strategy.neverShowDuring.contains(_currentScreen)) {
      return AdPlacementDecision.deny(
        placement,
        strategy.format,
        'Screen excluded',
      );
    }

    // Check cooldown between requests
    final lastRequest = _lastRequestTime[placement];
    if (lastRequest != null) {
      final elapsed = DateTime.now().difference(lastRequest);
      if (elapsed < strategy.minTimeBetweenRequests) {
        return AdPlacementDecision.deny(placement, strategy.format, 'Cooldown');
      }
    }

    return AdPlacementDecision.allow(placement, strategy.format);
  }

  /// Check if a banner should be shown in a feed after N items
  bool shouldShowBannerInFeed(String feedKey, AdPlacement placement) {
    final strategy = _strategyProvider(placement);
    if (strategy.format != AdMobFormat.banner) return false;

    final decision = shouldShowAd(placement);
    if (!decision.shouldShow) return false;

    final itemsCount = _itemsSinceLastAd[feedKey] ?? 0;
    return itemsCount >= strategy.showAfterContentItems;
  }

  /// Record a request was made (for cooldown tracking)
  void recordRequest(AdPlacement placement) {
    _lastRequestTime[placement] = DateTime.now();
  }

  /// Load and show a banner ad for a placement
  Future<Widget?> showBanner(AdPlacement placement) async {
    final decision = shouldShowAd(placement);
    if (!decision.shouldShow) return null;

    recordRequest(placement);

    final strategy = _strategyProvider(placement);
    if (strategy.format != AdMobFormat.banner) return null;

    await _admob.loadBanner(placement: placement);

    // Wait briefly for load
    await Future.delayed(const Duration(milliseconds: 100));

    final widget = _admob.buildBannerWidget(placement);
    if (widget != null) {
      _onImpressionLogged(placement);
      resetContentItems(placement.name);
    }
    return widget;
  }

  /// Show an interstitial ad
  Future<bool> showInterstitial({
    AdPlacement? placement,
    bool force = false,
  }) async {
    final p = placement ?? AdPlacement.groupEntryInterstitial; // Default
    final decision = force
        ? AdPlacementDecision.allow(p, AdMobFormat.interstitial)
        : shouldShowAd(p);

    if (!decision.shouldShow && !force) return false;

    recordRequest(p);
    final result = await _admob.showInterstitial(placement: p);

    if (result) {
      _onImpressionLogged(p);
    }
    return result;
  }

  /// Show a rewarded ad
  Future<RewardedAdResult> showRewarded() async {
    final result = await _admob.showRewarded();

    if (result.completed) {
      // Could trigger reward callback here
    }
    return result;
  }

  /// Show interstitial between screen transitions
  Future<void> showInterstitialBetweenScreens({
    required String fromScreen,
    required String toScreen,
    List<String> excludedTransitions = const [],
  }) async {
    final transitionKey = '$fromScreen->$toScreen';
    if (excludedTransitions.contains(transitionKey)) return;

    // Don't show interstitial too frequently
    final lastInterstitial =
        _lastRequestTime[AdPlacement.groupEntryInterstitial];
    if (lastInterstitial != null) {
      final elapsed = DateTime.now().difference(lastInterstitial);
      if (elapsed < const Duration(minutes: 3)) return;
    }

    await showInterstitial(
      placement: AdPlacement.groupEntryInterstitial,
      force: true,
    );
  }

  /// Preload ads for upcoming screens
  void preloadForScreen(String screenName) {
    switch (screenName) {
      case 'groups':
      case 'group_details':
        _admob.loadInterstitial(placement: AdPlacement.groupEntryInterstitial);
        break;
      case 'reels':
        _admob.loadNativeAd(placement: AdPlacement.reelsNativeFeed);
        break;
      case 'rewards':
      case 'games':
      case 'chat':
        _admob.loadRewarded();
        break;
      case 'settings':
      case 'store':
      case 'guide':
      case 'anime_hub':
        _admob.loadBanner(placement: AdPlacement.bannerNonIntrusive);
        break;
    }
  }

  /// Dispose all ads
  void dispose() {
    _admob.dispose();
  }
}

/// Ad widget that automatically handles loading and showing
class ManagedAdBanner extends StatefulWidget {
  const ManagedAdBanner({
    required this.placement,
    required this.adManager,
    super.key,
    this.feedKey,
    this.fallback,
  });

  final AdPlacement placement;
  final AdManager adManager;
  final String? feedKey;
  final Widget? fallback;

  @override
  State<ManagedAdBanner> createState() => _ManagedAdBannerState();
}

class _ManagedAdBannerState extends State<ManagedAdBanner> {
  Widget? _adWidget;
  StreamSubscription<AdMobLoadState>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    final shouldShow = widget.feedKey != null
        ? widget.adManager.shouldShowBannerInFeed(
            widget.feedKey!,
            widget.placement,
          )
        : widget.adManager.shouldShowAd(widget.placement).shouldShow;

    if (!shouldShow) return;

    widget.adManager.recordRequest(widget.placement);
    await widget.adManager._admob.loadBanner(placement: widget.placement);

    // Listen for state changes
    final controller =
        widget.adManager._admob.bannerControllers[widget.placement];
    if (controller != null) {
      _subscription = controller.stream.listen((state) {
        if (state == AdMobLoadState.loaded) {
          final bannerWidget = widget.adManager._admob.buildBannerWidget(
            widget.placement,
          );
          if (mounted && bannerWidget != null) {
            setState(() => _adWidget = bannerWidget);
            widget.adManager._onImpressionLogged(widget.placement);
            if (widget.feedKey != null) {
              widget.adManager.resetContentItems(widget.feedKey!);
            }
          }
        }
      });
    }

    // Check immediately
    final bannerWidget = widget.adManager._admob.buildBannerWidget(
      widget.placement,
    );
    if (bannerWidget != null && mounted) {
      setState(() => _adWidget = bannerWidget);
      widget.adManager._onImpressionLogged(widget.placement);
      if (widget.feedKey != null) {
        widget.adManager.resetContentItems(widget.feedKey!);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adWidget != null) return _adWidget!;
    return widget.fallback ?? const SizedBox.shrink();
  }
}

/// Interstitial ad trigger widget
class InterstitialTrigger extends StatelessWidget {
  const InterstitialTrigger({
    required this.child,
    required this.adManager,
    this.placement,
    this.onDismissed,
    super.key,
  });

  final Widget child;
  final AdManager adManager;
  final AdPlacement? placement;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Mixin for widgets that want to show interstitial on navigation
mixin InterstitialNavigationMixin<T extends StatefulWidget> on State<T> {
  AdManager get adManager;

  Future<void> pushWithInterstitial(
    BuildContext context,
    Widget page, {
    String? fromScreen,
    String? toScreen,
    AdPlacement? placement,
  }) async {
    await adManager.showInterstitialBetweenScreens(
      fromScreen: fromScreen ?? 'unknown',
      toScreen: toScreen ?? 'unknown',
    );
    if (context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }
  }
}
