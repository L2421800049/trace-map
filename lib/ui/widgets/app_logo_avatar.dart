import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/assets.dart';
import '../app_state_scope.dart';

class AppLogoAvatar extends StatelessWidget {
  const AppLogoAvatar({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.2);
    return AppStateBuilder(
      builder: (context, state) {
        final customLogo = state.customLogoUrl;
        if (customLogo == null || customLogo.isEmpty) {
          return _buildAsset(borderRadius);
        }
        final lower = customLogo.toLowerCase();
        if (lower.endsWith('.svg')) {
          return ClipRRect(
            borderRadius: borderRadius,
            child: SvgPicture.network(
              customLogo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholderBuilder: (context) => _placeholder(),
            ),
          );
        }
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            customLogo,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildAsset(borderRadius),
          ),
        );
      },
    );
  }

  Widget _buildAsset(BorderRadius borderRadius) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SvgPicture.asset(
        defaultAppLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _placeholder() {
    return SizedBox(
      width: size,
      height: size,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
