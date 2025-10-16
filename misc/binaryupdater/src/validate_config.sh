#!/bin/bash

# Simple configuration validator
CONFIG_FILE="$1"

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 <config_file>"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "✅ Config file exists: $CONFIG_FILE"
echo ""
echo "📋 Config file contents:"
echo "========================"
cat "$CONFIG_FILE"
echo "========================"
echo ""

echo "🔍 Testing field extraction:"

# Test each field extraction
fields=("project_name" "download_dir" "binary_dir" "service_name" "binary_names" "platform" "upgrade_method" "download_url_template")

for field in "${fields[@]}"; do
    echo -n "  $field: "
    if grep -q "^$field:" "$CONFIG_FILE"; then
        value=$(grep "^$field:" "$CONFIG_FILE" | sed 's/'"$field"': *//' | tr -d '"'"'"'')
        if [[ -n "$value" ]]; then
            echo "✅ '$value'"
        else
            echo "⚠️  (empty value)"
        fi
    else
        echo "❌ (not found)"
    fi
done

echo ""
echo "🔧 Potential issues to check:"
echo "  - Make sure there are no extra spaces before field names"
echo "  - Make sure colons are followed by spaces"
echo "  - Make sure there are no tabs (use spaces only)"
echo "  - Make sure paths with ~ are quoted if they contain spaces"
