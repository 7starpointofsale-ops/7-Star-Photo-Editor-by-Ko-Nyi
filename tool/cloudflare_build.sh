#!/usr/bin/env bash
set -euo pipefail

# Cloudflare Pages build image does not guarantee a Flutter SDK. Keep the SDK
# outside the repository and build a release that uses the same-origin
# /fileconv Pages Function.
FLUTTER_ROOT="${HOME}/flutter-sdk"

if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"
fi

"${FLUTTER_ROOT}/bin/flutter" config --no-analytics
"${FLUTTER_ROOT}/bin/flutter" pub get
"${FLUTTER_ROOT}/bin/flutter" build web --release \
  --dart-define=FILECONV_PROXY_BASE=/fileconv
