import 'dart:async';

import 'package:another_ble_manager/mock/ble_mock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:another_ble_manager/another_ble_manager.dart';

void main() {
  test('ConnectBle', () async {
    StreamController<BleSetupState> _stateStreamController = StreamController.broadcast();
    IBleAdapter adapter = MockBleAdapter.getInstance();
    adapter.startScan();
    List<IBleDevice> devices = await adapter.getScanResults().elementAt(0);
    expect(devices.isEmpty, false);
    IBleDevice device = devices[0];

    BleDeviceOwner deviceOwner = BleDeviceOwner(device: device);

    deviceOwner.getSetupStates().listen((event) {
      debugPrintSynchronously("Received Status: $event");
      _stateStreamController.add(event);
    });

    BleSetupState setupState = BleSetupState.unknown;

    setupState = await _stateStreamController.stream.take(1).first;
    print("Got initial state");
    expect(setupState, BleSetupState.initial);

    deviceOwner
        .getFsm()
        ?.handleEvent(event: BleConnectDeviceEvent(device: device));

    setupState = await _stateStreamController.stream.take(1).first;
    expect(setupState, BleSetupState.connecting);

    setupState = await _stateStreamController.stream.take(1).first;
    expect(setupState, BleSetupState.discoveringServices);

    setupState = await _stateStreamController.stream.take(1).first;
    expect(setupState, BleSetupState.configuring);

    setupState = await _stateStreamController.stream.take(1).first;
    expect(setupState, BleSetupState.ready);

    deviceOwner
        .getFsm()
        ?.handleEvent(event: BleDisconnectDeviceEvent(device: device));

    deviceOwner
        .getFsm()
        ?.handleEvent(event: BleReconnectDeviceEvent(device: device));

    setupState = await _stateStreamController.stream.take(1).first;
    expect(setupState, BleSetupState.disconnecting);

    setupState = await _stateStreamController.stream.take(1).first;
    expect(setupState, BleSetupState.disconnected);

    setupState = await _stateStreamController.stream.take(1).first;
    expect(setupState, BleSetupState.initial);

  });
}
