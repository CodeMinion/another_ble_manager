import 'dart:async';
import 'dart:typed_data';

import 'package:another_fsm/another_fsm.dart';

import '../another_ble_manager.dart';
import 'ble_connection_event.dart';

enum BleSetupState {
  unknown,
  initial,
  connecting,
  discoveringServices,
  configuring,
  ready,
  disconnecting,
  disconnected,
  reconnecting;

  String toShortString() {
    return toString().split('.').last;
  }
}

abstract class IBleInitCommand {
  // Performs the command on the specified device.
  Future<void> execute({required IBleDevice device});

  // Undo this initialization command.
  Future<void> undo({required IBleDevice device});
}

/// Init command to be performed on a device during the configuration
/// state.
class EnableCharacteristicNotificationCommand implements IBleInitCommand {
  final String serviceUuid;
  final String charUuid;

  const EnableCharacteristicNotificationCommand({required this.serviceUuid, required this.charUuid});
  @override
  Future<void> execute({required IBleDevice device}) async {
    await device.enableCharacteristicNotify(serviceUuid: serviceUuid, charUuid: charUuid);
  }

  @override
  Future<void> undo({required IBleDevice device}) async {
    await device.disableCharacteristicNotify(serviceUuid: serviceUuid, charUuid: charUuid);
  }

}

class BleDeviceOwner
    implements
        FsmOwner,
        IBleDeviceConnectionStateChangeListener,
        IBleCharacteristicChangeListener {
  final IBleDevice device;
  final List<IBleInitCommand> _initCommands;
  Fsm? _deviceFsm;
  BleSetupState _setupState = BleSetupState.unknown;
  final StreamController<BleSetupState> _streamController =
      StreamController.broadcast();

  final StreamController<BleCharacteristicChangedEvent>
      _charChangesStreamController = StreamController.broadcast();

  BleDeviceOwner({required this.device, List<IBleInitCommand> initCommands = const []}):_initCommands = initCommands {
    _deviceFsm = Fsm(owner: this);
    device.setOnDeviceConnectionsStateChangeListener(listener: this);
    device.setOnCharacteristicChangeListener(listener: this);
    _deviceFsm?.changeState(nextState: BleInitialState());
  }

  @override
  Fsm? getFsm() => _deviceFsm;

  @override
  void onDeviceConnectionStateChanged(
      {required IBleDevice device, required BleConnectionState newGattState}) {
    BleDeviceConnectionStateChangedEvent event =
        BleDeviceConnectionStateChangedEvent(
            device: device, newState: newGattState);
    _deviceFsm?.handleEvent(event: event);
  }

  void _notifyState({required BleSetupState state}) {
    _setupState = state;
    _streamController.add(state);
  }

  /// Notifies changes in the setup state.
  Stream<BleSetupState> getSetupStates() => _streamController.stream;

  /// Returns the current setup state.
  BleSetupState getSetupState() => _setupState;

  @override
  Future<bool> handleEvent({required FsmEvent event}) async {
    if (event is BleDeviceEvent) {
      if (event.getDevice().getId() != device.getId()) {
        return false;
      }
    }

    return (await _deviceFsm?.handleEvent(event: event)) ?? false;
  }

  @override
  void onCharacteristicChanged(
      {required IBleDevice device,
      required IBluetoothGattService service,
      required IBluetoothGattCharacteristic characteristic,
      required Uint8List value}) {
    BleCharacteristicChangedEvent event = BleCharacteristicChangedEvent(
        device: device,
        serviceUuid: service.getUuid(),
        charUuid: characteristic.getUuid(),
        value: value);
    _charChangesStreamController.add(event);
  }

  /// Returns a stream for listening on changes from any characteristics.
  Stream<BleCharacteristicChangedEvent> getCharacteristicsChanges() => _charChangesStreamController.stream;

  /// Returns a list of init commands to be performed in this
  /// device to get it ready for usage.
  List<IBleInitCommand> getInitCommands() => _initCommands;
}

/// Initial state for the BLE device connection
class BleInitialState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    // Do nothing
    print("OnEnter: BleInitialState");
    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    deviceOwner._notifyState(state: BleSetupState.initial);
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEvent: BleInitialState - Event $event}");

    if (event is BleConnectDeviceEvent) {
      await owner.getFsm()?.changeState(nextState: BleConnectDeviceState());
      return true;
    } else if (event is BleDeviceConnectionStateChangedEvent) {
      if (event.newState == BleConnectionState.connected) {
        await owner
            .getFsm()
            ?.changeState(nextState: BleDiscoverServicesState());
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    // Do nothing.
    print("OnExit: BleInitialState");
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }
}

/// During this state the device connection is performed.
class BleConnectDeviceState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    print("OnEnter: BleConnectDeviceState");
    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    deviceOwner._notifyState(state: BleSetupState.connecting);

    await deviceOwner.device.connect();
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEvent: BleConnectDeviceState - Event $event");

    if (event is BleDeviceConnectionStateChangedEvent) {
      if (event.newState == BleConnectionState.connected) {
        // Transition to the discovery state.
        await owner
            .getFsm()
            ?.changeState(nextState: BleDiscoverServicesState());
      }
      return true;
    }

    return false;
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    // Do nothing.
    print("OnExit: BleConnectDeviceState");
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }
}

/// During this state the the different services
/// available in the device are discovered.
class BleDiscoverServicesState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    print("OnEnter: BleDiscoverServicesState");

    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    deviceOwner._notifyState(state: BleSetupState.discoveringServices);

    await deviceOwner.device.discoverServices();
    deviceOwner.getFsm()?.handleEvent(
        event: BleServiceDiscoveredEvent(device: deviceOwner.device));
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEvent: BleDiscoverServicesState - Event $event");

    if (event is BleServiceDiscoveredEvent) {
      // Transition to Device config.
      await owner.getFsm()?.changeState(nextState: BleConfigureState());
      return true;
    }
    return false;
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    // Do nothing
    print("OnExit: BleDiscoverServicesState");
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }
}

class BleConfigureState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    print("OnEnter: BleConfigureState");

    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    deviceOwner._notifyState(state: BleSetupState.configuring);

    // Grab configuration step
    List<IBleInitCommand> initCommands = deviceOwner.getInitCommands();
    for (IBleInitCommand command in initCommands) {
      // Execute configuration step
      try {
        await command.execute(device: deviceOwner.device);
      }
      on Exception {
        // Todo Handle error.
      }
      on Error {
        // Handle error
      }
    }
    // If no more configuration steps available go to ready state.
    owner.getFsm()?.handleEvent(
        event: BleDeviceConfigurationCompleteEvent(device: deviceOwner.device));
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEvent: BleConfigureState - Event $event");

    if (event is BleDeviceConfigurationCompleteEvent) {
      await owner.getFsm()?.changeState(nextState: BleDeviceReadyState());
      return true;
    }
    return false;
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    // Do nothing
    print("OnExit: BleConfigureState");
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }
}

class BleDeviceReadyState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    deviceOwner._notifyState(state: BleSetupState.ready);

    print("OnEnter: BleDeviceReadyState");
    deviceOwner.device
        .setOnDeviceConnectionsStateChangeListener(listener: deviceOwner);
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEvent: BleDeviceReadyState - Event $event");

    if (event is BleDeviceConnectionStateChangedEvent) {
      if (event.newState == BleConnectionState.disconnected) {
        // Transition to the disconnected state.
        await owner
            .getFsm()
            ?.changeState(nextState: BleDeviceDisconnectedState());
      }
      return true;
    }

    if (event is BleWriteCharacteristicEvent) {
      BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
      await deviceOwner.device.writeCharacteristic(
          serviceUuid: event.serviceUuid,
          charUuid: event.charUuid,
          value: event.value);
    }
    if (event is BleDisconnectDeviceEvent) {
      // Transition to disconnecting state to handle user request to disconnect.
      await owner
          .getFsm()
          ?.changeState(nextState: BleDeviceDisconnectingState());
      return true;
    }
    else if (event is BleEnableCharacteristicNotifyEvent) {
      BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
      await deviceOwner.device.enableCharacteristicIndicate(serviceUuid: event.serviceUuid, charUuid: event.charUuid);
      return true;
    }

    else if (event is BleDisableCharacteristicNotifyEvent) {
      BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
      await deviceOwner.device.disableCharacteristicNotify(serviceUuid: event.serviceUuid, charUuid: event.charUuid);
    }

    return false;
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    // Do nothing.
    print("OnExit: BleDeviceReadyState");
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }
}

class BleDeviceDisconnectedState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    print("OnEnter: BleDeviceDisconnectedState");

    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    // TODO Consider using a flag for signaling auto reconnect on the owner.
    // For now attempt reconnect logic.
    deviceOwner._notifyState(state: BleSetupState.reconnecting);
    deviceOwner.device.reconnect();
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEvent: BleDeviceDisconnectedState - Event $event");

    if (event is BleDeviceConnectionStateChangedEvent) {
      if (event.newState == BleConnectionState.connected) {
        // Transition to the discovery state.
        await owner
            .getFsm()
            ?.changeState(nextState: BleDiscoverServicesState());
      }
      // TODO Handle reconnect failure.
      return true;
    }
    return false;
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    // TODO Cleanup reconnect logic if any.
    print("OnExit: BleDeviceDisconnectedState");
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }
}

class BleDeviceReconnectingState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    print("OnEnter: BleDeviceReconnectingState");

    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    // Attempt reconnect logic.
    deviceOwner._notifyState(state: BleSetupState.reconnecting);
    deviceOwner.device.reconnect();
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEvent: BleDeviceReconnectingState - Event $event");

    if (event is BleDeviceConnectionStateChangedEvent) {
      if (event.newState == BleConnectionState.connected) {
        // Transition to the discovery state.
        await owner
            .getFsm()
            ?.changeState(nextState: BleDiscoverServicesState());
      }
      return true;
    }
    return false;
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    print("OnExit: BleDeviceReconnectingState");
  }
}

/// State for handling user disconnection request.
class BleDeviceDisconnectingState implements FsmState {
  @override
  Future<void> onEnter({required FsmOwner owner}) async {
    print("OnEnter: BleDeviceDisconnectingState");

    // Attempt reconnect logic.
    BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
    deviceOwner._notifyState(state: BleSetupState.disconnecting);
    // Grab configuration step
    List<IBleInitCommand> initCommands = deviceOwner.getInitCommands();
    for (IBleInitCommand command in initCommands) {
      try {
        // Undo configuration step
        await command.undo(device: deviceOwner.device);
      }
      on Exception {
        // Todo handle error
      }
      on Error {
        // Handle error
      }
    }
    await deviceOwner.device
        .disconnect(); /*.then((value) => deviceOwner.handleEvent(
        event: BleDeviceConnectionStateChangedEvent(
            device: deviceOwner.device,
            newState: BleConnectionState.disconnected)));*/
  }

  @override
  Future<bool> onEvent(
      {required FsmEvent event, required FsmOwner owner}) async {
    print("OnEnter: BleDeviceDisconnectingState - Event $event");

    if (event is BleDeviceConnectionStateChangedEvent) {
      if (event.newState == BleConnectionState.disconnected) {
        BleDeviceOwner deviceOwner = owner as BleDeviceOwner;
        deviceOwner._notifyState(state: BleSetupState.disconnected);
        // Transition to initial state to be able to connect once again on user request.
        await owner.getFsm()?.changeState(nextState: BleInitialState());
      }
      return true;
    }

    return false;
  }

  @override
  Future<void> onExit({required FsmOwner owner}) async {
    print("OnExit: BleDeviceDisconnectingState");
  }

  @override
  Future<void> onUpdate({required FsmOwner owner, required int time}) async {
    // Do nothing
  }
}
