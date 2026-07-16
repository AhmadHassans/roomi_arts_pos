import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../backup/backup_view.dart';
import '../help/help_view.dart';
import '../reports/reports_view.dart';
import '../return_screen/return_view.dart';
import '../sale/sale_view.dart';
import '../sales_list/sales_list_view.dart';
import '../settings/settings_view.dart';
import '../staff/staff_view.dart';
import '../stock/stock_view.dart';
import 'shell_controller.dart';

/// One navigation item. [ownerOnly] entries are hidden from cashiers.
class _NavItem {
  final IconData icon;
  final String label;
  final bool ownerOnly;
  const _NavItem(this.icon, this.label, {this.ownerOnly = false});
}

/// Fixed index -> screen map. Indices never change so the sidebar stays stable.
const List<_NavItem> _navItems = [
  _NavItem(Icons.point_of_sale, 'Sale'),
  _NavItem(Icons.inventory_2, 'Stock'),
  _NavItem(Icons.assignment_return, 'Return'),
  _NavItem(Icons.receipt_long, 'Records'),
  _NavItem(Icons.bar_chart, 'Reports', ownerOnly: true),
  _NavItem(Icons.backup, 'Backup', ownerOnly: true),
  _NavItem(Icons.group, 'Staff', ownerOnly: true),
  _NavItem(Icons.settings, 'Settings', ownerOnly: true),
];

/// The app shell: fixed left sidebar + swapping body. Same layout on every
/// screen so muscle memory forms fast. Any pointer activity resets the
/// auto-lock timer.
class ShellView extends StatelessWidget {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ShellController());

    return Listener(
      onPointerDown: (_) => AuthService.to.registerActivity(),
      onPointerSignal: (_) => AuthService.to.registerActivity(),
      child: Scaffold(
        body: Row(
          children: [
            const _Sidebar(),
            Expanded(
              child: Column(
                children: [
                  const _TopBar(),
                  Expanded(child: Obx(() => _bodyFor(c.current.value))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bodyFor(int index) {
    // Defense in depth: even if an owner-only index is reached somehow, a
    // cashier is sent back to the Sale screen.
    if (_navItems[index].ownerOnly && !AuthService.to.isOwner) {
      return const SaleView();
    }
    switch (index) {
      case 0:
        return const SaleView();
      case 1:
        return const StockView();
      case 2:
        return const ReturnView();
      case 3:
        return const SalesListView();
      case 4:
        return const ReportsView();
      case 5:
        return const BackupView();
      case 6:
        return const StaffView();
      case 7:
        return const SettingsView();
      default:
        return const SaleView();
    }
  }
}

/// Top bar showing who is logged in, plus Lock and Log out.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.to;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.panelBorder)),
      ),
      child: Row(
        children: [
          const Spacer(),
          Obx(() {
            final u = auth.current.value;
            if (u == null) return const SizedBox.shrink();
            return Row(
              children: [
                Icon(
                    u.isOwner
                        ? Icons.admin_panel_settings
                        : Icons.point_of_sale,
                    color: AppColors.violet),
                const SizedBox(width: 8),
                Text(u.username,
                    style: const TextStyle(
                        fontSize: Sizes.bodyText, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.violetTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(u.roleLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.violetDark)),
                ),
              ],
            );
          }),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: auth.lock,
            icon: const Icon(Icons.lock, size: 18),
            label: const Text('Lock'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () => _confirmLogout(auth),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(AuthService auth) async {
    final ok = await askYesNo(
      title: 'Log out?',
      message: 'You will need to type your password again to get back in.',
      yesText: 'Yes, log out',
    );
    if (ok) auth.logout();
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShellController>();
    return Container(
      width: Sizes.sidebarWidth,
      color: AppColors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shop name at the top of the sidebar.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                const Icon(Icons.storefront, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppText.shopName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: Sizes.titleText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Only the items this role may use. Owner sees everything. Scrolls
          // if the list is taller than the window (keeps Help pinned below).
          Expanded(
            child: Obx(() {
              final isOwner = AuthService.to.isOwner;
              // touch current.value so a user switch rebuilds the menu
              AuthService.to.current.value;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < _navItems.length; i++)
                      if (!_navItems[i].ownerOnly || isOwner)
                        Obx(() => _SidebarButton(
                              icon: _navItems[i].icon,
                              label: _navItems[i].label,
                              selected: c.current.value == i,
                              onTap: () => c.go(i),
                            )),
                  ],
                ),
              );
            }),
          ),
          // Small "Help" button in the corner. Always labelled.
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: HelpView.open,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(0, Sizes.buttonHeight),
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Sizes.radius),
                ),
              ),
              icon: const Icon(Icons.help_outline),
              label: const Text('Help', style: TextStyle(fontSize: Sizes.bodyText)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(Sizes.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(Sizes.radius),
          onTap: onTap,
          child: Container(
            height: Sizes.buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon,
                    size: 26,
                    color: selected ? AppColors.teal : Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Sizes.bodyText,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.teal : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
