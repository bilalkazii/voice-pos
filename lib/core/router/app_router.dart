import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Phase 0 navigation: bottom-nav shell with placeholder screens.
///
/// The default route `/` represents the cart / current-sale screen and
/// will be built out in later phases.
abstract final class AppRouter {
  static GoRouter create() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return Scaffold(
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: navigationShell.goBranch,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.shopping_cart_outlined),
                    selectedIcon: Icon(Icons.shopping_cart),
                    label: 'Bill',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: 'Products',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Reports',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const CartScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/products',
                  builder: (context, state) => const ProductsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/history',
                  builder: (context, state) => const HistoryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/reports',
                  builder: (context, state) => const ReportsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
        // Checkout sits outside the bottom-nav shell: full-screen step with
        // a back button. Phase 2 is a placeholder only.
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
      ],
    );
  }
}
