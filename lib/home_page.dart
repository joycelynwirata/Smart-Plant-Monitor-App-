import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_plant_page.dart';
import 'ai_page.dart';
import 'models/plant_profile.dart';
import 'plant_settings_page.dart';
import 'services/plant_alert_service.dart';
import 'services/plant_history_service.dart';
import 'services/realtime_sensor_service.dart';
import 'widgets/metric_stat.dart';
import 'widgets/plant_chat.dart';
import 'widgets/sensor_history_card.dart';
import 'widgets/water_wave.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedPage = "dashboard";
  String? _activePlantId;
  Map<String, dynamic>? _latestSensorData;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _plantSubscription;
  Future<void> _sensorWork = Future.value();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _plantsStream;

  double? lastSavedSoil;
  double? lastSavedLight;
  String? lastWaterState;
  String currentProfile = "Tropical";
  PlantProfile get _profile => PlantProfile.fromName(currentProfile);
  int get minLight => _profile.minLight;
  int get maxLight => _profile.maxLight;
  late final PlantHistoryService _historyService;
  final _alertService = PlantAlertService();

  StreamSubscription<Map<String, dynamic>?>? sensorSubscription;

  final sensorService = RealtimeSensorService();

  Timer? timer;

  bool isSimpleMode = true;
  bool isWatering = false;

  DateTime? lastWaterAlert;
  DateTime? lastSoilAlert;
  DateTime? lastMaintenanceAlert;
  DateTime? lastLightAlert;

  DateTime? lightBadSince;

  Future<void> _sendEmail(String message) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    await _alertService.sendEmail(email: email, message: message);
  }

  Future<void> triggerPump() async {
    if (isWatering) return;
    setState(() => isWatering = true);
    try {
      await sensorService.requestWatering();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start watering. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isWatering = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _historyService = PlantHistoryService(
      uid: FirebaseAuth.instance.currentUser!.uid,
    );
    _plantsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('plants')
        .snapshots();
    _plantSubscription = _plantsStream.listen(
      (snapshot) {
        if (!mounted) return;
        final plant = snapshot.docs.isEmpty ? null : snapshot.docs.first;
        final nextId = plant?.id;
        setState(() {
          if (_activePlantId != nextId) {
            lastSavedSoil = null;
            lastSavedLight = null;
            lastWaterState = null;
            lastSoilAlert = null;
            lastWaterAlert = null;
            lastMaintenanceAlert = DateTime.now();
            lastLightAlert = null;
            lightBadSince = null;
          }
          _activePlantId = nextId;
          currentProfile = plant?.data()['profile'] as String? ?? 'Tropical';
        });
        if (_latestSensorData != null) _queueSensorData(_latestSensorData);
      },
      onError: (Object error) =>
          debugPrint('Plant subscription failed: $error'),
    );

    sensorSubscription = sensorService.getSensorData().listen(
      (data) {
        _latestSensorData = data;
        _queueSensorData(data);
      },
      onError: (Object error) =>
          debugPrint('Sensor subscription failed: $error'),
    );
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_latestSensorData != null) _queueSensorData(_latestSensorData);
    });
  }

  void _queueSensorData(Map<String, dynamic>? data) {
    _sensorWork = _sensorWork
        .then((_) async {
          if (!mounted || FirebaseAuth.instance.currentUser == null) return;
          await _processSensorData(data);
        })
        .catchError((Object error) {
          debugPrint('Sensor processing failed: $error');
        });
  }

  Future<void> _processSensorData(Map<String, dynamic>? data) async {
    if (data == null) {
      debugPrint("Data is null");
      return;
    }

    final soil = (data['soilMoisture'] ?? 0).toDouble();
    final water = (data['waterLevel'] ?? 0);

    final light = (data['light'] ?? 0).toDouble();

    final plantId = _activePlantId;
    final profile = currentProfile;
    if (plantId == null) return;
    bool stillActive() =>
        mounted &&
        _activePlantId == plantId &&
        currentProfile == profile &&
        FirebaseAuth.instance.currentUser != null;

    if (lastSavedSoil == null || (soil - lastSavedSoil!).abs() > 1) {
      await _historyService.recordSoil(plantId, soil);
      if (!stillActive()) return;
      lastSavedSoil = soil;
    }
    if (lastSavedLight == null || (light - lastSavedLight!).abs() > 10) {
      await _historyService.recordLight(plantId, light);
      if (!stillActive()) return;
      lastSavedLight = light;
    }
    final waterState = water == 1 ? 'FULL' : 'EMPTY';
    if (lastWaterState != waterState) {
      await _historyService.recordWater(plantId, waterState);
      if (!stillActive()) return;
      lastWaterState = waterState;
    }
    if (!stillActive()) return;

    final dryThreshold = _profile.dryThreshold;
    bool badLight = light < minLight || light > maxLight;

    if (badLight) {
      lightBadSince ??= DateTime.now();
    } else {
      lightBadSince = null;
    }

    if (soil > dryThreshold &&
        (lastSoilAlert == null ||
            DateTime.now().difference(lastSoilAlert!).inHours >= 8)) {
      debugPrint("Sending dry soil email...");
      await _sendEmail("⚠️ Soil is dry");
      if (!stillActive()) return;

      lastSoilAlert = DateTime.now();
    }

    if (water == 0 &&
        (lastWaterAlert == null ||
            DateTime.now().difference(lastWaterAlert!).inHours >= 8)) {
      await _sendEmail("⚠️ Water reservoir is low. Please refill.");
      if (!stillActive()) return;
      lastWaterAlert = DateTime.now();
    }

    if (lastMaintenanceAlert != null &&
        DateTime.now().difference(lastMaintenanceAlert!).inHours >= 12) {
      await _sendEmail(
        "🌱 Maintenance Update:\n"
        "Soil: $soil cb\n"
        "Light: $light lx",
      );

      lastMaintenanceAlert = DateTime.now();
    }

    if (badLight &&
        lightBadSince != null &&
        DateTime.now().difference(lightBadSince!).inHours >= 2 &&
        (lastLightAlert == null ||
            DateTime.now().difference(lastLightAlert!).inHours >= 3)) {
      await _sendEmail(
        "☀️ Light outside ideal range for $profile plant.\n"
        "Current: ${light.toInt()} lx\n"
        "Target: $minLight-$maxLight lx",
      );

      lastLightAlert = DateTime.now();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    sensorSubscription?.cancel();
    _plantSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName ?? "").trim();
    final greetingName = name.isNotEmpty ? name : "there";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Stack(
        children: [
          Row(
            children: [
              _buildSidebar(greetingName, user),

              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 110),
                          child: _buildMainContent(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Positioned(
            right: 20,
            bottom: 20,
            child: PlantChat(
              sensorSummary: () =>
                  'My plant has soil moisture '
                  '${_latestSensorData?['soilMoisture'] ?? '--'} and light '
                  '${_latestSensorData?['light'] ?? '--'}. How is it doing?',
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
      stream: _plantsStream,
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text("No plant added yet."),
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
                            color: Colors.green.withValues(alpha: 0.25),
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                        color: Colors.black.withValues(alpha: 0.04),
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
                              color: Colors.green.withValues(alpha: 0.1),
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
                              Text("Profile: ${data['profile']}"),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
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

  Widget _buildSidebar(String greetingName, User? user) {
    return Container(
      width: 220,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset("assets/logo.png", height: 70, fit: BoxFit.contain),

          const SizedBox(height: 30),

          const SizedBox(height: 30),

          _menuItem(
            Icons.dashboard,
            "Dashboard",
            onTap: () {
              setState(() {
                selectedPage = "dashboard";
              });
            },
          ),

          _menuItem(
            Icons.eco,
            "My Plant",
            onTap: () {
              setState(() {
                selectedPage = "plants";
              });
            },
          ),

          _menuItem(
            Icons.smart_toy,
            "Plant Doctor",
            onTap: () {
              setState(() {
                selectedPage = "ai";
              });
            },
          ),

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Icon(icon, color: const Color(0xFF4CAF50), size: 28),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
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
                        fontWeight: !isSimpleMode
                            ? FontWeight.normal
                            : FontWeight.bold,
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
                        fontWeight: !isSimpleMode
                            ? FontWeight.bold
                            : FontWeight.normal,
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
              Colors.black.withValues(alpha: 0.45),
              Colors.black.withValues(alpha: 0.35),
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
                StreamBuilder<QuerySnapshot>(
                  stream: _plantsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox();
                    }

                    final plant =
                        snapshot.data!.docs.first.data()
                            as Map<String, dynamic>;

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
                StreamBuilder<Map<String, dynamic>?>(
                  stream: sensorService.getSensorData(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return Row(
                        children: [
                          _glassCard("--", "Soil"),
                          _glassCard("--", "Light"),
                          _glassCard("--", "Water"),
                        ],
                      );
                    }

                    final data = snapshot.data!;

                    final soil = (data['soilMoisture'] ?? 0).toDouble();

                    final lightVal = (data['light'] ?? 0).toDouble();
                    final water = data['waterLevel'];

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          child: _glassCard(
                            "${soil.toStringAsFixed(0)} cb",
                            "Soil",
                          ),
                        ),
                        const SizedBox(width: 16),

                        SizedBox(
                          width: 150,
                          child: _glassCard(
                            "${lightVal.toStringAsFixed(0)} lx",
                            lightVal < minLight
                                ? "Low Light"
                                : lightVal < maxLight
                                ? "Adequate Light"
                                : "Ideal Light",
                          ),
                        ),
                        const SizedBox(width: 16),

                        SizedBox(
                          width: 150,
                          child: _glassCard(
                            water == 1 ? "OK" : "EMPTY",
                            "Water",
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 💧 WATER BUTTON
                Center(
                  child: ElevatedButton.icon(
                    onPressed: isWatering ? null : triggerPump,
                    icon: const Icon(Icons.water_drop),
                    label: Text(isWatering ? "Watering..." : "Water Now"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
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
            color: Colors.white.withValues(alpha: 0.15), // glass look
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
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
                  color: Colors.white.withValues(alpha: 0.85),
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
          SensorHistoryCard(
            kind: SensorKind.soil,
            history: _activePlantId == null
                ? Stream.value([])
                : _historyService.watchSoil(_activePlantId!),
            profile: _profile,
            profileName: currentProfile,
          ),
          SensorHistoryCard(
            kind: SensorKind.light,
            history: _activePlantId == null
                ? Stream.value([])
                : _historyService.watchLight(_activePlantId!),
            profile: _profile,
            profileName: currentProfile,
          ),
          _waterCard(),
        ],
      ),
    );
  }

  Widget _waterCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _activePlantId == null) return _buildWaterUI('--', '--');

    return StreamBuilder<Map<String, dynamic>?>(
      stream: sensorService.getSensorData(),
      builder: (context, sensorSnapshot) {
        if (!sensorSnapshot.hasData || sensorSnapshot.data == null) {
          return _buildWaterUI("--", "--");
        }

        final water = sensorSnapshot.data!['waterLevel'] ?? 0;
        String status = water == 1 ? "FULL" : "EMPTY";

        return StreamBuilder<QuerySnapshot>(
          stream: _historyService.watchLatestWaterEvent(_activePlantId!),

          builder: (context, snapshot) {
            String timeAgo = "--";

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final doc = snapshot.data!.docs.first;
              final timestamp = doc['timestamp'] as Timestamp?;

              if (timestamp != null) {
                final diff = DateTime.now().difference(timestamp.toDate());

                if (diff.inMinutes < 60) {
                  timeAgo = "${diff.inMinutes} min ago";
                } else {
                  timeAgo = "${diff.inHours}h ${diff.inMinutes % 60}m ago";
                }
              }
            }

            return _buildWaterUI(status, timeAgo);
          },
        );
      },
    );
  }

  Widget _buildWaterUI(String status, String timeAgo) {
    double level;
    Color boxColor;

    if (status == "EMPTY") {
      level = 0.12;
      boxColor = const Color(0xFFFFE5E5);
    } else if (status == 'FULL') {
      level = 0.88;
      boxColor = const Color(0xFFD9ECFF);
    } else {
      level = 0;
      boxColor = const Color(0xFFEEEEEE);
    }

    String action = status == 'FULL'
        ? 'None'
        : status == 'EMPTY'
        ? 'Refill Now'
        : '--';

    String label = status == "--"
        ? "--"
        : status[0] + status.substring(1).toLowerCase();

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
          const Text("Tank monitoring", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

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
                  Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
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
              MetricStat("Status", label),
              MetricStat("Action", action),
              MetricStat("Last Change", timeAgo),
            ],
          ),
        ],
      ),
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

      return StreamBuilder<QuerySnapshot>(
        stream: _plantsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load your plant. Please try again.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Add a plant to get started.'));
          }

          final plant =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;

          return StreamBuilder<Map<String, dynamic>?>(
            stream: sensorService.getSensorData(),
            builder: (context, snapshot) {
              String soil = "--";
              String light = "--";

              if (snapshot.hasData && snapshot.data != null) {
                final data = snapshot.data!;
                soil = (data['soilMoisture'] ?? 0).toString();
                light = (data['light'] ?? 0).toString();
              }

              return AIPage(
                soil: soil,
                light: light,
                name: (plant['name'] ?? "--").toString(),
                type: (plant['species'] ?? "--").toString(),
                profile: (plant['profile'] ?? "--").toString(),
              );
            },
          );
        },
      );
    }

    // default = dashboard
    return StreamBuilder<QuerySnapshot>(
      stream: _plantsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load data. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco_outlined, size: 55, color: Colors.green),
                  SizedBox(height: 14),
                  Text(
                    "No Plant Added Yet",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Go to My Plant page to add your first plant.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return isSimpleMode
            ? _buildSimpleDashboard()
            : Column(children: [_buildHeroSection(), _buildGridSection()]);
      },
    );
  }

  Widget _buildSimpleDashboard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Not logged in"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _plantsStream,
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
                      color: Colors.black.withValues(alpha: 0.05),
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
                        color: Colors.green.withValues(alpha: 0.1),
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

                    StreamBuilder<Map<String, dynamic>?>(
                      stream: sensorService.getSensorData(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _simpleStat("Light", "--", Icons.wb_sunny),
                              _simpleStat("Soil", "--", Icons.grass),
                              _simpleStat("Water", "--", Icons.water_drop),
                            ],
                          );
                        }

                        final data = snapshot.data!;

                        final soil = (data['soilMoisture'] ?? 0).toDouble();
                        final lightVal = (data['light'] ?? 0).toDouble();
                        final water = (data['waterLevel'] ?? 0);

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _simpleStat(
                              "Light",
                              "${lightVal.toStringAsFixed(0)} lx",
                              Icons.wb_sunny,
                            ),
                            _simpleStat(
                              "Soil",
                              "${soil.toStringAsFixed(0)} cb",
                              Icons.grass,
                            ),
                            _simpleStat(
                              "Water",
                              water == 1 ? "FULL" : "EMPTY",
                              Icons.water_drop,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isWatering ? null : triggerPump,
                        icon: const Icon(Icons.water_drop),
                        label: Text(isWatering ? "Watering..." : "Water Now"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
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
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.green),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
