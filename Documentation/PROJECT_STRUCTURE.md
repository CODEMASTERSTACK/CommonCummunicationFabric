# Project File Structure & Overview

## Complete Directory Tree

```
common_com/
│
├── lib/                                      # Main source code
│   ├── main.dart                             # App entry point & initialization
│   │
│   ├── screens/                              # UI Screens
│   │   ├── home_screen.dart                  # Create/Join room interface
│   │   └── chat_screen.dart                  # Messaging interface
│   │
│   ├── services/                             # Business logic
│   │   ├── room_service.dart                 # Room management (create/join)
│   │   ├── messaging_service.dart            # Message handling
│   │   ├── local_network_service.dart        # TCP socket communication
│   │   └── network_connection_manager.dart   # Connection management with retry
│   │
│   ├── models/                               # Data models
│   │   ├── room.dart                         # Room data structure
│   │   ├── device.dart                       # Device data structure
│   │   └── message.dart                      # Message data structure
│   │
│   ├── utils/                                # Utility functions
│   │   └── device_utils.dart                 # Device detection & helpers
│   │
│   ├── config/                               # Configuration
│   │   └── app_config.dart                   # App constants & settings
│   │
│   └── providers/                            # State management
│       └── state_notifiers.dart              # ChangeNotifier providers
│
├── android/                                  # Android platform code
│   ├── app/
│   │   └── src/
│   │       └── main/
│   │           └── AndroidManifest.xml       # Android configuration
│   ├── build.gradle.kts                      # Android build config
│   └── gradle.properties                     # Gradle settings
│
├── windows/                                  # Windows platform code
│   └── runner/
│       └── main.cpp                          # Windows entry point
│
├── ios/                                      # iOS platform code
│   └── Runner/
│       └── Info.plist                        # iOS configuration
│
├── web/                                      # Web platform code
├── macos/                                    # macOS platform code
├── linux/                                    # Linux platform code
│
├── pubspec.yaml                              # Flutter dependencies
├── pubspec.lock                              # Dependency versions
├── analysis_options.yaml                     # Linter configuration
│
├── README.md                                 # Original project README
├── SETUP_COMPLETE.md                         # ✅ Complete setup summary
├── QUICK_START.md                            # ✅ 5-minute quickstart
├── IMPLEMENTATION_GUIDE.md                   # ✅ Architecture guide
├── ANDROID_SETUP.md                          # ✅ Android instructions
├── WINDOWS_SETUP.md                          # ✅ Windows instructions
└── TROUBLESHOOTING.md                        # ✅ Debugging guide
```

---

## File Descriptions

### Core Application Files

#### `lib/main.dart` (71 lines)
- **Purpose**: App initialization and routing
- **Key Components**:
  - MainApp widget with theme configuration
  - Service initialization (RoomService, MessagingService)
  - Device type detection (Android/Windows/etc)
  - Route definition for navigation
- **Entry Point**: `void main()` - starts the app

#### `lib/screens/home_screen.dart` (170+ lines)
- **Purpose**: Create/Join room interface
- **Features**:
  - Create new room button
  - Join room with 6-digit code input
  - Current device information display
  - Error message handling
  - Loading state management
- **Navigation**: Routes to `/chat` on success

#### `lib/screens/chat_screen.dart` (220+ lines)
- **Purpose**: Real-time messaging interface
- **Features**:
  - Real-time message display
  - Connected devices list
  - Message input and sending
  - Message history
  - Device status indicators
- **Callbacks**: Handles back navigation with room cleanup

### Service Layer

#### `lib/services/room_service.dart` (115+ lines)
- **Purpose**: Room lifecycle management
- **Functionality**:
  - Generate unique 6-digit codes
  - Create new rooms
  - Join existing rooms
  - Track connected devices
  - Manage room expiration (24 hours)
- **Data**: Maintains in-memory room registry

#### `lib/services/messaging_service.dart` (60+ lines)
- **Purpose**: Message storage and retrieval
- **Functionality**:
  - Add messages to queue
  - Retrieve messages by room
  - Clear messages (room or all)
  - Provide callbacks for new messages
- **Storage**: In-memory list of messages

#### `lib/services/local_network_service.dart` (140+ lines)
- **Purpose**: TCP socket communication
- **Functionality**:
  - Start server on device
  - Connect to remote servers
  - Send/receive messages
  - Broadcast to multiple clients
  - Handle client disconnections
- **Protocol**: Text-based with `|` delimiters

#### `lib/services/network_connection_manager.dart` (130+ lines)
- **Purpose**: Enhanced connection management
- **Functionality**:
  - Connection state tracking
  - Automatic retry with exponential backoff
  - Heartbeat monitoring
  - Stream-based state changes
  - Error handling and recovery
- **States**: disconnected, connecting, connected, failed

### Data Models

#### `lib/models/message.dart` (35+ lines)
- **Fields**: id, senderDeviceId, senderDeviceName, content, timestamp, roomCode
- **Methods**: toJson(), fromJson()
- **Purpose**: Represent a single chat message

#### `lib/models/device.dart` (40+ lines)
- **Fields**: id, name, type, connectedAt, isActive
- **Methods**: toJson(), fromJson()
- **Purpose**: Represent a connected device

#### `lib/models/room.dart` (45+ lines)
- **Fields**: code, creatorDeviceId, creatorDeviceName, createdAt, connectedDevices
- **Methods**: isActive check, toJson(), fromJson()
- **Purpose**: Represent a communication room

### Utilities & Configuration

#### `lib/utils/device_utils.dart` (50+ lines)
- **Functions**:
  - `getDeviceType()` - Platform detection
  - `getDeviceIcon()` - Emoji for device type
  - `getPlatformName()` - Platform name string
  - `isMobile()` - Check if mobile device
  - `isDesktop()` - Check if desktop device

#### `lib/config/app_config.dart` (25+ lines)
- **Constants**:
  - Network configuration (port, timeout)
  - Room settings (code length, expiration)
  - Message limits (max length, retries)
  - UI configuration

#### `lib/providers/state_notifiers.dart` (100+ lines)
- **Classes**:
  - `RoomNotifier` - Room state management
  - `MessagingNotifier` - Message state management
  - `NetworkNotifier` - Network state management

---

## Documentation Files (5 Comprehensive Guides)

### 1. `SETUP_COMPLETE.md` (Main Overview)
- What was built
- Architecture overview
- File structure
- How to get started
- Technical details

### 2. `QUICK_START.md` (Fast Setup)
- 5-minute setup instructions
- Usage scenarios
- Testing on emulator
- Common commands
- Quick troubleshooting

### 3. `IMPLEMENTATION_GUIDE.md` (Architecture)
- Feature list
- Architecture explanation
- Getting started guide
- Project structure details
- Future enhancements

### 4. `ANDROID_SETUP.md` (Android Config)
- Required permissions
- Network security configuration
- Gradle settings
- Build instructions
- Troubleshooting

### 5. `WINDOWS_SETUP.md` (Windows Config)
- Requirements
- Network configuration
- Build instructions
- Firewall setup
- Distribution guide

### 6. `TROUBLESHOOTING.md` (Debugging)
- Logging techniques
- Network debugging
- Common issues & solutions
- Debugging tools
- Error message guide

---

## Key Statistics

| Metric | Value |
|--------|-------|
| Total Dart Files | 15 |
| Total Documentation | 6 files |
| Lines of Core Code | 1000+ |
| UI Screens | 2 |
| Services | 4 |
| Data Models | 3 |
| Supported Platforms | 5 (Android, Windows, iOS, macOS, Linux) |

---

## Code Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Opens App                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │   main.dart               │
         │ - Initialize services     │
         │ - Detect device type      │
         │ - Show HomeScreen         │
         └──────────┬────────────────┘
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
    ┌─────────────┐      ┌──────────────┐
    │   Create    │      │    Join      │
    │    Room     │      │    Room      │
    └─────┬───────┘      └──────┬───────┘
          │                     │
          ▼                     ▼
    Generate Code      Enter 6-digit Code
          │                     │
          └──────────┬──────────┘
                     │
                     ▼
         ┌──────────────────────────┐
         │   Room Created/Joined    │
         │ - RoomService creates    │
         │ - Devices tracked        │
         │ - Navigate to Chat       │
         └──────────┬───────────────┘
                    │
                    ▼
         ┌──────────────────────────┐
         │   ChatScreen Shows       │
         │ - Connected devices      │
         │ - Message history        │
         │ - Input field            │
         └──────────┬───────────────┘
                    │
                    ▼
         ┌──────────────────────────┐
         │  Send Message Flow       │
         │ - User types message     │
         │ - MessagingService adds  │
         │ - Notify listeners       │
         │ - Show on all devices    │
         └──────────────────────────┘
```

---

## Service Interaction Diagram

```
┌──────────────────┐
│   HomeScreen     │
└────────┬─────────┘
         │ calls
         ▼
┌──────────────────────────┐      ┌─────────────────┐
│   RoomService            │────→ │  Room Model     │
│ - createRoom()           │      │  Device Model   │
│ - joinRoom()             │      └─────────────────┘
│ - getConnectedDevices()  │
└──────────┬───────────────┘
           │ on success
           ▼
┌──────────────────────────┐
│   ChatScreen             │
└──────────┬───────────────┘
           │ uses
           ├─ MessagingService (messages)
           ├─ RoomService (devices)
           └─ LocalNetworkService (network)
                    │
         ┌──────────┴──────────────────────┐
         ▼                                  ▼
    Server Mode                         Client Mode
    (Device creates room)               (Device joins room)
    - Starts TCP server                 - Connects to server
    - Listens on port 5000              - Sends device info
    - Accepts connections               - Receives messages
    - Broadcasts messages               - Sends local messages
```

---

## Data Flow Example: Sending a Message

```
User Types Message
         │
         ▼
ChatScreen._sendMessage()
         │
         ├─ Get message from TextEditingController
         ├─ Validate (not empty)
         │
         ▼
MessagingService.addMessage()
         │
         ├─ Create Message object
         ├─ Add to messages list
         ├─ Call onMessageAdded callback
         │
         ▼
Update UI
         │
         ├─ Rebuild message list
         ├─ Show in ChatScreen
         │
         ▼
NetworkService.sendMessage()
         │
         ├─ Format message with protocol
         ├─ Send via socket
         │
         ▼
Broadcast to Other Devices
         │
         ├─ All connected sockets receive
         ├─ Display in their ChatScreen
         │
         ▼
Message Visible on All Devices ✅
```

---

## Technology Stack

```
Flutter Framework
│
├─ UI Layer
│  ├─ Material Design Widgets
│  ├─ StatefulWidgets (HomeScreen, ChatScreen)
│  └─ Navigation/Routing
│
├─ Business Logic
│  ├─ RoomService (State Management)
│  ├─ MessagingService
│  └─ LocalNetworkService
│
├─ Data Layer
│  ├─ In-Memory Storage (Maps, Lists)
│  ├─ Models (Room, Device, Message)
│  └─ JSON Serialization
│
└─ Networking
   ├─ Dart IO Library (Sockets)
   ├─ TCP Protocol
   └─ Text-Based Message Protocol
```

---

## Dependency Tree

```
pubspec.yaml
│
├─ flutter (SDK)
├─ provider ^6.0.0 (State Management - Optional)
├─ socket_io_client ^2.0.0 (Optional, for WebSocket)
├─ uuid ^4.0.0 (Unique IDs)
├─ intl ^0.19.0 (Date/Time Formatting)
└─ shared_preferences ^2.2.0 (Local Storage - Optional)
```

---

## What Gets Executed When?

### App Startup
1. `main()` → `runApp(MainApp())`
2. `MainApp.initState()` → Initialize services
3. `MainApp.build()` → Create MaterialApp
4. `HomeScreen.build()` → Show create/join UI

### Create Room
1. User clicks "Create New Room"
2. `RoomService.createRoom()` → Generate code
3. Navigate to ChatScreen with code
4. `ChatScreen.initState()` → Load services

### Join Room
1. User enters code and clicks "Join"
2. `RoomService.joinRoom()` → Verify and add device
3. Navigate to ChatScreen with code
4. Same as create room flow

### Send Message
1. User types and clicks send
2. `ChatScreen._sendMessage()` → Get text
3. `MessagingService.addMessage()` → Store
4. Update UI state
5. `setState()` → Rebuild message list

---

**This is your complete project structure! Start with QUICK_START.md to begin using the app.**
