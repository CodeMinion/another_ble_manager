import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import '../another_ble_manager.dart';

class MockBleCharacteristic implements IBluetoothGattCharacteristic {
  final MockBleDevice _device;
  final IBluetoothGattService _service;
  StreamSubscription<List<int>>? _charNotificationChannel;
  final String uuid;

  MockBleCharacteristic._(
      {required this.uuid,
      required IBluetoothGattService service,
      required MockBleDevice device})
      : _device = device,
        _service = service;

  @override
  Future<Uint8List> read() async {
    return Uint8List(1)..add(2);
  }

  @override
  Future<bool> setNotifyValue(bool notify) async {
    return true;
  }

  @override
  Future<void> write(
      {required Uint8List value, bool withoutResponse = false}) async {}

  @override
  String getUuid() {
    return uuid;
  }
}

class MockBleService implements IBluetoothGattService {
  final MockBleDevice _device;
  final HashMap<String, IBluetoothGattCharacteristic> _characteristics;
  final String uuid;

  MockBleService._({required MockBleDevice device, required this.uuid})
      : _device = device,
        _characteristics = HashMap() {
    // Load each characteristic
    for (var characteristic in {
      "00005A38-0000-1000-8000-00805f9b34fb",
      "00002902-0000-1000-8000-00805f9b34fb"
    }) {
      IBluetoothGattCharacteristic bleChar = MockBleCharacteristic._(
          device: _device, service: this, uuid: characteristic);
      _characteristics.putIfAbsent(characteristic, () => bleChar);
    }
  }

  @override
  IBluetoothGattCharacteristic? getCharacteristic({required String uuid}) {
    return _characteristics[uuid];
  }

  @override
  List<IBluetoothGattCharacteristic> getCharacteristics() {
    return _characteristics.values.toList();
  }

  @override
  String getUuid() => uuid;
}

class MockBleDevice implements IBleDevice {
  HashMap<String, IBluetoothGattService> _servicesFound;
  IBleCharacteristicChangeListener? _characteristicChangeListener;
  IBleDeviceConnectionStateChangeListener?
      _bleDeviceConnectionStateChangeListener;
  String device;
  MockBleDevice({required this.device}) : _servicesFound = HashMap();

  @override
  Future<bool> disableCharacteristicIndicate(
      {required String serviceUuid, required String charUuid}) async {
    // TODO: implement disableCharacteristicIndicate
    throw UnsupportedError("disableCharacteristicIndicate not yet supported");
  }

  @override
  Future<bool> disableCharacteristicNotify(
      {required String serviceUuid, required String charUuid}) async {
    return await _servicesFound[serviceUuid]
            ?.getCharacteristic(uuid: charUuid)
            ?.setNotifyValue(false) ??
        false;
  }

  @override
  Future<IBleDevice> connect(
      {Duration duration = const Duration(seconds: 2),
      bool autoConnect = false}) async {
    await Future.delayed(const Duration(seconds: 2)).then((value) {
      _bleDeviceConnectionStateChangeListener?.onDeviceConnectionStateChanged(
          device: this, newGattState: BleConnectionState.connected);
    });
    return this;
  }

  @override
  Future<IBleDevice> disconnect() async {
    await Future.delayed(const Duration(seconds: 2)).then((value) =>
        _bleDeviceConnectionStateChangeListener?.onDeviceConnectionStateChanged(
            device: this, newGattState: BleConnectionState.disconnected));
    return this;
  }

  @override
  Future<void> discoverServices({bool refresh = false}) async {
    if (refresh) {
      _servicesFound = HashMap();
    }
    List<String> services = ["00005300-0000-1000-8000-00805f9b34fb"];
    // Track service
    if (_servicesFound.isEmpty) {
      for (var service in services) {
        _servicesFound.putIfAbsent(
            service, () => MockBleService._(device: this, uuid: service));
      }
    }
  }

  @override
  Future<bool> enableCharacteristicIndicate(
      {required String serviceUuid, required String charUuid}) {
    // TODO: implement enableCharacteristicIndicate
    throw UnsupportedError("enableCharacteristicIndicate not yet supported");
  }

  @override
  Future<bool> enableCharacteristicNotify(
      {required String serviceUuid, required String charUuid}) async {
    return await _servicesFound[serviceUuid]
            ?.getCharacteristic(uuid: charUuid)
            ?.setNotifyValue(true) ??
        false;
  }

  @override
  BleConnectionState getConnectionState() {
    // TODO: implement getConnectionState
    throw UnimplementedError();
  }

  @override
  Future<IBluetoothGattCharacteristic> readCharacteristic(
      {required String serviceUuid, required String charUuid}) async {
    IBluetoothGattCharacteristic? characteristic =
        _servicesFound[serviceUuid]?.getCharacteristic(uuid: charUuid);

    if (characteristic == null) {
      throw BluetoothGattCharacteristicNotFound(
          serviceUuid: serviceUuid, uuid: charUuid);
    }

    await characteristic.read();
    return characteristic;
  }

  @override
  Future<IBleDevice> reconnect() async {
    await Future.delayed(const Duration(seconds: 2))
        .then((value) => _bleDeviceConnectionStateChangeListener
            ?.onDeviceConnectionStateChanged(
                device: this, newGattState: BleConnectionState.connecting))
        .then((value) => Future.delayed(const Duration(seconds: 1)).then(
            (value) => _bleDeviceConnectionStateChangeListener
                ?.onDeviceConnectionStateChanged(
                    device: this, newGattState: BleConnectionState.connected)));
    return this;
  }

  @override
  void setOnCharacteristicChangeListener(
      {IBleCharacteristicChangeListener? listener}) {
    _characteristicChangeListener = listener;
  }

  @override
  void setOnDeviceConnectionsStateChangeListener(
      {IBleDeviceConnectionStateChangeListener? listener}) {
    _bleDeviceConnectionStateChangeListener = listener;
  }

  @override
  Future<IBluetoothGattCharacteristic> writeCharacteristic(
      {required String serviceUuid,
      required String charUuid,
      required Uint8List value}) async {
    IBluetoothGattCharacteristic? characteristic =
        _servicesFound[serviceUuid]?.getCharacteristic(uuid: charUuid);

    if (characteristic == null) {
      throw BluetoothGattCharacteristicNotFound(
          serviceUuid: serviceUuid, uuid: charUuid);
    }

    await characteristic.write(value: value);
    return characteristic;
  }

  void _notifyCharacteristicChanged(
      {
        required IBluetoothGattService service,
        required IBluetoothGattCharacteristic characteristic,
      required Uint8List value}) {
    _characteristicChangeListener?.onCharacteristicChanged(
        device: this, service: service, characteristic: characteristic, value: value);
  }

  @override
  String getName() {
    return device;
  }

  @override
  Stream<BleConnectionState> getConnectionStates() {
    return Stream.fromIterable([BleConnectionState.connected]);
  }

  @override
  String getId() => device;
}

class MockBleAdapter implements IBleAdapter {

  final Random _random = Random.secure();
  final HashMap<String, MockBleDevice> _foundDevices = HashMap();

  MockBleAdapter._();
  final StreamController<List<IBleDevice>> _streamController = StreamController.broadcast();


  static MockBleAdapter? _instance;

  static MockBleAdapter getInstance() {
    return _instance ??= MockBleAdapter._();
  }

  @override
  Stream<List<IBleDevice>> getScanResults() {
    return _streamController.stream;
    /*
    return Stream.fromIterable([
      [MockBleDevice(device: "MockBleAB12")],
    ]);*/
  }

  String _generateRandomOctets() {
    return _random.nextInt(36556).toRadixString(16).toUpperCase();
  }

  @override
  Future<void> startScan() async {
    await Future.delayed(const Duration(seconds: 1));

    var resultList = [
      MockBleDevice(device: "MockBle ${_generateRandomOctets()}"),
      MockBleDevice(device: "GoDice ${_generateRandomOctets()}"),
      MockBleDevice(device: "Kinsect ${_generateRandomOctets()}"),
      MockBleDevice(device: "Slinger ${_generateRandomOctets()}"),
      MockBleDevice(device: "Scoutfly ${_generateRandomOctets()}"),
      MockBleDevice(device: "Glaive ${_generateRandomOctets()}"),
    ];

    _streamController.add(
      resultList.map((result) {
        String deviceId = result.getId();
        // If device is not tracked track
        if (_foundDevices.containsKey(deviceId)) {
          return _foundDevices[deviceId]!;
        }
        else {
          MockBleDevice device = MockBleDevice(device: result.device);
          _foundDevices.putIfAbsent(deviceId, () => device);
          return device;
        }
      }).toList()
    );
  }

  @override
  Future<void> stopScan() async {}
}
