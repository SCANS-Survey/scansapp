import 'package:flutter/material.dart';
import 'settings_service.dart';

/// Configuration dialog for device settings
class SettingsDialog extends StatefulWidget {
  final SettingsService settingsService;

  const SettingsDialog({
    super.key,
    required this.settingsService,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late bool _showCamera;
  late bool _captureAudio;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.settingsService.getDeviceName());
    _ipController =
        TextEditingController(text: widget.settingsService.getIpAddress());
    _portController = TextEditingController(
      text: widget.settingsService.getPort().toString(),
    );
    _showCamera = widget.settingsService.getShowCamera();
    _captureAudio = widget.settingsService.getCaptureAudio();
  }


  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    // Validate port number
    final portValue = int.tryParse(_portController.text);
    if (portValue == null || portValue < 1 || portValue > 65535) {
      _showErrorDialog('Invalid Port',
          'Port must be a number between 1 and 65535.');
      return;
    }

    // Validate IP address (basic validation)
    if (!_isValidIpAddress(_ipController.text)) {
      _showErrorDialog('Invalid IP Address',
          'Please enter a valid IP address (e.g., 192.168.1.1).');
      return;
    }

    // Save settings
    await widget.settingsService.setDeviceName(_nameController.text);
    await widget.settingsService.setIpAddress(_ipController.text);
    await widget.settingsService.setPort(portValue);
    await widget.settingsService.setShowCamera(_showCamera);
    await widget.settingsService.setCaptureAudio(_captureAudio);
    if (mounted) {
      Navigator.pop(context, true);
      _showSuccessSnackBar('Settings saved successfully');
    }
  }

  bool _isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    try {
      for (var part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset to Defaults?'),
          content: const Text(
            'Are you sure you want to reset all settings to their default values?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.settingsService.resetToDefaults();
      if (mounted) {
        _nameController.text = widget.settingsService.getDeviceName();
        _ipController.text = widget.settingsService.getIpAddress();
        _portController.text = widget.settingsService.getPort().toString();
        _showCamera = widget.settingsService.getShowCamera();
        _captureAudio = widget.settingsService.getCaptureAudio();
        _showSuccessSnackBar('Settings reset to defaults');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Device Name Field
              const Text(
                'Device Name',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter device name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // IP Address Field
              const Text(
                'IP Address',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  hintText: '230.0.0.0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Port Field
              const Text(
                'Port Number',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '4446',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Show camera option
              SwitchListTile(
                title: const Text('Show camera'),
                subtitle: const Text('Display rear camera preview at low resolution'),
                value: _showCamera,
                onChanged: (value) => setState(() => _showCamera = value),
              ),
              const SizedBox(height: 8),
              // Greyscale option
              SwitchListTile(
                title: const Text('Capture Audio'),
                subtitle: const Text('Record audio and send to base station'),
                value: _captureAudio,
                onChanged: (value) => setState(() => _captureAudio = value),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _resetToDefaults,
                    child: const Text('Reset Defaults'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
