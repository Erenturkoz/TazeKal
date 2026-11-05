# Repository working agreement

- Never publish, push, deploy, create a GitHub repository or open a PR unless the human explicitly requests it. The owner manages GitHub.
- Keep every change ready for Git: source and lockfiles belong in Git; secrets, device data, local configuration, generated files and binaries do not.
- Before adding tooling or generating artifacts, extend `.gitignore` for its local outputs. Keep source assets, migrations, configuration examples and dependency lockfiles versioned; never hide them just because they are generated once. Run `node tools/check-repo.mjs` before handoff.
- Use `.env.example` and `mobile/config/*.example.json` to document configuration. Never commit real passwords, tokens, signing keys, or service accounts.
- `mobile/` is the Flutter Android/iOS application. Root HTML/JS/CSS files are a retained legacy prototype; do not extend them for mobile features.
- `backend/` is the Node.js/TypeScript API. Keep business logic outside controllers and validate request data.
- Preserve local product data. Never clear an emulator, uninstall the app, reset a database or migrate guest data without the user's explicit consent.
- For Android emulator updates, use `mobile/run-emulator.ps1` (`adb install -r` then `flutter attach`). Do not use `flutter run` as a recovery installer on an emulator with user data: its install-failure fallback may automatically uninstall the app.
- Before handing off, run checks relevant to the change. For auth, include authorization, session revocation and cross-user isolation tests. Report unverified external integrations explicitly.
- Keep `README.md`, API setup docs and config examples in step with behavior. Do not claim Google sign-in or email delivery is live without real configuration and verification.
