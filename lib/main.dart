import 'dart:ffi';

import 'package:easy_isolate/easy_isolate.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:hidapi_dart/hidapi_dart.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:convert/convert.dart';
import 'package:provider/provider.dart';
import 'package:quick_usb/quick_usb.dart';
import 'package:hhljoytool/page_deviceselect.dart';
import 'package:hhljoytool/page_joypadtest.dart';
import 'package:hhljoytool/page_sticktest.dart';

class JoypadInputData {
  bool _dataChanged = false;

  void inputDirty() {
    _dataChanged = true;
  }

  bool inputState() {
    if (_dataChanged) {
      _dataChanged = false;
      return true;
    }
    return false;
  }

  ValueNotifier<int> aButton = ValueNotifier(0);
  ValueNotifier<int> bButton = ValueNotifier(0);
  ValueNotifier<int> xButton = ValueNotifier(0);
  ValueNotifier<int> yButton = ValueNotifier(0);
  ValueNotifier<int> dpadUp = ValueNotifier(0);
  ValueNotifier<int> dpadDown = ValueNotifier(0);
  ValueNotifier<int> dpadLeft = ValueNotifier(0);
  ValueNotifier<int> dpadRight = ValueNotifier(0);
  ValueNotifier<int> startButton = ValueNotifier(0);
  ValueNotifier<int> selectButton = ValueNotifier(0);
  ValueNotifier<int> lTrigger = ValueNotifier(0);
  ValueNotifier<int> rTrigger = ValueNotifier(0);
  ValueNotifier<int> lButton = ValueNotifier(0);
  ValueNotifier<int> rButton = ValueNotifier(0);
  ValueNotifier<int> zlButton = ValueNotifier(0);
  ValueNotifier<int> zrButton = ValueNotifier(0);
  ValueNotifier<int> lStickX = ValueNotifier(0);
  ValueNotifier<int> lStickY = ValueNotifier(0);
  ValueNotifier<int> rStickX = ValueNotifier(0);
  ValueNotifier<int> rStickY = ValueNotifier(0);
}

class JoyToolMasterState {
  JoyToolMasterState._sharedInstance();
  static final JoyToolMasterState _shared =
      JoyToolMasterState._sharedInstance();

  factory JoyToolMasterState() => _shared;

  bool _connected = false;
  bool _usbInit = false;
  bool _usbOpen = false;
  int _hidOpen = 0;
  bool _usbInterfaceClaimed = false;
  bool _usbPermission = false;
  int devType = -1;
  int uiSelectedDevice = -1;
  int subDev = 0;
  int uiButtonChanging = 0;
  late Uint8List inputRaw;
  JoypadInputData inputData = JoypadInputData();

  late UsbDevice _usbDevice;
  late UsbConfiguration _usbConfiguration;
  late UsbDeviceDescription _usbDeviceDescription;
  late UsbEndpoint _usbEndpointIn;
  late UsbEndpoint _usbEndpointOut;

  late HID _hidDevice;

  int _usbBulkTransferOut = 0;
  Uint8List? _usbBulkTransferIn;

  void setUsbDevice(UsbDevice device) {
    devType = 0;
    _usbDevice = device;
  }

  void setHidDevice(HID device) {
    devType = 1;
    _hidDevice = device;
  }

  Future<bool> startJoypadDevice() async {
    // For USB Device GameCube Adapter
    if (devType == 0) {
      _usbInit = await QuickUsb.init();

      if (!_usbInit) {
        debugPrint("USB not init yet FAIL.");
        return false;
      }

      if (Platform.isAndroid) {
        _usbDeviceDescription = await QuickUsb.getDeviceDescription(_usbDevice,
            requestPermission: true);
        debugPrint("Got Android permissions.");
      }

      _usbOpen = await QuickUsb.openDevice(_usbDevice);
      if (_usbOpen) {
        debugPrint("USB Device opened OK.");

        // Since device opened get configuration.
        _usbConfiguration = await QuickUsb.getConfiguration(0);

        // Claim the interface
        _usbInterfaceClaimed =
            await QuickUsb.claimInterface(_usbConfiguration.interfaces[0]);

        if (_usbInterfaceClaimed) {
          debugPrint("USB interface claimed OK.");

          // Interface got OK. Set endpoints.
          _usbEndpointIn = _usbConfiguration.interfaces[0].endpoints.firstWhere(
              (element) => element.direction == UsbEndpoint.DIRECTION_IN);

          _usbEndpointOut = _usbConfiguration.interfaces[0].endpoints
              .firstWhere(
                  (element) => element.direction == UsbEndpoint.DIRECTION_OUT);

          // Send SET_PROTOCOL HID specific command.
          int tmpRes = await QuickUsb.controlTransfer(
              _usbDevice, 0x21, 0x0B, 0x0001, 0x0, Uint8List.fromList([]), 0x0);

          debugPrint("Control transfer result code: $tmpRes");

          // Send activate command to GCC adapter.
          _usbBulkTransferOut = await QuickUsb.bulkTransferOut(
              _usbEndpointOut, Uint8List.fromList([0x13]),
              timeout: 1500);

          if (_usbBulkTransferOut > 0) {
            debugPrint("USB device transfer out OK.");
            _connected = true;
            return true;
          } else {
            debugPrint("USB device transfer out FAIL.");
            return false;
          }
        } else {
          debugPrint("USB interface claimed FAIL.");
          return false;
        }
      } else {
        debugPrint("USB Device opened FAIL.");
        return false;
      }
    }
    // For Bluetooth device Pro Controller
    else if (devType == 1) {
      _hidOpen = _hidDevice.open();

      if (_hidOpen > -1) {
        debugPrint("Bluetooth joypad opened.");

        List<int> lightCmd = [
          0x01, // Command output
          0x1, // Output counter
          0x0, // Rumble begin
          0x0,
          0x0,
          0x0,
          0x0,
          0x0,
          0x0,
          0x0, // End rumble section
          0x30, // Set player light
          0x1 // p1
        ];

        // Write command to send led light pattern
        int res = await _hidDevice.write(Uint8List.fromList(lightCmd));
        bool ok = false;

        // Check for acknowledgement
        for (int i = 0; i < 10; i++) {
          Uint8List? ls = await _hidDevice.read(len: 16, timeout: 1000);
          if (ls?[14] == 0x30) {
            debugPrint("LED message sent OK.");
            ok = true;
          }
        }

        if (ok) {
          debugPrint("LED message acknowledged OK.");

          // Set up message for full input report mode
          // Change to full input mode command
          List<int> changeCmd = [
            0x01, // Command output
            0x2, // Output counter
            0x0, // Rumble begin
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0,
            0x0, // End rumble section
            0x3, // Set input mode command
            0x30 // Full input mode
          ];

          // Send command to change input mode
          res = await _hidDevice.write(Uint8List.fromList(changeCmd));

          ok = false;

          // Check for acknowledgement
          for (int i = 0; i < 10; i++) {
            Uint8List? ls = await _hidDevice.read(len: 16, timeout: 1000);
            if (ls?[14] == 0x3) {
              debugPrint("Input mode change message sent OK.");
              ok = true;
            }
          }

          if (ok) {
            debugPrint("Input mode change message acknowledged OK.");
            _connected = true;
            return true;
          } else {
            _connected = false;
            debugPrint("Input mode change message acknowledged TIMEOUT.");
            return false;
          }
        } else {
          _connected = false;
          debugPrint("LED message acknowledged TIMEOUT.");
          return false;
        }
      } else {
        debugPrint("Cannot connect to HID device.");
        return false;
      }

      return false;
    }
    // For null device
    else if (devType < 0) {
      debugPrint("Device type is not set.");
      return false;
    }

    return false;
  }

  Future<bool> stopJoypadDevice() async {
    // Disconnect GCC OEM Adapter
    if (devType == 0) {
      debugPrint("Attempting disconnect USB device.");

      await QuickUsb.releaseInterface(_usbConfiguration.interfaces[0]);

      await QuickUsb.closeDevice();
      debugPrint("Device closed OK.");

      await QuickUsb.exit();

      _connected = false;
      devType = -1;
      return true;
    }
    // Disconnect Bluetooth Pro Controller
    else if (devType == 1) {
      debugPrint("Attempting disconnect Bluetooth device.");

      List<int> powerCmd = [
        0x01, // Command output
        0x3, // Output counter
        0x0, // Rumble begin
        0x0,
        0x0,
        0x0,
        0x0,
        0x0,
        0x0,
        0x0, // End rumble section
        0x6, // Set HCI state
        0x00 // Full input mode
      ];

      int res = await _hidDevice.write(Uint8List.fromList(powerCmd));

      _hidDevice.close();
      _connected = false;
      devType = -1;
      debugPrint("Blutooth device disconnected OK.");
      return true;
    }
    return false;
  }

  void getJoypadData() async {
    if (!_connected) {
      debugPrint("Can't get joypad data. Not connected FAIL.");
    }

    // GCC OEM Adapter Type.
    if (devType == 0) {
      try {
        _usbBulkTransferIn =
            await QuickUsb.bulkTransferIn(_usbEndpointIn, 37, timeout: 32);
      } catch (e) {
        debugPrint(_usbBulkTransferIn.toString());
        debugPrint("USB Failure - Timeout");
        //stopJoypadDevice();
      }

      try {
        if (_usbBulkTransferIn![0] == 33) {
          int offset = 9 * subDev;
          inputData.aButton.value = _usbBulkTransferIn![2 + offset] & 1;
          inputData.bButton.value = (_usbBulkTransferIn![2 + offset] >> 1) & 1;
          inputData.xButton.value = (_usbBulkTransferIn![2 + offset] >> 2) & 1;
          inputData.yButton.value = (_usbBulkTransferIn![2 + offset] >> 3) & 1;

          inputData.dpadLeft.value = (_usbBulkTransferIn![2 + offset] >> 4) & 1;
          inputData.dpadRight.value = (_usbBulkTransferIn![2 + offset] >> 5) & 1;
          inputData.dpadDown.value = (_usbBulkTransferIn![2 + offset] >> 6) & 1;
          inputData.dpadUp.value = (_usbBulkTransferIn![2 + offset] >> 7) & 1;

          inputData.startButton.value = _usbBulkTransferIn![3 + offset] & 1;
          inputData.zrButton.value = (_usbBulkTransferIn![3 + offset] >> 1) & 1;
          inputData.rButton.value = (_usbBulkTransferIn![3 + offset] >> 2) & 1;
          inputData.lButton.value = (_usbBulkTransferIn![3 + offset] >> 3) & 1;

          inputData.lStickX.value = _usbBulkTransferIn![4 + offset];
          inputData.lStickY.value = _usbBulkTransferIn![5 + offset];
          inputData.rStickX.value = _usbBulkTransferIn![6 + offset];
          inputData.rStickY.value = _usbBulkTransferIn![7 + offset];
          inputData.lTrigger.value = _usbBulkTransferIn![8 + offset];
          inputData.rTrigger.value = _usbBulkTransferIn![9 + offset];
        }
      } catch (e) {
        debugPrint("Failed USB Bulk transfer in.");
      }
    }

    // Pro Controller Bluetooth Type.
    else if (devType == 1) {
      try {
        Uint8List? out = await _hidDevice.read(timeout: 1000);

        if (out![0] == 0x30) {
          inputData.yButton.value = out[3] & 1;
          inputData.xButton.value = (out[3] >> 1) & 1;
          inputData.bButton.value = (out[3] >> 2) & 1;
          inputData.aButton.value = (out[3] >> 3) & 1;

          inputData.rButton.value = (out[3] >> 6) & 1;
          inputData.zrButton.value = (out[3] >> 7) & 1;

          inputData.startButton.value = out[4] & 1;

          inputData.dpadDown.value = out[5] & 1;
          inputData.dpadUp.value = (out[5] >> 1) & 1;
          inputData.dpadRight.value = (out[5] >> 2) & 1;
          inputData.dpadLeft.value = (out[5] >> 3) & 1;

          inputData.lButton.value = (out[5] >> 6) & 1;
          inputData.zlButton.value = (out[5] >> 7) & 1;

          inputData.lStickX.value = out[6] | ((out[7] & 0xF) << 8);
          inputData.lStickY.value = (out[7] >> 4) | (out[8] << 4);

          inputData.rStickX.value = out[9] | ((out[10] & 0xF) << 8);
          inputData.rStickY.value = (out[10] >> 4) | (out[11] << 4);
        }
      } catch (e) {
        debugPrint("HID Failure.");
        stopJoypadDevice();
      }
    }
  }

  bool isConnected() {
    return _connected;
  }
}

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.grey,
        primaryColor: Colors.black,
        brightness: Brightness.dark,
        backgroundColor: const Color(0xFF212121),
        selectedRowColor: Colors.red,
        buttonColor: Colors.red,
        accentColor: Color.fromARGB(255, 255, 120, 120),
        accentIconTheme: IconThemeData(color: Colors.black),
        dividerColor: Color.fromRGBO(255, 61, 61, 0.363),
      ),
      themeMode: ThemeMode.dark,
      home: RootPage(),
    );
  }
}

// Root Page
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

// Widget builder for MyApp builder
class _RootPageState extends State<RootPage> {
  int currentPage = 0;

  final pages = [
    const PageDevSelect(),
    const PageJoypadTest(),
    const PageStickTest()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HHL JoyTool"),
      ),
      body: pages[currentPage],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPage,
        destinations: const [
          NavigationDestination(
            tooltip: "Page to see available devices.",
            icon: Icon(Icons.device_hub),
            label: "Select Device",
          ),
          NavigationDestination(
            tooltip: "Test button functionality and general sticks.",
            icon: Icon(Icons.gamepad),
            label: "Gamepad Test",
          ),
          NavigationDestination(
            tooltip: "Test stick input and snapback.",
            icon: Icon(Icons.graphic_eq),
            label: "Stick Visualizer",
          ),
        ],
        onDestinationSelected: (index) => setState(() => currentPage = index),
      ),
    );
  }
}
