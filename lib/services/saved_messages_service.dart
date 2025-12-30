import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_message.dart';

class SavedMessagesService {
  static const String _storageKey = 'saved_messages';
  final List<SavedMessage> _savedMessages = [];
  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize the service and load saved messages
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedMessages();
    _initialized = true;
  }

  /// Load saved messages from persistent storage
  Future<void> _loadSavedMessages() async {
    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _savedMessages.clear();
        for (final item in jsonList) {
          _savedMessages.add(
            SavedMessage.fromJson(item as Map<String, dynamic>),
          );
        }
      }
    } catch (e) {
      print('Error loading saved messages: $e');
    }
  }

  /// Save messages to persistent storage
  Future<void> _saveToPersistence() async {
    try {
      final jsonList = _savedMessages.map((m) => m.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  /// Add a message to saved messages
  Future<void> saveMessage(SavedMessage message) async {
    await _ensureInitialized();
    // Check if already exists
    if (!_savedMessages.any((m) => m.id == message.id)) {
      _savedMessages.insert(0, message); // Add to beginning (newest first)
      await _saveToPersistence();
    }
  }

  /// Remove a message from saved messages
  Future<void> unsaveMessage(String messageId) async {
    await _ensureInitialized();
    _savedMessages.removeWhere((m) => m.id == messageId);
    await _saveToPersistence();
  }

  /// Check if a message is saved
  Future<bool> isMessageSaved(String messageId) async {
    await _ensureInitialized();
    return _savedMessages.any((m) => m.id == messageId);
  }

  /// Ensure service is initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Get all saved messages
  List<SavedMessage> getSavedMessages() {
    return List.unmodifiable(_savedMessages);
  }

  /// Get saved messages by type
  List<SavedMessage> getSavedMessagesByType(String type) {
    return _savedMessages.where((m) => m.type == type).toList();
  }

  /// Clear all saved messages
  Future<void> clearAll() async {
    await _ensureInitialized();
    _savedMessages.clear();
    await _saveToPersistence();
  }
}
