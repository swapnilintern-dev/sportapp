import 'package:flutter/material.dart';

//==============================================================================
// SPOCART — Design tokens
//------------------------------------------------------------------------------
// The single place every colour, spacing step, radius and shadow is decided.
// Screens compose these; they never hardcode hex values or magic paddings.
//
// Brand: black / red / white. Greys are derived neutrals for surfaces, borders
// and secondary text. Semantic colours (success / warning / info) are used
// sparingly for stock and order-status signalling only.
//==============================================================================

abstract final class AppColors {
  // Brand
  static const Color black = Color(0xFF0B0B0C);
  static const Color ink = Color(0xFF151517);
  static const Color red = Color(0xFFE4132B);
  static const Color redHot = Color(0xFFFF2038);
  static const Color redDeep = Color(0xFFA80D20);
  static const Color redTint = Color(0xFFFDE8EA);
  static const Color white = Color(0xFFFFFFFF);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF6F6F7);
  static const Color surfaceAlt = Color(0xFFEDEDEF);
  static const Color border = Color(0xFFE2E2E5);
  static const Color divider = Color(0xFFEEEEF0);

  // Text
  static const Color text = Color(0xFF141416);
  static const Color textSoft = Color(0xFF55555E);
  static const Color textMuted = Color(0xFF7C7C86);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSoft = Color(0xADFFFFFF);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successTint = Color(0xFFE8F7EE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningTint = Color(0xFFFEF3DF);
  static const Color info = Color(0xFF2563EB);
  static const Color infoTint = Color(0xFFE6EEFF);
  static const Color error = red;
  static const Color errorTint = redTint;

  // Ratings
  static const Color star = Color(0xFFF5A623);
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal page gutter used by every screen.
  static const double page = 16;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: page);
  static const EdgeInsets cardPadding = EdgeInsets.all(sm);
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

abstract final class AppShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F0B0B0C),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A0B0B0C),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> red = <BoxShadow>[
    BoxShadow(
      color: Color(0x40E4132B),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// Shadow for bars pinned to the bottom of a screen (cast upwards).
  static const List<BoxShadow> bottomBar = <BoxShadow>[
    BoxShadow(
      color: Color(0x140B0B0C),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];
}

abstract final class AppSizes {
  static const double buttonHeight = 52;
  static const double buttonHeightSmall = 40;
  static const double inputHeight = 52;
  static const double iconButton = 40;
  static const double bottomNavHeight = 64;
  static const double appBarHeight = 56;

  /// Content is centred and capped on wide screens (tablets / landscape) so
  /// phone layouts never stretch into unreadable widths.
  static const double maxContentWidth = 560;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
