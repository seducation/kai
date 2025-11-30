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

  // 1. Top Header (Date Range)
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color.fromRGBO(176, 196, 222, 0.3), // Light blue-grey
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.arrow_back_ios, size: 16),
          Text(
            "23 / 8 / 2021 to 29 / 8 / 2021",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    );
  }

  // 2. Days of the Week Header (M 23, T 24...)
  Widget _buildDaysHeader() {
    final List<String> days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final List<String> dates = ['23', '24', '25', '26', '27', '28', '29'];

    return Container(
      padding: const EdgeInsets.only(left: 50, top: 10, bottom: 10), // Left padding for time column
      color: const Color.fromRGBO(176, 196, 222, 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          return Column(
            children: [
              Text(days[index], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(dates[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          );
        }),
      ),
    );
  }
}

class TimeGrid extends StatelessWidget {
  // Config
  final double hourHeight = 60.0;
  final double timeColumnWidth = 50.0;
  final int startHour = 10; // 10 AM
  final int endHour = 20;   // 8 PM

  const TimeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A. Time Labels Column
        SizedBox(
          width: timeColumnWidth,
          child: Column(
            children: List.generate((endHour - startHour) + 1, (index) {
              int hour = startHour + index;
              String timeText = (hour > 12) ? '${hour - 12} pm' : '$hour am';
              if (hour == 12) timeText = '12 pm';
              
              return SizedBox(
                height: hourHeight,
                child: Text(
                  timeText,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),
        ),

        // B. The Grid & Events Stack
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double dayWidth = constraints.maxWidth / 7;

              return Stack(
                children: [
                  // Layer 1: Grid Lines
                  Column(
                    children: List.generate((endHour - startHour) + 1, (index) {
                      return Container(
                        height: hourHeight,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color.fromRGBO(158, 158, 158, 0.3)),
                            // Vertical lines logic could be added here or via a Row overlay
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  // Vertical Grid Lines (Overlay)
                  Row(
                    children: List.generate(7, (index) {
                      return Container(
                        width: dayWidth,
                        height: hourHeight * (endHour - startHour + 1),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color.fromRGBO(158, 158, 158, 0.2)),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Layer 2: Events
                  // Client Meeting: Mon (0), 10am - 12pm
                  _buildEventBlock(dayWidth, 0, 10, 2, "Client Meeting"),
                  
                  // Project Meeting: Mon (0), 2pm - 4pm
                  _buildEventBlock(dayWidth, 0, 14, 2, "Project Meeting"),
                  
                  // Football Match: Wed (2), 2pm - 5pm
                  _buildEventBlock(dayWidth, 2, 14, .3 as int, "Football Match"),

                  // Joe's Birthday: Fri (4), 7pm - 8pm
                  _buildEventBlock(dayWidth, 4, 19, 2, "Joe's Birthday"), // Made height 2h to match visual length in image

                  // Layer 3: Current Time Indicator (Black line with dot)
                  Positioned(
                    top: (13.5 - startHour) * hourHeight, // Approx 1:30 PM
                    left: 0,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventBlock(
    double dayWidth, 
    int dayIndex, 
    int eventStartHour, 
    int durationHours, 
    String title
  ) {
    // Calculate Position relative to the grid
    double top = (eventStartHour - startHour) * hourHeight;
    double left = dayIndex * dayWidth;
    double height = durationHours * hourHeight;

    return Positioned(
      top: top,
      left: left,
      width: dayWidth,
      height: height,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E6F9F), // specific blue from image
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}