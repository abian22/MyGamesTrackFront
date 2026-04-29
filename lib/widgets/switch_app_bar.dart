import 'package:flutter/material.dart';
import '../constants.dart';

class SwitchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const SwitchAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kBgDark,
      elevation: 0,
      title: Row(
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: kSwitchRed, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: kSwitchBlue, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}