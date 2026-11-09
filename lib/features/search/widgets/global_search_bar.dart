import 'package:flutter/material.dart';
import 'package:quizhub/core/design_system/app_colors.dart';
import 'package:quizhub/core/design_system/app_icons.dart';
import 'package:quizhub/core/design_system/design_tokens.dart';

class GlobalSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const GlobalSearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm...',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 42,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 42,
          ),
          prefixIcon: const Icon(AppIcons.search, size: 22),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: const Icon(AppIcons.close, size: 18),
                onPressed: onClear,
              );
            },
          ),
        ),
      ),
    );
  }
}