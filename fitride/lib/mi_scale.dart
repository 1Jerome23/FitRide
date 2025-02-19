import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data'; // Add this import

class MiScaleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  Future<List<String>> scanForDevices() async {
    List<String> deviceIds = [];
    Completer<void> scanCompleter = Completer<void>();

    final subscription = _ble.scanForDevices(
      withServices: [], 
      scanMode: ScanMode.lowLatency,
    ).listen((scanResult) {
      print("🔍 Found Device: ${scanResult.name} (${scanResult.id})");

      if (scanResult.name.toLowerCase().contains("mi scale")) {
        print("✅ Xiaomi Mi Scale detected by name!");
        if (!deviceIds.contains(scanResult.id)) {
          deviceIds.add(scanResult.id);
          print("➕ Added device ID: ${scanResult.id}");
        }
      }

      if (deviceIds.isNotEmpty && !scanCompleter.isCompleted) {
        scanCompleter.complete();
      }
    }, onError: (error) {
      print("❌ Error during BLE scan: $error");
      if (!scanCompleter.isCompleted) {
        scanCompleter.completeError(error);
      }
    });

    try {
      await Future.any([
        Future.delayed(const Duration(seconds: 10)), 
        scanCompleter.future,
      ]);
    } catch (e) {
      print("❌ Scanning failed: $e");
    } finally {
      await subscription.cancel();
      print("⏹️ Scanning stopped.");
    }

    return deviceIds;
  }

  Future<bool> connectToScale(String deviceId) async {
    try {
      await _ble.connectToDevice(
        id: deviceId,
        servicesWithCharacteristicsToDiscover: {}, 
        connectionTimeout: const Duration(seconds: 10),
      );
      print("✅ Connected to Xiaomi Mi Scale: $deviceId");
      return true;
    } catch (e) {
      print("❌ Failed to connect to $deviceId: $e");
      return false;
    }
  }

  /// Get weight data from the Xiaomi weighing scale
  Future<Map<String, dynamic>> getWeightData(String deviceId) async {
    try {
      final services = await _ble.discoverServices(deviceId);

      // Auto-detect UUIDs
      final weightCharacteristic = _findCharacteristic(services, "2a9d", deviceId); // Weight Measurement
      final bodyCompositionCharacteristic = _findCharacteristic(services, "2a9c", deviceId); // Body Composition

      final weight = await _readCharacteristic(weightCharacteristic);
      final bodyComposition = await _readCharacteristic(bodyCompositionCharacteristic);

      _saveToFirestore({
        'weight': weight,
        'bodyComposition': bodyComposition,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return {
        'weight': weight,
        'bodyComposition': bodyComposition,
      };
    } catch (e) {
      print("❌ Error retrieving weight data: $e");
      rethrow;
    }
  }

  /// Helper function to find a characteristic by keyword
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
    throw Exception("❌ Characteristic with keyword '$keyword' not found");
  }

  /// Helper function to read a characteristic value
  Future<double> _readCharacteristic(QualifiedCharacteristic characteristic) async {
    try {
      final value = await _ble.readCharacteristic(characteristic);
      return _parseData(value);
    } catch (e) {
      print("❌ Error reading characteristic: $e");
      rethrow;
    }
  }

/// Helper function to parse raw data into a meaningful value
double _parseData(List<int> value) {
    try {
      // Log raw data for debugging
      print("Raw Data (Hex): ${value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}");

      // Check data length
      if (value.isEmpty) {
        throw Exception("❌ Empty data received");
      }

      // Interpret the raw data based on its format
      if (value.length >= 4) {
        // Example: Assume the data is a 32-bit float (IEEE 754)
        final buffer = ByteData.sublistView(Uint8List.fromList(value));
        double floatValue = buffer.getFloat32(0, Endian.little); // Little-endian format
        print("Parsed Float Value: $floatValue");
        return floatValue;
      } else if (value.length >= 2) {
        // Example: Assume the data is a 16-bit integer
        final buffer = ByteData.sublistView(Uint8List.fromList(value));
        int intValue = buffer.getInt16(0, Endian.little); // Little-endian format
        double scaledValue = intValue / 200.0; // Example scaling factor for Xiaomi scales
        print("Parsed Integer Value (Scaled): $scaledValue");
        return scaledValue;
      } else {
        // Handle single-byte or insufficient data
        int rawValue = value[0];
        double scaledValue = rawValue / 10.0; // Example scaling factor
        print("Parsed Single-Byte Value (Scaled): $scaledValue");
        return scaledValue;
      }
    } catch (e) {
      print("❌ Error parsing data: $e");
      rethrow;
    }
  }
  /// Save data to Firestore
  void _saveToFirestore(Map<String, dynamic> data) {
    FirebaseFirestore.instance.collection('user_data').add(data).then((_) {
      print("✅ Data saved to Firestore");
    }).catchError((e) {
      print("❌ Failed to save data to Firestore: $e");
    });
  }
}