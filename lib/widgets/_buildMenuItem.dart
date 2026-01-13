import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';

class MenuItemWidget extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isTop;
  final bool isBottom;
  final bool isDestructive;
  final bool isChangeTheme;
  final VoidCallback? onTap;
  final bool isSwitched;
  final ValueChanged<bool>? onThemeChanged;

  const MenuItemWidget({
    Key? key,
    required this.icon,
    required this.text,
    this.isTop = false,
    this.isBottom = false,
    this.isDestructive = false,
    this.isChangeTheme = false,
    this.onTap,
    this.isSwitched = true,
    this.onThemeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color iconColor = isDestructive ? dangerColor : lightBackgroundColor;
    final Color iconDarkColor = isDestructive
        ? dangerDarkColor
        : darkThemeColor;

    final Color textColor = isDestructive ? dangerColor : Colors.black;
    final Color darkTextColor = isDestructive
        ? dangerDarkColor
        : darkThemeTextColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isDestructive
              ? (isSwitched
                    ? dangerTransparentColor
                    : dangerTransparentDarkColor)
              : (isSwitched
                    ? lightThemeBackgroundColor
                    : darkThemeSecondaryColor),
          borderRadius: BorderRadius.vertical(
            top: isTop ? const Radius.circular(12) : Radius.zero,
            bottom: isBottom ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isSwitched ? iconColor : iconDarkColor,
                    size: 24,
                  ),
                  const SizedBox(width: 15),
                  Text(
                    text,
                    style: bodyTextStyle.copyWith(
                      color: isSwitched ? textColor : darkTextColor,
                    ),
                  ),
                ],
              ),
              if (!isDestructive)
                isChangeTheme
                    ? Switch(
                        value: isSwitched,
                        onChanged: (value) => onThemeChanged?.call(value),
                        activeThumbColor: Colors.blueAccent,
                        inactiveThumbColor: darkThemeColor,
                        inactiveTrackColor: darkElevatedButtonColor,
                        trackOutlineColor: WidgetStatePropertyAll(
                          isSwitched ? Colors.blueAccent : darkThemeColor,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward,
                        color: isSwitched
                            ? lightBackgroundColor
                            : darkThemeColor,
                        size: 24,
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
