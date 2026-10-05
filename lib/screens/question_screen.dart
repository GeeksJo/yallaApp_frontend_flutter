import 'dart:async';
import 'dart:math' as math;

import 'package:game_kit/game_kit.dart';
import 'package:flutter/material.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../providers/coin_provider.dart';
import '../providers/game_provider.dart';
import '../providers/game_settings_provider.dart';
import '../providers/locale_provider.dart';
import '../services/countdown_urgency_policy.dart';
import '../services/emergency_block_notice.dart';
import '../services/game_feedback.dart';
import '../services/game_kit_bootstrap.dart';
import '../services/rating_moment.dart';
import '../services/storage_service.dart';
import '../services/game_kit_products.dart';
import '../services/yalla_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/app_bottom_banner_slot.dart';
import '../widgets/app_cross_promo.dart';
import '../widgets/red_button.dart';
import '../widgets/responsive_layout.dart';
import 'home_screen.dart';
import 'pass_screen.dart';
import 'player_setup_screen.dart';
import 'scoreboard_screen.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _timerController;
  late AnimationController _turnFlipController;
  bool _answered = false;
  bool _paused = false;
  bool _turnFlipping = false;
  bool _flipFrom = false;
  bool _flipTo = false;
  String? _flipName;
  String? _flipQuestionText;
  late int _answerSeconds;
  bool _introComplete = false;
  bool _countdownUrgencyActive = false;
  bool _emergencyBlocked = false;
  bool _appInBackground = false;

  static const _turnFlipDuration = Duration(milliseconds: 680);
  static const _afterTurnFlipPause = Duration(milliseconds: 400);

  double _timerDiameter(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    final wide = ResponsiveLayout.useWideGameLayout(context);
    final compact = ResponsiveLayout.isCompactHeight(context);
    if (wide && compact) {
      return isTablet ? 120 : 92;
    }
    if (isTablet && ResponsiveLayout.isLandscape(context)) {
      return compact ? 128 : 154;
    }
    if (isTablet) return 162;
    return 112;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _answerSeconds = context.read<GameSettingsProvider>().questionTimerSeconds;
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _answerSeconds),
    );
    _turnFlipController = AnimationController(
      vsync: this,
      duration: _turnFlipDuration,
    );
    _timerController.addStatusListener(_onTimerStatus);
    _timerController.addListener(_onTimerTick);
    final isFFA = context.read<GameProvider>().mode == GameMode.freeForAll;
    if (isFFA) {
      _introComplete = true;
    } else {
      // StageStartScreen already ran 2→1 for 1v1; no second intro here.
      _introComplete = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = context.read<GameProvider>();
      if (game.players.isNotEmpty &&
          yallaSessionShouldStart(
            round: game.currentRound,
            playerIndex: game.currentPlayerIndex,
          )) {
        unawaited(yallaSessionStarted(game.selectedCategories));
      }
      unawaited(GameKit.notifications.markPlayedToday());
      GameKitAdBridge.preloadAds();
      if (isFFA) {
        unawaited(_ffaStartAnswerPhase());
      } else {
        unawaited(_start1v1AnswerPhase(hideQuestionFirst: false));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blocked = EmergencyBlockNotice.blockedOf(context);
    if (blocked == _emergencyBlocked) return;
    _emergencyBlocked = blocked;
    _syncCountdownUrgency();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inBackground = state != AppLifecycleState.resumed;
    if (inBackground == _appInBackground) return;
    _appInBackground = inBackground;
    _syncCountdownUrgency();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerController.removeListener(_onTimerTick);
    _timerController.removeStatusListener(_onTimerStatus);
    _countdownUrgencyActive = false;
    unawaited(GameKit.sounds.stopCountdownUrgency());
    _timerController.dispose();
    _turnFlipController.dispose();
    super.dispose();
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_answered) {
      _onTimeout();
    }
  }

  void _onTimerTick() => _syncCountdownUrgency();

  void _syncCountdownUrgency() {
    final remaining =
        _answerSeconds - (_timerController.value * _answerSeconds);
    final shouldPlay = CountdownUrgencyPolicy.shouldPlay(
      answered: _answered,
      paused: _paused,
      introComplete: _introComplete,
      emergencyBlocked: _emergencyBlocked,
      inBackground: _appInBackground,
      answerSeconds: _answerSeconds,
      remainingSeconds: remaining,
    );
    if (shouldPlay && !_countdownUrgencyActive) {
      _countdownUrgencyActive = true;
      unawaited(GameKit.sounds.startCountdownUrgency());
    } else if (!shouldPlay) {
      _stopCountdownUrgency();
    }
  }

  void _stopCountdownUrgency() {
    if (!_countdownUrgencyActive) return;
    _countdownUrgencyActive = false;
    unawaited(GameKit.sounds.stopCountdownUrgency());
  }

  void _playGoSound() {
    GameKit.sounds.go();
  }

  void _resetAnswerTimerForNewRound() {
    _answerSeconds = context.read<GameSettingsProvider>().questionTimerSeconds;
    _timerController
      ..stop()
      ..reset();
    if (_timerController.duration != Duration(seconds: _answerSeconds)) {
      _timerController.duration = Duration(seconds: _answerSeconds);
    }
    _stopCountdownUrgency();
  }

  Future<void> _ffaStartAnswerPhase() async {
    if (!mounted || _answered) return;
    GameKitAdBridge.preloadAds();
    _resetAnswerTimerForNewRound();
    _playGoSound();
    if (!mounted || _answered) return;
    GameKit.haptics.milestoneSuccess();
    setState(() => _introComplete = true);
    _timerController.forward(from: 0);
  }

  /// 1v1: flip handoff or first question after [StageStartScreen] - no 2→1 intro.
  Future<void> _start1v1AnswerPhase({bool hideQuestionFirst = true}) async {
    if (!mounted || _answered) return;
    GameKitAdBridge.preloadAds();
    _resetAnswerTimerForNewRound();
    if (hideQuestionFirst) {
      setState(() {
        _introComplete = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted || _answered) return;
    }
    _playGoSound();
    if (!mounted || _answered) return;
    GameKit.haptics.milestoneSuccess();
    setState(() => _introComplete = true);
    _timerController.forward(from: 0);
  }

  Widget _buildCrossPromoButton({required bool isTablet, VoidCallback? onTap}) {
    final size = isTablet ? 100.0 : 44.0;
    final iconSize = isTablet ? 80.0 : 24.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.round(context)),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF52E3D7).withValues(alpha: 0.95),
                const Color(0xFF23BEB4).withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.round(context)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: 0.78539816339, // 45°
            child: Center(
              child: Transform.rotate(
                angle: -0.78539816339,
                child: Image.asset(
                  'assets/images/game_controller.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownBlock(
    AppLocalizations l10n,
    bool isTablet,
    double timerDiameter, {
    required bool is1v1,
  }) {
    final d = timerDiameter;
    final answerStroke = isTablet ? 14.0 : null;
    final handoffWaiting = is1v1 && !_introComplete;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (handoffWaiting)
          CountdownTimer(
            progress: 1,
            secondsLeft: _answerSeconds,
            diameter: d,
            answerRingStrokeWidth: answerStroke,
          )
        else
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, _) {
              final remaining =
                  _answerSeconds - (_timerController.value * _answerSeconds);
              return CountdownTimer(
                progress: (1 - _timerController.value).clamp(0.0, 1.0),
                secondsLeft: remaining.ceil(),
                diameter: d,
                answerRingStrokeWidth: answerStroke,
              );
            },
          ),
      ],
    );
  }

  Widget _buildHeaderRow({
    required AppLocalizations l10n,
    required bool isTablet,
    required String centerName,
    required VoidCallback? onPause,
    required VoidCallback? onRemoveAds,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, isTablet ? 8 : 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            style: IconButton.styleFrom(
              minimumSize: Size(isTablet ? 64 : 48, isTablet ? 64 : 48),
            ),
            icon: Icon(
              Icons.pause_rounded,
              size: isTablet ? 80 : 26,
              color: onPause == null
                  ? AppColors.textHint
                  : AppColors.textSecondary,
            ),
            onPressed: onPause,
          ),
          Expanded(
            child: Text(
              centerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.family,
                color: AppColors.coin,
                fontSize: isTablet ? 50.0 : 15.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: GameKit.iap.adsRemoved,
            builder: (context, adsRemoved, _) {
              final w = isTablet ? 72.0 : 48.0;
              if (adsRemoved) {
                return SizedBox(width: w, height: w);
              }
              return IconButton(
                style: IconButton.styleFrom(minimumSize: Size(w, w)),
                tooltip: l10n.removeAds,
                onPressed: onRemoveAds,
                icon: Image.asset(
                  'assets/images/no_ads.png',
                  height: isTablet ? 100 : 40,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoundLine(
    AppLocalizations l10n,
    GameProvider game,
    bool isTablet,
  ) {
    final text = '${l10n.round} ${game.currentRound}/${game.totalRounds}';
    if (!isTablet) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardFill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textMuted,
              fontSize: 35,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPanel({
    required bool isTablet,
    required String text,
    required bool is1v1,
    required AppLocalizations l10n,
  }) {
    final fontSize = isTablet ? 38.0 : 22.0;
    final showQuestion = is1v1
        ? (_introComplete && !_turnFlipping)
        : _introComplete;
    if (!showQuestion) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 20),
        child: SizedBox(
          height: fontSize * 1.35 * 2,
          child: Center(
            child: Text(
              l10n.getReady,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.family,
                color: AppColors.textMuted,
                fontSize: isTablet ? 26 : 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: Text(
          text,
          key: ValueKey<String>(text),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.family,
            color: AppColors.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildMainQuestionColumn({
    required BuildContext context,
    required AppLocalizations l10n,
    required GameProvider game,
    required bool isTablet,
    required bool is1v1,
    required VoidCallback? onPause,
    required VoidCallback? onRemoveAds,
    required String headerName,
    required String questionText,
    required bool redEnabled,
    required VoidCallback onDone,
    VoidCallback? onCrossPromo,
  }) {
    final timerD = _timerDiameter(context);
    final redBase = ResponsiveLayout.redButtonDiameter(context);
    final redD = isTablet ? redBase + 36.0 : redBase;
    final crossPromoSize = isTablet ? 100.0 : 44.0;

    return Column(
      children: [
        _buildHeaderRow(
          l10n: l10n,
          isTablet: isTablet,
          centerName: headerName,
          onPause: onPause,
          onRemoveAds: onRemoveAds,
        ),
        _buildRoundLine(l10n, game, isTablet),
        if (is1v1 && game.players.length == 2)
          _build1v1Scoreboard(game, isTablet)
        else
          const SizedBox(height: 6),
        const Spacer(flex: 2),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MoreGamesBadge(
                child: _buildCrossPromoButton(
                  isTablet: isTablet,
                  onTap: onCrossPromo,
                ),
              ),
              Expanded(
                child: Center(
                  child: _buildCountdownBlock(
                    l10n,
                    isTablet,
                    timerD,
                    is1v1: is1v1,
                  ),
                ),
              ),
              SizedBox(width: crossPromoSize),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 28 : 20),
        _buildQuestionPanel(
          isTablet: isTablet,
          text: questionText,
          is1v1: is1v1,
          l10n: l10n,
        ),
        const Spacer(flex: 3),
        RedButton(
          label: l10n.done,
          enabled: redEnabled,
          onPressed: onDone,
          diameter: redD,
        ),
        const Spacer(flex: 1),
        const AppBottomBannerSlot(),
      ],
    );
  }

  void _openOtherGames() {
    if (_answered || _paused || _turnFlipping || !_introComplete) return;
    GameFeedback.tap();
    unawaited(showAppCrossPromoSheet(context));
  }

  Future<void> _removeAdsFromHeader() async {
    if (_answered || _paused || _turnFlipping || !_introComplete) return;
    if (GameKit.iap.adsRemoved.value) return;
    GameFeedback.tap();
    unawaited(
      GameAnalytics.logIapOfferShown(
        productId: GameKitProducts.removeAds,
        source: GameAnalyticsKeys.sourceHudIcon,
      ),
    );

    final l10n = AppLocalizations.of(context)!;
    final price = GameKit.iap.getFormattedPrice(GameKitProducts.removeAds);
    final ui = GameKit.settingsUi;
    final dialogColors = GameKitSettingsDialogColors.fromConfig(
      seedColor: ui?.seedColor ?? AppColors.primary,
      dialog: ui?.dialog,
    );
    final ok = await GameKitSettingsDialogs.showConfirmRemoveAds(
      context,
      dialogColors: dialogColors,
      locale: GameKit.locale,
      price: price,
      fontFamily: ui?.fontFamily,
    );
    if (!ok || !mounted) return;
    await GameKit.iap.purchaseRemoveAds();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.purchaseThanks)));
  }

  void _togglePause() {
    if (_answered) return;
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _timerController.stop();
      } else {
        _timerController.forward();
      }
      _syncCountdownUrgency();
    });
  }

  Future<void> _abandonMatch() async {
    yallaSessionAbandoned();
    if (!RatingMoment.abandoned.recordFailure) return;
    await GameKit.rating.levelFailed();
  }

  Future<void> _exitToPlayerSetup() async {
    await _abandonMatch();
    if (!mounted) return;
    final names = context
        .read<GameProvider>()
        .players
        .map((player) => player.name)
        .toList();
    Navigator.pushAndRemoveUntil(
      context,
      yallaPage(
        name: YallaRoute.playerSetup,
        builder: (_) => PlayerSetupScreen(initialNames: names),
      ),
      (route) => route.isFirst,
    );
  }

  void _showPauseMenu() {
    GameFeedback.tap();
    _togglePause();
    final l10n = AppLocalizations.of(context)!;
    final isFreeForAll =
        context.read<GameProvider>().mode == GameMode.freeForAll;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        final isPad = ResponsiveLayout.isTablet(dialogContext);
        return Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: isPad ? 40 : 24),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isPad ? 440 : 360),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isPad ? 32 : 24,
                  vertical: isPad ? 32 : 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isPad ? 72.0 : 58,
                      height: isPad ? 72.0 : 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pause_rounded,
                        color: AppColors.textPrimary,
                        size: isPad ? 42 : 34,
                      ),
                    ),
                    SizedBox(height: isPad ? 18 : 14),
                    Text(
                      l10n.paused,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.textPrimary,
                        fontSize: isPad ? 42 : 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: isPad ? 24 : 20),
                    SizedBox(
                      width: double.infinity,
                      height: isPad ? 62.0 : 54,
                      child: ElevatedButton(
                        onPressed: () {
                          GameFeedback.tap();
                          Navigator.pop(dialogContext);
                          _togglePause();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          textStyle: TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: isPad ? 22 : 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(l10n.resume),
                      ),
                    ),
                    if (isFreeForAll) ...[
                      SizedBox(height: isPad ? 14 : 10),
                      SizedBox(
                        width: double.infinity,
                        height: isPad ? 62.0 : 54,
                        child: OutlinedButton(
                          onPressed: () {
                            GameFeedback.tap();
                            Navigator.pop(dialogContext);
                            unawaited(_exitToPlayerSetup());
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.textSecondary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            textStyle: TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: isPad ? 21 : 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            l10n.editPlayers,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: isPad ? 14 : 10),
                    SizedBox(
                      width: double.infinity,
                      height: isPad ? 62.0 : 54,
                      child: OutlinedButton(
                        onPressed: () async {
                          GameFeedback.tap();
                          Navigator.pop(dialogContext);
                          await _abandonMatch();
                          if (!mounted) return;
                          final nav = Navigator.of(context);
                          nav.pushAndRemoveUntil(
                            yallaPage(
                              name: YallaRoute.home,
                              builder: (_) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.danger,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          textStyle: TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: isPad ? 21 : 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(
                          l10n.home,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onDonePressed() {
    if (_answered || _paused || _turnFlipping || !_introComplete) return;
    _answered = true;
    _timerController.stop();
    _stopCountdownUrgency();

    final game = context.read<GameProvider>();
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final prevName = game.currentPlayer.name;
    final prevQuestionText = game.currentQuestion?.text(locale) ?? '';
    final prevFlip = game.isFlipped;
    final coinProvider = context.read<CoinProvider>();
    final isGameOver = game.answerCorrect();
    coinProvider.addCoins(1);
    GameFeedback.success();
    unawaited(
      _finishCorrectAnswer(
        isGameOver,
        prevFlip: prevFlip,
        prevName: prevName,
        prevQuestionText: prevQuestionText,
      ),
    );
  }

  Future<void> _finishCorrectAnswer(
    bool isGameOver, {
    required bool prevFlip,
    required String prevName,
    required String prevQuestionText,
  }) async {
    final level = await context
        .read<StorageService>()
        .incrementRatingSuccessCount();
    if (!mounted) return;
    await _navigate(
      isGameOver,
      prevFlip: prevFlip,
      prevName: prevName,
      prevQuestionText: prevQuestionText,
      ratingLevel: level,
    );
  }

  void _onTimeout() {
    if (_answered || _turnFlipping) return;
    _answered = true;
    _stopCountdownUrgency();
    GameFeedback.failure();

    final game = context.read<GameProvider>();
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final prevName = game.currentPlayer.name;
    final prevQuestionText = game.currentQuestion?.text(locale) ?? '';
    final prevFlip = game.isFlipped;
    final isGameOver = game.answerTimeout();

    unawaited(
      _navigate(
        isGameOver,
        prevFlip: prevFlip,
        prevName: prevName,
        prevQuestionText: prevQuestionText,
        roundFailed: true,
      ),
    );
  }

  Future<void> _navigate(
    bool isGameOver, {
    required bool prevFlip,
    required String prevName,
    required String prevQuestionText,
    bool roundFailed = false,
    int? ratingLevel,
  }) async {
    if (!mounted) return;
    final game = context.read<GameProvider>();
    final roundJustCompleted = game.currentPlayerIndex == 0;
    final moment = RatingMoment.forAnswer(
      succeeded: !roundFailed,
      roundCompleted: roundJustCompleted,
      gameOver: isGameOver,
    );
    if (moment.recordFailure) {
      await GameKit.rating.levelFailed();
      if (!mounted) return;
    }

    if (isGameOver) {
      await yallaSessionCompleted();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        yallaPage(
          name: YallaRoute.scoreboard,
          builder: (_) => ScoreboardScreen(
            adsRoundFailed: roundFailed,
            ratingLevel: moment.offerOnResults ? ratingLevel : null,
          ),
        ),
      );
      return;
    }

    // All players finished a round; index wraps to 0 before the next question.
    if (roundJustCompleted) {
      await GameKitAdBridge.presentAfterLevel(
        context: context,
        failed: roundFailed,
      );
      if (!mounted) return;
      if (moment.offerOnRoundBoundary && ratingLevel != null) {
        await presentYallaRatingIfEligible(context, level: ratingLevel);
        if (!mounted) return;
      }
      GameKitAdBridge.preloadAds();
    }

    if (game.mode == GameMode.oneVsOne) {
      _playTurnFlip(
        prevFlip: prevFlip,
        nextFlip: game.isFlipped,
        prevName: prevName,
        prevQuestionText: prevQuestionText,
      );
    } else {
      Navigator.pushReplacement(
        context,
        yallaPage(name: YallaRoute.pass, builder: (_) => const PassScreen()),
      );
    }
  }

  void _playTurnFlip({
    required bool prevFlip,
    required bool nextFlip,
    required String prevName,
    required String prevQuestionText,
  }) {
    if (_turnFlipping) return;
    GameFeedback.completion();
    setState(() {
      _turnFlipping = true;
      _flipFrom = prevFlip;
      _flipTo = nextFlip;
      _flipName = prevName;
      _flipQuestionText = prevQuestionText;
    });
    _turnFlipController.forward(from: 0).then((_) async {
      if (!mounted) return;
      await Future<void>.delayed(_afterTurnFlipPause);
      if (!mounted) return;
      setState(() {
        _turnFlipping = false;
        _flipName = null;
        _flipQuestionText = null;
        _introComplete = false;
      });
      _answered = false;
      _paused = false;
      unawaited(_start1v1AnswerPhase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final game = context.watch<GameProvider>();

    if (game.players.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          yallaPage(name: YallaRoute.home, builder: (_) => const HomeScreen()),
          (route) => false,
        );
      });
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: AppDecorations.gradientBg,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final question = game.currentQuestion;
    final isTablet = ResponsiveLayout.isTablet(context);
    final is1v1 = game.mode == GameMode.oneVsOne;

    final headerName = _turnFlipping
        ? (_flipName ?? '')
        : game.currentPlayer.name;
    final questionText = _turnFlipping
        ? (_flipQuestionText ?? '')
        : (question?.text(locale) ?? '');

    final body = _buildMainQuestionColumn(
      context: context,
      l10n: l10n,
      game: game,
      isTablet: isTablet,
      is1v1: is1v1,
      onPause: _turnFlipping || !_introComplete ? null : _showPauseMenu,
      onRemoveAds: _turnFlipping || !_introComplete || _answered || _paused
          ? null
          : _removeAdsFromHeader,
      headerName: headerName,
      questionText: questionText,
      redEnabled: _introComplete,
      onDone: _onDonePressed,
      onCrossPromo: _turnFlipping ? null : _openOtherGames,
    );

    final questionContentMaxWidth = isTablet
        ? double.infinity
        : ResponsiveLayout.maxWidthFor(
            context,
            phone: 600,
            tabletPortrait: 780,
            tabletLandscape: 960,
          );

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: AppDecorations.gradientBg,
          child: SafeArea(
            bottom: false,
            child: ResponsiveLayout(
              maxWidth: questionContentMaxWidth,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _turnFlipController,
                    builder: (context, child) {
                      final baseFrom = _flipFrom ? math.pi : 0.0;
                      final baseTo = _flipTo ? math.pi : 0.0;
                      final t = _turnFlipping
                          ? Curves.easeInOutCubic.transform(
                              _turnFlipController.value,
                            )
                          : 1.0;
                      final angle = _turnFlipping
                          ? baseFrom + (baseTo - baseFrom) * t
                          : (game.isFlipped ? math.pi : 0.0);
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateZ(angle),
                        child: _turnFlipping && _turnFlipController.value >= 0.5
                            ? _buildLiveBody(context)
                            : child,
                      );
                    },
                    child: body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final game = context.watch<GameProvider>();
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final question = game.currentQuestion;
    final isTablet = ResponsiveLayout.isTablet(context);
    final is1v1 = game.mode == GameMode.oneVsOne;

    return _buildMainQuestionColumn(
      context: context,
      l10n: l10n,
      game: game,
      isTablet: isTablet,
      is1v1: is1v1,
      onPause: null,
      onRemoveAds: null,
      headerName: game.currentPlayer.name,
      questionText: question?.text(locale) ?? '',
      redEnabled: _introComplete,
      onDone: () {},
      onCrossPromo: null,
    );
  }

  Widget _build1v1Scoreboard(GameProvider game, bool isTablet) {
    final p1 = game.players[0];
    final p2 = game.players[1];
    final turn = game.currentPlayerIndex;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 20 : 16,
        8,
        isTablet ? 20 : 16,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p1.name,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.family,
                color: turn == 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: isTablet ? 30.0 : 13.0,
                fontWeight: turn == 0 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 14 : 10),
            child: Text(
              '${p1.score}  -  ${p2.score}',
              style: TextStyle(
                fontFamily: AppFonts.family,
                color: AppColors.textPrimary,
                fontSize: isTablet ? 40.0 : 16.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              p2.name,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.family,
                color: turn == 1
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: isTablet ? 30.0 : 13.0,
                fontWeight: turn == 1 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreGamesBadge extends StatelessWidget {
  const _MoreGamesBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!GameKit.isInitialized) return child;
    return StreamBuilder<bool>(
      initialData: GameKit.crossPromo.hasNewGame,
      stream: GameKit.crossPromo.hasNewGameChanges,
      builder: (context, snapshot) {
        final showBadge = snapshot.data ?? false;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (showBadge)
              const Positioned(top: -4, right: -2, child: _NewGamesMark()),
          ],
        );
      },
    );
  }
}

class _NewGamesMark extends StatelessWidget {
  const _NewGamesMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.coin,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontFamily: AppFonts.family,
          color: AppColors.primaryDark,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
