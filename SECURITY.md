# Security Policy & API Key Guidelines

## Keeping Secrets Out of Git

- **Never hardcode API keys** in `lib/` or platform config files.
- Use `--dart-define` or `--dart-define-from-file=.env.json` (see `.env.example.json`).
- `.env`, `*.env`, `.env.json`, `*.env.json`, and `lib/env.g.dart` are listed in `.gitignore`.
- Before pushing, double-check staged diffs (`git diff --cached`) to verify no credentials are included.

## Important: Client-Side Apps vs. Compiled Binaries

Keeping keys out of source control protects your **public GitHub repository**, but remember:
- Any key passed via `--dart-define` (or obfuscation tools like `envied`) into a Flutter mobile, desktop, or web app is still bundled into the compiled app binary and sent directly from the user's device.
- **If you distribute compiled builds (APK/IPA/Web) publicly**:
  1. Restrict API keys (e.g., Google AI / Cloud key restrictions by Android package + SHA-1, iOS bundle ID, or HTTP referrer, plus strict daily quota caps), **or**
  2. Put a lightweight backend proxy (e.g., Cloudflare Worker or Cloud Function) in front of WAQI and Gemini so the keys live only on your server.
