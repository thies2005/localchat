# LocalChat — On-Device AI Chat App

> Flutter chatbot powered by Gemini Nano via Android AICore. Fully offline, privacy-first.

---

## Prompt Audit Summary

The original agent prompt was audited against the **actual `gemini_nano_android ^0.1.3`** API and current device compatibility data. Key findings:

### 🔴 Critical Fixes Required

| # | Issue | Fix |
|---|-------|-----|
| 1 | `checkAvailability()` doesn't exist | Use `isAvailable()` → `Future<bool>` |
| 2 | `ModelStatus.downloading` is fictional | AICore doesn't expose download state to Flutter. Remove it. |
| 3 | Empty `generate()` result unhandled | `generate()` → `Future<List<String>>`, can return `[]` |

### 🟡 Design Improvements

| # | Issue | Fix |
|---|-------|-----|
| 4 | No cloud fallback for unsupported devices | ~80% of Android lacks AICore. Add clear UX or fallback. |
| 5 | `minSdkVersion 31` too low | AICore requires Android 14 (API 34). Use `minSdkVersion 34`. |
| 6 | AppBar subtitle "Pixel 9 optimized" excludes other devices | Change to "Powered by Gemini Nano · On-Device AI" |
| 7 | No extracted widgets | Split into `chat_bubble.dart`, `status_banner.dart`, `message_input.dart` |
| 8 | No generation config exposed | `generate()` supports `temperature`, `topK`, `maxOutputTokens` |

---

## Architecture

```
lib/
├── main.dart                    # App entry, MultiProvider setup
├── models/
│   └── chat_message.dart        # Immutable message model
├── services/
│   └── ai_service.dart          # AICore bridge (singleton pattern)
├── providers/
│   └── chat_provider.dart       # Chat state management
├── widgets/
│   ├── chat_bubble.dart         # SelectableText message bubble
│   ├── status_banner.dart       # Device compatibility banner
│   └── message_input.dart       # Text input + send button
└── screens/
    └── chat_screen.dart         # Main chat UI
```

---

## Stack

| Component | Choice |
|-----------|--------|
| Framework | Flutter (latest stable) |
| AI Package | `gemini_nano_android: ^0.1.3` |
| State | `provider: ^6.1.0` |
| UI System | Material 3 (M3) |
| Min SDK | 34 (Android 14) |
| Target SDK | 35 |

---

## Corrected API Reference

```dart
// ✅ Correct API (gemini_nano_android ^0.1.3)
final gemini = GeminiNanoAndroid();  // singleton

// Check availability
Future<bool> isAvailable();

// Generate text
Future<List<String>> generate({
  required String prompt,
  double temperature = 0.0,
  int? seed,
  int topK = 0,
  int candidateCount = 1,
  int maxOutputTokens = 0,
});

// ❌ These DON'T EXIST in the package:
// checkAvailability()  — WRONG
// ModelStatus.downloading — WRONG
// generate() returning a single String — WRONG
```

---

## AI Service — Corrected Implementation

```dart
enum ModelStatus { checking, available, unavailable }

class AIService extends ChangeNotifier {
  final _gemini = GeminiNanoAndroid();
  ModelStatus _status = ModelStatus.checking;
  bool _isGenerating = false;

  ModelStatus get status => _status;
  bool get isGenerating => _isGenerating;

  Future<void> initialize() async {
    _status = ModelStatus.checking;
    notifyListeners();
    try {
      final available = await _gemini.isAvailable();
      _status = available ? ModelStatus.available : ModelStatus.unavailable;
    } catch (e) {
      _status = ModelStatus.unavailable;
    }
    notifyListeners();
  }

  Future<String> sendMessage(List<ChatMessage> history, String input) async {
    _isGenerating = true;
    notifyListeners();
    try {
      final prompt = _buildPrompt(history, input);
      final results = await _gemini.generate(
        prompt: prompt,
        temperature: 0.7,
        topK: 40,
        maxOutputTokens: 1024,
      );
      if (results.isEmpty) {
        return "I couldn't generate a response. Please try again.";
      }
      return results.first.trim();
    } catch (e) {
      return "Something went wrong. Please try again.";
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  String _buildPrompt(List<ChatMessage> history, String input) {
    final buffer = StringBuffer();
    final relevantHistory = <String>[];
    int charCount = 0;

    for (final msg in history.reversed) {
      final line = "${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}";
      if (charCount + line.length > 3000) break;
      relevantHistory.insert(0, line);
      charCount += line.length;
    }

    for (final line in relevantHistory) {
      buffer.writeln(line);
    }
    buffer.writeln("User: $input");
    buffer.write("Assistant:");
    return buffer.toString();
  }
}
```

---

## UI Spec

### Status Banner
| State | Display |
|-------|---------|
| `checking` | Grey banner + shimmer: "Checking AI compatibility..." |
| `unavailable` | Amber banner: "This device doesn't support on-device AI" + device list |
| `available` | Hidden |

### Chat Bubbles
- User: right-aligned, primary color, white text
- AI: left-aligned, surface variant color
- All use `SelectableText` (long-press to copy)
- Rounded corners (16px), sharp on sender side
- Max width: 80% of screen
- Timestamp in caption style below each bubble

### Input Bar
- `TextField`: multiline, max 4 lines, hint "Type a message..."
- Send: `IconButton(Icons.send_rounded)` → `CircularProgressIndicator` while generating
- Enter sends, Shift+Enter creates newline
- Disabled when model unavailable

---

## Supported Devices

| OEM | Devices |
|-----|---------|
| Google | Pixel 8, 8 Pro, 9, 9 Pro, 9 Pro XL, 10+ |
| Samsung | Galaxy S24, S24+, S24 Ultra, S25 series, Fold 6+ |
| OnePlus | 13, 12+ |
| Xiaomi | 15, 14T Pro+ |
| Others | Any device with AICore system service + NPU |

---

## Hard Constraints

1. ❌ No `INTERNET` permission in `AndroidManifest.xml`
2. ❌ No local storage — chat is in-memory only
3. ✅ `GeminiNanoAndroid()` is a singleton, never re-instantiated
4. ✅ All AI calls are async, never on main thread
5. ✅ Sliding window: hard cap 3000 chars of context
6. ✅ `SelectableText` on every bubble
7. ✅ Handle empty `generate()` results gracefully
8. ✅ All AI calls wrapped in try/catch

---

## Open Decisions

These questions must be answered before implementation:

1. **Cloud fallback?** — Dead-end on unsupported devices, or add optional Gemini API fallback?
2. **Chat persistence?** — Confirm in-memory only, or add lightweight Hive cache?
3. **Streaming?** — Batch-only, or implement `generateStream` if available?
4. **Generation config UI?** — Hardcode defaults or expose temperature/topK in settings?
5. **App name/branding?** — "LocalChat", "On-Device Chat", or something else?
6. **Multi-turn API?** — Check for native conversation sessions, or keep manual prompt building?
7. **minSdkVersion?** — 31 (broad install, more "unsupported" users) or 34 (strict, fewer dead installs)?

---

## Implementation Phases

### Phase 1: Scaffold (subagent 1)
- `flutter create` project
- Configure `pubspec.yaml`
- Set up Android build config
- Create project structure

### Phase 2: Core Logic (subagent 2)
- `ChatMessage` model
- `AIService` with correct API
- `ChatProvider` state management

### Phase 3: UI Components (subagent 3)
- `ChatBubble` widget
- `StatusBanner` widget
- `MessageInput` widget
- `ChatScreen` assembly

### Phase 4: Polish & Test (subagent 4)
- Theme tuning (light + dark)
- Animation & transitions
- `flutter analyze` clean
- Build verification

### Phase 5: Push to GitHub
- Commit all files
- Push to `https://github.com/thies2005/localchat`
