# Quickshell development guide

This file governs work under `home/quickshell/`. It is both a beginner-friendly
workflow for Chase and a set of requirements for coding agents. Keep it current
as the shell and its toolchain evolve.

## Project facts

- This is a custom Quickshell configuration, not DMS, Noctalia, or another
  shell distribution. Those projects may be visual references, but do not copy
  their architecture, dependencies, services, or behavior without a deliberate
  decision.
- The target compositor is Hyprland configured with its Lua configuration API.
  Legacy hyprlang dispatcher strings are not valid substitutes.
- `home/quickshell/` is the editable source tree.
- Home Manager deploys it to `~/.config/quickshell`. The deployed files may be
  Nix-store-backed and read-only; never edit them as the source of truth.
- The current baseline is Quickshell 0.3.1 from Nixpkgs. Before relying on a
  version-sensitive API, confirm the installed version with
  `quickshell --version` and consult the documentation for that version.
- `.qmlls.ini` is generated locally by Quickshell and must remain untracked.

## Non-negotiable workflow

Before changing QML, an agent must:

1. Read this file and inspect the relevant existing components.
2. Check the installed Quickshell version. Do not assume examples from search
   results, DMS, Noctalia, GitHub `master`, or an older blog match it.
3. Verify unfamiliar APIs in the versioned official Quickshell documentation.
   If documentation and the installed package appear to differ, inspect the
   installed `.qmltypes` metadata under Quickshell's Nix store path.
4. For compositor behavior, verify the current Hyprland Lua documentation.
   Do not translate an old `hyprctl dispatch ...` example by guesswork.
5. Make the smallest coherent change and preserve a usable shell. Add one
   feature at a time rather than importing a large prebuilt configuration.

After changing QML, an agent must:

1. Confirm the configuration actually loads, not merely that Nix evaluates.
2. Read the Quickshell log and resolve new QML errors and warnings that indicate
   a real runtime problem.
3. Exercise the changed interaction when tooling permits. If a click, scroll,
   keybind, DBus action, or compositor transition was not exercised, say so
   explicitly instead of claiming it works.
4. Check the relevant edge states: missing active window, monitor changes,
   empty models, unavailable services, and objects that may temporarily be
   `null` during startup or reload.
5. Run the Nix evaluation or dry build when Nix/Home Manager wiring changes.
6. Review `git diff --check`, `git diff`, and `git status --short`. New files
   must be added to Git before a Git-backed flake can see them.

## Development and deployment

There are two distinct loops:

### Fast development loop

Run the source tree directly so Quickshell can hot-reload saved files:

```console
quickshell --path "$HOME/.config/flake/home/quickshell"
```

Inspect its log with:

```console
quickshell --path "$HOME/.config/flake/home/quickshell" log --follow
```

Use `quickshell list --all` to distinguish source-tree and deployed instances.
Avoid running two full shell instances when they both own exclusive resources
such as a notification server or the same Hyprland global shortcut. Stop the
specific development instance with the same `--path` selection:

```console
quickshell --path "$HOME/.config/flake/home/quickshell" kill
```

Do not use a short `timeout` launch as the only runtime test. It can prove that
the root component loads, but it cannot prove interaction behavior or stable
operation.

### Deployment loop

After source-tree testing, rebuild NixOS/Home Manager with `nrs` (or the full
`nixos-rebuild switch --flake ...` command). The normal `quickshell` command
then loads the deployed `~/.config/quickshell` configuration. A successful
source-tree run does not replace the Nix evaluation, and a successful Nix
evaluation does not replace the runtime test.

## Hyprland integration

Prefer typed Quickshell APIs over raw dispatcher strings. They express intent,
are easier to inspect, and can handle compositor integration details. For
example, when a `HyprlandWorkspace` object exists, use:

```qml
onClicked: workspace.activate()
```

Only use `Hyprland.dispatch()` when there is no suitable typed method. This
machine uses Hyprland's Lua configuration, so raw requests must use Lua API
syntax. For example:

```qml
Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })")
```

Do not introduce the legacy form below:

```qml
Hyprland.dispatch("workspace " + workspaceId)
```

Quickshell exposes `Hyprland.usingLua`, but it is false until the Hyprland
module initializes. Do not use its initial false value to select and cache a
legacy command. This repository targets Lua mode; write the Lua command
directly unless support for both modes is an explicit requirement. If dual-mode
support is later added, centralize translation in one helper and test both
paths.

Treat these properties as temporarily nullable, particularly during startup,
reload, and monitor changes:

- `Hyprland.focusedWorkspace`
- `Hyprland.focusedMonitor`
- `Hyprland.activeToplevel`
- relationships such as a workspace's monitor

Use `Hyprland.monitorFor(screen)` for per-monitor behavior. Do not assume the
focused monitor is the monitor hosting a particular bar.

## QML design rules

- Keep `shell.qml` as a small composition root. Put windows in `windows/`,
  reusable visual elements in `components/`, feature widgets in `widgets/`, and
  shared state/integrations in `services/` as the project grows. Do not create
  directories or abstraction layers before they have a real consumer.
- Prefer small components with typed `required property` inputs over access to
  undeclared parent context.
- Give roots and referenced children explicit `id` values. Qualify parent
  properties through their IDs instead of relying on unqualified lookup.
- Prefer declarative property bindings over imperative assignments. Keep
  bindings small and free of side effects.
- Use explicit signal-handler parameters, for example
  `onClicked: event => { ... }`, when the event is consumed.
- Use `readonly property` for derived values and design tokens that callers
  must not mutate.
- Keep system state separate from presentation. A reusable visual component
  should receive state and emit intent; a service or owning feature component
  should talk to Hyprland, PipeWire, DBus, or a subprocess.
- Use `ScriptModel` when filtering or transforming a changing model for a
  `Repeater` or `ListView`; a raw JavaScript `filter()` model recreates every
  delegate whenever it changes.
- Use `LazyLoader` for genuinely heavy or initially hidden windows, not for
  every small component.
- Never perform blocking file or process work on the UI thread. Prefer native
  Quickshell services and asynchronous, event-driven APIs.
- Prefer native Quickshell integrations (Hyprland, PipeWire, MPRIS, system
  tray, notifications, UPower, networking, and Bluetooth) over polling shell
  commands. If a subprocess is necessary, pass arguments as a list and avoid a
  shell unless shell syntax is genuinely required.
- Bound text, lists, image sizes, histories, and caches. Desktop shell
  processes are long-lived; unbounded retained objects become leaks in
  practice.
- Keep animation restrained. Animate inexpensive presentation properties and
  avoid complex JavaScript that runs every frame.
- Add stable `reloadableId` values to important windows whose state should be
  preserved across hot reloads.
- Design multi-monitor behavior explicitly. Use `Variants` over
  `Quickshell.screens` for one window per screen and test monitor-specific
  filtering rather than showing global state accidentally.

Follow Qt's conventional declaration order inside an object: `id`, property
declarations, signals, functions, ordinary property assignments, then child
objects. Use four spaces and let `qmlformat` handle mechanical formatting when
it can do so without obscuring the change.

## State, commands, and security

- Store persistent data under `Quickshell.dataDir` or
  `Quickshell.stateDir`, and disposable data under `Quickshell.cacheDir`.
  Do not write generated state into this repository.
- Do not turn arbitrary displayed text into a shell command. Treat window
  titles, notification content, clipboard content, filenames, media metadata,
  and plugin data as untrusted input.
- Use argument arrays with `Quickshell.execDetached()` or `Process.command`.
  If a shell is unavoidable, document why and quote every untrusted value—or
  redesign the boundary so untrusted content is never interpreted.
- A notification daemon, lock screen, authentication prompt, clipboard
  manager, and Polkit agent have correctness or security implications. Build
  them as separate milestones with explicit acceptance tests. Never remove the
  existing fallback until the replacement has been tested.
- Do not add a dependency merely because an inspiration project uses it. Add
  Nix packages deliberately and document which component requires them.

## Tooling and validation notes

- Use the Nix-provided `qmlls`, not Mason's generic Linux binary.
- Keep a generated `home/quickshell/.qmlls.ini` locally so `qmlls` sees
  Quickshell's import paths. It is intentionally ignored by Git.
- `qmlls` is useful but not authoritative. It can report false positives for
  dynamically supplied Quickshell types. Runtime loading and logs remain
  required.
- `qmlformat` is the formatter. Review its changes; normalization and import
  sorting can create noisy or semantic changes.
- `qmllint` cannot necessarily understand Quickshell's runtime-provided module
  environment without matching import paths. Do not silence a runtime issue
  merely because linting is difficult, and do not treat a noisy lint result as
  proof that working QML is broken.

A practical completion checklist for each feature is:

- The QML configuration loads with no new runtime errors.
- Hot reload succeeds after editing each changed QML file.
- The feature works through its actual user interaction.
- Null, empty, unavailable-service, reload, and relevant multi-monitor states
  behave sensibly.
- No replaced desktop component is removed until the replacement is proven.
- Nix evaluation succeeds when packaging or deployment changed.
- The diff contains only intentional source and documentation changes.

## Primary references

- [Quickshell 0.3.1 type reference](https://quickshell.org/docs/v0.3.1/types/)
- [Quickshell QML language guide](https://quickshell.org/docs/v0.3.0/guide/qml-language/)
- [Quickshell Hyprland API](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/Hyprland/)
- [Quickshell reload behavior](https://quickshell.org/docs/v0.3.1/types/Quickshell/Reloadable/)
- [Hyprland Lua dispatchers](https://wiki.hypr.land/Configuring/Basics/Dispatchers/)
- [Qt QML coding conventions](https://doc.qt.io/qt-6/qml-codingconventions.html)
- [Qt Quick best practices](https://doc.qt.io/qt-6/qtquick-bestpractices.html)
- [Qt Quick performance guidance](https://doc.qt.io/qt-6/qtquick-performance.html)

Prefer these versioned, primary sources over snippets from third-party shell
configurations. Inspiration projects are evidence of a possible design, not
evidence that an API is correct for this installation.
