import 'package:flutter/material.dart';
import '../services/api_key_manager.dart';

/// Screen for managing API keys for AI providers.
class ApiKeySettingsScreen extends StatefulWidget {
  final ApiKeyManager apiKeyManager;

  const ApiKeySettingsScreen({
    super.key,
    required this.apiKeyManager,
  });

  @override
  State<ApiKeySettingsScreen> createState() => _ApiKeySettingsScreenState();
}

class _ApiKeySettingsScreenState extends State<ApiKeySettingsScreen> {
  // List of supported providers
  final List<String> _providers = [
    'openai',
    'anthropic',
    'gemini',
    'mistral',
    'ollama', // Usually localized, but might need auth
  ];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _isVisible = {};

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  void _loadKeys() {
    for (final provider in _providers) {
      final key = widget.apiKeyManager.getKey(provider) ?? '';
      _controllers[provider] = TextEditingController(text: key);
      _isVisible[provider] = false;
    }
  }

  Future<void> _saveKey(String provider) async {
    final controller = _controllers[provider];
    if (controller != null) {
      await widget.apiKeyManager.setKey(provider, controller.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved API key for $provider')),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final provider = _providers[index];
          return _buildProviderCard(provider);
        },
      ),
    );
  }

  Widget _buildProviderCard(String provider) {
    final controller = _controllers[provider];
    final visible = _isVisible[provider] ?? false;
    final hasKey = widget.apiKeyManager.hasKey(provider);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderIcon(provider: provider),
                const SizedBox(width: 12),
                Text(
                  _capitalize(provider),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (hasKey)
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: !visible,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        visible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isVisible[provider] = !visible;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () => _saveKey(provider),
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => _saveKey(provider),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _ProviderIcon extends StatelessWidget {
  final String provider;

  const _ProviderIcon({required this.provider});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (provider) {
      case 'openai':
        color = Colors.green;
        icon = Icons.bolt;
        break;
      case 'anthropic':
        color = Colors.orange;
        icon = Icons.chat_bubble;
        break;
      case 'gemini':
        color = Colors.blue;
        icon = Icons.diamond;
        break;
      case 'ollama':
        color = Colors.black;
        icon = Icons.computer;
        break;
      default:
        color = Colors.grey;
        icon = Icons.api;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
