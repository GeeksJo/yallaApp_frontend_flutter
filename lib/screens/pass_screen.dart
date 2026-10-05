import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../services/game_feedback.dart';
import '../services/game_kit_bootstrap.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
import 'question_screen.dart';

class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    GameKitAdBridge.preloadAds();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final game = context.read<GameProvider>();
    if (game.mode == GameMode.oneVsOne && game.players.length == 2) {
      // Animate towards the *next* player orientation.
      // game.isFlipped was toggled when the turn advanced.
      _flipController.value = game.isFlipped ? 0.0 : 1.0;
      Future.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        _flipController
            .animateTo(game.isFlipped ? 1.0 : 0.0, curve: Curves.easeInOutCubic)
            .then((_) {
              if (!mounted) return;
              Future.delayed(
                const Duration(milliseconds: 220),
                _goToNextQuestion,
              );
            });
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _goToNextQuestion() {
    if (!mounted) return;
    GameFeedback.success();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const QuestionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final mode = game.mode;

    if (mode == GameMode.oneVsOne) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: AppDecorations.gradientBg,
            child: Center(
              child: AnimatedBuilder(
                animation: _flipController,
                builder: (context, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateZ(_flipController.value * math.pi),
                    child: child,
                  );
                },
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final isTablet = ResponsiveLayout.isTablet(context);
    final compact = ResponsiveLayout.isCompactHeight(context);
    final scale = compact ? 0.88 : 1.0;
    final iconSize = (isTablet ? 120.0 : 64.0) * scale;
    final nameSize = (isTablet ? 80.0 : 36.0) * scale;
    final maxW = ResponsiveLayout.maxWidthFor(
      context,
      phone: 600,
      tabletPortrait: 720,
      tabletLandscape: 880,
    );
    final hPad = ResponsiveLayout.tabletContentHorizontalInset(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: GestureDetector(
          onTap: _goToNextQuestion,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: AppDecorations.gradientBg,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: ResponsiveLayout(
                  maxWidth: maxW,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android,
                                color: AppColors.textMuted,
                                size: iconSize,
                              ),
                              SizedBox(height: 24 * scale),
                              Text(
                                l10n.passTo,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: (isTablet ? 30.0 : 18.0) * scale,
                                ),
                              ),
                              SizedBox(height: 8 * scale),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  game.currentPlayer.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: nameSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 32 * scale),
                              Text(
                                l10n.tapToContinue,
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  color: AppColors.textHint,
                                  fontSize: (isTablet ? 30.0 : 14.0) * scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
