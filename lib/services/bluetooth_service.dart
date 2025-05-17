import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'encryption_service.dart';

class BluetoothDevice {
  final String id;
  final String name;
  final bool isPaired;
  
  BluetoothDevice({
    required this.id,
    required this.name,
    this.isPaired = false,
  });
}

class BluetoothService extends ChangeNotifier {
  static const platform = MethodChannel('com.example.bluetooth_photo_transfer/bluetooth');
  
  List<BluetoothDevice> _devices = [];
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isDiscoverable = false;
  
  // Add these fields to the BluetoothService class
  bool _useEncryption = false;
  String _encryptionKey = '';
  
  bool get useEncryption => _useEncryption;
  
  void setEncryption(bool value) {
    _useEncryption = value;
    if (value) {
      // Generate a new encryption key when encryption is enabled
      _encryptionKey = EncryptionService.generateEncryptionKey();
    } else {
      _encryptionKey = '';
    }
    notifyListeners();
  }
  
  String get encryptionKey => _encryptionKey;
  
  List<BluetoothDevice> get devices => _devices;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isDiscoverable => _isDiscoverable;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final result = await platform.invokeMethod('initialize');
      _isInitialized = result ?? false;
      notifyListeners();
    } on PlatformException catch (e) {
      throw 'Failed to initialize Bluetooth: ${e.message}';
    }
  }
  
  Future<void> startScan() async {
    if (!_isInitialized) {
      throw 'Bluetooth not initialized';
    }
    
    if (_isScanning) return;
    
    try {
      _isScanning = true;
      notifyListeners();
      
      final List<dynamic> result = await platform.invokeMethod('startScan') ?? [];
      
      _devices = result.map((device) {
        return BluetoothDevice(
          id: device['id'],
          name: device['name'] ?? 'Unknown Device',
          isPaired: device['isPaired'] ?? false,
        );
      }).toList();
      
      _isScanning = false;
      notifyListeners();
    } on PlatformException catch (e) {
      _isScanning = false;
      notifyListeners();
      throw 'Failed to scan for devices: ${e.message}';
    }
  }
  
  Future<void> connectToDevice(String deviceId) async {
    if (!_isInitialized) {
      throw 'Bluetooth not initialized';
    }
    
    try {
      final result = await platform.invokeMethod('connectToDevice', {
        'deviceId': deviceId,
      });
      
      _isConnected = result ?? false;
      notifyListeners();
      
      if (!_isConnected) {
        throw 'Failed to connect to device';
      }
    } on PlatformException catch (e) {
      throw 'Failed to connect to device: ${e.message}';
    }
  }
  
  Future<void> disconnect() async {
    if (!_isInitialized || !_isConnected) return;
    
    try {
      await platform.invokeMethod('disconnect');
      _isConnected = false;
      notifyListeners();
    } on PlatformException catch (e) {
      throw 'Failed to disconnect: ${e.message}';
    }
  }
  
  // Update the makeDiscoverable method to handle encryption metadata
  Future<void> makeDiscoverable({
    required VoidCallback onTransferStarted,
    required Function(double) onProgress,
    required Function(String, {String? fileName, bool isEncrypted, String? encryptionKey}) onFileReceived,
    required Function(String) onError,
  }) async {
    if (!_isInitialized) {
      throw 'Bluetooth not initialized';
    }
    
    if (_isDiscoverable) return;
    
    try {
      // Set up event channel for receiving file transfer events
      const EventChannel eventChannel = EventChannel('com.example.bluetooth_photo_transfer/bluetooth_events');
      
      eventChannel.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final String eventType = event['type'];
          
          switch (eventType) {
            case 'transferStarted':
              onTransferStarted();
              break;
            case 'progress':
              final double progress = (event['progress'] as num).toDouble();
              onProgress(progress);
              break;
            case 'fileReceived':
              final String filePath = event['filePath'];
              final String fileName = event['fileName'] ?? path.basename(filePath);
              final bool isEncrypted = event['isEncrypted'] ?? false;
              final String? encryptionKey = event['encryptionKey'];
              
              onFileReceived(
                filePath, 
                fileName: fileName,
                isEncrypted: isEncrypted,
                encryptionKey: encryptionKey
              );
              break;
            case 'error':
              final String errorMessage = event['message'];
              onError(errorMessage);
              break;
          }
        }
      });
      
      final result = await platform.invokeMethod('makeDiscoverable');
      _isDiscoverable = result ?? false;
      notifyListeners();
      
      if (!_isDiscoverable) {
        throw 'Failed to make device discoverable';
      }
    } on PlatformException catch (e) {
      throw 'Failed to make device discoverable: ${e.message}';
    }
  }
  
  Future<void> stopDiscoverable() async {
    if (!_isInitialized || !_isDiscoverable) return;
    
    try {
      await platform.invokeMethod('stopDiscoverable');
      _isDiscoverable = false;
      notifyListeners();
    } on PlatformException catch (e) {
      throw 'Failed to stop discoverable mode: ${e.message}';
    }
  }
  
  // Modify the sendFile method to handle encryption
  Future<void> sendFile(
    File file, {
    required Function(double) onProgress,
  }) async {
    if (!_isInitialized || !_isConnected) {
      throw 'Not connected to a device';
    }
    
    try {
      // Set up event channel for sending file transfer events
      const EventChannel eventChannel = EventChannel('com.example.bluetooth_photo_transfer/bluetooth_events');
      
      // Listen for progress updates
      final subscription = eventChannel.receiveBroadcastStream().listen((event) {
        if (event is Map && event['type'] == 'sendProgress') {
          final double progress = (event['progress'] as num).toDouble();
          onProgress(progress);
        }
      });
      
      // Encrypt the file if encryption is enabled
      String fileToSend = file.path;
      bool isEncrypted = false;
      
      if (_useEncryption) {
        fileToSend = await EncryptionService.encryptFile(file.path, _encryptionKey);
        isEncrypted = true;
      }
      
      // Send the file
      final result = await platform.invokeMethod('sendFile', {
        'filePath': fileToSend,
        'fileName': path.basename(file.path),
        'isEncrypted': isEncrypted,
        'encryptionKey': _encryptionKey,
      });
      
      // Delete temporary encrypted file if it was created
      if (isEncrypted) {
        await File(fileToSend).delete();
      }
      
      // Cancel the subscription after the file is sent
      subscription.cancel();
      
      if (!(result ?? false)) {
        throw 'Failed to send file';
      }
    } on PlatformException catch (e) {
      throw 'Failed to send file: ${e.message}';
    }
  }
}
