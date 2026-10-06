# Put Me In, Coach

Kids' soccer playing-time and substitution tracker. Flutter web app backed by
Firebase (Google sign-in + Firestore).

## Environments

Two Firebase projects, chosen at build time with `--dart-define=ENV=dev|prod`
(default `dev`):

| Env  | Project                | URL                                      |
| ---- | ---------------------- | ---------------------------------------- |
| dev  | `put-me-in-coach-dev`  | https://put-me-in-coach-dev.web.app      |
| prod | `put-me-in-coach-prod` | https://put-me-in-coach-prod.web.app     |

## Run locally

```bash
flutter run -d chrome --dart-define=ENV=dev
```

## Deploy

Builds a release for the environment and deploys it to Firebase Hosting.
`prod` asks for confirmation first.

```bash
scripts/deploy.sh dev
scripts/deploy.sh prod
```

Firestore security rules deploy separately:

```bash
firebase deploy --only firestore:rules --project dev
firebase deploy --only firestore:rules --project prod
```

Hosting sends `no-cache` for the entry files and service worker (see
`firebase.json`) so a new deploy shows up on the next load instead of a stale
cached build.

## Install on a phone

Open the site in the phone's browser, then "Add to Home Screen" (iOS Safari:
Share → Add to Home Screen). It runs full screen like an app.
