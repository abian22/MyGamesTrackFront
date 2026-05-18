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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            kAppIconAsset,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(width: 32, height: 32),
          ),
        ],
      ),
    );
  }
}
