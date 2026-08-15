/// The Specification types the Specification Editor supports (Work
/// Package 010 STUDIO-TASK-000024).
enum SpecificationType {
  torque('Torque'),
  voltage('Voltage'),
  resistance('Resistance'),
  pressure('Pressure'),
  temperature('Temperature'),
  clearance('Clearance'),
  measurement('Measurement');

  const SpecificationType(this.label);

  final String label;
}
