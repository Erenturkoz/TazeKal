import 'package:flutter/material.dart';
import 'legal_texts.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});
  final LegalDocument document;

  static Future<void> open(BuildContext context, LegalDocument document) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => LegalScreen(document: document)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(document.updated, style: theme.textTheme.bodySmall),
                for (final section in document.sections) ...[
                  const SizedBox(height: 20),
                  Text(section.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  SelectableText(section.body),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Kullanım Koşulları · Gizlilik Politikası" links, reused on sign-up and profile.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.alignment = WrapAlignment.center});
  final WrapAlignment alignment;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: alignment,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton(
        onPressed: () => LegalScreen.open(context, termsOfUse),
        child: const Text('Kullanım Koşulları'),
      ),
      TextButton(
        onPressed: () => LegalScreen.open(context, privacyPolicy),
        child: const Text('Gizlilik Politikası'),
      ),
    ],
  );
}
