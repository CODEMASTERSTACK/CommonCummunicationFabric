import 'package:flutter/material.dart';

class DeviceNameScreen extends StatefulWidget {
  final String defaultName;
  final Function(String) onNameSelected;

  const DeviceNameScreen({
    Key? key,
    required this.defaultName,
    required this.onNameSelected,
  }) : super(key: key);

  @override
  State<DeviceNameScreen> createState() => _DeviceNameScreenState();
}

class _DeviceNameScreenState extends State<DeviceNameScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continuePressed() {
    final deviceName = _nameController.text.trim();
    if (deviceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device name')),
      );
      return;
    }
    widget.onNameSelected(deviceName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Device Name'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.device_hub, size: 64, color: Colors.blue),
            const SizedBox(height: 32),
            const Text(
              'Enter Your Device Name',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'This name will be displayed to other devices in your room',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., My Phone, Krish\'s Laptop',
                labelText: 'Device Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.edit),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continuePressed(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continuePressed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
