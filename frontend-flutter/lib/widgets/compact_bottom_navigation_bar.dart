import 'package:material_ui/material_ui.dart';

/// Compact four-tab navigation for the HHK app shell.
///
/// NavigationBar already wraps its content with a bottom SafeArea. Its height
/// is therefore [contentHeight] plus *one* system inset (iOS home indicator).
/// Do not add another SafeArea/Padding around this widget or place the labels
/// inside the system gesture region. The former 80dp content height left an
/// unnecessarily large empty gap below the labels on iPhones.
class CompactBottomNavigationBar extends StatelessWidget {
  const CompactBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const double contentHeight = 60;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
        height: contentHeight,
        labelPadding: const EdgeInsets.only(top: 2),
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Môn học',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Luyện tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      );
}
