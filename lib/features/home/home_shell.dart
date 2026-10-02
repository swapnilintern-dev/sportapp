import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../account/account_tab.dart';
import '../cart/cart_screen.dart';
import '../catalog/categories_screen.dart';
import '../orders/orders_screen.dart';
import 'home_tab.dart';
import 'offer_popup.dart';

//==============================================================================
// SPOCART — Home shell (bottom navigation)
//------------------------------------------------------------------------------
// Hosts the five root tabs in an IndexedStack so each keeps its scroll
// position. Android back on a non-Home tab returns to Home first; on Home it
// leaves the app. Deep screens switch tabs through AppServices.homeTab.
//==============================================================================

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final ValueNotifier<HomeTab> _tab = AppScope.of(context).homeTab;

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTabChanged);
    // Kick off the catalogue fetch once for every tab.
    final AppServices services = AppScope.of(context);
    services.catalog.load();
    services.notifications.load();
    // Asked once per launch so the Account menu knows whether the rewards
    // programme is running; it hides the entry until the business turns it on.
    services.rewards.load();
    // The offer waits a few seconds so it never lands on a buyer mid-tap, and
    // the controller hands it over at most once per launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowOfferPopup(context);
    });
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  void _select(HomeTab tab) {
    if (_tab.value == tab) return;
    HapticFeedback.selectionClick();
    _tab.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final HomeTab current = _tab.value;

    return PopScope(
      canPop: current == HomeTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(HomeTab.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: current.index,
          children: const [
            HomeTabView(),
            CategoriesScreen(isTab: true),
            CartScreen(isTab: true),
            OrdersScreen(isTab: true),
            AccountTab(),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: services.cart,
          builder: (context, _) => _BottomNav(
            current: current,
            cartCount: services.cart.lineCount,
            onSelect: _select,
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.current,
    required this.cartCount,
    required this.onSelect,
  });

  final HomeTab current;
  final int cartCount;
  final ValueChanged<HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: AppShadows.bottomBar,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            children: [
              _NavItem(
                tab: HomeTab.home,
                current: current,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                onSelect: onSelect,
              ),
              _NavItem(
                tab: HomeTab.categories,
                current: current,
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Categories',
                onSelect: onSelect,
              ),
              _NavItem(
                tab: HomeTab.cart,
                current: current,
                icon: Icons.shopping_cart_outlined,
                activeIcon: Icons.shopping_cart_rounded,
                label: 'Cart',
                badge: cartCount,
                onSelect: onSelect,
              ),
              _NavItem(
                tab: HomeTab.orders,
                current: current,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Orders',
                onSelect: onSelect,
              ),
              _NavItem(
                tab: HomeTab.account,
                current: current,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Account',
                onSelect: onSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.current,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onSelect,
    this.badge = 0,
  });

  final HomeTab tab;
  final HomeTab current;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<HomeTab> onSelect;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final bool selected = tab == current;
    final Color color = selected ? AppColors.red : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: () => onSelect(tab),
          radius: 36,
          highlightShape: BoxShape.rectangle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? activeIcon : icon, size: 24, color: color),
                  if (badge > 0)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints:
                            const BoxConstraints(minWidth: 17, minHeight: 17),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: AppRadius.pillAll,
                          border:
                              Border.all(color: AppColors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
