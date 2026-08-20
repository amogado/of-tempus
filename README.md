# of-tempus

Automatic time tracking driven by your [OmniFocus](https://www.omnigroup.com/omnifocus/) selection: **select a task, the clock starts; move on, it stops.**

Time entries land in [Tempus](https://github.com/amogado/tempus) — or any [Toggl Track v9-compatible](https://engineering.toggl.com/docs/) API — with:

- **client** = the OmniFocus folder containing the project
- **project** = the OmniFocus project
- **description** = the task title

Clients and projects are created on the fly if they don't exist yet.

## How it works

```
OmniFocus (selected row)
   │  polled every 3s (needs ~6s of stable selection — debounce)
   ▼
oftempus-daemon ──POST /time_entries (duration -1)──▶ Tempus / Toggl v9 API
   │
   └─ selection changed / cleared / OmniFocus quit ──PATCH /time_entries/:id/stop
```

The timer follows the **selection only**: it keeps running while you work on the task in other apps, and stops when you select another row or deselect.

## Install

```zsh
git clone https://github.com/amogado/of-tempus.git
cd of-tempus
./install.sh
```

Requires [jq](https://jqlang.github.io/jq/) (`brew install jq`). On first run, macOS will ask permission to control OmniFocus (Automation) — accept it.

## Configuration

`~/.config/oftempus/config.json`:

```json
{
  "tempus_base_url": "https://your-tempus-instance.example.com",
  "workspace": "My Workspace"
}
```

Your API token goes in the macOS Keychain, never in a file:

```zsh
security add-generic-password -a oftempus -s oftempus-token -w "YOUR_TOKEN" -U
```

## Troubleshooting

```zsh
tail ~/.config/oftempus/daemon.log   # START/STOP history
tail ~/.config/oftempus/daemon.err   # daemon errors
launchctl kickstart -k gui/$UID/com.oftempus.daemon   # restart the daemon
```

## Uninstall

```zsh
launchctl bootout gui/$UID/com.oftempus.daemon
rm ~/Library/LaunchAgents/com.oftempus.daemon.plist ~/bin/oftempus-daemon ~/bin/oftempus-selection.applescript
rm -r ~/.config/oftempus
security delete-generic-password -s oftempus-token
```

## License

[PolyForm Noncommercial 1.0.0](LICENSE.md) — free for personal and other noncommercial use. See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution terms.
