library another_ble_manager;

import 'dart:typed_data';
export 'connection/ble_connection.dart';
export 'connection/ble_connection_event.dart';


enum BleConnectionState {
  unknown,
  connecting,
  connected,
  disconnecting,
  disconnected
}

abstract class IBleAdapter {
  /// Start scanning for BLE devices
  Future<void> startScan();

  /// Stop scanning for ble devices.
  Future<void> stopScan();

  /// Returns devices found.
  Stream<List<IBleDevice>> getScanResults();
}

abstract class IBluetoothGattService {
  /// Returns the specified characteristic if found in this service.
  IBluetoothGattCharacteristic? getCharacteristic({required String uuid});

  /// Returns all the characteristics of this service.
  List<IBluetoothGattCharacteristic> getCharacteristics();

  /// Returns the UUID of the service.
  String getUuid();
}

abstract class IBluetoothGattCharacteristic {
  /// Returns the UUID of the characteristics
  String getUuid();

  /// Read a value from the characteristic
  Future<Uint8List> read();

  /// Write a value to the characteristic
  Future<void> write({required Uint8List value, bool withoutResponse = false});

  /// Enable notification from the characteristic.
  Future<bool> setNotifyValue(bool notify);
}

abstract class IBleCharacteristicChangeListener {
  //Called when a characteristic changes on the remote
  //device. This will only be called if the remote device
  // has been configured for either notify or indicate.
  //@param device Devices whose characteristic changed.
  // @param characteristic Characteristic that changed.
  void onCharacteristicChanged(
      {required IBleDevice device,
        required IBluetoothGattService service,
        required IBluetoothGattCharacteristic characteristic,
        required Uint8List value});
}

abstract class IBleDeviceConnectionStateChangeListener {
  /// Gets called when there is a change in the state
  /// of the device connection.
  void onDeviceConnectionStateChanged(
      {required IBleDevice device, required BleConnectionState newGattState});
}

abstract class IBleDevice {
  static const String kClientCharacteristicConfiguration =
      "00002902-0000-1000-8000-00805f9b34fb";

  /// Returns the device name.
  String getName();

  /// Returns the ID of the device.
  String getId();

  /// Discover the available services in the BLE device.
  Future<void> discoverServices({bool refresh = false});

  /// Reads a the specified chracteristic from the service
  /// @param serviceUuid 128 bit UUID of the service
  /// @param charUuid 128 bit UUID of the characteristic
  Future<IBluetoothGattCharacteristic> readCharacteristic(
      {required String serviceUuid, required String charUuid});

  /// Writes the value to the specified characteristic of the
  /// given service.
  /// @param serviceUuid 128 bit UUID of the service
  /// @param charUuid 128 bit UUID of the characteristic
  /// @param value bytes of the value to write
  Future<IBluetoothGattCharacteristic> writeCharacteristic(
      {required String serviceUuid,
        required String charUuid,
        required Uint8List value});

  /// Tries to enable the specified characteristic notify.
  /// @param serviceUuid UUID of the service the characteristic belongs to.
  /// @param charUuid UUID of the characteristic to enable notify for.
  Future<bool> enableCharacteristicNotify(
      {required String serviceUuid, required String charUuid});

  /// Tries to disable the specified characteristic notify.
  /// @param serviceUuid UUID of the service the characteristic belongs to.
  /// @param charUuid UUID of the characteristic to enable notify for.
  Future<bool> disableCharacteristicNotify(
      {required String serviceUuid, required String charUuid});

  /// Tries to enable the specified characteristic to indicate.
  /// @param serviceUuid UUID of the service the characteristic belongs to.
  /// @param charUuid UUID of the characteristic to enable notify for.
  Future<bool> enableCharacteristicIndicate(
      {required String serviceUuid, required String charUuid});

  /// Tries to disable the specified characteristic to indicate.
  /// @param serviceUuid UUID of the service the characteristic belongs to.
  /// @param charUuid UUID of the characteristic to enable notify for.
  Future<bool> disableCharacteristicIndicate(
      {required String serviceUuid, required String charUuid});

  /// Sets a listener to be notified when a characteristic changes.
  /// @param listener to be called when a characteristic changes.
  void setOnCharacteristicChangeListener(
      {IBleCharacteristicChangeListener? listener});

  /// Sets the listener to be notified when the connection state
  /// of the device changes.
  /// @param listener to be called when the connection state changes.
  void setOnDeviceConnectionsStateChangeListener(
      {IBleDeviceConnectionStateChangeListener? listener});

  /// Returns the connection state for this device.
  /// @return connection state for the device, or BleConnectionState.UNKNOWN if state cannot be detected.
  BleConnectionState getConnectionState();

  /// Returns stream to listen for changes in connection states.
  Stream<BleConnectionState> getConnectionStates();

  /// Connect to the Device
  Future<IBleDevice> connect(
      {Duration duration = const Duration(seconds: 2),
        bool autoConnect = false});

  /// Disconnect from the Device
  Future<IBleDevice> disconnect();

  /// Tries to reconnect the device.
  Future<IBleDevice> reconnect();
}

/// Adapter factory.
class BleAdapterFactory {
  IBleAdapter? _adapter;

  IBleAdapter? getAdapter() {
    return _adapter;
  }

  void setAdapter({IBleAdapter? adapter}) {
    _adapter = _adapter;
  }
}

class BluetoothGattServiceNotFound implements Exception {
  final String uuid;

  BluetoothGattServiceNotFound({required this.uuid});

  @override
  String toString() {
    return "Service with UUID: $uuid Not Found";
  }
}

class BluetoothGattCharacteristicNotFound implements Exception {
  final String serviceUuid;
  final String uuid;

  BluetoothGattCharacteristicNotFound(
      {required this.serviceUuid, required this.uuid});

  @override
  String toString() {
    return "Characteristic with UUID: $uuid Not Found in Service with UUID: $serviceUuid";
  }
}
