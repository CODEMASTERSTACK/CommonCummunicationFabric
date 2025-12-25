# Step-by-Step Implementation Walkthrough

## Phase 1: Understanding the Architecture (Read This First)

### What You're Building

A Flutter app that lets multiple devices communicate on a local network:
- Device 1 creates a "room" with a 6-digit code
- Device 2 enters the code and joins
- All devices can now see each other and send messages
- No internet required (local network only)

### Three Main Components

```
1. ROOMS (RoomService)
   - Create rooms
   - Generate 6-digit codes
   - Track which devices are in which room

2. MESSAGING (MessagingService)
   - Store messages
   - Retrieve by room
   - Notify when new messages arrive

3. NETWORKING (LocalNetworkService)
   - Send data over TCP sockets
   - Act as server (for room creator)
   - Act as client (for room joiners)
   - Broadcast messages to all devices
```

---

## Phase 2: Code Walkthrough

### File 1: Models (Data Structures)

**`lib/models/device.dart`** - Represents a connected device
```dart
Device {
  id: "unique-id",
  name: "My Phone",
  type: "phone",  // or "pc", "laptop"
  connectedAt: DateTime.now(),
  isActive: true
}
```

**`lib/models/room.dart`** - Represents a room
```dart
Room {
  code: "123456",
  creatorDeviceId: "device-1",
  creatorDeviceName: "My PC",
  createdAt: DateTime.now(),
  connectedDevices: [device1, device2, device3],
  isActive: true  // Valid for 24 hours
}
```

**`lib/models/message.dart`** - Represents a message
```dart
Message {
  id: "msg-id",
  senderDeviceId: "device-1",
  senderDeviceName: "My PC",
  content: "Hello from PC",
  timestamp: DateTime.now(),
  roomCode: "123456"
}
```

### File 2: Services (Business Logic)

**`lib/services/room_service.dart`** - How rooms work

```dart
class RoomService {
  Map<String, Room> _rooms = {};  // All rooms
  
  // CREATE ROOM
  Room createRoom() {
    String code = _generateRoomCode();  // "123456"
    Room room = Room(
      code: code,
      creatorDeviceId: "my-device-id",
      creatorDeviceName: "My PC",
      createdAt: DateTime.now(),
      connectedDevices: [currentDevice]
    );
    _rooms[code] = room;  // Save room
    return room;
  }
  
  // JOIN ROOM
  bool joinRoom(String code) {
    if (_rooms.containsKey(code)) {
      Room room = _rooms[code];
      room.connectedDevices.add(newDevice);
      return true;
    }
    return false;
  }
  
  // GET DEVICES IN ROOM
  List<Device> getConnectedDevices() {
    Room room = _rooms[currentRoomCode];
    return room.connectedDevices;  // [device1, device2, device3]
  }
}
```

**`lib/services/messaging_service.dart`** - How messages work

```dart
class MessagingService {
  List<Message> _messages = [];  // All messages
  
  // ADD MESSAGE
  void addMessage({
    required String senderDeviceId,
    required String senderDeviceName,
    required String content,
    required String roomCode,
  }) {
    Message msg = Message(
      id: generateId(),
      senderDeviceId: senderDeviceId,
      senderDeviceName: senderDeviceName,
      content: content,
      timestamp: DateTime.now(),
      roomCode: roomCode
    );
    _messages.add(msg);
    
    // Tell UI to update
    onMessageAdded?.call(msg);
  }
  
  // GET MESSAGES FOR A ROOM
  List<Message> getMessagesForRoom(String roomCode) {
    return _messages.where((m) => m.roomCode == roomCode).toList();
  }
}
```

**`lib/services/local_network_service.dart`** - How network works

```dart
class LocalNetworkService {
  ServerSocket _serverSocket;  // Listen for connections
  Map<String, Socket> _clients = {};  // Connected clients
  
  // START SERVER (Device creates room)
  Future<void> startServer() async {
    _serverSocket = await ServerSocket.bind("0.0.0.0", 5000);
    
    // Listen for devices trying to connect
    _serverSocket.listen((Socket client) {
      print("Device connected!");
      _clients[deviceId] = client;
      
      // Listen for messages from this client
      client.listen((data) {
        String message = String.fromCharCodes(data);
        // Broadcast to all other clients
        for (var otherClient in _clients.values) {
          otherClient.write(message);
        }
      });
    });
  }
  
  // CONNECT TO SERVER (Device joins room)
  Future<Socket> connectToServer(String ip) async {
    Socket socket = await Socket.connect(ip, 5000);
    
    // Listen for messages from server
    socket.listen((data) {
      String message = String.fromCharCodes(data);
      // Show message on UI
    });
    
    return socket;
  }
  
  // SEND MESSAGE
  void sendMessage(Socket socket, String message) {
    socket.write(message);
  }
}
```

### File 3: UI Screens

**`lib/screens/home_screen.dart`** - The home page

```
┌─────────────────────────────────┐
│     Home Screen                 │
├─────────────────────────────────┤
│                                 │
│  📱 Current Device              │
│  └─ My Phone                    │
│                                 │
│  ┌─────────────────────────────┐│
│  │ Create New Room              ││
│  └─────────────────────────────┘│
│                                 │
│  ───────── OR ─────────         │
│                                 │
│  Enter 6-digit code:            │
│  [ 1 2 3 4 5 6 ]               │
│  ┌─────────────────────────────┐│
│  │ Join Room                    ││
│  └─────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

Flow:
1. User opens app → Sees HomeScreen
2. Two choices: Create or Join
3. If Create: Gets code, goes to ChatScreen
4. If Join: Enters code, tries to connect, goes to ChatScreen

**`lib/screens/chat_screen.dart`** - The chat page

```
┌────────────────────────────────┐
│ Room: 123456   (3 devices)     │ ← Room code
├────────────────────────────────┤
│                                │
│ Connected Devices:             │ ← Show all devices
│ ┌──┐ ┌──┐ ┌──┐                 │
│ │📱│ │🖥│ │💻│                 │
│ │My│ │PC│ │Lab│                │
│ │Ph│ │  │ │top│                │
│ └──┘ └──┘ └──┘ (You) ← Status  │
├────────────────────────────────┤
│                                │
│ ┌─────────────────────────────┐│ ← Messages
│ │ PC:                         ││
│ │ Hello from Windows!         ││
│ │ 10:30 AM                    ││
│ └─────────────────────────────┘│
│                                │
│              ┌─────────────────┐│ ← Your message
│              │ My Phone:       ││
│              │ Hi PC!          ││
│              │ 10:31 AM        ││
│              └─────────────────┘│
│                                │
├────────────────────────────────┤
│ [ Type message...        ] [➤] │ ← Input
└────────────────────────────────┘
```

Flow:
1. Shows all connected devices
2. Shows message history for the room
3. User types message and sends
4. Message appears in list and sent to all devices

---

## Phase 3: Step-by-Step Usage

### Scenario: Connect Phone to PC

#### Step 1: Device 1 (PC) - Create Room
```
1. Open app on Windows PC
2. Click "Create New Room"
   └─ RoomService.createRoom() called
   └─ Generates code: "234567"
   └─ Starts server on port 5000
   └─ Navigates to ChatScreen with code
3. See ChatScreen with only PC listed
4. Share code "234567" with phone
```

#### Step 2: Device 2 (Phone) - Join Room
```
1. Open app on Android phone
2. See HomeScreen
3. Click "Join Existing Room"
4. Enter code: "234567"
5. Click "Join"
   └─ RoomService.joinRoom("234567") called
   └─ LocalNetworkService.connectToServer("192.168.1.100") called
   └─ Connects to PC's server
   └─ Navigates to ChatScreen
6. See ChatScreen with both PC and Phone listed
7. PC also sees Phone in device list
```

#### Step 3: Send Messages
```
Phone user types: "Hello PC!"
                └─ ChatScreen._sendMessage()
                └─ MessagingService.addMessage()
                └─ LocalNetworkService.sendMessage()
                └─ PC receives via socket
                └─ Both show message

PC user types: "Hi Phone!"
                └─ Same flow in reverse
                └─ Phone receives and shows
```

---

## Phase 4: Understanding the Data Flow

### Creating a Room - Complete Flow

```
User clicks "Create Room"
    │
    ▼
HomeScreen._createRoom()
    │
    ├─ Call: roomService.createRoom()
    │   │
    │   └─ Create Room object
    │       ├─ Generate code: "234567"
    │       ├─ Set creator: "PC Device"
    │       ├─ Add current device to list
    │       └─ Save in _rooms map
    │
    ├─ Start server
    │   └─ LocalNetworkService.startServer(port: 5000)
    │
    └─ Navigate to ChatScreen
        ├─ Pass roomCode: "234567"
        └─ Pass services (RoomService, MessagingService)

ChatScreen loads
    ├─ Get current room data
    ├─ Show code "234567"
    ├─ Show device list: [PC Device]
    ├─ Ready to receive connections
    └─ Wait for other devices to join
```

### Joining a Room - Complete Flow

```
User enters code "234567" and clicks "Join"
    │
    ▼
HomeScreen._joinRoom("234567")
    │
    ├─ Call: roomService.joinRoom("234567")
    │   │
    │   ├─ Check if room exists
    │   │   └─ YES: Room found in _rooms
    │   │
    │   ├─ Add current device to room.connectedDevices
    │   │
    │   └─ Return success: true
    │
    ├─ Connect to server
    │   └─ LocalNetworkService.connectToServer(
    │       ip: "192.168.1.100",  // PC's IP
    │       port: 5000
    │   )
    │   └─ Socket connection established
    │
    └─ Navigate to ChatScreen
        ├─ Pass roomCode: "234567"
        └─ Pass services

ChatScreen loads
    ├─ Get current room data
    ├─ Show code "234567"
    ├─ Show device list: [PC Device, Phone Device]
    ├─ Both devices now see each other
    └─ Ready to exchange messages

PC's ChatScreen
    └─ Detects new device
    └─ Refreshes device list
    └─ Shows [PC Device, Phone Device]
```

### Sending a Message - Complete Flow

```
User types "Hello" in phone and taps send
    │
    ▼
ChatScreen._sendMessage()
    │
    ├─ Get text: "Hello"
    ├─ Clear input field
    │
    └─ Call: messagingService.addMessage(
         senderDeviceId: "phone-uuid",
         senderDeviceName: "My Phone",
         content: "Hello",
         roomCode: "234567"
       )
       │
       └─ Create Message object
       ├─ Add to _messages list
       ├─ Call onMessageAdded callback
       │
       └─ Phone's ChatScreen updates
           └─ setState() called
           └─ Message appears in list
           └─ User sees "My Phone: Hello"

Phone's network service
    │
    └─ Send via socket to PC:
       "234567|message|phone-uuid|Hello"

PC's network service
    │
    └─ Receive message
    ├─ Parse: code="234567", content="Hello"
    │
    └─ Call onMessageReceived callback
        │
        └─ MessagingService.addMessage()
        └─ PC's ChatScreen updates
           └─ setState() called
           └─ Message appears
           └─ User sees "My Phone: Hello"
```

---

## Phase 5: Key Concepts

### Room Code Generation

```dart
String generateRoomCode() {
  // Generate random number between 100000 and 999999
  Random random = Random();
  return (100000 + random.nextInt(900000)).toString();
}

// Examples: "234567", "512890", "100000"
```

### Device Types

```dart
String getDeviceType() {
  if (Platform.isAndroid) return "phone";
  if (Platform.isIOS) return "phone";
  if (Platform.isWindows) return "pc";
  if (Platform.isMacOS) return "laptop";
  if (Platform.isLinux) return "pc";
}
```

### Communication Protocol

```
Format: roomCode|type|deviceId|content

Types:
- "register": Device registration
- "message": Chat message

Examples:
- "234567|register|device-123|My Phone"
- "234567|message|device-123|Hello from Phone!"
```

### Message Timestamps

```dart
Message {
  timestamp: DateTime.now(),  // Current time when created
  // Used for: Ordering messages, showing time in UI
}
```

---

## Phase 6: Common Patterns

### Pattern 1: Update UI When Data Changes
```dart
// In service
class MessagingService {
  final Function(Message)? onMessageAdded;
  
  void addMessage({...}) {
    // ... create message ...
    onMessageAdded?.call(message);  // Notify UI
  }
}

// In UI
ChatScreen
  ├─ Listen for messages
  └─ Call setState() to rebuild
      └─ Show new message
```

### Pattern 2: Navigation with Data
```dart
// Navigate
Navigator.pushNamed(
  context,
  '/chat',
  arguments: {'roomCode': '234567'}
);

// Receive
final args = ModalRoute.of(context)!.settings.arguments as Map;
String roomCode = args['roomCode'];
```

### Pattern 3: Service Instance Sharing
```dart
// main.dart
RoomService roomService = RoomService(deviceName: "My Phone");

// Pass to screens
HomeScreen(roomService: roomService)
ChatScreen(roomService: roomService)

// Use in screens
widget.roomService.createRoom()
widget.roomService.joinRoom(code)
```

---

## Phase 7: Testing Locally

### Test 1: Create and Join Same Device
```
Device 1:
  1. Click Create → Get code "123456"
  2. Copy code
  3. Go back, click Join
  4. Enter "123456"
  5. Click Join
  6. Should see 2 devices (same device twice)
```

### Test 2: Multiple Emulators (Android)
```
Terminal 1:
  emulator -avd Pixel_4_API_30

Terminal 2:
  emulator -avd Pixel_5_API_31

Terminal 3:
  flutter devices

Terminal 4:
  flutter run -d emulator-5554  # Emulator 1

Terminal 5:
  flutter run -d emulator-5556  # Emulator 2
```

### Test 3: Real Devices
```
Both on same WiFi:
  Device 1: Create room → Code
  Device 2: Join with code
  Send messages both ways
```

---

## You Now Understand

✅ How rooms are created and managed  
✅ How devices join rooms  
✅ How messages are sent and received  
✅ How the UI updates  
✅ How network communication works  
✅ The complete data flow  

**Next: Read QUICK_START.md to actually run the app!**
