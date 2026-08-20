#!/bin/zsh
# of-tempus installer — copies scripts to ~/bin, sets up the launchd daemon.
set -eu

REPO_DIR="${0:A:h}"
LABEL="com.oftempus.daemon"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CONF_DIR="$HOME/.config/oftempus"

mkdir -p "$HOME/bin" "$CONF_DIR" "$HOME/Library/LaunchAgents"
cp "$REPO_DIR"/bin/oftempus-daemon "$REPO_DIR"/bin/oftempus-selection.applescript "$HOME/bin/"
chmod +x "$HOME/bin/oftempus-daemon"
[[ -f "$CONF_DIR/config.json" ]] || cp "$REPO_DIR/config.example.json" "$CONF_DIR/config.json"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>$HOME/bin/oftempus-daemon</string>
	</array>
	<key>KeepAlive</key>
	<true/>
	<key>RunAtLoad</key>
	<true/>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
	</dict>
	<key>StandardErrorPath</key>
	<string>$CONF_DIR/daemon.err</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"

echo "of-tempus installed."
echo "- Edit $CONF_DIR/config.json (Tempus URL + workspace name)"
echo "- Store your API token: security add-generic-password -a oftempus -s oftempus-token -w \"YOUR_TOKEN\" -U"
echo "- Select a task in OmniFocus: a running time entry starts; deselect to stop it."
