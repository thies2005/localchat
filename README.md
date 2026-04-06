# LocalChat

A fully offline, privacy-first AI chatbot for Android powered by Google's **Gemini Nano** model via Android AICore. All inference runs on-device — no internet required, no data ever leaves your phone.

## Features

- **On-device AI** — Gemini Nano runs entirely on the NPU, no cloud dependency
- **Multimodal input** — Attach images from gallery, processed on-device via Gemini Nano vision
- **Auto-detection** — Multimodal capability is probed on first image send; falls back gracefully if unsupported
- **Multi-conversation** — ChatGPT-style sidebar with conversation management
- **Persistent history** — All messages stored locally in Isar database
- **Simulated streaming** — Character-by-character text reveal animation (Nano lacks native streaming)
- **Auto-continuation** — Automatically extends truncated responses up to 4 rounds
- **Markdown rendering** — AI responses render with full Markdown support (code blocks, tables, headings, etc.)
- **Adjustable generation** — Temperature, Top-K, max tokens, and more via settings panel
- **Copy answers** — One-tap copy button on AI responses
- **Dark/light mode** — Material 3 theming that follows system preference
- **Debug logs** — Built-in log viewer for troubleshooting

## Supported Devices

LocalChat requires Android 14+ with Google AICore installed and updated. Compatible devices include:

| Brand | Models |
|-------|--------|
| Google | Pixel 8, 9, 10 series |
| Samsung | Galaxy S24, S25 series |
| OnePlus | 13 |
| Xiaomi | 15 |
| Honor | 7 |
| vivo | X200 |
| OPPO | Find X8 |

> First use may download the Gemini Nano model (~1GB). Ensure Wi-Fi and charging are available.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   main.dart                      │
│              MultiProvider Setup                 │
├──────────┬──────────┬───────────┬────────────────┤
│AIService │ChatProv. │Settings   │DatabaseService │
│(Nano API)│(UI state)│Provider   │(Isar CRUD)     │
├──────────┴──────────┴───────────┴────────────────┤
│                  ChatScreen                       │
│  ┌────────────────────────────────────────────┐  │
│  │ StatusBanner (checking/unavailable/hidden) │  │
│  ├────────────────────────────────────────────┤  │
│  │ Messages ListView (reverse scroll)         │  │
│  │  ├─ ChatBubble (user, right, primary)      │  │
│  │  ├─ ChatBubble (AI, left, surface+md)      │  │
│  │  └─ TypingIndicator (while generating)     │  │
│  ├────────────────────────────────────────────┤  │
│  │ MessageInput (text field + image + send)   │  │
│  └────────────────────────────────────────────┘  │
│  Drawer: ConversationDrawer                      │
│  BottomSheet: SettingsSheet, LogViewerSheet      │
└─────────────────────────────────────────────────┘
         │                        │
    ┌────▼────┐            ┌──────▼──────┐
    │ AICore  │            │   Isar DB   │
    │ (NPU)   │            │ (on-device) │
    └─────────┘            └─────────────┘
```

## Project Structure

```
lib/
├── main.dart                          # App entry, MultiProvider wiring
├── theme/
│   └── app_theme.dart                 # Material 3 light + dark theme definitions
├── models/
│   ├── chat_message.dart              # Isar message model (text + image)
│   ├── chat_message.g.dart            # Generated Isar schema
│   ├── conversation.dart              # Isar conversation model
│   └── conversation.g.dart            # Generated Isar schema
├── services/
│   ├── ai_service.dart                # Gemini Nano bridge (singleton, ChangeNotifier)
│   ├── database_service.dart          # Isar CRUD operations (singleton)
│   └── log_service.dart               # In-memory ring buffer logger (200 entries)
├── providers/
│   ├── chat_provider.dart             # Conversation/message state management
│   └── settings_provider.dart         # Generation config state
├── screens/
│   └── chat_screen.dart               # Main chat UI scaffold
└── widgets/
    ├── chat_bubble.dart               # Message bubble with streaming + image display
    ├── conversation_drawer.dart       # Sidebar with conversation list
    ├── context_diagram_sheet.dart     # Architecture overview bottom sheet
    ├── log_viewer_sheet.dart          # Debug log viewer
    ├── message_input.dart             # Text input + image picker + send button
    ├── settings_sheet.dart            # Generation settings bottom sheet
    ├── status_banner.dart             # Device compatibility banner
    └── typing_indicator.dart          # Animated "thinking" dots
```

## How It Works

### AI Inference (`ai_service.dart`)

LocalChat uses a single `GeminiNanoAndroid()` instance as a bridge to Android's AICore system service.

**Initialization flow:**
1. On app start, `AIService.initialize()` calls `_gemini.isAvailable()` to check device compatibility
2. Result maps to `ModelStatus.checking` / `available` / `unavailable`
3. A status banner displays the result; the input is disabled if unavailable

**Message generation:**
1. User message + conversation history are assembled into a text prompt
2. A sliding window of up to **3,000 characters** of recent history is included
3. Prompt format: `User: ...\nAssistant: ...\nUser: [current input]\nAssistant:`
4. Image messages are tagged with `[Image]` in history context
5. `_gemini.generate(prompt:, image:, temperature:, topK:, maxOutputTokens:)` is called
6. If an image is attached, `imageBytes` (Uint8List) are passed alongside the prompt for on-device vision

**Auto-continuation:**
Since Gemini Nano has a 256-token max output, long responses get truncated. LocalChat detects truncation by checking if the response ends without sentence-ending punctuation. If truncated, it sends up to **4 continuation rounds** with `"Continue exactly from where you left off"` prepended. Deduplication logic strips any repeated prefix from the continuation.

**Multimodal detection:**
There is no dedicated API to check if the device's AICore model supports images. On the first image send, a probe request is made with `"Describe what you see."`. If it succeeds, `MultimodalStatus.supported` is set and cached. If it throws, `MultimodalStatus.unsupported` is set and subsequent image sends fall back to text-only.

### Simulated Streaming (`chat_bubble.dart`)

Gemini Nano does not support native token streaming. LocalChat simulates it:

1. AI response is received as a complete string
2. A `Timer.periodic(30ms)` reveals the text character-by-character (1-4 chars per tick)
3. A blinking cursor is shown during the reveal
4. If the response updates mid-stream (e.g., from auto-continuation), the animation seamlessly continues from the current position

### Image Handling

1. User taps the image button in `MessageInput`
2. `image_picker` opens the device gallery
3. Selected image is compressed (85% quality) and saved to `{appDir}/chat_images/img_{timestamp}.ext`
4. The image path is stored in `ChatMessage.imagePath` (Isar)
5. Image bytes are passed to `AIService.sendMessage()` and forwarded to `_gemini.generate(image:)`
6. `ChatBubble` displays attached images using `Image.file` with error handling

### Chat Persistence (`database_service.dart`)

All data is stored in an on-device **Isar** (NoSQL) database:

- **Conversations** — title, created/updated timestamps, ordered by most recent
- **Messages** — text, imagePath, user/AI flag, timestamp, token count, tokens/sec
- Auto-incrementing integer IDs restored from max existing value on startup
- Conversation deletion cascades to all associated messages

### State Management

The app uses **Provider** with three `ChangeNotifier` services:

| Provider | Role |
|----------|------|
| `AIService` | Model status, generating flag, multimodal support |
| `ChatProvider` | Active conversation, message list, CRUD operations |
| `SettingsProvider` | Temperature, Top-K, max tokens, auto-continue, token stats |

### Generation Settings

Accessible via the settings icon in the app bar:

| Parameter | Default | Range | Step | Effect |
|-----------|---------|-------|------|--------|
| Temperature | 0.7 | 0.0 - 1.0 | 0.1 | Controls randomness (0 = deterministic, 1 = creative) |
| Top-K | 40 | 1 - 100 | 1 | Limits token candidates per step |
| Max Output Tokens | 256 | 1 - 256 | 5 | Max tokens per generation call |
| Auto-Continue | On | — | — | Automatically extends truncated responses |
| Show Token Stats | On | — | — | Displays token count and tok/s below AI responses |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart SDK ^3.5.0) |
| AI Model | Gemini Nano via Android AICore |
| AI Package | `gemini_nano_android: ^1.1.2` |
| Image Picking | `image_picker: ^1.2.1` |
| State Management | `provider: ^6.1.0` |
| Local Database | `isar: ^4.0.0-dev.14` |
| Markdown | `flutter_markdown: ^0.7.4` |
| UI | Material 3 (light + dark, system-adaptive) |
| Android minSdk | 34 (Android 14+) |
| Android compileSdk | 36 |

## Building

### Prerequisites

- Flutter SDK (^3.5.0)
- Android SDK with compileSdk 36
- A compatible Android device or emulator with AICore

### Build release APK

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Privacy

- **No INTERNET permission** — the app cannot make network requests
- All AI inference runs on the device NPU via AICore
- Chat history is stored only in the app's local Isar database
- Images are saved locally and never uploaded
- No analytics, telemetry, or crash reporting

## Debugging

Tap the bug report icon in the app bar to open the **Log Viewer**, which shows the last 200 log entries from all services with timestamps and severity levels. This is useful for diagnosing model availability issues, generation errors, or auto-continuation behavior.

## License

Private — all rights reserved.
