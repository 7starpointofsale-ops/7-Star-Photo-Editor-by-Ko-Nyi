# Myanmar Passport / License Photo Editor

Production Flutter Web app for Cloudflare Pages. There are no accounts, database, persistent application storage, or browser-visible API credentials. Photos stay in browser memory except when a user explicitly chooses FileConv background removal.

## Production architecture

```text
Browser -> Cloudflare Pages static Flutter Web -> /fileconv/* Pages Function -> FileConv
```

The release build uses the same-origin relative path `/fileconv`; it never uses `localhost`. The Pages Function in `functions/fileconv/[[path]].js` accepts only these FileConv routes:

- `POST /api/remove-bg/upload`
- `GET /api/remove-bg/status`
- `GET /api/remove-bg/download`

It forwards only the request body and content type required by FileConv. It does not store files, proxy arbitrary URLs, or use any API key/secret.

## Cloudflare Pages settings

Create a Pages project from this repository. Set:

| Setting | Value |
| --- | --- |
| Production branch | your default branch |
| Build command | `bash tool/cloudflare_build.sh` |
| Build output directory | `build/web` |
| Root directory | repository root |
| Environment variables | none required |

Cloudflare Pages automatically deploys the repository's `functions/` directory alongside `build/web`. The included `wrangler.jsonc` declares `build/web` as the Pages output directory.

The build script downloads the Flutter stable SDK in the temporary Pages build environment, runs `flutter pub get`, then creates a release build with `FILECONV_PROXY_BASE=/fileconv`. No local proxy is needed after deployment.

## Optional direct deployment

If you prefer a direct upload after building on a computer with Flutter and Wrangler installed:

```bash
flutter pub get
flutter build web --release --dart-define=FILECONV_PROXY_BASE=/fileconv
npx wrangler pages deploy build/web --project-name=myanmar-passport-photo-editor
```

Use Git-based Pages deployment for normal updates; it builds and deploys without leaving a computer or PowerShell running.

## Local development only

The local proxy is only for development, because a local browser cannot call FileConv directly due to CORS:

```bash
node tool/fileconv_proxy.mjs
flutter run -d chrome --dart-define=FILECONV_PROXY_BASE=http://localhost:8788/fileconv
```

This command is not used by the deployed site.

## Cloth Change

ImageHub has no verified supported public API configured in this project. The existing Cloth Change adapter remains intentionally unavailable and does not fabricate results.
