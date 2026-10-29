## build-c

iOS artifacts built from the pinned commit with `targets/cmi/patches/` applied
(premium compile condition, baked into the project file) and no code signing:

- `cmi-unsigned.ipa` / `cmi-unsigned.app.zip`
- `cmi-source.tar.gz` — corresponding source (GPLv3)

Unsigned products carry no entitlements: they run in the simulator, or on device
after re-signing with your own identity and a profile that provides the app group
and keychain access group.
