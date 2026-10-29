## build-c

iOS artifacts built from the pinned commit with `targets/c/patches/` applied
(premium compile condition, baked into the project file) and no code signing:

- `c-unsigned.ipa` / `c-unsigned.app.zip`
- `c-source.tar.gz` — corresponding source (GPLv3)

Unsigned products carry no entitlements: they run in the simulator, or on device
after re-signing with your own identity and a profile that provides the app group
and keychain access group.
