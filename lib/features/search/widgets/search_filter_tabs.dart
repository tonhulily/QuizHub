import 'package:flutter/material.dart';

import '../../../data/models/search_models.dart';

class SearchFilterTabs extends StatelessWidget {
  final SearchType selectedType;
  final ValueChanged<SearchType> onChanged;

  const SearchFilterTabs({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: SearchType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = SearchType.values[index];
          final selected = selectedType == type;

          return ChoiceChip(
            label: Text(type.label),
            selected: selected,
            onSelected: (_) => onChanged(type),
            selectedColor: theme.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          );
        },
      ),
    );
  }
}