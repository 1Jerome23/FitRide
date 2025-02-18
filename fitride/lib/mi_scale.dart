import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MiScaleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  Future<List<String>> scanForDevices() async {
    List<String> deviceIds = [];
    final subscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((scanResult) {
      if (scanResult.name == "Mi Scale") {
        deviceIds.add(scanResult.id);
      }
    });

    await Future.delayed(Duration(seconds: 10));
    subscription.cancel();

    return deviceIds;
  }

  Future<bool> connectToScale(String deviceId) async {
    try {
      await _ble.connectToDevice(
        id: deviceId,
        servicesWithCharacteristicsToDiscover: {},
        connectionTimeout: Duration(seconds: 10),
      );
      print("Connected to device: $deviceId");
      return true;
    } catch (e) {
      print("Failed to connect to device: $e");
      return false;
    }
  }

Future<Map<String, dynamic>> getWeightData(String deviceId) async {
  try {
    final services = await _ble.discoverServices(deviceId);

    // Print all available services and characteristics for debugging
    for (var service in services) {
      print("Service: ${service.serviceId}");
      for (var characteristic in service.characteristics) {
        print("  Characteristic: ${characteristic.characteristicId}");
      }
    }

    // Auto-detect UUIDs
    final weightCharacteristic = _findCharacteristic(services, "2a9d", deviceId); // Weight UUID (common for BLE scales)
    final bodyWaterCharacteristic = _findCharacteristic(services, "2a9e", deviceId); // Body Water UUID (if available)
    final bodyMassCharacteristic = _findCharacteristic(services, "2a9f", deviceId); // Body Mass UUID (if available)

    // Read values
    final weight = await _readCharacteristic(weightCharacteristic);
    final bodyWater = await _readCharacteristic(bodyWaterCharacteristic);
    final bodyMass = await _readCharacteristic(bodyMassCharacteristic);

    return {
      'weight': weight,
      'bodyWater': bodyWater,
      'bodyMass': bodyMass,
    };
  } catch (e) {
    print("Error retrieving weight data: $e");
    rethrow;
  }
}


  // Helper function to get a characteristic by UUID
// Function to dynamically find a characteristic by keyword
QualifiedCharacteristic _findCharacteristic(
    List<DiscoveredService> services, String keyword, String deviceId) {
  for (var service in services) {
    for (var characteristic in service.characteristics) {
      // Check if the UUID contains the keyword (case-insensitive)
      if (characteristic.characteristicId.toString().toLowerCase().contains(keyword)) {
        return QualifiedCharacteristic(
          characteristicId: characteristic.characteristicId,
          serviceId: service.serviceId,
          deviceId: deviceId,
        );
      }
    }
  }
  throw Exception("Characteristic with keyword '$keyword' not found");
}


  // Read a characteristic value
  Future<double> _readCharacteristic(QualifiedCharacteristic characteristic) async {
    try {
      final value = await _ble.readCharacteristic(characteristic);
      return _parseData(value);
    } catch (e) {
      print("Error reading characteristic: $e");
      rethrow;
    }
  }

  // Parse raw data into a double value
  double _parseData(List<int> value) {
    return double.parse(String.fromCharCodes(value));
  }

  // Save data to Firestore
  void _saveToFirestore(Map<String, dynamic> data) {
    FirebaseFirestore.instance.collection('user_data').add({
      'weight': data['weight'],
      'bodyWater': data['bodyWater'],
      'bodyMass': data['bodyMass'],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

