# Put Me In, Coach

Kids' soccer playing-time and substitution tracker. Flutter web app backed by
Firebase (Google sign-in + Firestore).

## What it does

Built for a youth soccer coach using a phone at the field, so it works on weak
signal.

- **Game clock** with periods and a sub reminder at a set interval; the
  substitution flow suggests who has played the least.
- **Roles and roster:** goalie, captain, favorite, absent players, extra-player
  banner. Players need a name; the jersey number is optional.
- **Score and goals:** live score (ours / theirs) and per-player goals.
- **Teams and leagues:** a team is a name, optional league and a roster; a
  league holds the rules (periods, length, players on field, sub interval).
  Starting a game picks one of each and applies them.
- **History:** finishing a game saves a summary; the home screen lists past
  games (tap for the summary, swipe to delete). Games not yet synced show a
  cloud-off icon.

## Architecture

- `lib/models/game_state.dart` — one `ChangeNotifier` holding the game in
  progress: clock, sub logic, score, flow flags (`settingUp`, `gameStarted`,
  `gameEnded`). Models for players, teams and leagues sit beside it.
- `lib/services/cloud_sync.dart` — all Firestore access under `users/{uid}`:
  `leagues`, `teams` (roster inside the doc) and `games` (one doc per finished
  game).
- `lib/services/persistence.dart` — the game in progress is saved locally
  (shared_preferences), not in Firestore, so it works offline and survives a
  reload. Only the finished game goes to the cloud.
- `lib/screens/`, `lib/widgets/` — UI; `lib/main.dart` gates on sign-in and
  routes to Home, Setup or Game from the `GameState` flags.

```bash
flutter analyze && flutter test
```

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
