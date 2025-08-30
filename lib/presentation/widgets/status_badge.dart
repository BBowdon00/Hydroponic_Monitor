import 'package:flutter/material.dart';
import 'package:hydroponic_monitor/core/theme.dart';
import 'package:hydroponic_monitor/domain/entities/device.dart';

/// Status badge widget for showing device/system status
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.isOn = false,
    this.size = StatusBadgeSize.medium,
  });

  final DeviceStatus status;
  final bool isOn;
  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final config = _getBadgeConfig(status, isOn, colorScheme);
    final sizeConfig = _getSizeConfig(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizeConfig.horizontalPadding,
        vertical: sizeConfig.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(sizeConfig.borderRadius),
        border: Border.all(
          color: config.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: sizeConfig.dotSize,
            height: sizeConfig.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: config.dotColor,
            ),
          ),
          SizedBox(width: sizeConfig.spacing),
          Text(
            config.label,
            style: sizeConfig.textStyle(theme).copyWith(
              color: config.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getBadgeConfig(
    DeviceStatus status,
    bool isOn,
    ColorScheme colorScheme,
  ) {
    switch (status) {
      case DeviceStatus.online:
        if (isOn) {
          return _BadgeConfig(
            label: 'Active',
            backgroundColor: colorScheme.primaryContainer,
            borderColor: colorScheme.primary.withAlpha(51),
            textColor: colorScheme.onPrimaryContainer,
            dotColor: colorScheme.primary,
          );
        } else {
          return _BadgeConfig(
            label: 'Ready',
            backgroundColor: colorScheme.surfaceContainerHighest,
            borderColor: colorScheme.outline.withAlpha(128),
            textColor: colorScheme.onSurfaceVariant,
            dotColor: colorScheme.primary,
          );
        }
      case DeviceStatus.offline:
        return _BadgeConfig(
          label: 'Offline',
          backgroundColor: colorScheme.surfaceContainerHighest,
          borderColor: colorScheme.outline.withAlpha(128),
          textColor: colorScheme.onSurfaceVariant,
          dotColor: colorScheme.onSurfaceVariant,
        );
      case DeviceStatus.error:
        return _BadgeConfig(
          label: 'Error',
          backgroundColor: colorScheme.errorContainer,
          borderColor: colorScheme.error.withAlpha(51),
          textColor: colorScheme.onErrorContainer,
          dotColor: colorScheme.error,
        );
      case DeviceStatus.maintenance:
        return _BadgeConfig(
          label: 'Maintenance',
          backgroundColor: colorScheme.tertiaryContainer,
          borderColor: colorScheme.tertiary.withAlpha(51),
          textColor: colorScheme.onTertiaryContainer,
          dotColor: colorScheme.tertiary,
        );
    }
  }

  _SizeConfig _getSizeConfig(StatusBadgeSize size) {
    switch (size) {
      case StatusBadgeSize.small:
        return const _SizeConfig(
          horizontalPadding: AppTheme.space8,
          verticalPadding: AppTheme.space4,
          borderRadius: AppTheme.radiusSmall,
          dotSize: 6,
          spacing: AppTheme.space4,
          textStyleGetter: _getBodySmallStyle,
        );
      case StatusBadgeSize.medium:
        return const _SizeConfig(
          horizontalPadding: AppTheme.space12,
          verticalPadding: AppTheme.space8,
          borderRadius: AppTheme.radiusSmall,
          dotSize: 8,
          spacing: AppTheme.space8,
          textStyleGetter: _getLabelMediumStyle,
        );
      case StatusBadgeSize.large:
        return const _SizeConfig(
          horizontalPadding: AppTheme.space16,
          verticalPadding: AppTheme.space12,
          borderRadius: AppTheme.radiusMedium,
          dotSize: 10,
          spacing: AppTheme.space8,
          textStyleGetter: _getLabelLargeStyle,
        );
    }
  }

  static TextStyle? _getBodySmallStyle(ThemeData theme) => theme.textTheme.bodySmall;
  static TextStyle? _getLabelMediumStyle(ThemeData theme) => theme.textTheme.labelMedium;
  static TextStyle? _getLabelLargeStyle(ThemeData theme) => theme.textTheme.labelLarge;
}

/// Status badge size options
enum StatusBadgeSize {
  small,
  medium,
  large,
}

/// Badge configuration
class _BadgeConfig {
  const _BadgeConfig({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.dotColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color dotColor;
}

/// Size configuration
class _SizeConfig {
  const _SizeConfig({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.borderRadius,
    required this.dotSize,
    required this.spacing,
    required this.textStyleGetter,
  });

  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double dotSize;
  final double spacing;
  final TextStyle? Function(ThemeData) textStyleGetter;

  TextStyle? textStyle(ThemeData theme) => textStyleGetter(theme);
}