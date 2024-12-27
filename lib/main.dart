import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final workDaysString = prefs.getStringList('workDays') ?? [];
    setState(() {
      workDays = workDaysString.map((e) {
        final parts = e.split(':');
        return WorkDay(
          date: parts[0],
          hoursWorked: double.parse(parts[1]),
          isPaid: parts[2] == '1',
        );
      }).toList();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final workDaysString = workDays.map((e) {
      return '${e.date}:${e.hoursWorked}:${e.isPaid ? '1' : '0'}';
    }).toList();
    await prefs.setStringList('workDays', workDaysString);
  }

  Future<void> _loadHourlyRate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hourlyRate = prefs.getDouble('hourlyRate') ?? 10.0;
    });
  }

  Future<void> _saveHourlyRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hourlyRate', rate);
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
                _saveData(); // Save changes to SharedPreferences
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
        return ListTile(
          title: Text(
              'Date: ${workDays[index].date}, Hours Worked: ${workDays[index].hoursWorked}'),
          subtitle: Text('Earnings: \$${workDays[index].calculateEarnings(hourlyRate)}'),
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
                  _saveHourlyRate(hourlyRate); // Save hourly rate to SharedPreferences
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
                    ));
                    _saveData(); // Save changes to SharedPreferences
                  });
                  fromTime = null;
                  toTime = null;
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Time Picker for Work Hours
  Future<void> _selectTime(BuildContext context, bool isFromTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
}

class WorkDay {
  String date;
  double hoursWorked;
  bool isPaid;

  WorkDay({required this.date, required this.hoursWorked, this.isPaid = false});

  double calculateEarnings(double hourlyRate) {
    return hoursWorked * hourlyRate;
  }
}


