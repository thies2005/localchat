# LocalChat — On-Device AI Chat App

> Flutter chatbot powered by Gemini Nano via Android AICore. Fully offline, privacy-first.
> ChatGPT-style conversation management with persistent history.

---

## Decisions (Finalized)

| Question | Answer |
|----------|--------|
| Cloud fallback | ❌ No — dead-end with clear "unsupported" banner |
| minSdkVersion | 34 (Android 14+, strict AICore-only) |
| Streaming | ✅ Simulated — animate text reveal (Nano has no native stream) |
| Chat persistence | ✅ Full ChatGPT-style — Isar DB, multi-conversation, sidebar |
| Multi-turn | Manual history (no native `startChat()` on Nano), context-aware follow-ups |
| Generation config | Adjustable via settings (defaults: temp 0.7, topK 40, maxTokens 1024) |
| App name | **LocalChat** |

---

## Finalized Agent Prompt

```
Build a Flutter chatbot app called "LocalChat" for Android using on-device
Gemini Nano via AICore. Targets all AICore-compatible devices: Pixel 8/9+,
Samsung S24/S25, OnePlus 13, Xiaomi 15, and similar flagships.
No internet required. Full offline operation.

***

## Stack
- Flutter (latest stable)
- Package: gemini_nano_android: ^0.1.3
- State: Provider ^6.1.0
- UI: Material 3 (dark + light mode, ThemeMode.system)
- Local DB: isar: ^4.0.0-dev.14 + isar_flutter_libs + path_provider
- Code Gen: isar_generator + build_runner (dev_dependencies)

***

## pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  gemini_nano_android: ^0.1.3
  provider: ^6.1.0
  isar: ^4.0.0-dev.14
  isar_flutter_libs: ^4.0.0-dev.14
  path_provider: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  isar_generator: ^4.0.0-dev.14
  build_runner: ^2.4.0

***

## Project Structure
lib/
├── main.dart
├── theme/
│   └── app_theme.dart               # M3 light + dark theme definitions
├── models/
│   ├── chat_message.dart            # Isar message model
│   └── conversation.dart            # Isar conversation model
├── services/
│   ├── ai_service.dart              # AICore bridge (singleton)
│   └── database_service.dart        # Isar CRUD operations
├── providers/
│   ├── chat_provider.dart           # Active conversation state
│   └── settings_provider.dart       # Generation config state
├── widgets/
│   ├── chat_bubble.dart             # SelectableText message bubble
│   ├── status_banner.dart           # Device compatibility banner
│   ├── message_input.dart           # Text input + send button
│   ├── typing_indicator.dart        # Animated "AI is thinking" dots
│   ├── conversation_drawer.dart     # Sidebar with conversation list
│   └── settings_sheet.dart          # Generation config bottom sheet
└── screens/
    └── chat_screen.dart             # Main chat UI

***

## Step 1 — Theme (app_theme.dart)
Material 3 theme system:

  class AppTheme {
    static ThemeData lightTheme() =>  ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Color(0xFF6750A4),  // Deep purple seed
      brightness: Brightness.light,
      fontFamily: 'Roboto',
    );

    static ThemeData darkTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Color(0xFF6750A4),
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
    );
  }

  Both themes must:
    - Use dynamic color scheme from seed (M3 tonal palettes)
    - Have proper surface, onSurface, primary, onPrimary contrast
    - Support elevated surfaces with tonal elevation in dark mode
    - Use M3 shape system (rounded corners)

***

## Step 2 — Models

### conversation.dart (Isar collection)
  @Collection()
  class Conversation {
    Id id = Isar.autoIncrement;
    String title;           // Auto-generated from first message or "New Chat"
    DateTime createdAt;
    DateTime updatedAt;
    // backlink to messages
  }

### chat_message.dart (Isar collection)
  @Collection()
  class ChatMessage {
    Id id = Isar.autoIncrement;
    int conversationId;     // Link to parent conversation
    String text;
    bool isUser;
    DateTime timestamp;
    // Index on conversationId for fast queries
  }

***

## Step 3 — Services

### database_service.dart
  Singleton Isar instance, initialized once on app start:

  class DatabaseService {
    late Isar _isar;

    Future<void> initialize() async {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [ConversationSchema, ChatMessageSchema],
        directory: dir.path,
      );
    }

    // Conversation CRUD
    Future<List<Conversation>> getAllConversations();  // ordered by updatedAt desc
    Future<Conversation> createConversation(String title);
    Future<void> updateConversationTitle(int id, String title);
    Future<void> deleteConversation(int id);           // cascade delete messages

    // Message CRUD
    Future<List<ChatMessage>> getMessages(int conversationId);  // ordered by timestamp
    Future<void> addMessage(ChatMessage message);
    Future<void> deleteMessagesForConversation(int conversationId);
  }

### ai_service.dart
  IMPORTANT: Use the ACTUAL gemini_nano_android ^0.1.3 API:
    - isAvailable() → Future<bool>
    - generate(prompt:, temperature:, topK:, maxOutputTokens:) → Future<List<String>>

  enum ModelStatus { checking, available, unavailable }
  // NOTE: No "downloading" state — AICore does not expose this.

  class AIService extends ChangeNotifier {
    final _gemini = GeminiNanoAndroid();  // singleton, created once
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

    Future<String> sendMessage({
      required List<ChatMessage> history,
      required String input,
      double temperature = 0.7,
      int topK = 40,
      int maxOutputTokens = 1024,
    }) async {
      _isGenerating = true;
      notifyListeners();
      try {
        final prompt = _buildPrompt(history, input);
        final results = await _gemini.generate(
          prompt: prompt,
          temperature: temperature,
          topK: topK,
          maxOutputTokens: maxOutputTokens,
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

      // Walk backwards, cap at 3000 chars for context window
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

***

## Step 4 — Providers

### chat_provider.dart
  class ChatProvider extends ChangeNotifier {
    final DatabaseService _db;
    List<Conversation> conversations = [];
    Conversation? activeConversation;
    List<ChatMessage> messages = [];

    // Load all conversations on init
    Future<void> loadConversations();

    // Create new conversation (like ChatGPT "New Chat" button)
    Future<void> newConversation();

    // Switch active conversation and load its messages
    Future<void> selectConversation(int conversationId);

    // Send a message: save user msg, get AI response, save AI msg
    // Auto-generate conversation title from first user message
    Future<void> sendMessage(String text, AIService ai, SettingsProvider settings);

    // Delete a conversation
    Future<void> deleteConversation(int conversationId);
  }

### settings_provider.dart
  class SettingsProvider extends ChangeNotifier {
    double temperature = 0.7;
    int topK = 40;
    int maxOutputTokens = 1024;

    void updateTemperature(double value);
    void updateTopK(int value);
    void updateMaxOutputTokens(int value);
    void resetDefaults();
  }

***

## Step 5 — Widgets

### chat_bubble.dart
  - User bubbles: right-aligned, primary color background, onPrimary text
  - AI bubbles: left-aligned, surfaceContainerHighest background, onSurface text
  - ALL text uses SelectableText (long-press to copy)
  - Timestamp in muted labelSmall style below each bubble
  - Rounded corners: 16px with sharp corner on sender's side
  - Max width: 80% of screen
  - Simulated streaming: AI response text animates in character-by-character
    using a periodic Timer that reveals text incrementally (50ms per chunk)
  - Entry animation: subtle slide + fade on appear

### status_banner.dart
  - ModelStatus.checking:    surfaceContainerHighest banner + shimmer
      "Checking AI compatibility..."
  - ModelStatus.unavailable: tertiaryContainer banner + warning icon
      "This device doesn't support on-device AI"
      + labelSmall: "Requires: Pixel 8/9+, Galaxy S24/S25, OnePlus 13, Xiaomi 15,
        or similar flagship with AICore"
  - ModelStatus.available:   SizedBox.shrink (hidden)
  - Animates in/out with AnimatedSwitcher

### message_input.dart
  - TextField: multiline, max 4 visible lines
  - Hint text: "Type a message..." (uses M3 outlinedBorder style)
  - Send button: IconButton(Icons.send_rounded) with primary color
  - While generating: replace send button with SizedBox-constrained
    CircularProgressIndicator (M3 style)
  - Submit on Enter (shift+Enter for newline)
  - Disabled + grey when status != available
  - Clear field after successful send
  - Autofocus when conversation is active

### typing_indicator.dart
  - Three animated bouncing dots in AI bubble style
  - Shown while AI is generating
  - Uses AnimationController with staggered intervals

### conversation_drawer.dart
  - NavigationDrawer (M3) or Drawer with conversation list
  - "New Chat" button at top (prominent, FilledButton style)
  - Each conversation shows:
      - Title (auto-generated from first message)
      - Last updated time in relative format ("2m ago", "Yesterday")
  - Swipe-to-delete or trailing IconButton to delete conversation
  - Active conversation is highlighted with M3 secondaryContainer
  - Empty state: centered illustration + "Start a new chat" text

### settings_sheet.dart
  - BottomSheet (M3 modal bottom sheet with drag handle)
  - Sliders for:
      - Temperature (0.0 – 1.0, step 0.1, default 0.7)
      - Top-K (1 – 100, step 1, default 40)
      - Max Output Tokens (64 – 2048, step 64, default 1024)
  - Each slider has a label + current value display
  - "Reset to Defaults" button at bottom
  - Uses M3 Slider widget with proper theming

***

## Step 6 — chat_screen.dart
  Scaffold with:
    - AppBar:
        - Leading: menu icon to open conversation_drawer
        - Title: "LocalChat"
        - Bottom: PreferredSize widget showing "Powered by Gemini Nano · On-Device"
          in labelSmall style, muted color
        - Actions: settings IconButton to open settings_sheet
    - Drawer: ConversationDrawer
    - Body: Column [StatusBanner, Expanded(messages list), MessageInput]
    - Messages list: ListView.builder with reverse: true
    - When generating: show TypingIndicator as last item
    - Welcome message on empty/new conversation:
        "👋 Hi! I'm running entirely on your device. Your conversations
         are private and never leave this phone."
    - Auto-scroll to bottom on new message

***

## Step 7 — main.dart
  MultiProvider wrapping:
    - ChangeNotifierProvider<AIService>(create: (_) => AIService()..initialize())
    - ChangeNotifierProvider<ChatProvider>(
        create: (ctx) => ChatProvider(ctx.read<DatabaseService>())..loadConversations()
      )
    - ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider())
    - Provider<DatabaseService>(create: (_) => DatabaseService()..initialize())

  MaterialApp:
    - title: 'LocalChat'
    - theme: AppTheme.lightTheme()
    - darkTheme: AppTheme.darkTheme()
    - themeMode: ThemeMode.system
    - home: ChatScreen()
    - debugShowCheckedModeBanner: false

***

## Step 8 — android/app/build.gradle
  minSdkVersion 34        // Android 14+, required for AICore
  targetSdkVersion 35
  compileSdkVersion 35

***

## Step 9 — AndroidManifest.xml
  - Remove any INTERNET permission
  - Ensure no network-related permissions exist

***

## Hard Constraints
1. ❌ No INTERNET permission
2. ✅ Full persistent chat history via Isar (ChatGPT-style multi-conversation)
3. ✅ GeminiNanoAndroid() is a singleton, never re-instantiated
4. ✅ All AI calls are async, never on main thread
5. ✅ Sliding window: hard cap 3000 chars of context before current input
6. ✅ SelectableText on EVERY bubble (user + AI)
7. ✅ Handle empty generate() results gracefully
8. ✅ All AI calls wrapped in try/catch
9. ✅ Simulated streaming: character-by-character text reveal animation
10. ✅ Material 3 with full dark + light mode support (ThemeMode.system)
11. ✅ Adjustable generation config (temperature, topK, maxOutputTokens)
12. ✅ Context-aware follow-up support via manual history management
13. ✅ Conversation auto-title from first user message
```

---

## Architecture Diagram

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
│  │ Messages ListView                          │  │
│  │  ├─ ChatBubble (user, right, primary)      │  │
│  │  ├─ ChatBubble (AI, left, surface)         │  │
│  │  └─ TypingIndicator (while generating)     │  │
│  ├────────────────────────────────────────────┤  │
│  │ MessageInput (TextField + send button)     │  │
│  └────────────────────────────────────────────┘  │
│  Drawer: ConversationDrawer                      │
│  BottomSheet: SettingsSheet                      │
└─────────────────────────────────────────────────┘
         │                        │
    ┌────▼────┐            ┌──────▼──────┐
    │ AICore  │            │   Isar DB   │
    │ (NPU)   │            │ (on-device) │
    └─────────┘            └─────────────┘
```

---

## Implementation Phases (Subagent Plan)

### Phase 1: Project Scaffold (subagent)
- `flutter create localchat`
- Configure `pubspec.yaml` with all dependencies
- Set up Android build config (minSdk 34, targetSdk 35)
- Remove INTERNET permission
- Create directory structure

### Phase 2: Theme + Models (subagent)
- `app_theme.dart` — M3 light + dark themes
- `conversation.dart` — Isar conversation collection
- `chat_message.dart` — Isar message collection
- Run `build_runner` for Isar code gen

### Phase 3: Services (subagent)
- `database_service.dart` — Isar CRUD operations
- `ai_service.dart` — AICore bridge with correct API

### Phase 4: Providers (subagent)
- `chat_provider.dart` — conversation + message state
- `settings_provider.dart` — generation config state

### Phase 5: UI Widgets (subagent)
- `chat_bubble.dart` with simulated streaming animation
- `status_banner.dart` with animated transitions
- `message_input.dart` with keyboard handling
- `typing_indicator.dart` with bouncing dots
- `conversation_drawer.dart` with swipe-to-delete
- `settings_sheet.dart` with M3 sliders

### Phase 6: Screen Assembly (subagent)
- `chat_screen.dart` — assemble all widgets
- `main.dart` — MultiProvider + MaterialApp

### Phase 7: Verify & Push
- `flutter analyze` — zero warnings
- `flutter build apk --release` — successful build
- Push all code to GitHub
