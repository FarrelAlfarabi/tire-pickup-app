#!/bin/bash
# Vercel build: Vercel has no Flutter, so download it, then build the web app.
set -e
if [ ! -d "$HOME/flutter-sdk" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter-sdk"
fi
export PATH="$HOME/flutter-sdk/bin:$PATH"
export CI=true
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
