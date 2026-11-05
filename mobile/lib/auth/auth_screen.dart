import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'auth_controller.dart';
import '../widgets/connection_status.dart';
import '../widgets/loading_skeleton.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, this.onGuest});
  final AuthController auth;
  final VoidCallback? onGuest;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool register = false, busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit({bool google = false}) async {
    if (busy || (!google && !form.currentState!.validate())) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (google) {
        await widget.auth.loginGoogle();
      } else if (register) {
        await widget.auth.register(name.text, email.text, password.text);
      } else {
        await widget.auth.login(email.text, password.text);
      }
    } on ApiFailure catch (e) {
      if (mounted && !e.cancelled) {
        setState(
          () => error = register && e.mayHaveCompleted
              ? '${e.message} Kayıt tamamlanmış olabilir; yeniden kayıt yerine giriş yapmayı deneyebilirsin.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Giriş tamamlanamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('taze kal')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: MotionReveal(
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const ConnectionBanner(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.eco_outlined,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        register
                            ? 'Tazeliğe\nbir adım daha.'
                            : 'Yeniden\nhoş geldin.',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        register
                            ? 'Profilini oluştur, mutfağını kendi hesabında takip et.'
                            : 'Hesabına giriş yap, mutfağına kaldığın yerden devam et.',
                      ),
                      const SizedBox(height: 28),
                      if (register) ...[
                        TextFormField(
                          controller: name,
                          enabled: !busy,
                          maxLength: 80,
                          autofillHints: const [AutofillHints.name],
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Adın'),
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'En az 2 karakter gir.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'E-posta'),
                        validator: (v) =>
                            v != null &&
                                RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(v.trim()) &&
                                v.trim().length <= 254
                            ? null
                            : 'Geçerli bir e-posta gir.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: password,
                        enabled: !busy,
                        obscureText: hidden,
                        maxLength: 128,
                        autofillHints: [
                          register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          helperText: register
                              ? 'En az 10 karakter kullan.'
                              : null,
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => hidden = !hidden),
                            tooltip: hidden
                                ? 'Şifreyi göster'
                                : 'Şifreyi gizle',
                            icon: Icon(
                              hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null ||
                                v.isEmpty ||
                                (register && v.length < 10)
                            ? (register
                                  ? 'En az 10 karakter gir.'
                                  : 'Şifreni gir.')
                            : null,
                        onFieldSubmitted: (_) => submit(),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (busy) SlowRequestHint(auth: widget.auth),
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: busy
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        register
                                            ? 'Hesap oluşturuluyor…'
                                            : 'Giriş yapılıyor…',
                                      ),
                                    ),
                                  ],
                                )
                              : Text(register ? 'Hesap oluştur' : 'Giriş yap'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('veya'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: busy ? null : () => submit(google: true),
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Google ile devam et'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                register = !register;
                                error = null;
                                password.clear();
                                form.currentState?.reset();
                              }),
                        child: Text(
                          register
                              ? 'Zaten hesabım var · Giriş yap'
                              : 'Hesabım yok · Kayıt ol',
                        ),
                      ),
                      if (widget.onGuest != null)
                        TextButton(
                          onPressed: () async {
                            try {
                              if (busy) {
                                await widget.auth.cancelAuthentication();
                              }
                              if (mounted) widget.onGuest!();
                            } on ApiFailure catch (e) {
                              if (mounted && !e.cancelled) {
                                setState(() => error = e.message);
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => error =
                                      'Bekleyen giriş kapatılamadı. Tekrar dene.',
                                );
                              }
                            }
                          },
                          child: const Text('Hesapsız devam et'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
