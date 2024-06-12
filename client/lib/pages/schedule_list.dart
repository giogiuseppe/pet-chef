// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleListPage extends StatefulWidget {
  final List<TimeOfDay> scheduledTimes;
  final Future<void> Function() clearScheduledTimes;
  final Function(TimeOfDay) onRemove;

  const ScheduleListPage({
    super.key,
    required this.scheduledTimes,
    required this.clearScheduledTimes,
    required this.onRemove,
  });

  @override
  _ScheduleListPageState createState() => _ScheduleListPageState();
}

class _ScheduleListPageState extends State<ScheduleListPage> {
  late List<TimeOfDay> scheduledTimes;

  @override
  void initState() {
    super.initState();
    scheduledTimes = widget.scheduledTimes;
  }

  @override
  Widget build(BuildContext context) {
    final String currentDate = DateFormat('dd/MM/yyyy').format(
      DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () async {
              await widget.clearScheduledTimes();
              setState(() {
                scheduledTimes.clear();
              });
            },
            icon: const Icon(
              Icons.clear,
              color: Color(0xFFE10051),
            ),
          ),
        ],
      ),
      body: scheduledTimes.isEmpty
          ? const Center(
              child: Text(
                'Nenhum agendamento',
                style: TextStyle(
                  fontSize: 16.0,
                  letterSpacing: 2.0,
                ),
              ),
            )
          : ListView.builder(
              itemCount: scheduledTimes.length,
              itemBuilder: (context, index) {
                final time = scheduledTimes[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2.0,
                    horizontal: 24.0,
                  ),
                  child: InkWell(
                    onTap: () {

                    },
                    child: Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.access_time,
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              time.format(context),
                              style: const TextStyle(
                                letterSpacing: 2.0,
                              ),
                            ),
                            Text(
                              currentDate,
                              style: const TextStyle(
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
