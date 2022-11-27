import 'dart:ffi';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quick_usb/quick_usb.dart';
import 'main.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/animation.dart';

class ButtonUpdateWidget extends StatefulWidget {
  ButtonUpdateWidget({super.key, required this.name, required this.notifier});

  String name;
  ValueNotifier<int> notifier;

  @override
  State<ButtonUpdateWidget> createState() => _ButtonUpdateWidgetState();
}

class _ButtonUpdateWidgetState extends State<ButtonUpdateWidget> {
  final Icon butOn = const Icon(Icons.radio_button_checked);
  final Icon butOff = const Icon(Icons.radio_button_off);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.name),
        AnimatedBuilder(
          // [AnimatedBuilder] accepts any [Listenable] subtype.
          animation: widget.notifier,
          builder: (BuildContext context, Widget? child) {
            return widget.notifier.value == 1 ? butOn : butOff;
          },
        ),
      ],
    );
  }
}

class AnalogUpdateWidget extends StatefulWidget {
  AnalogUpdateWidget({super.key, required this.name, required this.notifier});

  String name;
  ValueNotifier<int> notifier;

  @override
  State<AnalogUpdateWidget> createState() => _AnalogUpdateWidgetState();
}

class _AnalogUpdateWidgetState extends State<AnalogUpdateWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.name),
        AnimatedBuilder(
          // [AnimatedBuilder] accepts any [Listenable] subtype.
          animation: widget.notifier,
          builder: (BuildContext context, Widget? child) {
            return Text(widget.notifier.value.toString());
          },
        ),
      ],
    );
  }
}

class PageJoypadTest extends StatefulWidget {
  const PageJoypadTest({super.key});

  @override
  State<PageJoypadTest> createState() => _PageJoypadTestState();
}

class _PageJoypadTestState extends State<PageJoypadTest> {
  bool _pageOpen = true;

  Future<void> joypadLoop() async {
    while (JoyToolMasterState().isConnected() && _pageOpen) {
      await Future.delayed(const Duration(milliseconds: 1), () {
        JoyToolMasterState().getJoypadData();
      });
      if (!_pageOpen) {
        return;
      }
    }
  }

  @override
  void dispose() {
    _pageOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    joypadLoop();

    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
        Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ButtonUpdateWidget(
            name: "A ",
            notifier: JoyToolMasterState().inputData.aButton,
          ),
          ButtonUpdateWidget(
            name: "B ",
            notifier: JoyToolMasterState().inputData.bButton,
          ),
          ButtonUpdateWidget(
            name: "X ",
            notifier: JoyToolMasterState().inputData.xButton,
          ),
          ButtonUpdateWidget(
            name: "Y ",
            notifier: JoyToolMasterState().inputData.yButton,
          ),
          ButtonUpdateWidget(
            name: "D-Up ",
            notifier: JoyToolMasterState().inputData.dpadUp,
          ),
          ButtonUpdateWidget(
            name: "D-Down ",
            notifier: JoyToolMasterState().inputData.dpadDown,
          ),
          AnalogUpdateWidget(
            name: "L Stick X ",
            notifier: JoyToolMasterState().inputData.lStickX,
          ),
          AnalogUpdateWidget(
            name: "L Stick Y ",
            notifier: JoyToolMasterState().inputData.lStickY,
          ),
          AnalogUpdateWidget(
            name: "L Trigger Analog ",
            notifier: JoyToolMasterState().inputData.lTrigger,
          )
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ButtonUpdateWidget(
            name: "Z ",
            notifier: JoyToolMasterState().inputData.zrButton,
          ),
          ButtonUpdateWidget(
            name: "R Button ",
            notifier: JoyToolMasterState().inputData.rButton,
          ),
          ButtonUpdateWidget(
            name: "L Button ",
            notifier: JoyToolMasterState().inputData.lButton,
          ),
          ButtonUpdateWidget(
            name: "Start ",
            notifier: JoyToolMasterState().inputData.startButton,
          ),
          ButtonUpdateWidget(
            name: "D-Left ",
            notifier: JoyToolMasterState().inputData.dpadLeft,
          ),
          ButtonUpdateWidget(
            name: "D-Right ",
            notifier: JoyToolMasterState().inputData.dpadRight,
          ),
          AnalogUpdateWidget(
            name: "R Stick X ",
            notifier: JoyToolMasterState().inputData.rStickX,
          ),
          AnalogUpdateWidget(
            name: "R Stick Y ",
            notifier: JoyToolMasterState().inputData.rStickY,
          ),
          AnalogUpdateWidget(
            name: "R Trigger Analog ",
            notifier: JoyToolMasterState().inputData.rTrigger,
          )
        ],
      )
      ],)
    );
  }
}
