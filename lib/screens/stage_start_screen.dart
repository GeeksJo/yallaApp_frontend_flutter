import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:provider/provider.dart';
import 'package:yalla/l10n/app_localizations.dart';

import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../services/game_kit_bootstrap.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
import 'home_screen.dart';
import 'question_screen.dart';

/// Full-screen countdown after categories + Start (same layout for 1v1 and FFA;
/// FFA uses 3s / 3-2-1, 1v1 uses 2s / 2-1).
/// Mid-game FFA: [PassScreen] → [QuestionScreen] directly.
class StageStartScreen extends StatefulWidget {
  const StageStartScreen({super.key});

  @override
  State<StageStartScreen> createState() => _StageStartScreenState();
}

class _StageStartScreenState extends State<StageStartScreen>
    with SingleTickerProviderStateMixin {
  late final bool _ffa;
  late final int _countFrom;
  late final AnimationController _controller;
  late int _displayNumber;

  @override
  void initState() {
    super.initState();
    _ffa = context.read<GameProvider>().mode == GameMode.freeForAll;
    _countFrom = _ffa ? 3 : 2;
    _displayNumber = _countFrom;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _countFrom),
    );
    _controller.addListener(_onTick);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onComplete();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameKitAdBridge.preloadAds();
      GameKit.haptics.lightTap();
      _playCountdownTick();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    final v = _controller.value;
    final n = (_countFrom - (v * _countFrom).floor()).clamp(1, _countFrom);
    if (n != _displayNumber) {
      setState(() => _displayNumber = n);
      GameKit.haptics.lightTap();
      _playCountdownTick();
    }
  }

  void _playCountdownTick() {
    GameKit.sounds.countdownTick();
  }

  void _onComplete() {
    GameKit.haptics.milestoneSuccess();
    if (!mounted) return;
    final game = context.read<GameProvider>();
    if (game.players.isEmpty) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const QuestionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final game = context.watch<GameProvider>();
    final isTablet = ResponsiveLayout.isTablet(context);
    final baseTitle = isTablet ? 60.0 : 28.0;
    final baseDigit = isTablet ? 96.0 : 78.0;
    final baseRing = isTablet ? 152.0 : 128.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: AppDecorations.gradientBg,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final compact =
                    ResponsiveLayout.isCompactHeight(context) || h < 460;
                final scale = compact ? (h / 520).clamp(0.52, 1.0) : 1.0;
                final titleSize = baseTitle * scale;
                final digitSize = baseDigit * scale;
                final ring = baseRing * scale;

                return ResponsiveLayout(
                  maxWidth: ResponsiveLayout.maxWidthFor(
                    context,
                    phone: 560,
                    tabletPortrait: 680,
                    tabletLandscape: 800,
                  ),
                  child: SingleChildScrollView(
                    physics: compact
                        ? const BouncingScrollPhysics()
                        : const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: h),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..rotateZ(game.isFlipped ? math.pi : 0.0),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: isTablet ? 20 : 12),
                                  Text(
                                    l10n.stageStartsIn,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppFonts.family,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      height: 1.05,
                                      shadows: [
                                        Shadow(
                                          color: AppColors.primaryDeep
                                              .withValues(alpha: 0.95),
                                          offset: const Offset(0, 3),
                                          blurRadius: 0,
                                        ),
                                        Shadow(
                                          color: AppColors.danger.withValues(
                                            alpha: 0.88,
                                          ),
                                          offset: const Offset(0, 5),
                                          blurRadius: 12,
                                        ),
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.45,
                                          ),
                                          offset: const Offset(0, 2),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: compact ? 16 : 28),
                                  SizedBox(
                                    width: ring,
                                    height: ring,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: ring,
                                          height: ring,
                                          child: CircularProgressIndicator(
                                            value: _controller.value.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            strokeWidth: (7 * scale).clamp(
                                              4.0,
                                              8.0,
                                            ),
                                            strokeCap: StrokeCap.round,
                                            backgroundColor:
                                                AppColors.cardBorder,
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                  AppColors.coin,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          '$_displayNumber',
                                          style: TextStyle(
                                            fontFamily: AppFonts.family,
                                            color: AppColors.textPrimary,
                                            fontSize: digitSize,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                            shadows: [
                                              Shadow(
                                                color: AppColors.primaryDeep
                                                    .withValues(alpha: 0.55),
                                                offset: const Offset(0, 4),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: compact ? 16 : 32),
                                  Text(
                                    l10n.stageStartsFootnote,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppFonts.family,
                                      color: AppColors.textSecondary,
                                      fontSize:
                                          (isTablet ? 30.0 : 14.0) * scale,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 20 : 16),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
