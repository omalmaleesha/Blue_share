import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

class DeviceList extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final Function(String) onDeviceSelected;
  
  const DeviceList({
    Key? key,
    required this.devices,
    required this.onDeviceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: device.isPaired
                    ? Colors.green.withOpacity(0.1)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                device.isPaired ? Icons.bluetooth_connected : Icons.bluetooth,
                color: device.isPaired
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(device.name),
            subtitle: Text(
              device.isPaired ? 'Paired' : 'Available',
              style: TextStyle(
                color: device.isPaired ? Colors.green : null,
                fontWeight: device.isPaired ? FontWeight.w500 : null,
              ),
            ),
            trailing: ElevatedButton(
              onPressed: () => onDeviceSelected(device.id),
              child: const Text('Send'),
            ),
            onTap: () => onDeviceSelected(device.id),
          ),
        );
      },
    );
  }
}
