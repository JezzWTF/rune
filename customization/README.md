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

Run a local dev instance without compiling the full fork:

```sh
docker compose -f docker-compose.dev.yml up -d --build
```

Open `http://127.0.0.1:8484` and log in with the password from `RUNE_DEV_PASSWORD`.

To stop it:

```sh
docker compose -f docker-compose.dev.yml down
```
