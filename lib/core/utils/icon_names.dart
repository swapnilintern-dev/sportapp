import 'package:flutter/material.dart';

//==============================================================================
// SPOCART — Icon name → IconData
//------------------------------------------------------------------------------
// The API stores Material icon names as strings (categories, product
// features). One lookup keeps that mapping in a single place.
//==============================================================================

const Map<String, IconData> _icons = <String, IconData>{
  'sports_cricket': Icons.sports_cricket_rounded,
  'sports_soccer': Icons.sports_soccer_rounded,
  'sports_tennis': Icons.sports_tennis_rounded,
  'sports_basketball': Icons.sports_basketball_rounded,
  'sports_hockey': Icons.sports_hockey_rounded,
  'sports_volleyball': Icons.sports_volleyball_rounded,
  'table_bar': Icons.table_bar_rounded,
  'directions_run': Icons.directions_run_rounded,
  'pool': Icons.pool_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'sports': Icons.sports_rounded,
  'forest': Icons.forest_outlined,
  'air': Icons.air_rounded,
  'shield': Icons.shield_outlined,
  'emoji_events': Icons.emoji_events_outlined,
  'wb_cloudy': Icons.wb_cloudy_outlined,
  'back_hand': Icons.back_hand_outlined,
  'brush': Icons.brush_outlined,
  'verified': Icons.verified_outlined,
  'accessibility_new': Icons.accessibility_new_rounded,
  'star': Icons.star_outline_rounded,
  'bolt': Icons.bolt_rounded,
  'eco': Icons.eco_outlined,
  'water_drop': Icons.water_drop_outlined,
};

IconData iconFromName(String? name, {IconData fallback = Icons.sports_rounded}) {
  if (name == null) return fallback;
  final String key = name.replaceAll(RegExp(r'_(rounded|outlined|sharp)$'), '');
  return _icons[key] ?? fallback;
}
