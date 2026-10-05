import 'package:flutter/material.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/coin_provider.dart';
import '../providers/game_provider.dart';
import '../providers/game_settings_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_banner_slot.dart';
import '../widgets/category_card.dart';
import '../widgets/locked_category_sheet.dart';
import '../widgets/responsive_layout.dart';
import '../services/game_feedback.dart';
import '../services/game_kit_bootstrap.dart';
import 'stage_start_screen.dart';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final Set<String> _selected = {};
  int _selectedRounds = 3;
  static const _roundOptions = [1, 3, 5, 7, 10];
  late final Future<List<GameCategory>> _categoriesFuture =
      GameCategory.loadAll();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GameKitAdBridge.preloadAds();
    });
  }

  void _onCategoryTap(GameCategory category, bool isLocked) {
    if (isLocked) {
      _showLockedSheet(category);
      return;
    }

    setState(() {
      if (_selected.contains(category.key)) {
        _selected.remove(category.key);
      } else {
        _selected.add(category.key);
      }
    });
  }

  void _showLockedSheet(GameCategory category) async {
    final unlocked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<CoinProvider>(),
        child: LockedCategorySheet(category: category),
      ),
    );

    if (unlocked == true && mounted) {
      setState(() {
        _selected.add(category.key);
      });
    }
  }

  Widget _buildAnswerTimeRow(
    BuildContext context,
    AppLocalizations l10n,
    GameSettingsProvider settings,
    bool isTablet,
  ) {
    final seconds = settings.questionTimerSeconds;
    final labelSize = isTablet ? 30.0 : 13.0;
    final trackH = isTablet ? 7.0 : 3.0;
    final thumbR = isTablet ? 12.0 : 8.0;
    final overlayR = isTablet ? 20.0 : 14.0;
    final hPad = isTablet ? 20.0 : 16.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.answerTime,
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textMuted,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$seconds s',
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textSecondary,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: trackH,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbR),
              overlayShape: RoundSliderOverlayShape(overlayRadius: overlayR),
              activeTrackColor: AppColors.coin,
              inactiveTrackColor: AppColors.cardBorder,
              thumbColor: AppColors.textPrimary,
            ),
            child: Slider(
              value: seconds.toDouble(),
              min: GameSettingsProvider.minQuestionTimerSeconds.toDouble(),
              max: GameSettingsProvider.maxQuestionTimerSeconds.toDouble(),
              divisions:
                  GameSettingsProvider.maxQuestionTimerSeconds -
                  GameSettingsProvider.minQuestionTimerSeconds,
              onChanged: (v) => context
                  .read<GameSettingsProvider>()
                  .setQuestionTimerSeconds(v.round()),
              onChangeEnd: (_) => GameFeedback.tap(),
            ),
          ),
        ],
      ),
    );
  }

  void _onStart() {
    GameFeedback.tap();
    final game = context.read<GameProvider>();
    if (game.players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noPlayersSet)),
      );
      return;
    }
    game.setTotalRounds(_selectedRounds);
    game.setCategories(_selected.toList());
    game.startGame();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StageStartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final coinProvider = context.watch<CoinProvider>();
    final gameSettings = context.watch<GameSettingsProvider>();
    final isTablet = ResponsiveLayout.isTablet(context);
    final gridCols = ResponsiveLayout.gridColumns(context);
    final roundChipSize = isTablet ? 56.0 : 40.0;
    final aspect = ResponsiveLayout.categoryGridChildAspectRatio(context);
    final cardTitleSize = isTablet
        ? (ResponsiveLayout.isLandscape(context) ? 19.0 : 20.5)
        : (ResponsiveLayout.isLandscape(context) ? 14.0 : 15.0);
    final cardVisualScale = isTablet
        ? (ResponsiveLayout.isLandscape(context) ? 1.10 : 1.22)
        : (ResponsiveLayout.isLandscape(context) ? 0.92 : 1.0);
    final contentMax = ResponsiveLayout.maxWidthFor(
      context,
      phone: 800,
      tabletPortrait: 940,
      tabletLandscape: 1080,
    );
    final hPad = ResponsiveLayout.tabletContentHorizontalInset(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.gradientBg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: ResponsiveLayout(
              maxWidth: contentMax,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: isTablet ? 48 : 40,
                            minHeight: isTablet ? 48 : 40,
                          ),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textPrimary,
                            size: isTablet ? 28 : 22,
                          ),
                          onPressed: () {
                            GameFeedback.tap();
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                          child: Text(
                            l10n.chooseCategories,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              color: AppColors.textPrimary,
                              fontSize: isTablet ? 22 : 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: isTablet ? 48 : 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.howManyRounds,
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          color: AppColors.textMuted,
                          fontSize: isTablet ? 30.0 : 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _roundOptions.map((n) {
                      final active = _selectedRounds == n;
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 4 : 3,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            GameFeedback.tap();
                            setState(() => _selectedRounds = n);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: roundChipSize,
                            height: roundChipSize,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.textPrimary
                                  : AppColors.cardFill,
                              borderRadius: BorderRadius.circular(
                                isTablet ? AppRadius.lg : AppRadius.md,
                              ),
                              border: Border.all(
                                color: active
                                    ? AppColors.textPrimary
                                    : AppColors.cardBorder,
                                width: active ? (isTablet ? 2.5 : 2) : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontSize: isTablet ? 30.0 : 16.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: isTablet ? 12 : 10),
                  _buildAnswerTimeRow(context, l10n, gameSettings, isTablet),
                  SizedBox(height: isTablet ? 8 : 6),

                  Expanded(
                    child: FutureBuilder<List<GameCategory>>(
                      future: _categoriesFuture,
                      builder: (context, snapshot) {
                        final categories =
                            snapshot.data ?? GameCategory.allFallback;
                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 14 : 12,
                            0,
                            isTablet ? 14 : 12,
                            isTablet ? 10 : 8,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridCols,
                                mainAxisSpacing: isTablet ? 12 : 10,
                                crossAxisSpacing: isTablet ? 12 : 10,
                                childAspectRatio: aspect,
                              ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isLocked =
                                cat.lockedByDefault &&
                                !coinProvider.isCategoryUnlocked(cat.key);

                            return CategoryCard(
                              category: cat,
                              locale: locale,
                              isSelected: _selected.contains(cat.key),
                              isLocked: isLocked,
                              onTap: () => _onCategoryTap(cat, isLocked),
                              titleFontSize: cardTitleSize,
                              visualScale: cardVisualScale,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 24 : 20,
                      isTablet ? 8 : 6,
                      isTablet ? 24 : 20,
                      0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: AppSpacing.buttonHeight(context),
                      child: ElevatedButton(
                        onPressed: _selected.isNotEmpty ? _onStart : null,
                        style: AppButtonStyles.primaryDisabled.merge(
                          ButtonStyle(
                            textStyle: WidgetStateProperty.all(
                              TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: isTablet ? 30 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        child: Text(
                          _selected.isEmpty
                              ? l10n.selectAtLeastOne
                              : l10n.start,
                          style: TextStyle(fontSize: isTablet ? 30 : 18),
                        ),
                      ),
                    ),
                  ),
                  const AppBottomBannerSlot(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
