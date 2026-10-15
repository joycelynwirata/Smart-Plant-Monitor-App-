/// Shared care thresholds used by alerts and dashboard cards.
class PlantProfile {
  const PlantProfile({
    required this.dryThreshold,
    required this.minLight,
    required this.maxLight,
  });

  final int dryThreshold;
  final int minLight;
  final int maxLight;

  static const tropical = PlantProfile(
    dryThreshold: 80,
    minLight: 1000,
    maxLight: 2500,
  );
  static const succulent = PlantProfile(
    dryThreshold: 100,
    minLight: 5000,
    maxLight: 15000,
  );
  static const flowering = PlantProfile(
    dryThreshold: 90,
    minLight: 3000,
    maxLight: 10000,
  );

  static PlantProfile fromName(String name) => switch (name) {
    'Succulent' => succulent,
    'Flowering' => flowering,
    _ => tropical,
  };
}
