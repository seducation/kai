import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QueueProvider with ChangeNotifier {
  List<Map<String, String>> _queueItems = [];
  bool _isLoading = true;

  List<Map<String, String>> get queueItems => _queueItems;
  bool get isLoading => _isLoading;

  QueueProvider() {
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final String? serializedQueue = prefs.getString('post_queue_json');
    if (serializedQueue != null) {
      final List<dynamic> decoded = jsonDecode(serializedQueue);
      _queueItems = decoded
          .map((item) => Map<String, String>.from(item))
          .toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addToQueue(String id, String label) async {
    // Prevent duplicates in queue
    _queueItems.removeWhere((item) => item['id'] == id);

    // Insert at the beginning to show as "Item 1"
    _queueItems.insert(0, {'id': id, 'label': label});
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('post_queue_json', jsonEncode(_queueItems));
  }

  Future<void> clearQueue() async {
    _queueItems.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('post_queue_json');
  }
}
