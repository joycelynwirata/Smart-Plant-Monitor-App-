import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as Math;

import 'ai_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_plant_page.dart';
import 'plant_settings_page.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedPage = "dashboard";
  String light = '--';
  String soilTension = '--';
  String liquidDetected = '--';
  String status = "Connecting...";
  List<double> soilHistory = [45, 50, 55, 53, 60, 58, 62];

  final String ipAddress = 'http://192.168.4.1/data';

  Timer? timer;

  bool isSimpleMode = true;
  bool isWatering = false;
  DateTime lastWaterAlert =
    DateTime.now().subtract(const Duration(hours: 9));

  DateTime lastSoilAlert =
    DateTime.now().subtract(const Duration(hours: 9));

  final Map<String, Map<String, dynamic>> plantProfiles = {
    "Succulent": {
      "light": "High",
      "watering": "Low",
      "soil": "Dry",
      "dryThreshold": 100,
    },
    "Tropical": {
      "light": "Medium",
      "watering": "High",
      "soil": "Moist",
      "dryThreshold": 80,
    },
    "Flowering": {
      "light": "High",
      "watering": "Medium",
      "soil": "Moderate",
      "dryThreshold": 90,
    },
  };

  Future<void> sendEmail(String message) async {
    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");

    final response = await http.post(
      url,
      headers: {
        "origin": "http://localhost",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "service_id": const String.fromEnvironment('EMAILJS_SERVICE_ID'),
        "template_id": const String.fromEnvironment('EMAILJS_TEMPLATE_ID'),
        "user_id": const String.fromEnvironment('EMAILJS_USER_ID'),
        "template_params": {
          "message": message,
          "to_email": FirebaseAuth.instance.currentUser?.email,
        }
      }),
    );

    print("Email status: ${response.statusCode}");
  }

  Future<void> triggerPump() async {
    setState(() {
      isWatering = true;
      status = "Watering...";
    });

    try {
      await http.get(Uri.parse("http://192.168.4.1/waterNow"));
      setState(() {
        status = "Watered";
      });
    } catch (e) {
      setState(() {
        status = "Failed";
      });
    }

    setState(() {
      isWatering = false;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void initState() {
    super.initState();

    getSensorData();

    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      getSensorData(); 
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> getSensorData() async {
    try {
      final response = await http.get(Uri.parse(ipAddress));
      final data = jsonDecode(response.body);

      setState(() {
        light = data['lux'].toString();
        soilTension = data['soil'].toString();
        liquidDetected =
            data['liquid'].toString().trim().toUpperCase();
        status = "Connected";
      });

      final soilValue = data['soil'] is num
          ? (data['soil'] as num).toInt()
          : int.tryParse(data['soil'].toString()) ?? 0;

      final now = DateTime.now();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final plantsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plants')
          .limit(1)
          .get();

      if (plantsSnapshot.docs.isEmpty) return;

      final plantData = plantsSnapshot.docs.first.data();
      final profile = (plantData['profile'] ?? "Tropical").toString();

      final threshold =
          plantProfiles[profile]?['dryThreshold'] ?? 80;

      // 🚨 WATER ALERT
      if (liquidDetected == "EMPTY") {
        if (now.difference(lastWaterAlert).inHours >= 8) {
          print("🚨 WATER ALERT");

          await sendEmail("⚠️ Water tank is empty!");

          lastWaterAlert = now;
        }
      }

      // 🌱 SOIL ALERT
      if (soilValue > threshold) {
        if (now.difference(lastSoilAlert).inHours >= 8) {
          print("🌱 SOIL ALERT");

          await sendEmail("🌱 Your plant is too dry!");

          lastSoilAlert = now;
        }
      }

    } catch (e) {
      setState(() {
        status = "Connection failed";
      });
    }
  }

    // 🌱 UI helpers
    String getEmoji(String profile) {
      if (profile == "Succulent") return "🌵";
      if (profile == "Tropical") return "🌿";
      if (profile == "Flowering") return "🌸";
      return "🪴";
    }

    String getStatus(int soil) {
      if (soil > 80) return "Needs Water";
      if (soil > 60) return "Okay";
      return "Healthy";
    }

    Color getColor(int soil) {
      if (soil > 80) return Colors.red.shade100;
      if (soil > 60) return Colors.orange.shade100;
      return Colors.green.shade100;
    }


    @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName ?? "").trim();
    final greetingName = name.isNotEmpty ? name : "there";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Row(
        children: [
          _buildSidebar(greetingName, user),

          Expanded(
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: SingleChildScrollView(
                    child: _buildMainContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildMyPlantsPage() {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text("Not logged in"),
      ),
    );
  }

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('plants')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Plant",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text("No plants added yet."),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddPlantPage(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Add Plant",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final plants = snapshot.data!.docs;

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Plant",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...plants.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.eco, color: Colors.green),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name'] ?? 'Unnamed Plant',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Species: ${data['species'] ?? '--'}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              "Location: ${data['location'] ?? '--'}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text("Profile: ${data['profile']}")
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlantSettingsPage(
                              plantId: doc.id,
                              name: data['name'] ?? '',
                              species: data['species'] ?? '',
                              location: data['location'] ?? '',
                              profile: data['profile'] ?? "Tropical", 
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.edit, size: 16, color: Colors.green),
                            SizedBox(width: 6),
                            Text(
                              "Edit",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

Widget _buildSidebar(greetingName, user) {
  return Container(
    width: 220,
    color: Colors.white,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Smart Plant",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7CB342),
          ),
        ),

        const SizedBox(height: 30),

        _menuItem(Icons.dashboard, "Dashboard", onTap: () {
          setState(() {
            selectedPage = "dashboard";
          });
        }),

        _menuItem(Icons.eco, "My Plant", onTap: () {
          setState(() {
            selectedPage = "plants";
          });
        }),

        _menuItem(Icons.smart_toy, "AI Plant Doctor", onTap: () {
          setState(() {
            selectedPage = "ai";
          });
        }),

        _menuItem(Icons.settings, "Settings", onTap: () {
          setState(() {
            selectedPage = "settings";
          });
        }),

        const Spacer(),

        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text("Logout"),
          onTap: _logout,
        ),
      ],
    ),
  );
}

Widget _menuItem(IconData icon, String title, {VoidCallback? onTap}) {
  return ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: onTap,
  );
}

Widget _buildTopBar() {
  return Container(
    padding: const EdgeInsets.all(16),
    color: Colors.white,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          selectedPage == "plants"
              ? "My Plant"
              : selectedPage == "analytics"
                  ? "Analytics"
                  : selectedPage == "settings"
                      ? "Settings"
                      : selectedPage == "ai"
                          ? "AI Plant Doctor"
                          : "Dashboard",
        ),

        selectedPage == "dashboard"
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Simple",
                  style: TextStyle(
                    fontWeight:
                        !isSimpleMode ? FontWeight.normal : FontWeight.bold,
                    color: !isSimpleMode ? Colors.grey : Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: !isSimpleMode,
                  onChanged: (value) {
                    setState(() {
                      isSimpleMode = !value;
                    });
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  "Detailed",
                  style: TextStyle(
                    fontWeight:
                        !isSimpleMode ? FontWeight.bold : FontWeight.normal,
                    color: !isSimpleMode ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            )
          : const SizedBox(),
      ],
    ),
  );
}

Widget _buildHeroSection() {
  return Container(
    margin: const EdgeInsets.all(20),
    height: 300,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      image: const DecorationImage(
        image: AssetImage("assets/dashboard.png"),
        fit: BoxFit.cover,
      ),
    ),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.45),
            Colors.black.withOpacity(0.35),
          ],
        ),
      ),

      // 👇 MAIN CONTENT
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 10),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🌱 PLANT INFO 
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('plants')
                    .limit(1)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox();
                  }

                  final plant =
                      snapshot.data!.docs.first.data() as Map<String, dynamic>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant['name'] ?? '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Type: ${plant['species'] ?? '--'}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "Preset: ${plant['profile'] ?? '--'}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              // 🌱 SENSOR CARDS
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _glassCard("$soilTension cb", "Soil"),
                  _glassCard("$light lx", "Light"),
                  _glassCard(liquidDetected, "Water"),
                ],
              ),

              const SizedBox(height: 20),

              // 💧 WATER BUTTON
              ElevatedButton.icon(
                onPressed: triggerPump,
                icon: const Icon(Icons.water_drop),
                label: const Text("Water Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _glassCard(String value, String label) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 🔥 blur effect
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15), // glass look
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔢 VALUE
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black54,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 🏷 LABEL
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildGridSection() {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _soilCard(),
        _lightCard(),
        _waterCard(),
      ],
    ),
  );
}

Widget _soilCard() {
  double current = soilHistory.last;

  double previous = soilHistory.length > 1
      ? soilHistory[soilHistory.length - 2]
      : current;

  double change = current - previous;

  String status;
  if (current > 80) {
    status = "Very Dry";
  } else if (current > 60) {
    status = "Dry";
  } else if (current >= 40) {
    status = "Optimal";
  } else {
    status = "Wet";
  }

  String trendText;
  if (change > 0) {
    trendText = "↑ Drying";
  } else if (change < 0) {
    trendText = "↓ Moistening";
  } else {
    trendText = "Stable";
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Soil Intelligence",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          "Moisture over time",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 140,
          child: Stack(
            children: [
              LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),

                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        soilHistory.length,
                        (i) => FlSpot(i.toDouble(), soilHistory[i]),
                      ),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,

                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          if (index == soilHistory.length - 1) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: Colors.green,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          }
                          return FlDotCirclePainter(
                            radius: 0,
                            color: Colors.transparent,
                          );
                        },
                      ),

                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.3),
                            Colors.green.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${current.toInt()} cb",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniStat("Current", "${current.toInt()} cb"),
            _miniStat("Trend", trendText),
            _miniStat("Status", status),
          ],
        ),
      ],
    ),
  );
}

Widget _waterCard() {
  double level;
  Color boxColor;
  Color iconBg;

  // normalize once (safety)
  String status = liquidDetected;

  // 👇 VISUAL SETTINGS
  if (status == "EMPTY") {
    level = 0.12;
    boxColor = const Color(0xFFFFE5E5);
    iconBg = const Color(0xFFFFCACA);
  } else if (status == "LOW") {
    level = 0.40;
    boxColor = const Color(0xFFFFF1D6);
    iconBg = const Color(0xFFFFE1A8);
  } else {
    level = 0.88;
    boxColor = const Color(0xFFD9ECFF);
    iconBg = const Color(0xFFB9DBFB);
  }

  // 👇 ACTION LOGIC (FIXED)
  String action;
  if (status == "FULL") {
    action = "None";
  } else if (status == "LOW") {
    action = "Refill";
  } else {
    action = "Refill Now";
  }

  // 👇 CLEAN LABEL (Full / Low / Empty)
  String label =
      status[0] + status.substring(1).toLowerCase();

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Water Level",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          "Tank monitoring",
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 20),

        // 🌊 WATER AREA
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: WaterWave(
                      color: const Color(0xFFA9D0F5),
                      level: level,
                    ),
                  ),
                ),

                // CENTER CONTENT
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          size: 28,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 📊 STATUS ROW
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniStat("Status", label),
            _miniStat("Action", action),
          ],
        ),
      ],
    ),
  );
}

Widget _lightCard() {
  final lightValue = int.tryParse(light) ?? 0;

  final double normalized =
    ((lightValue - 0) / (800 - 0)).clamp(0.0, 1.0);

  String lightStatus;
  if (lightValue == 0) {
    lightStatus = "No Data";
  } else if (lightValue < 300) {
    lightStatus = "Low Light";
  } else if (lightValue <= 800) {
    lightStatus = "Optimal";
  } else {
    lightStatus = "Too Bright";
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Light Intensity",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Real-time light monitoring",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF6E8A6),
                  Color(0xFFEED9A0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  lightValue == 0 ? "--" : "$lightValue lx",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),

                const SizedBox(height: 9),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    final fillWidth = barWidth * normalized;
                    final dotLeft =
                        (fillWidth - 7).clamp(0.0, barWidth - 14);

                    return SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            height: 10,
                            width: fillWidth,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Positioned(
                            left: dotLeft,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.deepOrange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                Text(
                  lightStatus,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniStat("Low", "30 lx"),
            _miniStat("Optimal", "300-800 lx"),
            _miniStat("Now", lightValue == 0 ? "--" : "$lightValue lx"),
          ],
        ),
      ],
    ),
  );
}

Widget _miniStat(String label, String value) {
  return Column(
    children: [
      Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ],
  );
}

Widget _buildMainContent() {
  if (selectedPage == "plants") {
    return _buildMyPlantsPage();
  }

  if (selectedPage == "ai") {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Not logged in"));
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plants')
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final plant =
            snapshot.data!.docs.first.data() as Map<String, dynamic>;

        return AIPage(
          soil: "30",
          light: "150",
          name: (plant['name'] ?? "--").toString(),
          type: (plant['species'] ?? "--").toString(),
          profile: (plant['profile'] ?? "--").toString(),
        );
      },
    );
  }

  if (selectedPage == "settings") {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Text("Settings page coming soon"),
    );
  }

  // default = dashboard
  return isSimpleMode
      ? _buildSimpleDashboard()
      : Column(
          children: [
            _buildHeroSection(),
            _buildGridSection(),
          ],
        );
}

Widget _buildSimpleDashboard() {

  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    return const Center(child: Text("Not logged in"));
  }

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('plants')
        .limit(1)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Text("No plant found"),
        );
      }

      final plant = snapshot.data!.docs.first.data() as Map<String, dynamic>;

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 🌱 PLANT CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.eco, color: Colors.green),
                  ),

                  const SizedBox(width: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant['name'] ?? 'Unnamed Plant',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Type: ${plant['species'] ?? '--'}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        "Preset: ${plant['profile'] ?? '--'}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 📊 SUMMARY CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Plant Summary",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _simpleStat("Light", light, Icons.wb_sunny),
                      _simpleStat("Soil", soilTension, Icons.grass),
                      _simpleStat("Water", liquidDetected, Icons.water_drop),
                    ],
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: triggerPump,
                        icon: const Icon(Icons.water_drop),
                        label: const Text("Water Now"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,        
                          foregroundColor: Colors.white,      
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _simpleStat(String label, String value, IconData icon) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.green),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    ],
  );
}

Widget _bullet(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 6, color: Colors.green),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

}

class WaterWave extends StatefulWidget {
  final Color color;
  final double level;

  const WaterWave({
    super.key,
    required this.color,
    required this.level,
  });

  @override
  State<WaterWave> createState() => _WaterWaveState();
}

class _WaterWaveState extends State<WaterWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return ClipPath(
          clipper: WaveClipper(_controller.value, widget.level),
          child: Container(
            color: widget.color,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class WaveClipper extends CustomClipper<Path> {
  final double value;
  final double level;

  WaveClipper(this.value, this.level);

  @override
  Path getClip(Size size) {
    final path = Path();
    const waveHeight = 10.0;
    final baseHeight = size.height * (1 - level);

    path.lineTo(0, baseHeight);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        baseHeight +
            waveHeight *
                Math.sin((i / size.width * 2 * Math.pi) + value * 2 * Math.pi),
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper oldClipper) => true;
}