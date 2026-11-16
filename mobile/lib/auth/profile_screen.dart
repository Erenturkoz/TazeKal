import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'auth_controller.dart';
import '../legal/legal_screen.dart';
import '../widgets/connection_status.dart';
import '../widgets/loading_skeleton.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.onLogout,
    this.onLocalLogout,
    this.onImport,
    this.onDeleteAccount,
    this.guestCount = 0,
  });
  final AuthController auth;
  final Future<void> Function() onLogout;
  final Future<void> Function()? onLocalLogout;
  final Future<void> Function()? onImport;

  /// Deletes the account permanently. Receives the password for password accounts.
  final Future<void> Function(String? password)? onDeleteAccount;
  final int guestCount;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final name = TextEditingController(text: widget.auth.user?.displayName);
  bool busy = false, imported = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on ApiFailure catch (e) {
      if (mounted && !e.cancelled) {
        setState(() => error = e.message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) setState(() => error = 'İşlem tamamlanamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> localLogout() async {
    if (busy || widget.onLocalLogout == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu cihazdan çıkış yapılsın mı?'),
        content: const Text(
          'Bu cihazdaki oturum bilgileri kaldırılır; ürünlerin korunur. Sunucudaki oturumun iptali doğrulanamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bu cihazdan çık'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await act(widget.onLocalLogout!);
  }

  Future<void> logout() async {
    ApiFailure? failure;
    await act(() async {
      try {
        await widget.onLogout();
      } on ApiFailure catch (e) {
        failure = e;
        rethrow;
      }
    });
    if (mounted &&
        failure?.unavailable == true &&
        widget.onLocalLogout != null) {
      await localLogout();
    }
  }

  Future<void> deleteAccount() async {
    final user = widget.auth.user;
    if (busy || user == null || widget.onDeleteAccount == null) return;
    final usesPassword = user.providers.contains('password');
    // The dialog owns its text field; it returns the password ('' for Google) or null.
    final secret = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteAccountDialog(usesPassword: usesPassword),
    );
    if (secret == null || !mounted) return;
    await act(() => widget.onDeleteAccount!(usesPassword ? secret : null));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) => content(context),
  );

  Widget content(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Oturum sona erdi')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Giriş ekranına dön'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: MotionReveal(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const ConnectionBanner(),
                  if (busy) SlowRequestHint(auth: widget.auth),
                  CircleAvatar(
                    radius: 36,
                    child: Text(
                      user.displayName.isEmpty
                          ? '?'
                          : user.displayName.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(user.email, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    user.emailVerified
                        ? 'E-posta doğrulandı'
                        : 'E-posta henüz doğrulanmadı',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: name,
                    enabled: !busy,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Adın'),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (name.text.trim().length < 2) {
                              setState(() => error = 'En az 2 karakter gir.');
                              return;
                            }
                            act(() async {
                              await widget.auth.rename(name.text);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profilin güncellendi.'),
                                  ),
                                );
                              }
                            });
                          },
                    child: const Text('Değişiklikleri kaydet'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Giriş yöntemlerin',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (user.providers.contains('password'))
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.alternate_email),
                      title: Text('E-posta ve şifre'),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link),
                    title: Text(
                      user.providers.contains('google')
                          ? 'Google hesabı bağlı'
                          : 'Google hesabını bağla',
                    ),
                    subtitle: user.providers.contains('google')
                        ? null
                        : const Text('Aynı e-posta adresine ait hesabını seç.'),
                    onTap: busy || user.providers.contains('google')
                        ? null
                        : () => act(widget.auth.linkGoogle),
                  ),
                  if (!imported &&
                      widget.guestCount > 0 &&
                      widget.onImport != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Bu cihazdaki misafir ürünleri',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.guestCount} ürün henüz bir hesaba bağlı değil. İstersen bu hesaba taşıyıp diğer cihazlarınla eşitleyebilirsin.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    'Ürünler bu hesaba taşınsın mı?',
                                  ),
                                  content: const Text(
                                    'Misafir ürünleri bu hesaba ait olacak ve misafir görünümünden kalkacak. Bağlantı kurulduğunda hesabına eşitlenecek.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Vazgeç'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Taşı'),
                                    ),
                                  ],
                                ),
                              );
                              if (yes == true) {
                                await act(() async {
                                  await widget.onImport!();
                                  if (mounted) setState(() => imported = true);
                                });
                              }
                            },
                      child: const Text('Misafir ürünlerimi taşı'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Yasal', style: Theme.of(context).textTheme.titleMedium),
                  const LegalLinks(alignment: WrapAlignment.start),
                  if (widget.onDeleteAccount != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Hesabı sil',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hesabını ve sunucudaki tüm verilerini kalıcı olarak silebilirsin.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : deleteAccount,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Hesabımı sil'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Ürünlerin hesabına ait alanda saklanır. Çevrimdışı değişikliklerin cihazda korunur ve bağlantı geldiğinde sunucuya eşitlenir. Taslakların yalnız bu cihazda tutulur.',
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : logout,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Çıkış yap'),
                ),
              ),
              if (widget.onLocalLogout != null)
                AnimatedBuilder(
                  animation: Listenable.merge([widget.auth, widget.auth.api]),
                  builder: (context, _) =>
                      widget.auth.offline ||
                          widget.auth.api.connection ==
                              ApiConnection.unavailable ||
                          !widget.auth.api.configured
                      ? TextButton(
                          onPressed: busy ? null : localLogout,
                          child: const Text('Yalnızca bu cihazdan çıkış yap'),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.usesPassword});
  final bool usesPassword;
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final password = TextEditingController();
  bool understood = false, hidden = true;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        understood && (!widget.usesPassword || password.text.isNotEmpty);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
      title: const Text('Hesabın kalıcı olarak silinsin mi?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hesabın, tüm oturumların ve sunucudaki bütün ürün kayıtların silinir. '
              'Bu hesaba ait ürünlerin bu cihazdaki kopyası da kaldırılır. '
              'Bu işlem geri alınamaz.',
            ),
            const SizedBox(height: 8),
            const Text('Hesapsız kullandığın misafir ürünlerine dokunulmaz.'),
            const SizedBox(height: 16),
            if (widget.usesPassword)
              TextField(
                key: const Key('delete-password'),
                controller: password,
                obscureText: hidden,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Şifreni onayla',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => hidden = !hidden),
                    tooltip: hidden ? 'Şifreyi göster' : 'Şifreyi gizle',
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              )
            else
              const Text(
                'Onayladığında güvenliğin için Google hesabınla yeniden doğrulaman istenecek.',
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: understood,
              onChanged: (v) => setState(() => understood = v ?? false),
              title: const Text('Bu işlemin geri alınamayacağını anlıyorum.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: ready
              ? () => Navigator.pop(
                  context,
                  widget.usesPassword ? password.text : '',
                )
              : null,
          child: const Text('Hesabımı kalıcı olarak sil'),
        ),
      ],
    );
  }
}
