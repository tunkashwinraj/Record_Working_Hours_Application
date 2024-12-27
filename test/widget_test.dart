import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // To format date and time
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(WorkTrackerApp());
}

class WorkTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Work Tracker',
      home: WorkHomePage(),
    );
  }
}

class WorkHomePage extends StatefulWidget {
  @override
  _WorkHomePageState createState() => _WorkHomePageState();
}

class _WorkHomePageState extends State<WorkHomePage> {
  int _selectedIndex = 0;
  List<WorkDay> workDays = [];
  double hourlyRate = 10.0; // Default hourly rate
  TimeOfDay? fromTime;
  TimeOfDay? toTime;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadHourlyRate();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _pages = <Widget>[
      _buildHomePage(),
      _buildPaymentsPage(),
      _buildMarkedAttendancePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Work Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _setHourlyRateDialog(),
          ),
        ],
      ),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: 'Marked Attendance',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  // Home Page with Digital Clock and Mark Timing
  Widget _buildHomePage() {
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());

    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            currentTime,
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Text(
            'Today\'s Date: $currentDate',
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _markTimeDialog(currentDate),
            child: Text('Mark Work Time for Today'),
          ),
        ],
      ),
    );
  }

  // Payments Page: List of Paid/Unpaid Days
  Widget _buildPaymentsPage() {
    return ListView.builder(
      itemCount: workDays.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(
              'Date: ${workDays[index].date}, Hours: ${workDays[index].hoursWorked}, Paid: ${workDays[index].isPaid ? "Yes" : "No"}'),
          trailing: Checkbox(
            value: workDays[index].isPaid,
            onChanged: (bool? value) {
              setState(() {
                workDays[index].isPaid = value!;
                _saveData();
              });
            },
          ),
        );
      },
    );
  }

  // Marked Attendance Page: List of All Marked Work Hours
  Widget _buildMarkedAttendancePage() {
    return ListView.builder(
      itemCount: workDays.length,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.all(8),
          color: workDays[index].isPaid ? Colors.lightGreen : Colors.redAccent,
          child: ListTile(
            title: Text(
                'Date: ${workDays[index].date}, Hours Worked: ${workDays[index].hoursWorked}'),
            subtitle: Text('Earnings: \$${workDays[index].calculateEarnings(hourlyRate)}'),
            trailing: IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _editWorkDayDialog(index),
            ),
          ),
        );
      },
    );
  }

  // Dialog to Set Hourly Rate
  void _setHourlyRateDialog() {
    TextEditingController payController = TextEditingController();
    payController.text = hourlyRate.toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Set Hourly Rate'),
          content: TextField(
            controller: payController,
            decoration: InputDecoration(hintText: 'Enter Hourly Rate'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              child: Text('Save'),
              onPressed: () {
                setState(() {
                  hourlyRate = double.tryParse(payController.text) ?? hourlyRate;
                  _saveHourlyRate();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Dialog to Mark Work Time
  void _markTimeDialog(String currentDate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Mark Work Hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(fromTime != null
                    ? 'From: ${fromTime!.format(context)}'
                    : 'Select Start Time'),
                trailing: Icon(Icons.access_time),
                onTap: () => _selectTime(context, true),
              ),
              ListTile(
                title: Text(toTime != null
                    ? 'To: ${toTime!.format(context)}'
                    : 'Select End Time'),
                trailing: Icon(Icons.access_time),
                onTap: () => _selectTime(context, false),
              ),
              if (fromTime != null && toTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    'Hours Worked: ${_calculateHoursWorked(fromTime!, toTime!)}',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Save'),
              onPressed: () {
                if (fromTime != null && toTime != null) {
                  setState(() {
                    final hoursWorked = _calculateHoursWorked(fromTime!, toTime!);
                    workDays.add(WorkDay(
                      date: currentDate,
                      hoursWorked: hoursWorked,
                      fromTime: fromTime!,
                      toTime: toTime!,
                    ));
                    _saveData();
                    fromTime = null;
                    toTime = null;
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Dialog to Edit Work Day
  void _editWorkDayDialog(int index) {
    final dateController = TextEditingController(text: workDays[index].date);
    final initialFromTime = workDays[index].fromTime;
    final initialToTime = workDays[index].toTime;

    showDialog(
        context: context,
        builder: (BuildContext context) {
      return AlertDialog(
          title: Text('Edit Work Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: InputDecoration(labelText: 'Date (yyyy-MM-dd)'),
                keyboardType: TextInputType.datetime,
              ),
              ListTile(
                title: Text(initialFromTime != null
                    ? 'From: ${initialFromTime.format(context)}'
                    : 'Select Start Time'),
                trailing: Icon(Icons.access_time),
                onTap: () => _selectTime(context, true, initialFromTime),
              ),
              ListTile(
                title: Text(initialToTime != null
                    ? 'To: ${initialToTime.format(context)}'
                    : 'Select End Time'),
                trailing: Icon(Icons.access_time),
                onTap: () => _selectTime(context, false, initialToTime),
              ),
              if (initialFromTime != null && initialToTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    'Hours Worked: ${_calculateHoursWorked(initialFromTime, initialToTime)}',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
          actions: [
      TextButton(
      child: Text('Save'),
    onPressed: () {
    if (dateController.text.isNotEmpty &&
        initialToTime != null) {
      setState(() {
        final updatedDate = dateController.text;
        final updatedFromTime = initialFromTime;
        final updatedToTime = initialToTime;
        final hoursWorked = _calculateHoursWorked(updatedFromTime, updatedToTime);

        workDays[index] = WorkDay(
          date: updatedDate,
          hoursWorked: hoursWorked,
          fromTime: updatedFromTime,
          toTime: updatedToTime,
          isPaid: workDays[index].isPaid,
        );

        _saveData();
      });
      Navigator.of(context).pop();
    }
    },
      ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                setState(() {
                  workDays.removeAt(index);
                  _saveData();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
      );
        },
    );
  }

  // Time Picker for Work Hours
  Future<void> _selectTime(BuildContext context, bool isFromTime, [TimeOfDay? initialTime]) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromTime) {
          fromTime = picked;
        } else {
          toTime = picked;
        }
      });
    }
  }

  // Calculate total hours worked based on time selection
  double _calculateHoursWorked(TimeOfDay start, TimeOfDay end) {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, start.hour, start.minute);
    final endTime = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    final difference = endTime.difference(startTime).inMinutes / 60;
    return difference;
  }

  // Save data to SharedPreferences
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(workDays.map((day) => day.toJson()).toList());
    await prefs.setString('workDays', jsonString);
  }

  // Load data from SharedPreferences
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('workDays');
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        workDays = jsonList.map((json) => WorkDay.fromJson(json)).toList();
      });
    }
  }

  // Save hourly rate to SharedPreferences
  Future<void> _saveHourlyRate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hourlyRate', hourlyRate);
  }

  // Load hourly rate from SharedPreferences
  Future<void> _loadHourlyRate() async {
    final prefs = await SharedPreferences.getInstance();
    hourlyRate = prefs.getDouble('hourlyRate') ?? 10.0;
  }
}

class WorkDay {
  String date;
  double hoursWorked;
  bool isPaid;
  TimeOfDay fromTime;
  TimeOfDay toTime;

  WorkDay({
    required this.date,
    required this.hoursWorked,
    required this.fromTime,
    required this.toTime,
    this.isPaid = false,
  });

  factory WorkDay.fromJson(Map<String, dynamic> json) {
    return WorkDay(
      date: json['date'],
      hoursWorked: json['hoursWorked'].toDouble(),
      isPaid: json['isPaid'],
      fromTime: TimeOfDay(
        hour: json['fromTime']['hour'],
        minute: json['fromTime']['minute'],
      ),
      toTime: TimeOfDay(
        hour: json['toTime']['hour'],
        minute: json['toTime']['minute'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'hoursWorked': hoursWorked,
      'isPaid': isPaid,
      'fromTime': {
        'hour': fromTime.hour,
        'minute': fromTime.minute,
      },
      'toTime': {
        'hour': toTime.hour,
        'minute': toTime.minute,
      },
    };
  }

  double calculateEarnings(double hourlyRate) {
    return hoursWorked * hourlyRate;
  }
}

