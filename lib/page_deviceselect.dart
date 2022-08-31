import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:core';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:hidapi_dart/hidapi_dart.dart';
import 'package:quick_usb/quick_usb.dart';
import 'package:hhljoytool/main.dart';

class GamepadListItem {
  String name = "No Object Found";
  int type = -1; // -1 is null, 0 is USB, 1 is bluetooth
  int subIdx = 0;
  int subDev = 0;

  GamepadListItem(this.name, this.type, this.subIdx, this.subDev);
}

class PageDevSelect extends StatefulWidget {
  const PageDevSelect({super.key});

  @override
  State<PageDevSelect> createState() => _PageDevSelectState();
}

class _PageDevSelectState extends State<PageDevSelect> {
  final List<UsbDevice>? _deviceList = [];
  final List<HID>? _hidList = [];
  final List<GamepadListItem> _gamepadList = [
    GamepadListItem("No device found.", -1, 0, 0)
  ];

  // Function for refresh button pressed
  void refreshPressed() async {
    JoyToolMasterState().uiButtonChanging = 1;
    setState(() => {});

    // Clear current device list
    _deviceList?.clear();
    _gamepadList.clear();

    JoyToolMasterState().uiSelectedDevice = -1;

    // USB Device Scan
    var tmpopen = await QuickUsb.init();

    if (tmpopen) {
      List<UsbDevice>? tmpList = await QuickUsb.getDeviceList();
      int tmpIdx = 0;
      if (tmpList.isNotEmpty) {
        for (int i = 0; i < tmpList.length; i++) {
          if (tmpList[i].productId == 0x337) {
            // Gamecube OEM Adapter Found
            _deviceList!.add(tmpList[i]);
            _gamepadList
                .add(GamepadListItem("GCC Adapter - Port 1", 0, tmpIdx, 0));
            _gamepadList
                .add(GamepadListItem("GCC Adapter - Port 2", 0, tmpIdx, 1));
            _gamepadList
                .add(GamepadListItem("GCC Adapter - Port 3", 0, tmpIdx, 2));
            _gamepadList
                .add(GamepadListItem("GCC Adapter - Port 4", 0, tmpIdx, 3));
            tmpIdx++;
          }
        }
      }
      JoyToolMasterState().uiButtonChanging = 0;
      await QuickUsb.exit();
      setState(() => {});
    } else {
      debugPrint("Failed to get device list.");
      JoyToolMasterState().uiButtonChanging = 0;
      setState(() => {});
    }

    // HID Device Scan
    List<int> validIDs = [0x2007, 0x2006, 0x2009];
    int hidIdx = 0;

    for (int i = 0; i < validIDs.length; i++) {
      try {
        HID? hidDev = HID(idProduct: validIDs[i], idVendor: 0x057E);
        if (hidDev.open() < 0) {
          debugPrint("Can't open known device. Not Connected.");
        } else {
          String name = "";
          switch (hidDev.idProduct) {
            case 0x2006:
              name = "Joy-Con Left";
              break;
            case 0x2007:
              name = "Joy-Con Right";
              break;
            case 0x2009:
              name = "NS Pro Controller";
              break;
          }
          _gamepadList.add(GamepadListItem(name, 1, hidIdx, 0));
          _hidList!.add(hidDev);
          hidIdx++;
          hidDev.close();
        }
      } catch (e) {
        debugPrint("Device not found HID");
      }
    }
  }
  // End function

  // Function for connect pressed
  void connectPressed() async {
    if (JoyToolMasterState().uiSelectedDevice > -1) {
      JoyToolMasterState().uiButtonChanging = 1;
      setState(() => {});

      if (_gamepadList[JoyToolMasterState().uiSelectedDevice].type == 0) {
        int tmpIdx = _gamepadList[JoyToolMasterState().uiSelectedDevice].subIdx;
        JoyToolMasterState().subDev =
            _gamepadList[JoyToolMasterState().uiSelectedDevice].subDev;

        JoyToolMasterState().setUsbDevice(_deviceList![tmpIdx]);
      } else if (_gamepadList[JoyToolMasterState().uiSelectedDevice].type ==
          1) {
        int tmpIdx = _gamepadList[JoyToolMasterState().uiSelectedDevice].subIdx;

        JoyToolMasterState().setHidDevice(_hidList![tmpIdx]);
      }

      var check = await JoyToolMasterState().startJoypadDevice();

      if (!check) {
        refreshPressed();
      }

      JoyToolMasterState().uiButtonChanging = 0;
      setState(() => {});
    }
  }
  // End function

  // Function for disconnect pressed
  void disconnectPressed() async {
    debugPrint("Attempting disconnect...");
    JoyToolMasterState().uiButtonChanging = 1;
    JoyToolMasterState().uiSelectedDevice = -1;
    setState(() => {});
    setState(() => {});
    var check = await JoyToolMasterState().stopJoypadDevice();
    if (check) {
      refreshPressed();
      JoyToolMasterState().uiButtonChanging = 0;
      setState(() => {});
    } else {
      refreshPressed();
      JoyToolMasterState().uiButtonChanging = 0;
      debugPrint("Failed to disconnect device");
      setState(() => {});
    }
  }
  // End function

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: JoyToolMasterState().uiButtonChanging == 1
                      ? null
                      : JoyToolMasterState().isConnected()
                          ? null
                          : refreshPressed,
                  child: const Text("Refresh List"),
                ),
                ElevatedButton(
                  onPressed: JoyToolMasterState().uiButtonChanging == 1 ||
                          JoyToolMasterState().uiSelectedDevice < 0
                      ? null
                      : JoyToolMasterState().isConnected()
                          ? null
                          : connectPressed,
                  child: const Text("Connect"),
                ),
                ElevatedButton(
                  onPressed: JoyToolMasterState().uiButtonChanging == 1
                      ? null
                      : JoyToolMasterState().isConnected()
                          ? disconnectPressed
                          : null,
                  child: const Text("Disconnect"),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: ListView.builder(
                padding: const EdgeInsets.all(10.0),
                shrinkWrap: true,
                itemCount: _gamepadList.length,
                itemBuilder: ((context, index) => Ink(
                      color: JoyToolMasterState().uiSelectedDevice == index
                          ? (_gamepadList[index].type == -1
                              ? Colors.transparent
                              : Color.fromARGB(255, 155, 40, 40))
                          : Colors.transparent,
                      child: ListTile(
                        leading: _gamepadList[index].type == 1
                            ? const Icon(Icons.bluetooth)
                            : _gamepadList[index].type == 0
                                ? const Icon(Icons.usb)
                                : const Icon(Icons.question_mark),
                        title: Text(_gamepadList[index].name.toString()),
                        onTap: () {
                          if (_gamepadList[index].type != -1) {
                            JoyToolMasterState().uiSelectedDevice = index;
                          }

                          setState(() => {});
                        },
                      ),
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
