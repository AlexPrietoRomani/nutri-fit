import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'onboarding_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentPage = 0;
  final int _totalPages = 8;

  /// Diálogo para editar un valor numérico (altura/peso) con el teclado,
  /// complementando el slider. Devuelve el valor ya acotado a [min, max].
  Future<void> _editNumberDialog({
    required String title,
    required double current,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onSubmit,
  }) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(current == current.roundToDouble() ? 0 : 1));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E201E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D302D))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2ED573))),
          ),
          onSubmitted: (v) => Navigator.pop(context, double.tryParse(v.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text.replaceAll(',', '.'))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value != null) {
      onSubmit(value.clamp(min, max));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F0E), // Ultra dark premium background
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _totalPages,
                        backgroundColor: const Color(0xFF1E201E),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentPage + 1}/$_totalPages',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Form body (Carousel)
            Expanded(
              child: Consumer<OnboardingProvider>(
                builder: (context, provider, child) {
                  return PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // Control navigation via buttons
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildNameStep(provider),
                      _buildBirthDateStep(provider),
                      _buildGenderStep(provider),
                      _buildHeightStep(provider),
                      _buildWeightStep(provider),
                      _buildBodyTypeStep(provider),
                      _buildActivityStep(provider),
                      _buildCalculationStep(provider),
                    ],
                  );
                },
              ),
            ),
            // Bottom navigation buttons
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // --- Step Widgets ---

  // Slide 1: Name
  Widget _buildNameStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: '¿Cómo te llamas?',
      subtitle: 'Queremos personalizar tu experiencia en Nutri-Fit.',
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E201E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2D302D), width: 1.5),
          ),
          child: TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Tu nombre',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2ED573)),
              filled: true,
              fillColor: const Color(0xFF0E0F0E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF2ED573), width: 1.5),
              ),
            ),
            onChanged: (val) => provider.setName(val),
          ),
        ),
      ),
    );
  }

  // Slide 2: Birthdate
  Widget _buildBirthDateStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: '¿Cuál es tu fecha de nacimiento?',
      subtitle: 'Calcularemos tu edad exacta para estimar tu metabolismo basal.',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E201E).withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2D302D), width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cake_outlined, size: 60, color: Color(0xFF2ED573)),
                  const SizedBox(height: 16),
                  Text(
                    '${provider.birthDate.day}/${provider.birthDate.month}/${provider.birthDate.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ED573),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: provider.birthDate,
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF2ED573),
                                onPrimary: Colors.black,
                                surface: Color(0xFF1E201E),
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: const Color(0xFF0E0F0E),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (selected != null) {
                        provider.setBirthDate(selected);
                      }
                    },
                    child: const Text(
                      'Seleccionar Fecha',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 3: Gender
  Widget _buildGenderStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: '¿Cuál es tu sexo biológico?',
      subtitle: 'La fórmula Mifflin-St Jeor varía de acuerdo al sexo.',
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildGenderCard(
              title: 'Masculino',
              icon: Icons.male_rounded,
              value: 'M',
              selectedValue: provider.gender,
              onSelect: () => provider.setGender('M'),
            ),
            _buildGenderCard(
              title: 'Femenino',
              icon: Icons.female_rounded,
              value: 'F',
              selectedValue: provider.gender,
              onSelect: () => provider.setGender('F'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard({
    required String title,
    required IconData icon,
    required String value,
    required String selectedValue,
    required VoidCallback onSelect,
  }) {
    final isSelected = value == selectedValue;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        height: 160,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E201E) : const Color(0xFF1E201E).withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2ED573) : const Color(0xFF2D302D),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2ED573).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: isSelected ? const Color(0xFF2ED573) : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 4: Height
  Widget _buildHeightStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: '¿Cuánto mides?',
      subtitle: 'Desliza el control para definir tu altura en centímetros.',
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E201E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2D302D), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editNumberDialog(
                  title: 'Ingresa tu altura',
                  current: provider.heightCm,
                  min: 100,
                  max: 230,
                  unit: 'cm',
                  onSubmit: provider.setHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        provider.heightCm.round().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'cm',
                        style: TextStyle(color: Colors.grey, fontSize: 20),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF2ED573),
                  inactiveTrackColor: const Color(0xFF2D302D),
                  thumbColor: const Color(0xFF2ED573),
                  overlayColor: const Color(0xFF2ED573).withOpacity(0.2),
                  valueIndicatorColor: const Color(0xFF2ED573),
                  valueIndicatorTextStyle: const TextStyle(color: Colors.black),
                ),
                child: Slider(
                  value: provider.heightCm,
                  min: 100,
                  max: 230,
                  divisions: 130,
                  label: '${provider.heightCm.round()} cm',
                  onChanged: (val) => provider.setHeight(val),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 5: Weight
  Widget _buildWeightStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: '¿Cuál es tu peso actual?',
      subtitle: 'Úsalo como referencia de partida en kg.',
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E201E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2D302D), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editNumberDialog(
                  title: 'Ingresa tu peso',
                  current: provider.weightKg,
                  min: 30,
                  max: 200,
                  unit: 'kg',
                  onSubmit: provider.setWeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        provider.weightKg.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'kg',
                        style: TextStyle(color: Colors.grey, fontSize: 20),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF2ED573),
                  inactiveTrackColor: const Color(0xFF2D302D),
                  thumbColor: const Color(0xFF2ED573),
                  overlayColor: const Color(0xFF2ED573).withOpacity(0.2),
                  valueIndicatorColor: const Color(0xFF2ED573),
                  valueIndicatorTextStyle: const TextStyle(color: Colors.black),
                ),
                child: Slider(
                  value: provider.weightKg,
                  min: 30,
                  max: 200,
                  divisions: 340,
                  label: '${provider.weightKg.toStringAsFixed(1)} kg',
                  onChanged: (val) => provider.setWeight(val),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 6: Body type
  Widget _buildBodyTypeStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: 'Selecciona tu tipo de cuerpo',
      subtitle: 'Elige el biotipo corporal que mejor describa tu estructura.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildBodyTypeCard(
              title: 'Mesomorfo',
              dbValue: 'mesomorph',
              description: 'Atlético por naturaleza. Gana músculo y pierde grasa con facilidad.',
              selectedValue: provider.bodyType,
              onSelect: () => provider.setBodyType('mesomorph'),
            ),
            const SizedBox(height: 12),
            _buildBodyTypeCard(
              title: 'Ectomorfo',
              dbValue: 'ectomorph',
              description: 'Constitución delgada, extremidades largas. Metabolismo rápido.',
              selectedValue: provider.bodyType,
              onSelect: () => provider.setBodyType('ectomorph'),
            ),
            const SizedBox(height: 12),
            _buildBodyTypeCard(
              title: 'Endomorfo',
              dbValue: 'endomorph',
              description: 'Constitución robusta. Tiende a almacenar grasa fácilmente.',
              selectedValue: provider.bodyType,
              onSelect: () => provider.setBodyType('endomorph'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyTypeCard({
    required String title,
    required String dbValue,
    required String description,
    required String selectedValue,
    required VoidCallback onSelect,
  }) {
    final isSelected = dbValue == selectedValue;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E201E) : const Color(0xFF1E201E).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2ED573) : const Color(0xFF2D302D),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.accessibility_new_rounded,
              size: 32,
              color: isSelected ? const Color(0xFF2ED573) : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 7: Physical activity level (PAL)
  Widget _buildActivityStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: 'Nivel de actividad física',
      subtitle: '¿Cuánta energía gastas en tu día a día?',
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildActivityCard(
              title: 'Sedentario',
              pal: 1.2,
              description: 'Trabajo sedentario, poco o nada de ejercicio.',
              selectedValue: provider.palLevel,
              onSelect: () => provider.setPalLevel(1.2),
            ),
            const SizedBox(height: 10),
            _buildActivityCard(
              title: 'Ligero',
              pal: 1.375,
              description: 'Ejercicio ligero o deportes 1-3 días/semana.',
              selectedValue: provider.palLevel,
              onSelect: () => provider.setPalLevel(1.375),
            ),
            const SizedBox(height: 10),
            _buildActivityCard(
              title: 'Moderado',
              pal: 1.55,
              description: 'Ejercicio moderado o deportes 3-5 días/semana.',
              selectedValue: provider.palLevel,
              onSelect: () => provider.setPalLevel(1.55),
            ),
            const SizedBox(height: 10),
            _buildActivityCard(
              title: 'Activo',
              pal: 1.725,
              description: 'Ejercicio intenso o deportes 6-7 días/semana.',
              selectedValue: provider.palLevel,
              onSelect: () => provider.setPalLevel(1.725),
            ),
            const SizedBox(height: 10),
            _buildActivityCard(
              title: 'Muy Activo',
              pal: 1.9,
              description: 'Ejercicio muy duro, atleta o trabajo físico pesado.',
              selectedValue: provider.palLevel,
              onSelect: () => provider.setPalLevel(1.9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard({
    required String title,
    required double pal,
    required String description,
    required double selectedValue,
    required VoidCallback onSelect,
  }) {
    final isSelected = pal == selectedValue;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E201E) : const Color(0xFF1E201E).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2ED573) : const Color(0xFF2D302D),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.directions_run_rounded,
              size: 28,
              color: isSelected ? const Color(0xFF2ED573) : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'x$pal',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF2ED573) : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 8: Mifflin calculation & target goals
  Widget _buildCalculationStep(OnboardingProvider provider) {
    return _buildStepContainer(
      title: 'Tus Resultados Nutricionales',
      subtitle: 'Configura tu meta física y calcula tus necesidades energéticas.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            // IMC & TDEE Badges
            Row(
              children: [
                Expanded(
                  child: _buildBadgeCard(
                    title: 'BMR (TMB)',
                    value: '${provider.bmr.round()} kcal',
                    subtitle: 'Metabolismo Basal',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBadgeCard(
                    title: 'TDEE (GETD)',
                    value: '${provider.tdee.round()} kcal',
                    subtitle: 'Gasto Diario Estimado',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildBadgeCard(
                    title: 'Tu IMC (BMI)',
                    value: provider.bmi.toStringAsFixed(1),
                    subtitle: _getBmiCategory(provider.bmi),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Select Goal
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Define tu objetivo:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildGoalOption(
                    title: 'Déficit',
                    value: 'deficit',
                    selectedValue: provider.goalType,
                    onSelect: () => provider.setGoalType('deficit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildGoalOption(
                    title: 'Mantener',
                    value: 'maintenance',
                    selectedValue: provider.goalType,
                    onSelect: () => provider.setGoalType('maintenance'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildGoalOption(
                    title: 'Superávit',
                    value: 'surplus',
                    selectedValue: provider.goalType,
                    onSelect: () => provider.setGoalType('surplus'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Macro Targets Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E201E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D302D), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Presupuesto Diario',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${provider.targetCalories} kcal',
                        style: const TextStyle(
                          color: Color(0xFF2ED573),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF2D302D), height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroColumn('Proteína', '${provider.targetProtein.round()}g', Colors.redAccent),
                      _buildMacroColumn('Carbohidratos', '${provider.targetCarbs.round()}g', Colors.orangeAccent),
                      _buildMacroColumn('Grasas', '${provider.targetFat.round()}g', Colors.blueAccent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Bajo peso';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Sobrepeso';
    return 'Obesidad';
  }

  Widget _buildBadgeCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E201E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D302D), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF2ED573), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalOption({
    required String title,
    required String value,
    required String selectedValue,
    required VoidCallback onSelect,
  }) {
    final isSelected = value == selectedValue;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ED573) : const Color(0xFF1E201E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2ED573) : const Color(0xFF2D302D),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMacroColumn(String name, String value, Color color) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  // Common Layout Container for Carousel Steps
  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(child: child),
        ],
      ),
    );
  }

  // --- Navigation Controls ---

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Consumer<OnboardingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
              ),
            );
          }

          final isLastPage = _currentPage == _totalPages - 1;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              if (_currentPage > 0)
                TextButton(
                  onPressed: _previousPage,
                  child: const Text(
                    'Atrás',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              // Next / Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ED573),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                ),
                onPressed: () async {
                  if (_currentPage == 0 && provider.name.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, ingresa tu nombre.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  if (_currentPage == 6) {
                    // Trigger BMR and TDEE calculations when leaving activity slide to go to results slide
                    provider.calculateNutrition();
                    _nextPage();
                  } else if (isLastPage) {
                    // Save to database
                    final success = await provider.saveProfile(context);
                    if (success) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Perfil e Ingesta guardados correctamente!'),
                            backgroundColor: Color(0xFF2ED573),
                          ),
                        );
                        // Redirect to main home dashboard or pop back/reload main screen
                        Navigator.of(context).pushReplacementNamed('/dashboard');
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar datos: ${provider.errorMessage}'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  } else {
                    _nextPage();
                  }
                },
                child: Text(
                  isLastPage ? 'Registrar y Guardar Perfil' : 'Siguiente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
