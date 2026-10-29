## build-b

Android artifacts built from the pinned commit with `targets/b/patches/` applied:

- `b-universal.apk` — premium variant
- `b-freemium-universal.apk` — freemium variant, entitlement granted unconditionally
- `b-source.tar.gz` — corresponding source (GPLv3)

Both APKs are signed with a self-signed certificate, so the store-installed
version has to be uninstalled first. Provider integrations that need publisher
OAuth client ids cannot log in with this build; local storage, WebDAV, S3 and Hub
work.
