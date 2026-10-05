import 'package:flutter/material.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../services/game_feedback.dart';
import '../services/yalla_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_back_button.dart';
import '../widgets/app_bottom_banner_slot.dart';
import '../widgets/responsive_layout.dart';
import 'category_selection_screen.dart';

class PlayerSetupScreen extends StatefulWidget {
  final List<String>? initialNames;

  const PlayerSetupScreen({super.key, this.initialNames});

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  static const int minFreeForAllPlayers = 3;

  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    final game = context.read<GameProvider>();
    final seedNames = _seedNames(game);
    if (seedNames != null && seedNames.isNotEmpty) {
      for (final name in seedNames) {
        _controllers.add(TextEditingController(text: name));
      }
      if (game.mode == GameMode.freeForAll &&
          _controllers.length < minFreeForAllPlayers) {
        for (var i = _controllers.length; i < minFreeForAllPlayers; i++) {
          _controllers.add(TextEditingController());
        }
      }
    } else {
      final count = game.mode == GameMode.oneVsOne ? 2 : 3;
      for (var i = 0; i < count; i++) {
        _controllers.add(TextEditingController());
      }
    }
  }

  /// Session names from a prior free-for-all run (not persisted to disk).
  List<String>? _seedNames(GameProvider game) {
    if (widget.initialNames != null && widget.initialNames!.isNotEmpty) {
      return widget.initialNames;
    }
    if (game.mode != GameMode.freeForAll) return null;
    if (game.sessionFreeForAllNames.isNotEmpty) {
      return game.sessionFreeForAllNames;
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canProceed {
    final mode = context.read<GameProvider>().mode;
    final minPlayers = mode == GameMode.freeForAll ? minFreeForAllPlayers : 2;
    return _controllers.length >= minPlayers &&
        _controllers.every((c) => c.text.trim().isNotEmpty);
  }

  void _addPlayer() {
    GameFeedback.tap();
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removePlayer(int index) {
    GameFeedback.tap();
    final minPlayers = context.read<GameProvider>().mode == GameMode.freeForAll
        ? minFreeForAllPlayers
        : 2;
    if (_controllers.length <= minPlayers) return;
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  Widget _buildNameField(
    BuildContext context,
    AppLocalizations l10n,
    int index,
    bool isFFA,
  ) {
    bool isTablet = ResponsiveLayout.isTablet(context);
    final nameSize = isTablet ? 30.0 : 18.0;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controllers[index],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '${l10n.enterPlayerName} ${index + 1}',
              hintStyle: const TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.cardFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: TextStyle(color: AppColors.textPrimary, fontSize: nameSize),
          ),
        ),
        if (isFFA && _controllers.length > minFreeForAllPlayers)
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              color: AppColors.danger,
              size: isTablet ? 40 : 28,
            ),
            onPressed: () => _removePlayer(index),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = context.watch<GameProvider>().mode;
    final isFFA = mode == GameMode.freeForAll;
    final twoCols =
        ResponsiveLayout.isTablet(context) &&
        ResponsiveLayout.isLandscape(context);
    final maxW = ResponsiveLayout.maxWidthFor(
      context,
      phone: 520,
      tabletPortrait: 680,
      tabletLandscape: 920,
    );
    final hPad = ResponsiveLayout.tabletContentHorizontalInset(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    return Scaffold(
      appBar: AppBar(
        leading: const FeedbackBackButton(),
        title: Text(l10n.playerSetup),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.gradientBg,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: ResponsiveLayout(
            maxWidth: maxW,
            child: Column(
              children: [
                Expanded(
                  child: twoCols
                      ? GridView.builder(
                          padding: AppSpacing.screenPadding,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 16,
                                childAspectRatio: 4.2,
                              ),
                          itemCount: _controllers.length,
                          itemBuilder: (context, index) {
                            return _buildNameField(context, l10n, index, isFFA);
                          },
                        )
                      : ListView.builder(
                          padding: AppSpacing.screenPadding,
                          itemCount: _controllers.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildNameField(
                                context,
                                l10n,
                                index,
                                isFFA,
                              ),
                            );
                          },
                        ),
                ),
                if (isFFA)
                  Padding(
                    padding: AppSpacing.screenH,
                    child: TextButton.icon(
                      onPressed: _addPlayer,
                      icon: Icon(
                        Icons.add,
                        color: AppColors.textSecondary,
                        size: isTablet ? 40 : 28,
                      ),
                      label: Text(
                        l10n.addPlayer,
                        style: TextStyle(
                          fontSize: isTablet ? 30 : 18,
                          fontFamily: AppFonts.family,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight(context),
                    child: ElevatedButton(
                      onPressed: _canProceed
                          ? () {
                              GameFeedback.tap();
                              final names = _controllers
                                  .map((c) => c.text.trim())
                                  .toList();
                              context.read<GameProvider>().setPlayers(names);
                              Navigator.push(
                                context,
                                yallaPage(
                                  name: YallaRoute.categories,
                                  builder: (_) =>
                                      const CategorySelectionScreen(),
                                ),
                              );
                            }
                          : null,
                      style: AppButtonStyles.primaryDisabled,
                      child: Text(
                        l10n.next,
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
    );
  }
}
