import 'package:flutter/material.dart';
import '../data/form_draft.dart';

class DraftStatusLabel extends StatelessWidget {
  const DraftStatusLabel({super.key, required this.draft});
  final FormDraft draft;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DraftStatus>(
    valueListenable: draft,
    builder: (context, status, _) => status == DraftStatus.idle
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              status == DraftStatus.saving
                  ? 'Taslak kaydediliyor…'
                  : status == DraftStatus.saved
                  ? 'Taslak bu cihazda saklandı'
                  : 'Taslak kaydedilemedi; bilgiler bu ekranda duruyor.',
              style: TextStyle(
                fontSize: 12,
                color: status == DraftStatus.failed
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
  );
}
