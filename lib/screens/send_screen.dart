import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/bluetooth_service.dart';
import '../widgets/device_list.dart';
import '../widgets/transfer_progress.dart';
import '../services/encryption_service.dart';
import '../widgets/encryption_badge.dart';
import 'image_selection_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({Key? key}) : super(key: key);

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final List<File> _selectedFiles = [];
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;
  bool _isTransferring = false;
  double _transferProgress = 0.0;
  String _statusMessage = '';
  bool _useEncryption = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    await bluetoothService.initialize();
  }

  Future<void> _pickImagesLegacy() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(images.map((xFile) => File(xFile.path)).toList());
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking images: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageSelectionScreen(
            onImagesSelected: (List<AssetEntity> assets) async {
              final files = <File>[];
              for (final asset in assets) {
                final file = await asset.file;
                if (file != null) {
                  files.add(file);
                }
              }
              setState(() {
                _selectedFiles.addAll(files);
              });
            },
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error picking images: $e');
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for nearby devices...';
    });

    try {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      await bluetoothService.startScan();
      
      setState(() {
        _isScanning = false;
        _statusMessage = bluetoothService.devices.isEmpty 
            ? 'No devices found. Try again.' 
            : 'Select a device to send photos';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error scanning: $e';
      });
      _showErrorSnackBar('Error scanning for devices: $e');
    }
  }

  Future<void> _sendToDevice(String deviceId) async {
    if (_selectedFiles.isEmpty) {
      _showErrorSnackBar('Please select at least one image to send');
      return;
    }

    setState(() {
      _isTransferring = true;
      _transferProgress = 0.0;
      _statusMessage = 'Connecting to device...';
    });

    try {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      
      // Connect to the device
      await bluetoothService.connectToDevice(deviceId);
      
      setState(() {
        _statusMessage = 'Connected. Preparing to send ${_selectedFiles.length} photos' + 
            (_useEncryption ? ' with encryption...' : '...');
      });
      
      // Send each image
      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        
        setState(() {
          _statusMessage = 'Sending ' + 
              (_useEncryption ? 'encrypted ' : '') + 
              'image ${i + 1} of ${_selectedFiles.length}...';
        });
        
        await bluetoothService.sendFile(
          file,
          onProgress: (progress) {
            setState(() {
              _transferProgress = progress;
            });
          },
        );
        
        setState(() {
          _transferProgress = (i + 1) / _selectedFiles.length;
        });
      }
      
      setState(() {
        _isTransferring = false;
        _statusMessage = 'Transfer completed successfully!';
        _selectedFiles.clear();
      });
      
      // Disconnect after transfer
      await bluetoothService.disconnect();
      
      _showSuccessSnackBar('All photos sent successfully!');
    } catch (e) {
      setState(() {
        _isTransferring = false;
        _statusMessage = 'Transfer failed: $e';
      });
      _showErrorSnackBar('Error sending photos: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleEncryption(bool value) {
    setState(() {
      _useEncryption = value;
    });
    
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    bluetoothService.setEncryption(value);
  }

  void _viewImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagePreviewScreen(
          images: _selectedFiles,
          initialIndex: index,
          onRemove: _removeImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothService = Provider.of<BluetoothService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Photos'),
        actions: [
          if (_selectedFiles.isNotEmpty && !_isTransferring)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _selectedFiles.clear();
                });
              },
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status and progress section
            if (_statusMessage.isNotEmpty || _isTransferring)
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_useEncryption && _isTransferring)
                          const EncryptionBadge(isEncrypted: true),
                      ],
                    ),
                    if (_isTransferring) ...[
                      const SizedBox(height: 8),
                      TransferProgress(progress: _transferProgress),
                    ],
                  ],
                ),
              ),
            
            // Selected images section
            if (_selectedFiles.isNotEmpty && !_isTransferring) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '${_selectedFiles.length} photos selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (!_isScanning && bluetoothService.devices.isEmpty)
                      ElevatedButton.icon(
                        onPressed: _scanForDevices,
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Scan for Devices'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _viewImage(index),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              _selectedFiles[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            
            // Encryption toggle
            if (_selectedFiles.isNotEmpty && !_isTransferring) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Encrypt photos',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Switch(
                      value: _useEncryption,
                      onChanged: _toggleEncryption,
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              if (_useEncryption)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Photos will be encrypted during transfer for added security.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            
            // Device list section
            if (_isScanning) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Scanning for nearby devices...'),
                    ],
                  ),
                ),
              ),
            ] else if (bluetoothService.devices.isNotEmpty && !_isTransferring) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Available Devices',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _scanForDevices,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DeviceList(
                  devices: bluetoothService.devices,
                  onDeviceSelected: _sendToDevice,
                ),
              ),
            ],
            
            // Empty state
            if (_selectedFiles.isEmpty && !_isScanning && !_isTransferring)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No photos selected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap the button below to select photos to send',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Select Photos'),
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
      floatingActionButton: _selectedFiles.isNotEmpty && !_isTransferring && !_isScanning
          ? FloatingActionButton.extended(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add More'),
            )
          : null,
    );
  }
}

class ImagePreviewScreen extends StatefulWidget {
  final List<File> images;
  final int initialIndex;
  final Function(int) onRemove;

  const ImagePreviewScreen({
    Key? key,
    required this.images,
    required this.initialIndex,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              widget.onRemove(_currentIndex);
              if (widget.images.isEmpty) {
                Navigator.pop(context);
              } else {
                setState(() {
                  if (_currentIndex >= widget.images.length) {
                    _currentIndex = widget.images.length - 1;
                    _pageController.jumpToPage(_currentIndex);
                  }
                });
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: Image.file(
                widget.images[index],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: _currentIndex > 0
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
              Text(
                '${_currentIndex + 1} of ${widget.images.length}',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: _currentIndex < widget.images.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
