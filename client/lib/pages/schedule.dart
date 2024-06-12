import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:client/pages/schedule_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  Timer? _timer;
  List<TimeOfDay> scheduledTimes = [];
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final String adafruitApiKey = 'ADAFRUIT-API-KEY';
  final String adafruitFeedName = 'ADAFRUIT-FEED-NAME';

  @override
  void initState() {
    super.initState();
    _loadScheduledTimes();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadScheduledTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? times = prefs.getStringList('scheduledTimes');
    if (times != null) {
      setState(() {
        scheduledTimes = times.map((time) {
          final parts = time.split(':');
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return TimeOfDay(hour: hour, minute: minute);
        }).toList();
      });
    }
  }

  Future<void> _saveScheduledTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> times = scheduledTimes
        .map((time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}')
        .toList();
    await prefs.setStringList('scheduledTimes', times);
  }

  Future<void> _sendMessageNow() async {
    final response = await http.post(
      Uri.parse(
          'https://io.adafruit.com/api/v2/ADAFRUIT-USERNAME/feeds/$adafruitFeedName/data'),
      headers: {
        'X-AIO-Key': adafruitApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'value': 'OK',
      }),
    );

    if (response.statusCode == 200) {
      try {
        await FirebaseFirestore.instance
            .collection('sentMessages')
            .add({'message': 'OK', 'timestamp': DateTime.now()});
      } catch (error) {
        _showAlertDialog(
          Icons.close,
          24.0,
          const Color(0xFFE10051),
          'Erro ao salvar mensagem enviada no Firestore: $error',
          () {
            Navigator.of(context).pop();
          },
        );
      }

      _showAlertDialog(
        Icons.done_all,
        24.0,
        const Color(0xFF00E1C2),
        'Horário enviado com sucesso',
        () {
          Navigator.of(context).pop();
        },
      );
    } else {
      _showAlertDialog(
        Icons.close,
        24.0,
        const Color(0xFFE10051),
        'Falha ao enviar o horário',
        () {
          Navigator.of(context).pop();
        },
      );
    }
  }

  Future<void> _scheduleMessage(TimeOfDay timeOfDay) async {
    final now = DateTime.now();
    final scheduledDateTime = DateTime(
        now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);

    if (scheduledDateTime.isBefore(now)) {
      _showAlertDialog(
        Icons.close,
        24.0,
        const Color(0xFFE10051),
        'Você só pode agendar para um horário futuro',
        () {
          Navigator.of(context).pop();
        },
      );
      return;
    }

    final int hour = timeOfDay.hour;
    final int minute = timeOfDay.minute;

    final formattedTime =
        '${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}';

    _showAlertDialog(
      Icons.done_all,
      24.0,
      const Color(0xFF00E1C2),
      'Acionamento agendado para $hour:$minute',
      () {
        Navigator.of(context).pop();
      },
    );

    await Future.delayed(scheduledDateTime.difference(now));

    final response = await http.post(
      Uri.parse(
          'https://io.adafruit.com/api/v2/ADAFRUIT-USERNAME/feeds/$adafruitFeedName/data'),
      headers: {
        'X-AIO-Key': adafruitApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'value': formattedTime,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        scheduledTimes.remove(timeOfDay);
      });
      await _saveScheduledTimes();
      try {
        await FirebaseFirestore.instance.collection('scheduledMessages').add({
          'message': formattedTime,
          'timestamp': scheduledDateTime,
        });
      } catch (error) {
        _showAlertDialog(
          Icons.close,
          24.0,
          const Color(0xFFE10051),
          'Erro ao salvar agendamento no Firestore: $error',
          () {
            Navigator.of(context).pop();
          },
        );
      }
    } else {
      _showAlertDialog(
        Icons.close,
        24.0,
        const Color(0xFFE10051),
        'Falha ao enviar o horário',
        () {
          Navigator.of(context).pop();
        },
      );
    }
  }

  Future<void> _clearScheduledTimes() async {
    try {
      await FirebaseFirestore.instance
          .collection('scheduledTimes')
          .doc('userScheduledTimes')
          .delete();
    } catch (error) {
      _showAlertDialog(
        Icons.close,
        24.0,
        const Color(0xFFE10051),
        'Erro ao salvar agendamento no Firestore: $error',
        () {
          Navigator.of(context).pop();
        },
      );
      _showAlertDialog(
        Icons.error,
        24.0,
        const Color(0xFFE10051),
        'Falha ao remover os horários',
        () {
          Navigator.of(context).pop();
        },
      );
      return;
    }

    setState(() {
      scheduledTimes.clear();
    });
    _showAlertDialog(
      Icons.done_all,
      24.0,
      const Color(0xFF00E1C2),
      'Todos os horários foram removidos com sucesso',
      () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showTimePicker() {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (BuildContext context, Widget? child) {
        return TimePickerTheme(
          data: const TimePickerThemeData(
            dayPeriodColor: Color(0xFFD6E1E0),
            dayPeriodBorderSide: BorderSide.none,
            helpTextStyle: TextStyle(
              letterSpacing: 2.0,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF002D62),
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              textSelectionTheme: const TextSelectionThemeData(
                cursorColor: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
      },
      helpText: 'Selecionar Horário',
      hourLabelText: '',
      minuteLabelText: '',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    ).then((value) {
      if (value != null) {
        setState(() {
          scheduledTimes.add(value);
          scheduledTimes.sort((a, b) => a.hour != b.hour
              ? a.hour.compareTo(b.hour)
              : a.minute.compareTo(b.minute));
        });
        _saveScheduledTimes();
        _scheduleMessage(value);
      }
    });
  }

  void _showAlertDialog(IconData icon, double iconSize, Color iconColor,
      String content, VoidCallback onDismiss) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
          content: Text(
            content,
            style: const TextStyle(
              letterSpacing: 2.0,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002D62),
                  elevation: 0.0,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToScheduleList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleListPage(
          scheduledTimes: scheduledTimes,
          onRemove: (TimeOfDay time) {
            setState(() {
              scheduledTimes.remove(time);
            });
            _saveScheduledTimes();
          },
          clearScheduledTimes: _clearScheduledTimes,
        ),
      ),
    );
    _loadScheduledTimes();
  }

  TimeOfDay? getNextScheduledTime() {
    if (scheduledTimes.isEmpty) {
      return null;
    }
    final now = TimeOfDay.now();
    scheduledTimes.sort((a, b) => a.hour != b.hour
        ? a.hour.compareTo(b.hour)
        : a.minute.compareTo(b.minute));
    return scheduledTimes.firstWhere(
      (time) =>
          time.hour > now.hour ||
          (time.hour == now.hour && time.minute > now.minute),
      orElse: () => scheduledTimes.first,
    );
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            if (val.finalResult) {
              if (val.recognizedWords.isNotEmpty) {
                String command = val.recognizedWords.toLowerCase();
                if (command.contains('agendar')) {
                  _showTimePicker();
                } else if (command.contains('acionar agora')) {
                  _sendMessageNow();
                } else if (command.contains('agendamentos')) {
                  _navigateToScheduleList();
                }
              } else {
                _showAlertDialog(
                  Icons.close,
                  24.0,
                  const Color(0xFFE10051),
                  'Comando não reconhecido',
                  () {
                    Navigator.of(context).pop();
                  },
                );
              }
            }
          }),
        );

        Future.delayed(const Duration(seconds: 5), () {
          setState(() => _isListening = false);
          _speech.stop();
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextTime = getNextScheduledTime();
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _navigateToScheduleList,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      nextTime != null
                          ? 'Próximo Acionamento'
                          : 'Nenhum Agendamento',
                      style: const TextStyle(
                        fontSize: 16.0,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Text(
                      nextTime != null
                          ? nextTime.format(context).toString()
                          : '--:--',
                      style: const TextStyle(
                        fontSize: 48.0,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF002D62),
                        ),
                        backgroundColor: Colors.transparent,
                        elevation: 0.0,
                      ),
                      onPressed: _sendMessageNow,
                      child: const Text(
                        'Acionar Agora',
                        style: TextStyle(
                          fontSize: 16.0,
                          letterSpacing: 2.0,
                          color: Color(0xFF002D62),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening
                          ? const Color(0xFF00E1C2)
                          : const Color(0xFF002D62),
                      width: 1.0,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening
                          ? const Color(0xFF00E1C2)
                          : const Color(0xFF002D62),
                    ),
                    onPressed: _startListening,
                    iconSize: 32.0,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002D62),
                      elevation: 0.0,
                    ),
                    onPressed: _showTimePicker,
                    child: const Text(
                      'Agendar',
                      style: TextStyle(
                        fontSize: 16.0,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
