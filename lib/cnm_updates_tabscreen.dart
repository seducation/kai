import 'package:flutter/material.dart';

class CNMUpdatesTabscreen extends StatelessWidget {
  const CNMUpdatesTabscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CalendarPage();
  }
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDaysHeader(),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: 10, bottom: 20),
                child: TimeGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "May 2024",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaysHeader() {
    final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri"];
    final List<String> dates = ["13", "14", "15", "16", "17"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(5, (index) {
          final isToday = dates[index] == "14";
          return Column(
            children: [
              Text(
                days[index],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CircleAvatar(
                radius: 16,
                backgroundColor: isToday ? Colors.blue : Colors.transparent,
                child: Text(
                  dates[index],
                  style: TextStyle(
                    color: isToday ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class TimeGrid extends StatelessWidget {
  const TimeGrid({super.key});

  final double hourHeight = 60.0;
  final int totalHours = 24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double dayWidth = totalWidth / 5; // 5 days: Mon-Fri

        return Stack(
          children: [
            // Layer 1: Grid Lines and Time Labels
            Positioned.fill(
              child: Row(
                children: [
                  // Time Column
                  SizedBox(
                    width: 50,
                    child: Column(
                      children: List.generate(totalHours, (i) {
                        return Container(
                          height: hourHeight,
                          alignment: Alignment.topCenter,
                          child: Text(
                            "${i.toString().padLeft(2, '0')}:00",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Days Grid
                  Expanded(
                    child: Column(
                      children: List.generate(totalHours, (i) {
                        return Container(
                          height: hourHeight,
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey[200]!)),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Layer 2: Events
            // Client Meeting: Mon (0), 10am - 12pm
            _buildEventBlock(dayWidth, 0, 10, 2, "Client Meeting"),
            
            // Project Meeting: Mon (0), 2pm - 4pm
            _buildEventBlock(dayWidth, 0, 14, 2, "Project Meeting"),
            
            // Football Match: Wed (2), 2pm - 5pm
            _buildEventBlock(dayWidth, 2, 14, 3, "Football Match"),

            // Joe's Birthday: Fri (4), 7pm - 8pm
            _buildEventBlock(dayWidth, 4, 19, 2, "Joe's Birthday"), // Made height 2h to match visual length in image

          ],
        );
      },
    );
  }

  Widget _buildEventBlock(double dayWidth, int dayIndex, int startHour, int duration, String title) {
    return Positioned(
      top: startHour * hourHeight,
      left: 50 + (dayIndex * dayWidth) + 5, // 50 for time column, 5 for padding
      child: Container(
        width: dayWidth - 10, // 10 for padding
        height: duration * hourHeight, // Use integer duration
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(38),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Colors.blue, width: 3)),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
