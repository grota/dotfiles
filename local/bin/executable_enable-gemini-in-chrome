#!/bin/bash

# Enable Gemini in Chrome
# Patches Chrome config to unlock Gemini features for non-US users
# Supports: macOS, Linux

set -e

echo ""
echo "🚀 Gemini in Chrome Enabler"
echo ""

# Detect OS and set config path
OS_TYPE=$(uname -s)
case "$OS_TYPE" in
    Darwin)
        CHROME_STATE=~/Library/Application\ Support/Google/Chrome/Local\ State
        CHROME_PROCESS="Google Chrome"
        ;;
    Linux)
        CHROME_STATE=~/.config/google-chrome/Local\ State
        CHROME_PROCESS="chrome"
        ;;
    *)
        echo "💡 Windows users, please run this PowerShell command instead:"
        echo "irm https://raw.githubusercontent.com/user/Gemini-in-Chrome/main/install.ps1 | iex"
        exit 1
        ;;
esac

# Check if Chrome is running
check_chrome_running() {
    pgrep -x "$CHROME_PROCESS" > /dev/null 2>&1
}

if check_chrome_running; then
    echo "⚠️  Chrome is running!"
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        echo "📌 Please quit Chrome completely (Cmd+Q) before proceeding"
    else
        echo "📌 Please quit Chrome completely before proceeding"
    fi
    echo ""
    read -p "Press Enter after closing Chrome... " -r
    echo ""

    if check_chrome_running; then
        echo "❌ Chrome is still running. Please quit Chrome and try again."
        exit 1
    fi
fi

# Check if config file exists
if [ ! -f "$CHROME_STATE" ]; then
    echo "❌ Chrome config not found: $CHROME_STATE"
    exit 1
fi

# Backup original file
cp "$CHROME_STATE" "$CHROME_STATE.bak"
echo "✓ Backed up: Local State.bak"

# Apply patches
if [[ "$OS_TYPE" == "Darwin" ]]; then
    sed -i '' -e 's/"is_glic_eligible":[[:space:]]*false/"is_glic_eligible":true/g' \
              -e 's/"variations_country":"[^"]*"/"variations_country":"us"/g' \
              -e 's/\("variations_permanent_consistency_country":\[[^]]*\)"[^"]*"\]/\1"us"]/g' \
              "$CHROME_STATE"
else
    sed -i -e 's/"is_glic_eligible":[[:space:]]*false/"is_glic_eligible":true/g' \
           -e 's/"variations_country":"[^"]*"/"variations_country":"us"/g' \
           -e 's/\("variations_permanent_consistency_country":\[[^]]*\)"[^"]*"\]/\1"us"]/g' \
           "$CHROME_STATE"
fi

# Verify changes
echo ""
errors=0
if grep -q '"is_glic_eligible":true' "$CHROME_STATE"; then
    echo "✓ enabled"
else
    echo "⚠️  is_glic_eligible not modified (field may not exist)"
    ((errors++)) || true
fi
if grep -q '"variations_country":"us"' "$CHROME_STATE"; then
    echo "✓ set to us"
else
    echo "⚠️  variations_country not modified (field may not exist)"
    ((errors++)) || true
fi

echo ""
if [ $errors -eq 0 ]; then
    echo "✅ Done! Restart Chrome to apply changes."
else
    echo "⚠️  Some changes may not have applied. Check your Chrome version."
fi
