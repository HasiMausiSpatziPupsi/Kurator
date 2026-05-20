# Distribution / Release

## Builds

- Android: `flutter build apk` oder `flutter build appbundle`
- iOS: Xcode / `flutter build ipa` (Signing, Provisioning)
- Google Books optional: `flutter build apk --dart-define=GOOGLE_BOOKS_API_KEY=dein_key`

## Datenschutz & Stores

- Opt-in für Online-Metadaten in der App (Schalter); keine automatischen Abrufe ohne Nutzeraktion.
- Dienste: Open Library; optional Google Books mit API-Key.
- Datenschutzerklärung und Support-Kontakt für Play Console / App Store bereitstellen.

## Side-load / Open Source

- APK/IPA oder GitHub Releases mit kurzer Installationsanleitung und Hinweis auf manuelle Netzwerk-/Kamera-Berechtigungen.

## Google Drive (optional, später)

- OAuth-Client (Android/iOS/Web) in der Google Cloud Console anlegen, `google_sign_in` mit Drive-Scope (`drive.file`) konfigurieren; Backup-ZIP analog zum lokalen Export hochladen.
