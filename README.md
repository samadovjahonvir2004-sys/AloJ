# AloJ

**AloJ** — Telegram API asosidagi norasmiy messenjer. *Alo, Jahon!*

AloJ is an unofficial messenger built on the Telegram API and the open-source
[Telegram for Android](https://github.com/DrKLO/Telegram) client. It is not affiliated
with or endorsed by Telegram.

## License

Licensed under the GNU GPL v2 or later, the same as the original Telegram for Android
source. See [LICENSE](LICENSE).

## Build

The repository holds `aloj.patch`, applied on top of the upstream Telegram for Android commit pinned in the workflow. APKs are built automatically by GitHub Actions (`.github/workflows/build.yml`).
Required repository secrets: `ALOJ_API_HASH`, `ALOJ_KEY_PASSWORD`.
