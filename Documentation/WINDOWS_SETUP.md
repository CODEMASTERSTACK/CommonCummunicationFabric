# Windows Configuration Guide

## Requirements

- Windows 10 or later
- Visual Studio 2022 Community (or Build Tools)
- Flutter SDK configured for Windows

## Network Configuration

Windows allows local network communication without special configuration for sockets on the same network.

## Building for Windows

### Development

```bash
# Run in debug mode
flutter run -d windows

# Watch for changes
flutter run -d windows --hot
```

### Release Build

```bash
# Build release executable
flutter build windows --release

# The executable will be at:
# build/windows/x64/runner/Release/common_com.exe
```

## Firewall Configuration

If you encounter connection issues:

1. Open Windows Defender Firewall
2. Click "Allow an app through firewall"
3. Look for "Common Communication" (or Flutter app)
4. Ensure both "Private" and "Public" are checked
5. Alternatively, allow port 5000:
   - Inbound: TCP/UDP port 5000
   - Outbound: TCP/UDP port 5000

### Command Line (Admin)

```powershell
# Allow port 5000
netsh advfirewall firewall add rule name="CommonCom" dir=in action=allow protocol=tcp localport=5000
netsh advfirewall firewall add rule name="CommonCom" dir=out action=allow protocol=tcp localport=5000
```

## Testing Connection

### Find Your IP Address

```powershell
# Open PowerShell and run:
ipconfig

# Look for "IPv4 Address" under your network adapter
# Format: 192.168.x.x or 10.x.x.x
```

### Test Port Connectivity

From another device on the same network:

```bash
# Test if port 5000 is reachable
telnet 192.168.1.x 5000

# Or use Flutter diagnostics
flutter doctor -v
```

## Distribution

### Create Installer

1. Build release version
2. Use MSIX packaging:
   ```bash
   flutter pub add msix
   flutter pub run msix:create
   ```

3. Or create a portable version by distributing the executable folder

## Troubleshooting

### Port Already in Use

```powershell
# Find process using port 5000
netstat -ano | findstr :5000

# Kill the process
taskkill /PID <PID> /F
```

### Connection Refused

- Check if Windows Firewall is blocking the connection
- Verify the other device has the same network
- Ensure port 5000 is not used by another application

### IPv6 Issues

If IPv4 doesn't work, check if your network uses IPv6:

```powershell
# Check network configuration
ipconfig /all
```

## Remote Debugging

### Enable Port Forwarding

If on different networks but with VPN:

```bash
# On the PC running the server
flutter run -d windows

# Find the local IP from the app output
# On phone, use that IP with port forwarding
```

## Performance Tips

1. Use Release builds for better performance
2. Keep window size reasonable for rendering performance
3. Monitor network traffic using Task Manager
4. Use "flutter analyze" to check for issues

## Known Limitations

- Works best on same local network (same WiFi/LAN)
- May require firewall exceptions
- Port 5000 may conflict with other services
- IPv6-only networks may have connectivity issues
