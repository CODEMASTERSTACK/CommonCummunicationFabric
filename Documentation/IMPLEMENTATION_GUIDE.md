# Common Communication App

A cross-platform Flutter application that enables real-time communication between your phone, PC, and laptop over a local network.

## Features

- **Create Rooms**: One device can create a communication room and receive a unique 6-digit code
- **Join Rooms**: Other devices can join using the generated code
- **Real-time Messaging**: Send and receive messages across all connected devices
- **Device Management**: Track which devices are connected to a room
- **Local Network Communication**: All communication happens over your local network for privacy
- **Multi-Platform Support**: Works on Android, Windows, Linux, macOS, and iOS

## Architecture

### Core Components

1. **RoomService** (`services/room_service.dart`)
   - Manages room creation and joining
   - Generates 6-digit room codes
   - Tracks connected devices
   - Handles device registration

2. **MessagingService** (`services/messaging_service.dart`)
   - Stores and retrieves messages
   - Manages message history per room
   - Provides callbacks for new messages

3. **LocalNetworkService** (`services/local_network_service.dart`)
   - Handles TCP socket connections
   - Implements server-client architecture
   - Manages device-to-device communication
   - Supports message broadcasting

4. **Models**
   - `Device`: Represents a connected device with metadata
   - `Message`: Represents a chat message
   - `Room`: Represents a communication room

### UI Screens

1. **HomeScreen** (`screens/home_screen.dart`)
   - Create new room
   - Join existing room with code
   - Display current device information

2. **ChatScreen** (`screens/chat_screen.dart`)
   - Real-time chat interface
   - Show connected devices
   - Send and receive messages
   - Display message history

## Getting Started

### Prerequisites

- Flutter SDK (3.10.4 or higher)
- Android SDK (for Android development)
- Windows SDK (for Windows development)

### Installation

1. Clone the repository
   ```bash
   cd common_com
   ```

2. Get dependencies
   ```bash
   flutter pub get
   ```

3. Run the app
   ```bash
   # For Android
   flutter run -d android
   
   # For Windows
   flutter run -d windows
   
   # For specific device
   flutter run -d <device_id>
   ```

## How to Use

### Creating a Room (Device 1)

1. Open the app on your first device
2. Tap "Create New Room"
3. A 6-digit code will be generated
4. Share this code with other devices

### Joining a Room (Device 2 & 3)

1. Open the app on your second device
2. Enter the 6-digit code from Device 1
3. Tap "Join Room"
4. You're now connected and can see all connected devices
5. Start sending messages!

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   ├── device.dart                   # Device model
│   ├── message.dart                  # Message model
│   └── room.dart                     # Room model
├── services/
│   ├── local_network_service.dart    # Network communication
│   ├── messaging_service.dart        # Message management
│   └── room_service.dart             # Room management
└── screens/
    ├── home_screen.dart              # Home/Login screen
    └── chat_screen.dart              # Chat interface
```

## Dependencies

- **provider**: State management
- **socket_io_client**: WebSocket communication (optional, can use raw sockets)
- **uuid**: Generate unique identifiers
- **intl**: Internationalization and formatting
- **shared_preferences**: Local data persistence

## Technical Details

### Room Code Generation

- 6-digit numeric code (100000-999999)
- Randomly generated when room is created
- Valid for 24 hours by default
- Checked against existing rooms to prevent duplicates

### Network Communication Protocol

The app uses a simple text-based protocol over TCP sockets:

```
Format: <roomCode>|<type>|<deviceId>|<content>
Types: register, message
Example: 123456|message|device-uuid|Hello from Android!
```

### Device Types

- `phone`: Android or iOS device
- `pc`: Windows device
- `laptop`: macOS or Linux device

## Future Enhancements

1. **End-to-End Encryption**: Encrypt messages for privacy
2. **File Transfer**: Share files between devices
3. **Voice/Video Calls**: Real-time audio/video communication
4. **Device Discovery**: Auto-discover devices on network
5. **Persistent Storage**: Save chat history
6. **User Profiles**: Custom user names and avatars
7. **Read Receipts**: Show message delivery status
8. **Typing Indicators**: Show when someone is typing
9. **Room Persistence**: Save rooms across sessions
10. **Mobile Notifications**: Push notifications for new messages

## Troubleshooting

### Can't connect to another device

1. Ensure both devices are on the same WiFi network
2. Check firewall settings
3. Verify the room code is entered correctly
4. Restart both apps and try again

### Messages not appearing

1. Check if devices are still connected
2. Verify network connectivity
3. Restart the app
4. Check device logs for errors

### Room code not found

1. Ensure the code is still valid (within 24 hours)
2. Verify the code is entered correctly
3. Ensure the creating device's app is still running
4. Try creating a new room

## License

This project is open source and available under the MIT License.

## Support

For issues and questions, please create an issue on the GitHub repository.
