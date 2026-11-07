# DevPocket

A macOS menu bar app that keeps everyday developer tools one click or one keystroke away: a JWT decoder, a JSON formatter, Base64 and an epoch converter.

Copy something, press `⌃⌥Space`, and DevPocket opens the right tool with it already filled in.

Everything runs locally. Nothing you paste leaves your Mac, and nothing you paste is written to disk.

## Tools

| Tool | `⌘` | What it does |
|---|---|---|
| **JWT Decoder** | `⌘1` | Shows the header and payload as formatted JSON, the issued, not-before and expiry times, and whether the token is valid, expired or not yet valid. A leading `Bearer ` is fine. It decodes only and **does not verify the signature**. |
| **JSON Formatter** | `⌘2` | Checks the JSON as you type. Pretty-prints with 2 or 4 spaces or tabs, minifies, and can sort keys. Key order and numbers stay exactly as written, unless you sort keys. Errors say where the problem is, e.g. *Invalid value around line 1, column 6*. |
| **Base64** | `⌘3` | Encodes and decodes, with a URL-safe (Base64URL) option. Decoding accepts both alphabets and missing padding. A swap button feeds the output back in as the input. |
| **Epoch Converter** | `⌘4` | Converts Unix timestamps to dates and back. Numbers can be in seconds, milliseconds, microseconds or nanoseconds; the unit is worked out from the number's size. Dates can be ISO 8601, RFC 2822, `2023-11-14 22:13:20`, `2023-11-14`, or `now`. It shows Unix seconds and milliseconds, ISO 8601 in UTC and in local time, RFC 2822, a readable date and how long ago it was. With nothing typed, it shows the current time, live. |

## Opening DevPocket

- **Floating bubble.** A small round button that floats above other windows on every desktop.
  - Click it to show or hide the tool window.
  - Drag it anywhere; it remembers where you left it.
  - Right-click it to jump straight to a tool, hide the bubble, or quit.
  - It grows when you hover, squishes when pressed, and ripples when clicked. These animations turn off when Reduce Motion is on.
- **Menu bar icon (🔧).** Lists every tool, plus the settings below.
- **`⌃⌥Space`** shows or hides DevPocket from any app.

### It opens with what you copied

When the window opens, DevPocket checks the clipboard once. If it recognizes what's there, it switches to the matching tool, fills it in, and shows a **From clipboard** label in the title bar.

| On the clipboard | Opens |
|---|---|
| A JWT, with or without `Bearer ` | JWT Decoder |
| Text starting with `{` or `[`. Broken JSON counts too, so you see the error | JSON Formatter |
| Base64 that decodes to readable text | Base64, set to Decode |
| A 10- or 13-digit Unix timestamp between the years 2000 and 2100, or a date with a time, like `2023-11-14T22:13` | Epoch Converter |

Some rules:
- The clipboard is read **only when you open the window**, never in the background.
- It's read only if it has changed since DevPocket last looked.
- Anything you copy from inside DevPocket is ignored.
- If you open a specific tool from the menu, the clipboard is used only if it suits that tool.
- To turn this off, untick **Open With Clipboard Content** in the menu bar. `⌘⇧V` still pastes into the current tool.

## The tool window

```
┌───────────────────────────────────────────────────────────────┐
│ ● ● ●  JWT Decoder  [From clipboard]     tool controls   🔍  📌 │  title bar
├────┬──────────────────────────────────────────────────────────┤
│ 🔑 │                                                          │
│ {} │   the current tool                                       │
│ ⇄  │                                                          │
│ 🕘 │                                                          │
├────┴──────────────────────────────────────────────────────────┤
│ ● Valid · expires in 1 hour · alg HS256        Copy Payload ⌘⇧C │  status bar
└───────────────────────────────────────────────────────────────┘
```

- **Title bar:** the tool's name and its controls, such as JSON's Pretty/Minify, the indent and Sort keys, or the epoch tool's Local/UTC and Now. There's also search (`⌘K`) and a pin that keeps the window above other apps.
- **Icon column on the left:** one icon per tool; hover over one to see its name and shortcut.
- **Status bar:** whether the input is valid or what's wrong with it, plus details such as sizes, the algorithm or how long ago. The button on the right copies the tool's main result.
- **Inputs are kept.** Each tool keeps its input while you switch between tools and when you hide the window. They live in memory only.

### Keyboard

| Keys | Action |
|---|---|
| `⌃⌥Space` | Show or hide DevPocket, from any app |
| `⌘K` | Search tools, or open what's on the clipboard (`↑` `↓` `Return`) |
| `⌘1` – `⌘9` | Switch tool, in the order of the icon column |
| `⌘⇧V` | Replace the input with the clipboard |
| `⌘⇧C` | Copy the main result: the payload, formatted JSON, decoded text or converted date. In the epoch tool with nothing typed, it copies the current epoch |
| `⌘L` | Clear the input |
| `Esc` | Close the palette; press again to hide the window |
| `⌘W` | Hide the window |

The usual editing shortcuts (`⌘C`, `⌘V`, `⌘X`, `⌘A`, `⌘Z`, `⌘⇧Z`) work in every editor. Smart quotes, autocorrect and spell check are turned off so they can't change JSON or tokens.

### Settings (menu bar)

| Setting | Default | What it does |
|---|---|---|
| Show Floating Bubble | On | Show or hide the bubble |
| Keep Window on Top | On | Same as the pin in the title bar |
| Open With Clipboard Content | On | The clipboard behavior described above |
| Clear Inputs When Hidden | Off | Wipe every tool's input whenever the window hides. Useful if you paste tokens you'd rather not leave around |
| Launch at Login | Off | Start DevPocket when you log in. Install it to `/Applications` first |

The bubble's position, the window's size and position, the last tool you used and these settings are saved between launches. Nothing you type or paste is saved.

## Install & build

Requires macOS 14 or later and Xcode (or the Swift 5.10+ command line tools).

```bash
make run        # build build/DevPocket.app and launch it
make install    # copy to /Applications and launch
make test       # run the unit tests
make icon       # regenerate the app icon (see below)
make clean      # delete build output
```

During development, `swift run DevPocket` also works. DevPocket still runs without a Dock icon, but **Launch at Login** needs the real `.app`.

The app is signed ad hoc, so it runs on the Mac that built it. To share it, sign it with a Developer ID and notarize it.

### App icon

`scripts/make-icon.swift` draws the icon (a pocket holding `{ }`) with plain vector shapes and writes `Support/AppIcon.icns`. Five styles are available: `classic` (the default), `midnight`, `sunset`, `paper` and `terminal`.

```bash
make icon ICON_STYLE=sunset && make run
```

Finder caches icons, so a new one can take a moment to appear.

## Project layout

```
Sources/
  DevPocketCore/            Pure logic, no UI, unit-tested
    JWTDecoder.swift
    JSONTool.swift          Re-indenter that keeps key order and numbers as written
    Base64Tool.swift
    EpochTool.swift         Timestamp/date parsing and formatting
    ContentDetector.swift   Guesses whether text is a JWT, JSON, Base64 or a timestamp
  DevPocket/
    App/                    Entry point, AppCoordinator (windows, clipboard, shortcuts), menu bar menu, global hotkey
    Windows/                Floating bubble, tool window (title bar, icon column, status bar), ⌘K palette
    Components/             CodeEditor (NSTextView wrapper), Pane, IconButton, Theme, helpers
    Utilities/              DevUtility + registry, ToolModel + ToolStore, one file per tool
Tests/DevPocketCoreTests/   Unit tests for everything in DevPocketCore
Support/                    Info.plist (no Dock icon) and AppIcon.icns
scripts/                    bundle.sh (builds the .app) and make-icon.swift
```

## Adding a tool

1. **Logic:** add it to `Sources/DevPocketCore/` and test it in `Tests/DevPocketCoreTests/`.
2. **UI:** create `Sources/DevPocket/Utilities/MyTool.swift` with:
   - A `ToolModel` subclass for the tool's state. Override `status`, `primaryOutput` and `copyLabel` to feed the status bar and `⌘⇧C`.
   - A content view.
   - Optionally, a controls view for the title bar.

   Then declare the tool:
   ```swift
   extension DevUtility {
       static let myTool = DevUtility(
           id: "my-tool", name: "My Tool", symbol: "hammer",
           summary: "One-line description", keywords: ["search", "terms"],
           model: { MyToolModel() },
           content: { MyToolView(model: $0) },
           controls: { MyToolControls(model: $0) }   // or { _ in EmptyView() }
       )
   }
   ```
3. **Register it:** append `.myTool` to `UtilityRegistry.all` in `DevUtility.swift`.

It then appears in the icon column with the next `⌘` number, and in the menu bar, the bubble's right-click menu and the `⌘K` palette.

To have it **open automatically for clipboard content**:
1. Add a case to `ContentKind`.
2. Teach `ContentDetector` to recognize that content, and add tests for it, including text it should *not* match.
3. Set `handles: [.myKind]` on the tool.
4. Optionally, override `accept(clipboard:kind:)` to prepare the tool; Base64 uses this to switch to Decode.

Building blocks you can reuse: `Pane` (a titled editor card with icon buttons), `CodeEditor`, `InputActions` (paste and clear buttons), `IconButton`, `EmptyHint`, `Clipboard`, and `relativeDate`.

## Known limitations

- **JWT signatures aren't verified.** DevPocket decodes tokens; it doesn't validate them.
- **Clipboard prompts.** Newer versions of macOS may ask before an app reads the clipboard. If the prompt gets annoying, turn off *Open With Clipboard Content*. `⌘⇧V` and the paste buttons still work.
- **Timestamp detection is a guess.** A 10-digit number in the 2000–2100 range, such as some phone numbers, is treated as a timestamp. Switch tools with `⌘K` or `⌘1`–`⌘4`.
- **Sort keys** in the JSON formatter rebuilds the JSON, so numbers may change form, e.g. `1.50` becomes `1.5`.
- **Microseconds and nanoseconds** are converted to dates exactly, but only seconds and milliseconds are shown as numbers.
- **The `⌃⌥Space` shortcut can't be changed yet.** If another app already uses it, DevPocket logs a warning and the bubble and menu bar still work.

## Ideas for next steps

- More tools: URL encode/decode, UUID generator, hashes (MD5/SHA), regex tester, diff, cron explainer, color converter
- Syntax highlighting in `CodeEditor`, and highlighting the line where JSON breaks
- JWT claims table with a timeline from issued to expiry; JSON tree view; Base64 image preview
- Bubble: pocket icon to match the app icon, snapping to screen edges, fading when idle, opening the window from the bubble
- Settings window with a configurable shortcut
