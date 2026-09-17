import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/account.dart';
import '../../state/session_controller.dart';

//==============================================================================
// SPOCART — Account tab (Business Profile)
//------------------------------------------------------------------------------
// The profile card (business name, GSTIN, contact, mobile) with Edit, then
// the account menu: business details, GST, addresses, team, dashboard,
// invoices, quotations, wishlist, notifications, bulk/custom orders, settings.
//==============================================================================

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final SessionController session = services.session;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SpocartAppBar(
        title: 'Business Profile',
        showBack: false,
        actions: [
          GhostButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: () => AppNavigator.toBusinessDetails(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([session, services.notifications]),
        builder: (context, _) {
          final UserSession? user = session.session;
          final BusinessProfile? profile = user?.profile;
          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
              children: [
                _ProfileCard(user: user, profile: profile),
                if (profile == null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _CompleteProfileBanner(
                    onTap: () => AppNavigator.toBusinessRegistration(
                      context,
                      allowSkip: false,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const _GroupLabel('Business'),
                AccountMenuGroup(
                  items: [
                    AccountMenuItem(
                      icon: Icons.business_outlined,
                      label: 'Business Details',
                      onTap: () => AppNavigator.toBusinessDetails(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'GST Details',
                      onTap: () => AppNavigator.toGstDetails(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.location_on_outlined,
                      label: 'Addresses',
                      onTap: () => AppNavigator.toAddresses(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.group_outlined,
                      label: 'Team Members',
                      onTap: () => AppNavigator.toTeamMembers(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const _GroupLabel('Activity'),
                AccountMenuGroup(
                  items: [
                    AccountMenuItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Business Dashboard',
                      onTap: () => AppNavigator.toDashboard(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.description_outlined,
                      label: 'Invoices',
                      onTap: () => AppNavigator.toInvoices(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.request_quote_outlined,
                      label: 'Quotations',
                      onTap: () => AppNavigator.toQuotes(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.favorite_border_rounded,
                      label: 'Wishlist',
                      onTap: () => AppNavigator.toWishlist(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      badge: services.notifications.unreadCount,
                      onTap: () => AppNavigator.toNotifications(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const _GroupLabel('Bulk & Custom'),
                AccountMenuGroup(
                  items: [
                    AccountMenuItem(
                      icon: Icons.upload_file_outlined,
                      label: 'Bulk Order Upload',
                      onTap: () => AppNavigator.toBulkUpload(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.checkroom_outlined,
                      label: 'Custom / Team Order',
                      onTap: () => AppNavigator.toCustomOrder(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AccountMenuGroup(
                  items: [
                    AccountMenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => AppNavigator.toSettings(context),
                    ),
                    AccountMenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () => AppNavigator.toHelpSupport(context),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.profile});

  final UserSession? user;
  final BusinessProfile? profile;

  @override
  Widget build(BuildContext context) {
    final String business = profile?.businessName ?? 'Your Business';
    final String contact = profile?.contactName ?? 'Add your business details';
    final String mobile = formatIndianMobile(profile?.mobile ?? user?.mobile ?? '');

    return AppCard(
      color: AppColors.black,
      borderColor: AppColors.black,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          InitialsAvatar(
            initials: initialsOf(profile?.businessName ?? 'SP'),
            size: 60,
            background: AppColors.red,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(business,
                    style: AppTypography.h3.copyWith(color: AppColors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (profile != null)
                  Text('GSTIN: ${profile!.gstin}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textOnDarkSoft)),
                const SizedBox(height: 6),
                Text(contact,
                    style: AppTypography.small
                        .copyWith(color: AppColors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(mobile,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textOnDarkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteProfileBanner extends StatelessWidget {
  const _CompleteProfileBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.redTint,
      borderColor: AppColors.redTint,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.red),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Complete your business details to place orders and receive GST invoices.',
              style: AppTypography.small,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.red),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
      child: Text(text, style: AppTypography.overline),
    );
  }
}

class AccountMenuItem {
  const AccountMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge = 0,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final int badge;
  final Color color;
}

/// Bordered group of menu rows with dividers — the account / settings list.
class AccountMenuGroup extends StatelessWidget {
  const AccountMenuGroup({super.key, required this.items});

  final List<AccountMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(items[i].icon, size: 19, color: items[i].color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].label,
                              style: AppTypography.title
                                  .copyWith(color: items[i].color)),
                          if (items[i].subtitle != null)
                            Text(items[i].subtitle!,
                                style: AppTypography.caption),
                        ],
                      ),
                    ),
                    if (items[i].badge > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          '${items[i].badge}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
