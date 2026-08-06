# Оттер Mobile

Flutter-клиент планировщика **Оттер** для **Android** и **Windows**. UI/UX и API совпадают с [otter-app](../otter-app/) (Nuxt). Папка `otter-app` не изменяется.

## Стек

- Flutter 3.12+, Riverpod, go_router, Dio
- Firebase Auth + Google Sign-In
- Inter (google_fonts), Lucide icons

## Быстрый старт

```bash
cd otter-mobile
cp .env.example .env
# Windows Google Sign-In: обязательно заполните FIREBASE_GOOGLE_DESKTOP_CLIENT_SECRET
# (Google Cloud → Credentials → Desktop OAuth client → Client secret).
# Файл .env в Git не попадает — на каждой машине создаётся локально.
flutter pub get
flutter run -d windows
# или
flutter run -d android
```

## Firebase / Google

**Android** (`com.nbekdev.otter`):

- Файл [`android/app/google-services.json`](android/app/google-services.json) уже подключён (Firebase app `com.nbekdev.otter`).
- Gradle: плагин `com.google.gms.google-services`.
- Google Sign-In: в `.env` задан `FIREBASE_GOOGLE_SERVER_CLIENT_ID` (Web OAuth client из того же JSON).

**Windows** (Firebase Web app + ручной OAuth 2.0 PKCE / loopback):

- В `.env`: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_AUTH_DOMAIN` (Firebase Console → Web app).
- Google Sign-In использует **Desktop** OAuth client (не Web):
  - `FIREBASE_GOOGLE_DESKTOP_CLIENT_ID` — Client ID (есть default в коде / `.env.example`)
  - `FIREBASE_GOOGLE_DESKTOP_CLIENT_SECRET` — **обязателен**, только в локальном `.env`
- Google Cloud → Credentials → Desktop client: redirect на loopback (`http://127.0.0.1`) разрешён для installed apps.
- Firebase Console → Authentication → Sign-in method → **Google** — включён.

Для release-сборки Android добавьте SHA-1 отпечаток в Firebase Console → Project settings → Your apps.

## API

Базовый URL: `API_BASE_URL` (по умолчанию `https://admin.skkamni.ru/api/v1/`).

## Структура

- `lib/core/` — тема, Dio, роутинг, хранение токенов
- `lib/data/services/` — доменные API-сервисы
- `lib/features/` — экраны
- `lib/shared/widgets/` — переиспользуемые компоненты

## Сборка

**Android:**
```bash
flutter build apk --release
```

**Windows** (только на ПК с Windows — кросс-сборка с macOS/Linux недоступна):
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows.ps1
```

Скрипт запускает `analyze`, `test`, `flutter build windows --release` и упаковывает результат в `dist/otter-windows-x64-<version>.zip`.

Готовое приложение: `build/windows/x64/runner/Release/otter_mobile.exe` (рядом — `data/` и DLL плагинов; копируйте всю папку `Release`).
