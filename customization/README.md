# Branding Layer

This fork includes a lightweight branding layer intended for local development first.

## What is included

- `src/browser/pages/rune-theme.css`: login page visual overrides.
- `customization/i18n/en.json`: optional custom UI strings loaded with `--i18n`.

## Local run example

After building code-server, run it with branding flags:

```sh
./out/node/entry.js --auth password --app-name "Rune IDE" --welcome-text "Welcome to Rune IDE" --i18n ./customization/i18n/en.json
```

The custom stylesheet is loaded automatically from `login.html` as part of this fork.

## Next layer

For full workbench styling and AI UI, keep those as extensions so upstream rebases stay low-friction.

## Docker dev launch

Build the canonical Rune image from this repository and run a local instance.
The build uses the initialized, pinned `lib/vscode` checkout, applies
`patches/series`, packages Rune, and
copies the package and customization assets into a clean runtime stage:

```sh
docker compose -f docker-compose.dev.yml up -d --build
```

Initialize the pinned submodule before the first build:

```sh
git submodule update --init --recursive
```

Open `http://127.0.0.1:8484` and log in with the password from `RUNE_DEV_PASSWORD`.
The image defaults to the Rune application name, welcome text, and English
customization file, so Compose does not overlay or replace upstream files.

To stop it:

```sh
docker compose -f docker-compose.dev.yml down
```
