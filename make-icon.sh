#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Generating AppIcon.icns..."
swift run -c release MakeIcon