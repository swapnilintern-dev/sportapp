import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/account.dart';
import '../../data/repositories/repositories.dart';
import '../../state/session_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/team_controller.dart';
import '../support/help_sheet.dart';
import 'account_tab.dart';
import 'business_registration_screen.dart';

//==============================================================================
// SPOCART — Account sub-screens
//------------------------------------------------------------------------------
// BusinessDetailsScreen      — edit the business profile (reuses registration)
// GstDetailsScreen           — GSTIN summary with copy + edit
// TeamMembersScreen          — add / remove colleagues
// NotificationSettingsScreen — per-channel toggles
// PrivacySecurityScreen      — data controls + policy links
// HelpSupportScreen          — contact channels + FAQs
// AboutScreen                — version + company links
//==============================================================================

class BusinessDetailsScreen extends StatelessWidget {
  const BusinessDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BusinessRegistrationScreen(
      allowSkip: false,
      title: 'Business Details',
      subtitle: 'These details appear on your GST invoices.',
    );
  }
}

class GstDetailsScreen extends StatelessWidget {
  const GstDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = AppScope.of(context).session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final BusinessProfile? p = session.session?.profile;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'GST Details'),
          body: p == null
              ? EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No GST details yet',
                  message:
                      'Add your GSTIN so invoices carry your input tax credit.',
                  actionLabel: 'Add Business Details',
                  onAction: () => AppNavigator.toBusinessDetails(context),
                )
              : ContentWidth(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('GSTIN', style: AppTypography.overline),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(p.gstin,
                                      style: AppTypography.h2
                                          .copyWith(letterSpacing: 1)),
                                ),
                                AppIconButton(
                                  icon: Icons.copy_rounded,
                                  tooltip: 'Copy',
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: p.gstin));
                                    if (context.mounted) {
                                      showAppSnackBar(context, 'GSTIN copied',
                                          tone: SnackTone.success);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: AppSpacing.lg),
                            _DetailRow('Legal / Trade Name', p.businessName),
                            _DetailRow('Business Type', p.businessType.label),
                            _DetailRow('State Code', p.gstin.length >= 2
                                ? p.gstin.substring(0, 2)
                                : '—'),
                            _DetailRow('PAN', p.gstin.length >= 12
                                ? p.gstin.substring(2, 12)
                                : '—'),
                            _DetailRow('Billing Email', p.email),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Invoices are issued with 18% GST (CGST 9% + SGST 9% for intra-state supply). Keep your GSTIN current to claim input credit.',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SecondaryButton(
                        label: 'Edit GST Details',
                        icon: Icons.edit_outlined,
                        color: AppColors.black,
                        onPressed: () => AppNavigator.toBusinessDetails(context),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: AppTypography.small)),
          Expanded(child: Text(value, style: AppTypography.bodyStrong)),
        ],
      ),
    );
  }
}

//------------------------------------------------------------------------------
// Team members
//------------------------------------------------------------------------------
class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  @override
  void initState() {
    super.initState();
    AppScope.of(context).team.load();
  }

  Future<void> _add() async {
    final TeamMember? member = await showAppBottomSheet<TeamMember>(
      context,
      title: 'Add Team Member',
      builder: (context) => const _TeamMemberForm(),
    );
    if (member == null || !mounted) return;
    await AppScope.of(context).team.save(member);
    if (mounted) {
      showAppSnackBar(context, '${member.name} added to your team',
          tone: SnackTone.success);
    }
  }

  Future<void> _remove(TeamMember m) async {
    final bool ok = await showAppConfirmDialog(
      context,
      title: 'Remove ${m.name}?',
      message: 'They will no longer be able to order for your business.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!ok || !mounted) return;
    await AppScope.of(context).team.remove(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final TeamController team = services.team;
    return ListenableBuilder(
      listenable: team,
      builder: (context, _) {
        final BusinessProfile? owner = services.session.session?.profile;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'Team Members'),
          body: AsyncStateView<List<TeamMember>>(
            loading: team.loading,
            error: team.error,
            data: team.loaded ? team.members : null,
            onRetry: () => team.load(force: true),
            builder: (context, members) => ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.xs, AppSpacing.page, 96),
                children: [
                  if (owner != null)
                    _MemberTile(
                      name: owner.contactName,
                      mobile: owner.mobile,
                      role: TeamRole.owner.label,
                    ),
                  for (final TeamMember m in members)
                    _MemberTile(
                      name: m.name,
                      mobile: m.mobile,
                      role: m.role.label,
                      onRemove: () => _remove(m),
                    ),
                  if (members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.lg),
                      child: EmptyStateView(
                        icon: Icons.group_outlined,
                        title: 'No team members yet',
                        message:
                            'Add purchasers or accounts staff so they can order and view invoices for your business.',
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: BottomActionBar(
            child: PrimaryButton(
              label: 'Add Team Member',
              icon: Icons.person_add_alt_1_outlined,
              onPressed: _add,
            ),
          ),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.name,
    required this.mobile,
    required this.role,
    this.onRemove,
  });

  final String name;
  final String mobile;
  final String role;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        child: Row(
          children: [
            InitialsAvatar(initials: initialsOf(name), size: 40),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.title),
                  Text(formatIndianMobile(mobile), style: AppTypography.caption),
                ],
              ),
            ),
            StatusPill(
              label: role,
              color: onRemove == null ? AppColors.red : AppColors.textSoft,
              background:
                  onRemove == null ? AppColors.redTint : AppColors.surfaceAlt,
              dense: true,
            ),
            if (onRemove != null)
              AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Remove',
                size: 32,
                iconSize: 18,
                color: AppColors.textMuted,
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamMemberForm extends StatefulWidget {
  const _TeamMemberForm();

  @override
  State<_TeamMemberForm> createState() => _TeamMemberFormState();
}

class _TeamMemberFormState extends State<_TeamMemberForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _mobile = TextEditingController();
  TeamRole _role = TeamRole.purchaser;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(TeamMember(
      id: Ids.local(),
      name: _name.text.trim(),
      mobile: _mobile.text.trim(),
      role: _role,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _name,
              label: 'Name',
              required: true,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.minLength(v, 2, field: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _mobile,
              label: 'Mobile Number',
              required: true,
              prefixText: '+91  ',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.mobile,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdownField<TeamRole>(
              label: 'Role',
              value: _role,
              items: TeamRole.values.where((r) => r != TeamRole.owner).toList(),
              labelOf: (r) => r.label,
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Add Member', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

//------------------------------------------------------------------------------
// Notification settings
//------------------------------------------------------------------------------
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final AppSettings s = settings.settings;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'Notification Settings'),
          body: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  clip: true,
                  child: Column(
                    children: [
                      _Toggle(
                        title: 'Order updates',
                        subtitle: 'Placed, shipped, out for delivery, delivered',
                        value: s.orderUpdates,
                        onChanged: (v) =>
                            settings.update(s.copyWith(orderUpdates: v)),
                      ),
                      const Divider(),
                      _Toggle(
                        title: 'Special offers',
                        subtitle: 'Seasonal deals and bulk discounts',
                        value: s.offers,
                        onChanged: (v) =>
                            settings.update(s.copyWith(offers: v)),
                      ),
                      const Divider(),
                      _Toggle(
                        title: 'Price drops',
                        subtitle: 'When a wishlisted product gets cheaper',
                        value: s.priceDrops,
                        onChanged: (v) =>
                            settings.update(s.copyWith(priceDrops: v)),
                      ),
                      const Divider(),
                      _Toggle(
                        title: 'New products',
                        subtitle: 'New arrivals in your categories',
                        value: s.newProducts,
                        onChanged: (v) =>
                            settings.update(s.copyWith(newProducts: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Transactional messages about your orders and invoices are always delivered.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.white,
      activeTrackColor: AppColors.red,
      title: Text(title, style: AppTypography.title),
      subtitle: Text(subtitle, style: AppTypography.caption),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 2),
    );
  }
}

//------------------------------------------------------------------------------
// Privacy & security
//------------------------------------------------------------------------------
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  Future<void> _clearLocalData(BuildContext context) async {
    final bool ok = await showAppConfirmDialog(
      context,
      title: 'Clear local data?',
      message:
          'Your cart, wishlist and cached data on this device will be removed and you will be signed out. Orders and invoices stay with your account.',
      confirmLabel: 'Clear & Sign Out',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!ok || !context.mounted) return;
    final AppServices services = AppScope.of(context);
    services.cart.clear();
    services.wishlist.clear();
    await services.signOut();
    if (context.mounted) AppNavigator.toLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'Privacy & Security'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text('How we protect your account', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'You sign in with a one-time code sent to your mobile number — there is no password to leak. '
              'Your session stays on this device only; sign out from Settings on shared devices.\n\n'
              'Business details (name, GSTIN, contact) are used solely for invoicing and delivery. '
              'We never sell your data.',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            AccountMenuGroup(
              items: [
                AccountMenuItem(
                  icon: Icons.policy_outlined,
                  label: 'Privacy Policy',
                  subtitle: 'Opens spocart.in',
                  onTap: () =>
                      SupportLauncher.website(context, AppInfo.privacyUrl),
                ),
                AccountMenuItem(
                  icon: Icons.gavel_outlined,
                  label: 'Terms of Service',
                  subtitle: 'Opens spocart.in',
                  onTap: () => SupportLauncher.website(context, AppInfo.termsUrl),
                ),
                AccountMenuItem(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Clear local data & sign out',
                  subtitle: 'Removes cart and cached data from this device',
                  color: AppColors.red,
                  onTap: () => _clearLocalData(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//------------------------------------------------------------------------------
// Help & support
//------------------------------------------------------------------------------
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<(String, String)> _faqs = <(String, String)>[
    (
      'What is the minimum order?',
      'Every product has its own MOQ (minimum order quantity) shown on the product page. Per-unit prices drop as you order more — see Bulk Pricing.'
    ),
    (
      'Do I get a GST invoice?',
      'Yes. A GST invoice is generated for every order and can be downloaded from Orders → Invoices.'
    ),
    (
      'How do I pay?',
      'Pay instantly by UPI (scan the QR or use our UPI ID), or use Business Credit and settle within 30 days once your account is approved.'
    ),
    (
      'Can I get custom jerseys?',
      'Yes — use Custom / Team Order to upload your design, pick a product and request a quote. We print crests, names and numbers.'
    ),
    (
      'How long is delivery?',
      'Typically 3–7 working days across India depending on quantity and location. Track every order from the Orders tab.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'Help & Support'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            AccountMenuGroup(
              items: [
                AccountMenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat on WhatsApp',
                  subtitle: 'Fastest response',
                  color: AppColors.red,
                  onTap: () => SupportLauncher.whatsapp(context,
                      message: 'Hi SPOCART, I need help with my account.'),
                ),
                AccountMenuItem(
                  icon: Icons.call_outlined,
                  label: 'Call ${SupportContacts.phoneDisplay}',
                  subtitle: SupportContacts.hours,
                  onTap: () => SupportLauncher.call(context),
                ),
                AccountMenuItem(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email ${SupportContacts.email}',
                  subtitle: 'For invoices, GST and account queries',
                  onTap: () => SupportLauncher.email(context,
                      subject: 'SPOCART app support'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Frequently asked', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                children: [
                  for (int i = 0; i < _faqs.length; i++) ...[
                    if (i > 0) const Divider(),
                    ExpansionTile(
                      title: Text(_faqs[i].$1, style: AppTypography.title),
                      iconColor: AppColors.red,
                      collapsedIconColor: AppColors.textMuted,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_faqs[i].$2,
                              style: AppTypography.bodyMuted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//------------------------------------------------------------------------------
// About
//------------------------------------------------------------------------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'About SPOCART'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const Center(child: BrandLogo(height: 80)),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppInfo.tagline,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: AppColors.textSoft),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Version ${AppInfo.version}',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'SPOCART is a B2B sports supply platform for retailers, academies, schools, clubs and institutions. '
              'Bulk pricing on every product, GST invoices on every order, and custom team kits printed to your design.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AccountMenuGroup(
              items: [
                AccountMenuItem(
                  icon: Icons.language_rounded,
                  label: 'spocart.in',
                  onTap: () => SupportLauncher.website(context),
                ),
                AccountMenuItem(
                  icon: Icons.mail_outline_rounded,
                  label: SupportContacts.email,
                  onTap: () => SupportLauncher.email(context),
                ),
                AccountMenuItem(
                  icon: Icons.call_outlined,
                  label: SupportContacts.phoneDisplay,
                  onTap: () => SupportLauncher.call(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              '© ${DateTime.now().year} SPOCART. All rights reserved.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
