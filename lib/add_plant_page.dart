import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPlantPage extends StatefulWidget {
  const AddPlantPage({super.key});

  @override
  State<AddPlantPage> createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final _formKey = GlobalKey<FormState>();
  final _plantName = TextEditingController();
  final _species = TextEditingController();

  String _location = "Indoor";
  bool _loading = false;
  String _profile = "Tropical";

  @override
  void dispose() {
    _plantName.dispose();
    _species.dispose();
    super.dispose();
  }

  Future<void> _savePlant() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not logged in.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plants')
          .add({
        'name': _plantName.text.trim(),
        'species': _species.text.trim(),
        'location': _location,
        'profile': _profile,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));

      debugPrint("Saved plant doc: ${docRef.id}");

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint("SAVE PLANT ERROR: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
  }) {
    return TextFormField(
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
      validator: required
          ? (v) => (v ?? "").trim().isEmpty ? "Required" : null
          : null,
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


  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),

      appBar: AppBar(
        title: const Text("Add Plant"),
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

                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // 🌱 HEADER
                      const Text(
                        "Add New Plant 🌿",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🌿 PLANT NAME
                      _inputField(
                        controller: _plantName,
                        label: "Plant Name",
                        icon: Icons.local_florist,
                        required: true,
                      ),

                      const SizedBox(height: 14),

                      // 🌱 SPECIES
                      _inputField(
                        controller: _species,
                        label: "Plant Type",
                        icon: Icons.eco_outlined,
                        required: true,
                      ),

                      const SizedBox(height: 14),

                      // 🌿 PROFILE
                      _dropdownField(
                        label: "Plant Profile",
                        icon: Icons.tune,
                        value: _profile,
                        items: const [
                          DropdownMenuItem(value: "Succulent", child: Text("Succulent 🌵")),
                          DropdownMenuItem(value: "Tropical", child: Text("Tropical 🌿")),
                          DropdownMenuItem(value: "Flowering", child: Text("Flowering 🌸")),
                        ],
                        onChanged: (v) => setState(() => _profile = v!),
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
                        onChanged: (v) => setState(() => _location = v!),
                      ),

                      const SizedBox(height: 24),

                      // 💾 SAVE BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _savePlant,
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
                                  "Save Plant",
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }
}