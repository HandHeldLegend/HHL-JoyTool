import 'package:draw_graph/draw_graph.dart';
import 'package:flutter/material.dart';
import 'package:draw_graph/models/feature.dart';
import 'dart:math';

import 'package:hhljoytool/main.dart';

// Smash ultimate 26
// melee is 23

class JoystickSeries {
  final int value;
  int index;

  JoystickSeries({required this.value, required this.index});

  void upIdx() {
    index++;
  }
}

class PageStickTest extends StatefulWidget {
  const PageStickTest({super.key});

  @override
  State<PageStickTest> createState() => _PageStickTestState();
}

class _PageStickTestState extends State<PageStickTest> {
  bool _pageOpen = true;
  bool _processStarted = false;
  final List<bool> _selections = [false, false, false, false];

  bool _readX = true;
  bool _readY = true;
  bool _leftStick = true;
  String _stickText = "Left Stick";
  bool _absoluteVal = false;

  int _stickCenter = 128;
  int _stickSnapMod = 0;
  int _stickMax = 255;

  int _maxX = 128;
  int _maxY = 128;

  int _curValX = 0;
  int _curValY = 0;

  bool _resetSnapPositiveX = true;
  bool _resetSnapPositiveY = true;

  bool _readPauseCheck = false;
  bool _readPause = false;

  // Set up data for chart
  final List<double> _xAnalogValues = [0];
  final List<double> _yAnalogValues = [0];
  static const _len = 150;
  ValueNotifier<bool> _dirty = ValueNotifier(false);

  Feature testF = Feature(data: []);
  static Feature gccCenter =
      Feature(data: List.filled(_len, 0.5), color: Colors.red, title: "");

  static Feature gccUpper = Feature(
      data: List.filled(_len, 156 / 255),
      color: const Color.fromARGB(134, 119, 0, 255),
      title: "");

  static Feature gccLower = Feature(
      data: List.filled(_len, 100 / 255),
      color: const Color.fromARGB(134, 119, 0, 255),
      title: "");

  Future<void> debugGraphLoop() async {
    while (JoyToolMasterState().isConnected() && _pageOpen) {
      await Future.delayed(const Duration(microseconds: 750), () {
        JoyToolMasterState().getJoypadData();

        if (JoyToolMasterState().inputData.aButton.value == 1 &&
            !_readPauseCheck) {
          _readPauseCheck = true;
        } else if (JoyToolMasterState().inputData.aButton.value == 0 &&
            _readPauseCheck) {
          _readPause = !_readPause;
          _readPauseCheck = false;
        }

        _curValX = _leftStick
            ? JoyToolMasterState().inputData.lStickX.value
            : JoyToolMasterState().inputData.rStickX.value;
        _curValY = _leftStick
            ? JoyToolMasterState().inputData.lStickY.value
            : JoyToolMasterState().inputData.rStickY.value;

        // X axis snapback check
        if (_curValX >= (_stickCenter + _stickSnapMod)) {
          _maxX =
              !_resetSnapPositiveX ? (_absoluteVal ? 0 : _stickCenter) : _maxX;
          _resetSnapPositiveX = true;
        }

        if (_curValX <= (_stickCenter - _stickSnapMod)) {
          _maxX =
              _resetSnapPositiveX ? (_absoluteVal ? 0 : _stickCenter) : _maxX;
          _resetSnapPositiveX = false;
        }

        if (_resetSnapPositiveX && (_curValX <= _stickCenter)) {
          if (_curValX - (_absoluteVal ? _stickCenter : 0) < _maxX) {
            _maxX = _curValX - (_absoluteVal ? _stickCenter : 0);
          }
        } else if (!_resetSnapPositiveX && _curValX >= _stickCenter) {
          if (_curValX - (_absoluteVal ? _stickCenter : 0) > _maxX) {
            _maxX = _curValX - (_absoluteVal ? _stickCenter : 0);
          }
        }

        // Y axis snapback check
        if (_curValY >= _stickCenter + _stickSnapMod) {
          _maxY =
              !_resetSnapPositiveY ? (_absoluteVal ? 0 : _stickCenter) : _maxY;
          _resetSnapPositiveY = true;
        }

        if (_curValY <= _stickCenter - _stickSnapMod) {
          _maxY =
              _resetSnapPositiveY ? (_absoluteVal ? 0 : _stickCenter) : _maxY;
          _resetSnapPositiveY = false;
        }

        if (_resetSnapPositiveY && _curValY <= _stickCenter) {
          if (_curValY - (_absoluteVal ? _stickCenter : 0) < _maxY) {
            _maxY = _curValY - (_absoluteVal ? _stickCenter : 0);
          }
        } else if (!_resetSnapPositiveY && _curValY >= _stickCenter) {
          if (_curValY - (_absoluteVal ? _stickCenter : 0) > _maxY) {
            _maxY = _curValY - (_absoluteVal ? _stickCenter : 0);
          }
        }

        if (_absoluteVal) {
          _curValX = _curValX - _stickCenter;
          _curValY = _curValY - _stickCenter;
        }

        _dirty.value = !_dirty.value;
        if (!_pageOpen) {
          return;
        }
      });
    }
  }

  @override
  void initState() {
    testF = Feature(
        data: _xAnalogValues, color: Colors.green, title: "Analog Stick");
    super.initState();
  }

  @override
  void dispose() {
    _processStarted = false;
    _pageOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (JoyToolMasterState().devType == 0) {
      _stickCenter = 128;
      _stickSnapMod = 80;
      _stickMax = 255;
    } else if (JoyToolMasterState().devType == 1) {
      _stickCenter = 2048;
      _stickSnapMod = 1280;
      _stickMax = 4095;
    }

    if (!_processStarted) {
      debugGraphLoop();
      _selections[1] = false;
      _selections[2] = false;
      _readX = true;
      _readY = false;
      _leftStick = true;
      _selections[0] = true;
      _processStarted = true;
    }

    return Column(
      children: [
        ToggleButtons(
          isSelected: _selections,
          onPressed: (int index) => setState(() {
            _selections[index] = !_selections[index];
            _readX = _selections[0];
            _readY = _selections[1];
            _leftStick = !_selections[2];
            _stickText = !_selections[2] ? "Left Stick" : "Right Stick";
            _absoluteVal = _selections[3];
            _curValX = _absoluteVal ? 0 : _stickCenter;
            _curValY = _absoluteVal ? 0 : _stickCenter;
            _maxX = _absoluteVal ? 0 : _stickCenter;
            _maxY = _absoluteVal ? 0 : _stickCenter;
          }),
          children: [
            const Text("X Axis"),
            const Text("Y Axis"),
            Text(_stickText),
            const Text("Absolute Value")
          ],
        ),
        AnimatedBuilder(
          animation: _dirty,
          builder: (BuildContext context, Widget? child) {
            if (!_readPause) {
              if (_leftStick && _readX) {
                _xAnalogValues.insert(
                    0,
                    JoyToolMasterState().inputData.lStickX.value /
                        _stickMax.toDouble());

                if (_xAnalogValues.length > _len) {
                  _xAnalogValues.removeLast();
                }
              } else if (!_leftStick && _readX) {
                _xAnalogValues.insert(
                    0,
                    JoyToolMasterState().inputData.rStickX.value /
                        _stickMax.toDouble());

                if (_xAnalogValues.length > _len) {
                  _xAnalogValues.removeLast();
                }
              }

              if (_leftStick && _readY) {
                _yAnalogValues.insert(
                    0,
                    JoyToolMasterState().inputData.lStickY.value /
                        _stickMax.toDouble());

                if (_xAnalogValues.length > _len) {
                  _xAnalogValues.removeLast();
                }
              } else if (!_leftStick && _readY) {
                _yAnalogValues.insert(
                    0,
                    JoyToolMasterState().inputData.rStickY.value /
                        _stickMax.toDouble());

                if (_yAnalogValues.length > _len) {
                  _yAnalogValues.removeLast();
                }
              }
            }

            List<Feature> tmpFeatures = [gccCenter, gccUpper, gccLower];

            if (_readX) {
              tmpFeatures.add(Feature(
                  data: _xAnalogValues,
                  color: Colors.green,
                  title: "Analog Stick X"));
            }

            if (_readY) {
              tmpFeatures.add(Feature(
                  data: _yAnalogValues,
                  color: Colors.orange,
                  title: "Analog Stick Y"));
            }

            return Expanded(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text("X Axis: "),
                          Text(_curValX.toString()),
                          const Text("Y Axis: "),
                          Text(_curValY.toString())
                        ],
                      ),
                      Column(
                        children: [
                          const Text("X Max: "),
                          Text(_maxX.toString()),
                          const Text("Y Max: "),
                          Text(_maxY.toString())
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        return Container(
                          width: double.infinity,
                          height: double.infinity,
                          child: LineGraph(
                            features: tmpFeatures,
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight),
                            labelX: List.filled(_len, ""),
                            graphOpacity: 0.025,
                            showDescription: false,
                            labelY: [
                              "0",
                              (_stickMax / 2).round().toString(),
                              _stickMax.toString()
                            ],
                            descriptionHeight: 0,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
