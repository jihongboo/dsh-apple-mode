#!/usr/bin/env bash
#
# dsh-apple-xcode uninstaller
# Removes the `apple` agent preset and the Xcode-exported skills that
# install.sh placed into the DSH skill root.
#
set -euo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
AGENTS_HOME="${DSH_AGENTS_HOME:-$HOME/.agents}"
PRESET_DIR="$DSH_HOME/.agent-presets/apple"

echo "==> Removing preset: $PRESET_DIR"
rm -rf "$PRESET_DIR"
echo "    removed."

echo "==> Removing Xcode-exported skills from $AGENTS_HOME/skills"
for name in \
  adopt-c-bounds-safety \
  app-intents-specialist \
  app-intents-whats-new-27 \
  audit-xcode-security-settings \
  building-document-based-swiftui-applications \
  device-interaction \
  modernize-tests \
  swiftui-specialist \
  swiftui-whats-new-27 \
  uikit-app-modernization; do
  if [ -d "$AGENTS_HOME/skills/$name" ]; then
    echo "  - $name"
    rm -rf "$AGENTS_HOME/skills/$name"
  fi
done
echo "    done."

echo "Done. Your other skills (xcsift, app-store-aso, ...) are untouched."
