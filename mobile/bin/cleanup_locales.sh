#!/bin/bash
# Run this once to clean up unused locale files
cd "$(dirname "$0")/.."
rm -f lib/l10n/app_hi.arb lib/l10n/app_ta.arb lib/l10n/app_te.arb
echo "Removed hi/ta/te ARB files. Only en and mr are supported."
