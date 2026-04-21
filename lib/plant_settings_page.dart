import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlantSettingsPage extends StatefulWidget {
  final String plantId;
  final String name;
  final String species;
  final String location;
  final String profile;

  const PlantSettingsPage({
    super.key,
    required this.plantId,
    required this.name,
    required this.species,
    required this.location,
    required this.profile,
  });

  @override
  State<PlantSettingsPage> createState() => _PlantSettingsPageState();
}

class _PlantSettingsPageState extends State<PlantSettingsPage> {
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  String _location = "Indoor";
  String _profile = "Tropical";
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.name;
    _speciesController.text = widget.species;
    _location = widget.location.isNotEmpty ? widget.location : "Indoor";
    _profile = widget.profile.isNotEmpty ? widget.profile : "Tropical";

  }

  Future<void> _showDeleteDialog() async {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0), // 👈 FIX
        child: Center(
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete, color: Colors.red, size: 28),

                const SizedBox(height: 16),

                const Text(
                  "Delete Plant",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Are you sure you want to delete this plant? This action cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _delete();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text("Delete"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plants')
          .doc(widget.plantId)
          .update({
        'name': _nameController.text.trim(),
        'location': _location,
        'species': _speciesController.text.trim(), 
        'profile': _profile,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update plant")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('plants')
        .doc(widget.plantId)
        .delete();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),

      appBar: AppBar(
        title: const Text("Plant Settings"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),

      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),

              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // 🌱 HEADER
                    const Text(
                      "Edit Plant 🌿",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🌿 NAME
                    _inputField(
                      controller: _nameController,
                      label: "Plant Name",
                      icon: Icons.local_florist,
                    ),

                    const SizedBox(height: 14),

                    // 🌱 SPECIES
                    _inputField(
                      controller: _speciesController,
                      label: "Plant Type",
                      icon: Icons.eco_outlined,
                    ),

                    const SizedBox(height: 14),

                    // 📍 LOCATION
                    _dropdownField(
                      label: "Location",
                      icon: Icons.place_outlined,
                      value: _location,
                      items: const [
                        DropdownMenuItem(value: "Indoor", child: Text("Indoor")),
                        DropdownMenuItem(value: "Outdoor", child: Text("Outdoor")),
                      ],
                      onChanged: (val) => setState(() => _location = val!),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _profile,
                      decoration: InputDecoration(
                        labelText: "Plant Profile",
                        prefixIcon: const Icon(Icons.tune),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Succulent", child: Text("Succulent 🌵")),
                        DropdownMenuItem(value: "Tropical", child: Text("Tropical 🌿")),
                        DropdownMenuItem(value: "Flowering", child: Text("Flowering 🌸")),
                      ],
                      onChanged: (val) => setState(() => _profile = val!),
                    ),

                    const SizedBox(height: 24),

                    // 💾 SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🗑 DELETE BUTTON (better UX)
                    Center(
                      child: TextButton.icon(
                        onPressed: _showDeleteDialog,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          "Delete Plant",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdownField({
  required String label,
  required IconData icon,
  required String value,
  required List<DropdownMenuItem<String>> items,
  required Function(String?) onChanged,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    items: items,
    onChanged: onChanged,
  );
}

}