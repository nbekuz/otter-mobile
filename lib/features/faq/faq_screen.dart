import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/faq_provider.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/primary_button.dart';

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(faqProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faq = ref.watch(faqProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? OtterColors.darkSurface : Colors.white;
    final bg = isDark ? OtterColors.darkBg : OtterColors.grayLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.chevronLeft),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? OtterColors.darkSurfaceAlt
                          : OtterColors.grayLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Частые вопросы',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? OtterColors.darkText : OtterColors.sberBlack,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: ref.read(faqProvider.notifier).setSearch,
                onTapOutside: dismissKeyboardOnTapOutside,
                onEditingComplete: KeyboardDismisser.dismiss,
                decoration: InputDecoration(
                  hintText: 'Поиск по вопросам...',
                  prefixIcon: const Icon(LucideIcons.search, size: 20),
                  suffixIcon: faq.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(faqProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: faq.loading
                  ? const Center(child: CircularProgressIndicator())
                  : faq.error != null
                      ? _ErrorState(
                          message: faq.error!,
                          onRetry: () => ref.read(faqProvider.notifier).load(),
                        )
                      : faq.filteredItems.isEmpty
                          ? const Center(
                              child: Text(
                                'Вопросы не найдены',
                                style: TextStyle(color: OtterColors.sberGray),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: faq.filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = faq.filteredItems[index];
                                return Card(
                                  color: surface,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    children: [
                                      ListTile(
                                        title: Text(
                                          item.question,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        trailing: Icon(
                                          item.isOpen
                                              ? LucideIcons.chevronUp
                                              : LucideIcons.chevronDown,
                                          size: 20,
                                          color: OtterColors.sberGray,
                                        ),
                                        onTap: () => ref
                                            .read(faqProvider.notifier)
                                            .toggle(item.id),
                                      ),
                                      if (item.isOpen)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            16,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              item.answer,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.5,
                                                color: OtterColors.sberGray,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: PrimaryButton(
                label: 'Связаться с нами',
                onPressed: () => context.go('/app/settings?openContact=1'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
