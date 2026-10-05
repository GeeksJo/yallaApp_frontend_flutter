import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/game_feedback.dart';
import '../theme/app_theme.dart';

class CategoryCard extends StatelessWidget {
  final GameCategory category;
  final String locale;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  /// Title size (default matches original phone grid).
  final double titleFontSize;

  /// Scales the circular visual and inner image/icon (1 = original).
  final double visualScale;

  const CategoryCard({
    super.key,
    required this.category,
    required this.locale,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
    this.titleFontSize = 15,
    this.visualScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final accent = category.color;
    final borderColor = isSelected
        ? accent
        : AppColors.cardBorder.withValues(alpha: isLocked ? 0.35 : 0.65);
    final titleColor = isLocked
        ? AppColors.textSecondary
        : (isSelected ? accent : AppColors.textPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          GameFeedback.tap();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isLocked ? 0.10 : 0.16),
                Colors.white.withValues(alpha: isLocked ? 0.04 : 0.07),
              ],
            ),
            border: Border.all(color: borderColor, width: isSelected ? 2.5 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (isSelected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildVisual(accent),
                    SizedBox(height: 10 * visualScale.clamp(0.85, 1.28)),
                    Text(
                      category.name(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        color: titleColor,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.cardBorder.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: AppColors.coin,
                      size: (16 * visualScale).clamp(14.0, 26.0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisual(Color accent) {
    final s = visualScale.clamp(0.72, 1.32);
    final well = Container(
      width: 115 * s,
      height: 115 * s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: accent.withValues(alpha: isLocked ? 0.22 : 0.35),
        ),
      ),
      child: _visualChild(accent, s),
    );

    if (isLocked) {
      return Opacity(opacity: 0.55, child: well);
    }
    return well;
  }

  Widget _visualChild(Color accent, double s) {
    if (category.imagePath != null) {
      return Padding(
        padding: EdgeInsets.all(10 * s),
        child: Image.asset(
          category.imagePath!,
          width: 72 * s,
          height: 72 * s,
          fit: BoxFit.contain,
        ),
      );
    }

    return Icon(
      category.icon,
      color: accent.withValues(alpha: 0.95),
      size: 40 * s,
    );
  }
}
