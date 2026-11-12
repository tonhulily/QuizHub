import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../data/models/search_models.dart';
import 'search_result_item.dart';

class SearchResultList extends StatelessWidget {
  const SearchResultList({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundSecondary,
      child: PagedListView<GlobalSearchItem>(
        padding: EdgeInsets.zero,
        itemSpacing: ComponentTokens.postGap,
        itemBuilder: (context, item) {
          return SearchResultItem(item: item);
        },
      ),
    );
  }
}
