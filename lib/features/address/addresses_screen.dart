import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/account.dart';
import '../../state/address_controller.dart';

//==============================================================================
// SPOCART — Address management ("My Addresses")
//------------------------------------------------------------------------------
// Saved addresses with edit / delete / set default and Add New Address.
//==============================================================================

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    AppScope.of(context).addresses.load();
  }

  Future<void> _delete(Address a) async {
    final AddressController addresses = AppScope.of(context).addresses;
    final bool ok = await showAppConfirmDialog(
      context,
      title: 'Delete address?',
      message: '${a.contactName} · ${a.summary}',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    await addresses.remove(a.id);
    if (mounted) showAppSnackBar(context, 'Address deleted');
  }

  @override
  Widget build(BuildContext context) {
    final AddressController addresses = AppScope.of(context).addresses;
    return ListenableBuilder(
      listenable: addresses,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'My Addresses'),
          body: AsyncStateView<List<Address>>(
            loading: addresses.loading,
            error: addresses.error,
            data: addresses.loaded ? addresses.addresses : null,
            onRetry: () => addresses.load(force: true),
            isEmpty: (list) => list.isEmpty,
            emptyBuilder: (context) => EmptyStateView(
              icon: Icons.location_on_outlined,
              title: 'No saved addresses',
              message:
                  'Add your shop, warehouse or ground so checkout is one tap.',
              actionLabel: 'Add New Address',
              onAction: () => AppNavigator.toAddressForm(context),
            ),
            builder: (context, list) => ContentWidth(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.xs, AppSpacing.page, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _AddressCard(
                  address: list[i],
                  onEdit: () =>
                      AppNavigator.toAddressForm(context, existing: list[i]),
                  onDelete: () => _delete(list[i]),
                  onSetDefault: list[i].isDefault
                      ? null
                      : () => addresses.setDefault(list[i].id),
                ),
              ),
            ),
          ),
          bottomNavigationBar: BottomActionBar(
            child: PrimaryButton(
              label: 'Add New Address',
              icon: Icons.add_rounded,
              onPressed: () => AppNavigator.toAddressForm(context),
            ),
          ),
        );
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(address.label),
                size: 18, color: AppColors.black),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(address.contactName,
                          style: AppTypography.title),
                    ),
                    if (address.isDefault)
                      const StatusPill(
                        label: 'Default',
                        color: AppColors.red,
                        dense: true,
                      )
                    else
                      StatusPill(
                        label: address.label.label,
                        color: AppColors.textSoft,
                        background: AppColors.surfaceAlt,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(address.summary, style: AppTypography.small),
                Text(formatIndianMobile(address.mobile),
                    style: AppTypography.caption),
                if (onSetDefault != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GhostButton(
                      label: 'Set as default',
                      color: AppColors.textSoft,
                      onPressed: onSetDefault,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                size: 34,
                iconSize: 18,
                color: AppColors.textSoft,
                onPressed: onEdit,
              ),
              AppIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                size: 34,
                iconSize: 18,
                color: AppColors.textSoft,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AddressLabel label) => switch (label) {
        AddressLabel.home => Icons.home_outlined,
        AddressLabel.office => Icons.business_outlined,
        AddressLabel.warehouse => Icons.warehouse_outlined,
        AddressLabel.ground => Icons.stadium_outlined,
        AddressLabel.other => Icons.location_on_outlined,
      };
}
