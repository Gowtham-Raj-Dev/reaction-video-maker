import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../controllers/layout_controller.dart';

class LayoutPresetsSheet extends StatelessWidget {
  const LayoutPresetsSheet({
    super.key,
    required this.currentMode,
    required this.onSelectMode,
  });

  final LayoutMode currentMode;
  final void Function(LayoutMode mode) onSelectMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.stroke),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.strokeStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Available Layouts',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildLayoutCard(
                        mode: LayoutMode.classic,
                        label: 'Classic',
                        graphic: _buildClassicGraphic(),
                      ),
                      _buildLayoutCard(
                        mode: LayoutMode.topVideo,
                        label: 'Top Video',
                        graphic: _buildTopVideoGraphic(),
                      ),
                      _buildLayoutCard(
                        mode: LayoutMode.topCamera,
                        label: 'Top Camera',
                        graphic: _buildTopCameraGraphic(),
                      ),
                      _buildLayoutCard(
                        mode: LayoutMode.pip,
                        label: 'PiP',
                        graphic: _buildPipGraphic(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutCard({
    required LayoutMode mode,
    required String label,
    required Widget graphic,
  }) {
    final selected = currentMode == mode;
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        onSelectMode(mode);
      },
      child: Column(
        children: [
          Container(
            width: 120,
            height: 160,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.accentSecondary : Colors.transparent,
                width: 2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.accentSecondary.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: graphic,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicGraphic() {
    return Column(
      children: [
        Expanded(
          flex: 70,
          child: _panel(Icons.movie_creation_rounded),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 30,
          child: Row(
            children: [
              Expanded(flex: 50, child: _panel(Icons.dashboard_customize_rounded)),
              const SizedBox(width: 6),
              Expanded(flex: 50, child: _panel(Icons.camera_alt_rounded)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopVideoGraphic() {
    return Column(
      children: [
        Expanded(
          flex: 70,
          child: _panel(Icons.movie_creation_rounded),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 30,
          child: _panel(Icons.camera_alt_rounded),
        ),
      ],
    );
  }

  Widget _buildTopCameraGraphic() {
    return Column(
      children: [
        Expanded(
          flex: 30,
          child: _panel(Icons.camera_alt_rounded),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 70,
          child: _panel(Icons.movie_creation_rounded),
        ),
      ],
    );
  }

  Widget _buildPipGraphic() {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            Positioned.fill(
              child: _panel(Icons.movie_creation_rounded),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              width: 32,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.strokeStrong, width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.camera_alt_rounded, size: 10, color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _panel(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(icon, size: 24, color: AppColors.textMuted),
      ),
    );
  }
}
