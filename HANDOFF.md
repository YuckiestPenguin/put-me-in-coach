# Handoff — Put Me In, Coach

Snapshot as of 2026-10-06 (see `git log` for the latest commit). Written so a fresh session can
pick up without the prior conversation.

## What this is

A Flutter **web** app for a youth soccer coach: tracks playing time, prompts for
substitutions, keeps score, and saves finished games. Google sign-in and Firestore
(`users/{uid}/...`). The owner is the only user for now (single coach); they use
it on a phone at the field, so it must work on weak signal.

Repo: `YuckiestPenguin/put-me-in-coach` (public). Work happens directly on `main`.

## Current state

Working and pushed:
- Game: clock with periods, sub reminders, fairness-ordered sub flow, goalie /
  captain / favorite roles, absent players, per-player goals, live score
  (ours / theirs), extra-player banner, end game, summary (start/end time, table).
- Players: **name required, jersey number optional**; stable internal `id` is the
  key everywhere (not the number).
- Leagues (rules: periods, length, players on field, sub interval, extra-player
  threshold) and Teams (name, optional league, roster) — both CRUD, stored in
  Firestore. Half-minute steps for period length and sub interval.
- New game: pick a team (loads roster) and a league (applies rules); both optional.
  A lone team is auto-selected. Roster edits in setup affect that game only.
- Home screen lists saved games (tap = summary, swipe = delete; a cloud-off icon
  marks games not yet synced; league filter chips appear once games span more
  than one league or a league plus no-league), "New game", Teams
  and Leagues icons. Game menu has Home / Add player / Game settings / End game /
  New game.
- Hosting: dev site is live at https://put-me-in-coach-dev.web.app.
- Failed game saves/deletes show a snackbar (`CloudSync.onError`, wired in
  `main.dart`). Offline writes are queued by Firestore, not errors.
- Debug sub-timer menu item is hidden outside debug builds.
- 36 unit tests (game logic + models), `flutter analyze` clean.

**Not done / needs verification**
- **Prod is not deployed.** Before it is: confirm Firestore rules are on prod
  (`firebase deploy --only firestore:rules --project prod` — the owner said they
  ran the setup steps but verify), then `scripts/deploy.sh prod`.
- The owner has **not yet confirmed** the hosted dev site's games list loads after
  the release-build fix (below). Ask them first.
- Native iOS/Android: not set up (see #10). Only web is configured.

## Architecture (where things live)

| Area | Files |
| --- | --- |
| Game state + clock + score + persistence hooks | `lib/models/game_state.dart` (one big `ChangeNotifier`) |
| Models | `lib/models/{player,team,league}.dart` |
| Firestore | `lib/services/cloud_sync.dart` (leagues, teams, games, migrations, `probe()`) |
| Local save (in-progress game) | `lib/services/persistence.dart` (shared_preferences) |
| Screens | `lib/screens/` — home, setup, game, settings, history, leagues, teams (+ edit screens), sign_in |
| Widgets | `lib/widgets/` — sub flow sheet, summary sheet, role sheet, `slow_load_notice` |
| Entry / routing | `lib/main.dart` (auth gate → Home / Setup / Game by `GameState` flags) |
| Rules / hosting | `firestore.rules`, `firebase.json`, `.firebaserc`, `scripts/deploy.sh` |

Data model:
- Firestore: `users/{uid}/leagues/{id}`, `users/{uid}/teams/{id}` (roster inside
  the doc), `users/{uid}/games/{id}` (summary written once at End game),
  legacy `users/{uid}/team/roster` (read once to migrate; no longer written).
- **The game in progress lives in local storage**, not Firestore (must work
  offline and survive reloads). Only the finished game is written to the cloud.
- `GameState.ownerUid` stops one user's local data leaking to another account.
- Saved game summaries carry `teamId/teamName/leagueId/leagueName`, `ourScore`,
  `theirScore`. Older games lack the score fields (handled).

Flow flags in `GameState`: `settingUp` (setup), `gameStarted` (game), `gameEnded`
(frozen, shows summary). Neither set → Home.

## Environments and commands

Two Firebase projects: `put-me-in-coach-dev`, `put-me-in-coach-prod` (aliases
`dev` / `prod` in `.firebaserc`). Pick at build time with
`--dart-define=ENV=dev|prod` (default dev).

```bash
export PATH=/opt/homebrew/bin:$PATH          # Flutter lives here
flutter run -d web-server --web-port 64649 --dart-define=ENV=dev
flutter analyze && flutter test
scripts/deploy.sh dev                          # build + deploy hosting
firebase deploy --only firestore:rules --project dev
```

Full Xcode is **not installed** (command-line tools only), so no iOS/macOS builds
or simulator. Verify on web.

## Gotchas learned the hard way

1. **Release builds were missing Firestore's web plugin** (stale generated plugin
   list from before Firestore was added). Symptom: hosted site spun forever;
   console showed `Int64 accessor not supported by dart2js`. Fixed with
   `flutter clean && flutter pub get`, and `scripts/deploy.sh` now refuses to
   deploy a bundle missing `flutter-fire-fst/auth/core`. If this ever recurs, run
   the clean first.
2. **Browser testing:** the Chrome tab I control is often `visibilityState:
   hidden`, and Flutter web doesn't render frames in a hidden tab, so screenshots
   can show stale spinners and clicks seem to lag. Check `document.visibilityState`
   before trusting a screenshot. Flutter web also often needs a second click, and
   the viewport size changes between screenshots, so re-screenshot before clicking.
   Flutter web has no DOM for widgets; drive it by coordinates.
3. **Service worker caching** serves the previous build after a deploy/rebuild. To
   test a fresh build, unregister the service worker and clear `caches` (JS:
   `navigator.serviceWorker.getRegistrations()` + `caches.keys()`) and reload.
   `firebase.json` sends `no-cache` for entry files to limit this on the hosted site.
4. **Don't run `dart format` over the whole tree** — it reflows unrelated lines.
   Format only files you changed, or skip it.
5. After `flutter pub get`/builds, `macos/Flutter/GeneratedPluginRegistrant.swift`
   gets modified and `ios|macos/**/swiftpm/` folders appear untracked. They are
   tooling noise: `git checkout -- macos` and don't commit the swiftpm folders.
6. `build/` is excluded from analysis (`analysis_options.yaml`); Flutter downloads
   Firebase package sources into `build/macos` which otherwise floods the analyzer.
7. Stream objects are created in `initState` for lists (not inside `build`) so they
   don't resubscribe on every rebuild.
8. Dev Firestore contains the owner's real test data (a team "My Team", league
   "Loudoun Soccer K", etc.). Don't delete data without asking; clean up any test
   data you create.

## Working agreements with the owner

- They ask for commits and pushes explicitly ("commit, push"); don't push unasked.
  Closing an issue is done with `Closes #N` in the commit message.
- Commit trailer: end messages with the `Co-Authored-By:` line given by the
  session's system reminder.
- Outward-facing actions (prod deploy, deleting data) need explicit go-ahead.
- Prefer verifying changes in the browser and reporting honestly what was and
  wasn't tested.
- Tests: add unit tests for model/logic changes in `test/widget_test.dart`.

## Open issues (GitHub)

Ready to pick up:
- **#5** Share a game summary as image/PDF.
- **#6** Seasons (team + league over time). Depends on #1–#3 (done).
- **#10** Native iOS/Android with separate dev/prod Firebase configs (needs Xcode).
- **#15** Widget/integration tests + GitHub Actions CI (largest of the cleanups).

On hold (label `on-hold`): **#8** location + weather, **#11** security hardening
(restrict API keys, App Check, rules tests).

Done since the last snapshot: #4, #13, #14, #16. The league filter (#4) and the
sync-error snackbar/pending icon (#13) were only checked with `flutter analyze` and
unit tests, not in a browser.

Suggested order: #15 → #5 → #6.

## Which model to use

- **Default: Claude Sonnet 5.5** (`claude-sonnet-5-5`) for feature work and the
  small cleanups (#4, #13, #14, #16, #5). The patterns are established and it's
  fast and cheap.
- **Switch to Opus 5.5** (`claude-opus-5-5`) for anything investigative or
  design-heavy: debugging build/runtime problems like the release-build Firestore
  failure (took long to track down), the Seasons data/aggregation design (#6),
  and native platform/Firebase config (#10).
