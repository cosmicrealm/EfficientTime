# EfficientTime

[中文](README.zh-CN.md) | English

EfficientTime is a local-first macOS AI planning and productivity assistant for turning rough task notes into an executable daily schedule. It keeps the current task visible through the menu bar, a desktop floating panel, and system notifications, so you can focus on execution instead of repeatedly checking what comes next.

Current version: `0.02`

## What It Does

- Turns daily work into time blocks.
- Shows the current task, remaining time, and nearby tasks in an always-on desktop floating panel.
- Provides a clickable 24-hour clock view for seeing which parts of the day are planned, completed, skipped, delayed, or still open.
- Keeps the floating panel visible on the desktop while the app is running; it can be collapsed to reduce screen space.
- Sends proactive reminders when tasks start and end.
- Supports quick manual task entry with title, start time, and end time.
- Uses AI planning to turn rough plan text into editable daily schedule drafts.
- Stores plans and settings locally, with no account or cloud sync requirement.

EfficientTime is not a general todo app, team workspace, or full calendar replacement. It focuses on one thing: helping you execute the plan for the day.

## Screenshots

### Daily Schedule

![Daily Schedule](docs/assets/screenshots/main-plan.svg)

### AI Planning

![AI Planning](docs/assets/screenshots/ai-planning.svg)

### Floating Execution Panel

![Floating Execution Panel](docs/assets/screenshots/floating-panel.svg)

## Basic Usage

1. Open EfficientTime.
2. Choose a date in the `Plan` tab.
3. Add a task with title, start time, and end time.
4. Click `Start Execution`.
5. Use the floating panel to track the current task, countdown, and nearby tasks.
6. Mark tasks as done, skipped, or delayed from the timeline or floating panel.
7. Paste rough plan text into `AI Planning`, generate an editable draft schedule, then apply it to a target date.

## AI Planning

AI planning is an assistant workflow. It does not directly overwrite the final schedule.

```text
Raw plan text -> AI draft -> Local validation and cleanup -> User confirmation -> Day schedule
```

Supported providers:

- DeepSeek
- Volcengine Ark

API keys are configured in `Settings` and should stay local. Do not commit API keys or private planning data to the repository.

## Local Development

Requirements:

- macOS 15 or later
- Swift 6

Run tests:

```bash
swift test
```

Build locally:

```bash
swift build
```

Run for development:

```bash
./scripts/run_app.sh
```

## Packaging

Build the local `.app` bundle:

```bash
./scripts/build_app_bundle.sh
open dist/EfficientTime.app
```

Create a `.dmg` and zip that can be uploaded to a GitHub Release:

```bash
./scripts/package_release.sh 0.02
```

Output:

```text
dist/EfficientTime-0.02.dmg
dist/EfficientTime-0.02-macOS.zip
```

The `.dmg` is the recommended Release asset, while the zip can stay as a fallback. The current package is a local development build. It is not Developer ID signed or notarized yet.

## Project Layout

```text
Sources/EfficientTimeCore
  Domain/       Domain models
  Scheduling/   Local scheduling and validation
  AI/           AI planning interfaces and context packing

Sources/EfficientTimeApp
  App/          App state
  Views/        Main SwiftUI views
  MenuBar/      Menu bar entry
  FloatingPanel/Desktop floating panel
  Notifications/System notifications
  Persistence/ Local persistence and secret storage
```

## Built With Codex

EfficientTime is a vibe coding project built with OpenAI Codex. Most of the product design, SwiftUI implementation, interaction iteration, documentation, and release packaging were built through collaboration with Codex.

Thanks to Codex for helping turn the original product idea into a working local macOS app.

## Release Status

`0.02` is an early preview focused on local daily scheduling, real-time reminders, the floating execution panel, AI draft planning, and a richer execution/status overview for the day. Code signing, notarization, and installer polish can be added in future releases.
