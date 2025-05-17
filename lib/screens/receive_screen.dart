import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../widgets/transfer_progress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/encryption_service.dart';
import '../models/received_file.dart';
import 'package:path/path.dart' as path;

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({Key? key}) : super(key: key);

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _isReceiving = false;
  bool _isDiscoverable = false;
  double _transferProgress = 0.0;
  String _statusMessage = '';
  List<String> _receivedFiles = [];
  String _savePath = '';
  List<ReceivedFile> _receivedFileObjects = [];

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _getSavePath();
  }

  Future<void> _getSavePath() async {
    final directory = await getExternalStorageDirectory();
    final path = '${directory?.path}/BluetoothPhotoTransfer';
    
    // Create directory if it doesn't exist
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    setState(() {
      _savePath = path;
    });
  }

  Future<void> _initBluetooth() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    await bluetoothService.initialize();
  }

  Future<void> _makeDiscoverable() async {
    setState(() {
      _isDiscoverable = true;
      _statusMessage = 'Making device discoverable...';
    });

    try {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      await bluetoothService.makeDiscoverable(
        onTransferStarted: () {
          setState(() {
            _isReceiving = true;
            _statusMessage = 'Receiving photo...';
            _transferProgress = 0.0;
          });
        },
        onProgress: (progress) {
          setState(() {
            _transferProgress = progress;
          });
        },
        onFileReceived: (filePath, {String? fileName, bool isEncrypted = false, String? encryptionKey}) async {
          // If the file is encrypted, decrypt it
          String finalPath = filePath;
          if (isEncrypted && encryptionKey != null && fileName != null) {
            setState(() {
              _statusMessage = 'Decrypting received photo...';
            });
            
            try {
              finalPath = await EncryptionService.decryptFile(
                filePath, 
                encryptionKey,
                fileName
              );
              
              // Delete the encrypted temporary file
              await File(filePath).delete();
            } catch (e) {
              setState(() {
                _statusMessage = 'Error decrypting file: $e';
              });
              return;
            }
          }
          
          // Add to received files list
          final newFile = ReceivedFile(
            path: finalPath,
            name: fileName ?? path.basename(finalPath),
            isEncrypted: isEncrypted,
            receivedAt: DateTime.now(),
          );
          
          setState(() {
            _receivedFiles.add(finalPath);
            _receivedFileObjects.add(newFile);
            _isReceiving = false;
            _statusMessage = isEncrypted 
                ? 'Encrypted photo received and decrypted successfully!' 
                : 'Photo received successfully!';
          });
        },
        onError: (error) {
          setState(() {
            _isReceiving = false;
            _statusMessage = 'Error receiving file: $error';
          });
          _showErrorSnackBar('Error receiving file: $error');
        },
      );
      
      setState(() {
        _statusMessage = 'Your device is now discoverable. Waiting for connection...';
      });
    } catch (e) {
      setState(() {
        _isDiscoverable = false;
        _statusMessage = 'Error making device discoverable: $e';
      });
      _showErrorSnackBar('Error making device discoverable: $e');
    }
  }

  Future<void> _stopDiscoverable() async {
    try {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      await bluetoothService.stopDiscoverable();
      
      setState(() {
        _isDiscoverable = false;
        _statusMessage = '';
      });
    } catch (e) {
      _showErrorSnackBar('Error stopping discoverable mode: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _viewReceivedPhotos() async {
    if (_receivedFiles.isEmpty) {
      _showErrorSnackBar('No photos received yet');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceivedPhotosScreen(
          photos: _receivedFiles,
          receivedFileObjects: _receivedFileObjects,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Photos'),
        actions: [
          if (_receivedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: _viewReceivedPhotos,
              tooltip: 'View received photos',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status and progress section
            if (_statusMessage.isNotEmpty || _isReceiving)
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (_isReceiving) ...[
                      const SizedBox(height: 8),
                      TransferProgress(progress: _transferProgress),
                    ],
                  ],
                ),
              ),
            
            Expanded(
              child: Center(
                child: _isDiscoverable
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bluetooth_searching,
                              size: 60,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Waiting for sender device',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your device is discoverable and ready to receive photos',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                          if (_receivedFiles.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              '${_receivedFiles.length} photos received',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Saved to: $_savePath',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _viewReceivedPhotos,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('View Received Photos'),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Ready to Receive Photos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Tap the button below to make your device discoverable and receive photos via Bluetooth',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _makeDiscoverable,
                            icon: const Icon(Icons.bluetooth_searching),
                            label: const Text('Make Discoverable'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isDiscoverable
          ? FloatingActionButton.extended(
              onPressed: _stopDiscoverable,
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('Stop Discoverable'),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
          : null,
    );
  }
}

// Update the ReceivedPhotosScreen class to show encryption status
class ReceivedPhotosScreen extends StatelessWidget {
  final List<String> photos;
  final List<ReceivedFile> receivedFileObjects;
  
  const ReceivedPhotosScreen({
    Key? key, 
    required this.photos,
    required this.receivedFileObjects,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${photos.length} Received Photos'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final isEncrypted = index < receivedFileObjects.length 
              ? receivedFileObjects[index].isEncrypted 
              : false;
              
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenPhoto(
                    photoPath: photos[index],
                    isEncrypted: isEncrypted,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(photos[index]),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                if (isEncrypted)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: EncryptionBadge(
                      isEncrypted: isEncrypted,
                      mini: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FullScreenPhoto extends StatelessWidget {
  final String photoPath;
  final bool isEncrypted;
  
  const FullScreenPhoto({
    Key? key, 
    required this.photoPath,
    this.isEncrypted = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isEncrypted)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: EncryptionBadge(isEncrypted: isEncrypted),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.file(
            File(photoPath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class EncryptionBadge extends StatelessWidget {
  final bool isEncrypted;
  final bool mini;

  const EncryptionBadge({
    Key? key,
    required this.isEncrypted,
    this.mini = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mini ? 4 : 8,
        vertical: mini ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isEncrypted ? Colors.orange : Colors.green,
        borderRadius: BorderRadius.circular(mini ? 8 : 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEncrypted ? Icons.lock : Icons.lock_open,
            size: mini ? 12 : 16,
            color: Colors.white,
          ),
          if (!mini) ...[
            const SizedBox(width: 4),
            Text(
              isEncrypted ? 'Encrypted' : 'Unencrypted',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
