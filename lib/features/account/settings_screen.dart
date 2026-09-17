import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../state/settings_controller.dart';
import '../support/help_sheet.dart';
import 'account_tab.dart';

//==============================================================================
// SPOCART — Settings
//------------------------------------------------------------------------------
// Account, notifications, language, privacy, help, about — and Logout.
//==============================================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickLanguage(BuildContext context) async {
    final SettingsController settings = AppScope.of(context).settings;
    final AppLanguage? picked = await showAppBottomSheet<AppLanguage>(
      context,
      title: 'Language',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final AppLanguage l in AppLanguage.values)
              ListTile(
                onTap: () => Navigator.of(context).pop(l),
                title: Text(l.label,
                    style: l == settings.settings.language
                        ? AppTypography.bodyStrong
                        : AppTypography.body),
                trailing: l == settings.settings.language
                    ? const Icon(Icons.check_rounded, color: AppColors.red)
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Need the app in another language? Tell us which one.',
                      style: AppTypography.caption,
                    ),
                  ),
                  GhostButton(
                    label: 'Request',
                    onPressed: () {
                      Navigator.of(context).pop();
                      SupportLauncher.whatsapp(
                        context,
                        message:
                            'Hi SPOCART, I would like the app in my language: ',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await settings.update(settings.settings.copyWith(language: picked));
  }

  Future<void> _logout(BuildContext context) async {
    final bool ok = await showAppConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need an OTP to sign in again. Your cart is kept on this device.',
      confirmLabel: 'Logout',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!ok || !context.mounted) return;
    await AppScope.of(context).signOut();
    if (context.mounted) AppNavigator.toLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = AppScope.of(context).settings;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'Settings'),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              AccountMenuGroup(
                items: [
                  AccountMenuItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Account Settings',
                    subtitle: 'Business details, contact, email',
                    onTap: () => AppNavigator.toBusinessDetails(context),
                  ),
                  AccountMenuItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notification Settings',
                    onTap: () => AppNavigator.toNotificationSettings(context),
                  ),
                  AccountMenuItem(
                    icon: Icons.translate_rounded,
                    label: 'Language',
                    subtitle: settings.settings.language.label,
                    onTap: () => _pickLanguage(context),
                  ),
                  AccountMenuItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Privacy & Security',
                    onTap: () => AppNavigator.toPrivacySecurity(context),
                  ),
                  AccountMenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () => AppNavigator.toHelpSupport(context),
                  ),
                  AccountMenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'About SPOCART',
                    onTap: () => AppNavigator.toAbout(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Logout',
                icon: Icons.logout_rounded,
                onPressed: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
