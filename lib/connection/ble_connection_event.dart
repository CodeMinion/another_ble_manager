
import 'dart:typed_data';

import 'package:another_fsm/another_fsm.dart';

import '../another_ble_manager.dart';

abstract class BleDeviceEvent implements FsmEvent {
  IBleDevice getDevice();
}
class BleDeviceConnectedEvent implements BleDeviceEvent {
  final IBleDevice device;
  const BleDeviceConnectedEvent({required this.device});

  @override
  IBleDevice getDevice()=> device;
}

class BleServiceDiscoveredEvent implements BleDeviceEvent{
  final IBleDevice device;
  const BleServiceDiscoveredEvent({required this.device});

  @override
  IBleDevice getDevice() => device;
}

class BleDeviceConnectionStateChangedEvent implements BleDeviceEvent {
  final IBleDevice device;
  final BleConnectionState newState;
  const BleDeviceConnectionStateChangedEvent({required this.device, required this.newState});

  @override
  IBleDevice getDevice() => device;
}

class BleDeviceConfigurationCompleteEvent implements BleDeviceEvent {
  final IBleDevice device;
  const BleDeviceConfigurationCompleteEvent({required this.device});

  @override
  IBleDevice getDevice() => device;
}

class BleWriteCharacteristicEvent implements BleDeviceEvent {
  final IBleDevice device;
  final String serviceUuid;
  final String charUuid;
  final Uint8List value;
  const BleWriteCharacteristicEvent({required this.device, required this.serviceUuid, required this.charUuid, required this.value});

  @override
  IBleDevice getDevice() => device;
}

class BleConnectDeviceEvent implements BleDeviceEvent {
  final IBleDevice device;
  const BleConnectDeviceEvent({required this.device});

  @override
  IBleDevice getDevice() => device;
}

class BleReconnectDeviceEvent implements BleDeviceEvent {
  final IBleDevice device;
  const BleReconnectDeviceEvent({required this.device});

  @override
  IBleDevice getDevice() => device;
}

class BleDisconnectDeviceEvent implements BleDeviceEvent {
  final IBleDevice device;
  const BleDisconnectDeviceEvent({required this.device});

  @override
  IBleDevice getDevice() => device;
}

class BleCharacteristicChangedEvent implements BleDeviceEvent {
  final IBleDevice device;
  final String serviceUuid;
  final String charUuid;
  final Uint8List value;
  const BleCharacteristicChangedEvent({required this.device, required this.serviceUuid, required this.charUuid, required this.value});

  @override
  IBleDevice getDevice() => device;
}

class BleEnableCharacteristicNotifyEvent implements BleDeviceEvent {
  final IBleDevice device;
  final String serviceUuid;
  final String charUuid;
  const BleEnableCharacteristicNotifyEvent({required this.device, required this.serviceUuid, required this.charUuid});

  @override
  IBleDevice getDevice() => device;
}

class BleDisableCharacteristicNotifyEvent implements BleDeviceEvent {
  final IBleDevice device;
  final String serviceUuid;
  final String charUuid;
  const BleDisableCharacteristicNotifyEvent({required this.device, required this.serviceUuid, required this.charUuid});

  @override
  IBleDevice getDevice() => device;
}