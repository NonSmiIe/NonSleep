# NonSleep

A small menu bar app that keeps a MacBook working with the lid closed — no external
display needed. Made so that long-running jobs (AI agents, builds, downloads) carry on
while the Mac sits closed on a desk.

## What it does

- **One switch** in the menu bar: *Stay awake with lid closed*.
- **Saves power while closed**: when the lid closes, the Mac goes into Low Power mode;
  when it opens, your previous energy mode comes back.
- **Battery cut-off**: on battery, when the charge drops to the level you pick
  (10–50%, 20% by default), the mode switches off and the Mac goes to sleep.
- **Heat cut-off**: if macOS reports serious thermal pressure or the battery reaches
  45 °C, the mode switches off and a closed Mac goes to sleep.

After a cut-off the switch stays off until you turn it on again; the menu says why.

## Things to know

- While the switch is on, the Mac does not sleep at all — not with the lid open either.
- Low Power mode is applied whenever the lid is closed, also when the Mac is docked to
  an external display.
- A closed Mac under load in a bag has nowhere to shed heat. The heat cut-off is a
  safety net, not a licence to do that.
- Quitting the menu bar app does not change the mode: the helper keeps it, and keeps
  watching battery and heat. Turn the switch off before quitting if you want sleep back.

## Install

Requires macOS 14 or later and the Xcode command line tools (`xcode-select --install`).
No Apple developer certificate is involved: the app is built on your Mac.

```sh
git clone https://github.com/NonSmiIe/NonSleep.git
cd NonSleep
./scripts/install.sh
```

The script asks for your password once to install the root helper.

To remove everything and restore the settings:

```sh
./scripts/uninstall.sh
```

## How it works

macOS forces sleep on lid close unless the system setting `disablesleep` is on, and only
root can change it (`pmset -a disablesleep 1`). So NonSleep has two parts:

- **`NonSleep.app`** — the menu bar UI. It holds no privileges.
- **`com.nonsmile.nonsleep.helper`** — a small root daemon run by launchd. It owns the
  mode: sets `disablesleep`, switches the energy mode on lid close and open, and checks
  battery and heat every 5 seconds while the mode is on. It accepts XPC connections only
  from root and the user logged in at the Mac.

`disablesleep` survives reboots, so the helper is what keeps it honest: on every start it
puts the setting back in line with the switch, and it restores the energy mode if it was
interrupted with the lid closed.

Installed files:

| Path | What |
| --- | --- |
| `/Applications/NonSleep.app` | menu bar app |
| `/Library/PrivilegedHelperTools/com.nonsmile.nonsleep.helper` | root helper |
| `/Library/LaunchDaemons/com.nonsmile.nonsleep.helper.plist` | launchd job |
| `/Library/Application Support/NonSleep/state.json` | the switch and the threshold |

## Development

```sh
swift test                              # logic tests
swift run NonSleepHelper --probe        # print lid, battery and heat readings
./scripts/build.sh                      # build/NonSleep.app
```

## License

MIT
