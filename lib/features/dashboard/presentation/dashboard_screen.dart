import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tabler_icons/tabler_icons.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const Key markerKey = Key('dashboard-screen');

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  static const List<_DashboardTab> _tabs = [
    _DashboardTab(
      label: 'Home',
      assetPath: 'assets/icons/home_filled.svg',
      title: 'Dashboard Home',
      description: 'Placeholder content for the main dashboard view.',
    ),
    _DashboardTab(
      label: 'Wallet',
      assetPath: 'assets/icons/wallet_filled.svg',
      title: 'Wallet',
      description: 'Placeholder content for balances and transactions.',
    ),
    _DashboardTab(
      label: 'Analysis',
      assetPath: 'assets/icons/chart_pie_filled.svg',
      title: 'Analysis',
      description: 'Placeholder content for insights and trends.',
    ),
    _DashboardTab(
      label: 'Profile',
      assetPath: 'assets/icons/user_filled.svg',
      title: 'Profile',
      description: 'Placeholder content for user profile and settings.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = _tabs[_currentIndex];

    return Scaffold(
      key: DashboardScreen.markerKey,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _DashboardContent(
          tab: tab,
          theme: theme,
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onChanged: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
      ),
    );
  }
}

class _DashboardTab {
  const _DashboardTab({
    required this.label,
    required this.assetPath,
    required this.title,
    required this.description,
  });

  final String label;
  final String assetPath;
  final String title;
  final String description;
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.tab,
    required this.theme,
  });

  final _DashboardTab tab;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8FAFC);

    return ColoredBox(
      color: background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          _HeaderRow(theme: theme),
          const SizedBox(height: 20),
          const _StatGrid(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            TablerIcons.user,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Hi, Fahmi',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('👋'),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Welcome back, Proma',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            TablerIcons.bell,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _StatCard(
          label: 'All Projects',
          value: '234',
          icon: TablerIcons.briefcase,
          iconColor: Color(0xFFF59E0B),
        ),
        _StatCard(
          label: 'Active Project',
          value: '23',
          icon: TablerIcons.circle_check,
          iconColor: Color(0xFF22C55E),
        ),
        _StatCard(
          label: 'All Users',
          value: '234',
          icon: TablerIcons.users,
          iconColor: Color(0xFF8B5CF6),
        ),
        _StatCard(
          label: 'All Milestones',
          value: '23',
          icon: TablerIcons.flag_3,
          iconColor: Color(0xFFF97316),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF4F4F5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onChanged,
  });

  final int currentIndex;
  final List<_DashboardTab> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1E88E5);
    const inactiveColor = Color(0xFF9AA9C4);

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          const indicatorWidth = 34.0;
          final indicatorLeft =
              (tabWidth * currentIndex) + (tabWidth / 2) - (indicatorWidth / 2);

          return Container(
            height: 80,
            color: Colors.white,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: indicatorLeft,
                  top: 6,
                  child: Container(
                    width: indicatorWidth,
                    height: 3,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(tabs.length, (index) {
                    final tab = tabs[index];
                    final isActive = index == currentIndex;

                    return Expanded(
                      child: InkWell(
                        onTap: () => onChanged(index),
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                tab.assetPath,
                                width: 26,
                                height: 26,
                                colorFilter: ColorFilter.mode(
                                  isActive ? activeColor : inactiveColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tab.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color:
                                        isActive ? activeColor : inactiveColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
