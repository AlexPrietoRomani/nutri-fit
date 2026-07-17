import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'nutrition_provider.dart';
import 'nutrition_preferences_screen.dart';
import '../ai/ai_provider.dart';
import '../ai/vision_service.dart';
import '../ai/chat_fab.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NutritionProvider>().loadDailyData(_selectedDate);
      context.read<NutritionProvider>().fetchMealPlans();
    });
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    context.read<NutritionProvider>().loadDailyData(_selectedDate);
  }

  /// Captura/elige una foto de comida, la analiza con la IA y muestra un borrador.
  Future<void> _scanMeal() async {
    final XFile? img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (img == null || !mounted) return;

    final cfg = context.read<AiProvider>().config;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
      )),
    );
    try {
      final data = await VisionService().analyzeMeal(img, cfg);
      if (!mounted) return;
      Navigator.of(context).pop(); // cierra el loader
      await _showMealDraft(data);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo analizar la foto: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  /// Muestra el borrador detectado (editable el tipo de comida) y al confirmar
  /// lo inserta en nutrition.food_logs.
  Future<void> _showMealDraft(Map<String, dynamic> data, {String initialMealType = 'lunch'}) async {
    final items = (data['food_items'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final foodName = items.isNotEmpty ? items.join(', ') : (data['notes']?.toString() ?? 'Comida');
    final calories = (data['calories'] as num?)?.toDouble() ?? 0;
    final protein = (data['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (data['carbohydrates'] as num?)?.toDouble() ?? 0;
    final fat = (data['fat'] as num?)?.toDouble() ?? 0;
    String mealType = initialMealType;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1E201E),
          title: const Text('Borrador detectado', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(foodName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${calories.round()} kcal · P ${protein.round()}g · C ${carbs.round()}g · G ${fat.round()}g',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: mealType,
                dropdownColor: const Color(0xFF1E201E),
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Desayuno')),
                  DropdownMenuItem(value: 'lunch', child: Text('Almuerzo')),
                  DropdownMenuItem(value: 'dinner', child: Text('Cena')),
                  DropdownMenuItem(value: 'snack', child: Text('Snack')),
                ],
                onChanged: (v) => setSt(() => mealType = v ?? 'lunch'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final ok = await context.read<NutritionProvider>().addFoodLog(
                      foodName: foodName,
                      calories: calories,
                      proteinG: protein,
                      carbsG: carbs,
                      fatG: fat,
                      servingSizeG: 100,
                      mealType: mealType,
                      date: _selectedDate,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Comida añadida' : 'No se pudo guardar')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F0E),
      appBar: AppBar(
        title: const Text(
          'Diario Alimenticio',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF2ED573)),
            tooltip: 'Preferencias de nutrición',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NutritionPreferencesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.photo_camera_rounded, color: Color(0xFF2ED573)),
            tooltip: 'Tomar foto con IA',
            onPressed: _scanMeal,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF2ED573)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF2ED573),
                        onPrimary: Colors.black,
                        surface: Color(0xFF1E201E),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
                if (mounted) {
                  context.read<NutritionProvider>().loadDailyData(_selectedDate);
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: const ChatFab(),
      body: Consumer<NutritionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
              ),
            );
          }

          final goals = provider.goals;
          final targetCalories = goals?.targetCalories ?? 2000;
          final totalCalories = provider.totalCalories;
          final remainingCalories = targetCalories - totalCalories;

          return Column(
            children: [
              // Date Selector Header
              _buildDateSelector(),
              
              // Calorie Progress Card
              _buildCalorieCard(targetCalories, totalCalories, remainingCalories, provider),

              // Meal list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildMealSection(context, 'Desayuno', 'breakfast', provider.getMealsOfType('breakfast')),
                    const SizedBox(height: 16),
                    _buildMealSection(context, 'Almuerzo', 'lunch', provider.getMealsOfType('lunch')),
                    const SizedBox(height: 16),
                    _buildMealSection(context, 'Cena', 'dinner', provider.getMealsOfType('dinner')),
                    const SizedBox(height: 16),
                    _buildMealSection(context, 'Snacks', 'snack', provider.getMealsOfType('snack')),
                    const SizedBox(height: 24),
                    _buildMealPlansSection(context, provider),
                    const SizedBox(height: 80), // spacer at bottom
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    final today = DateTime.now();
    String dateStr;
    if (_selectedDate.year == today.year && _selectedDate.month == today.month && _selectedDate.day == today.day) {
      dateStr = 'Hoy';
    } else if (_selectedDate.year == today.year && _selectedDate.month == today.month && _selectedDate.day == today.day - 1) {
      dateStr = 'Ayer';
    } else if (_selectedDate.year == today.year && _selectedDate.month == today.month && _selectedDate.day == today.day + 1) {
      dateStr = 'Mañana';
    } else {
      dateStr = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFF1E201E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
            onPressed: () => _changeDate(-1),
          ),
          Text(
            dateStr,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(int target, double consumed, double remaining, NutritionProvider provider) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E201E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF2E302E)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calorías Restantes',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${remaining.round()} kcal',
                    style: TextStyle(
                      color: remaining >= 0 ? const Color(0xFF2ED573) : Colors.redAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 70,
                    width: 70,
                    child: CircularProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFF2E302E),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
                      strokeWidth: 8,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2E302E), height: 1),
          const SizedBox(height: 16),
          // Macro details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroProgress('Proteína', provider.totalProtein, provider.goals?.targetProteinG ?? 150, Colors.orangeAccent),
              _buildMacroProgress('Carbs', provider.totalCarbs, provider.goals?.targetCarbsG ?? 200, Colors.blueAccent),
              _buildMacroProgress('Grasas', provider.totalFat, provider.goals?.targetFatG ?? 65, Colors.pinkAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgress(String label, double current, double target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF2E302E),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${current.round()}/${target.round()}g',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Sección "Mis Planes de Comida" (T16.2.2), mismo patrón visual que "Mis
  /// Rutinas" de `workout_screen.dart`: `Card` + `InkWell` con una estrella
  /// para marcar/desmarcar el plan predeterminado.
  Widget _buildMealPlansSection(BuildContext context, NutritionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mis Planes de Comida',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        const SizedBox(height: 12),
        if (provider.mealPlans.isEmpty)
          const Text(
            'Aún no tienes planes guardados — pídele uno al chat.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.mealPlans.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final plan = provider.mealPlans[index];
              // Soporta planes multi-día (T18.4.2): cuenta las comidas del día 1.
              final days = normalizePlanDays(planFromRow(plan, 'meals'), 'meals');
              final mealCount = (days.first['meals'] as List? ?? const []).length;
              return Card(
                color: const Color(0xFF1E201E),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ED573).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: Color(0xFF2ED573),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$mealCount comidas',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: Key('set_default_meal_plan_${plan['id']}'),
                        tooltip: plan['is_default'] == true ? 'Plan predeterminado' : 'Marcar como predeterminado',
                        icon: Icon(
                          plan['is_default'] == true ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFF2ED573),
                        ),
                        onPressed: () => provider.setDefaultMealPlan(plan['id'] as String),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMealSection(BuildContext context, String title, String mealType, List<FoodLog> logs) {
    final sectionCalories = logs.fold<double>(0, (sum, item) => sum + item.calories);
    final planWidget = _buildPlanVsActual(context, mealType, sectionCalories, logs);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E201E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E302E)),
      ),
      // Material(transparency) evita que el ListTile interno del
      // ExpansionTile pinte su fondo/splash de tinta sobre este Container
      // decorado (advertencia del framework: "background color or ink
      // splashes may be invisible") sin alterar el look ya existente.
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
        initiallyExpanded: true,
        iconColor: const Color(0xFF2ED573),
        collapsedIconColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            Text(
              '${sectionCalories.round()} kcal',
              style: const TextStyle(color: Color(0xFF2ED573), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        children: [
          const Divider(color: Color(0xFF2E302E), height: 1),
          if (planWidget != null) planWidget,
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Text(
                'No hay alimentos registrados en esta comida.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(color: Color(0xFF2E302E), height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(log.foodName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    '${log.servingSizeG.round()}g  •  P: ${log.proteinG.round()}g  C: ${log.carbsG.round()}g  G: ${log.fatG.round()}g',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${log.calories.round()} kcal',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          if (log.id != null) {
                            context.read<NutritionProvider>().deleteFoodLog(log.id!);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          const Divider(color: Color(0xFF2E302E), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF2E302E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showAddFoodManualDialog(context, mealType),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Manual', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF2E302E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showFoodCatalogDialog(context, mealType),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Buscar en catálogo', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ED573),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showBarcodeScannerDialog(context, mealType),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Escanear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
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

  /// Compara lo planificado (plan default, si hay) contra lo realmente
  /// registrado (`logs`) para un `mealType` (T16.3.1). Devuelve `null` si no
  /// hay plan default o el plan no tiene nada para este tipo de comida —
  /// en ese caso `_buildMealSection` queda exactamente igual que antes.
  Widget? _buildPlanVsActual(BuildContext context, String mealType, double actualCalories, List<FoodLog> logs) {
    final defaultPlan = context.watch<NutritionProvider>().defaultMealPlan;
    if (defaultPlan == null) return null;

    // ponytail: compara contra el día 1 del plan default (multi-día, T18.4.2);
    // lógica de calendario por día queda fuera de alcance.
    final planDay = normalizePlanDays(planFromRow(defaultPlan, 'meals'), 'meals').first;
    final plannedItems = (planDay['meals'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((m) => m['meal_type'] == mealType)
        .toList();
    if (plannedItems.isEmpty) return null;

    final plannedCalories = plannedItems.fold<double>(0, (sum, m) => sum + (m['calories'] as num).toDouble());
    final plannedNames = plannedItems.map((m) => m['food_name'] as String).join(', ');

    String deltaText;
    Color deltaColor;
    if (logs.isEmpty) {
      deltaText = 'Aún no registrado';
      deltaColor = Colors.grey;
    } else if (actualCalories > plannedCalories * 1.1) {
      deltaText = '${(actualCalories - plannedCalories).round()} kcal de más';
      deltaColor = Colors.orangeAccent;
    } else if (actualCalories < plannedCalories * 0.9) {
      deltaText = '${(plannedCalories - actualCalories).round()} kcal de menos';
      deltaColor = Colors.redAccent;
    } else {
      deltaText = 'En línea con el plan';
      deltaColor = const Color(0xFF2ED573);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planificado: $plannedNames · ${plannedCalories.round()} kcal',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            deltaText,
            style: TextStyle(color: deltaColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showAddFoodManualDialog(BuildContext context, String mealType) {
    final formKey = GlobalKey<FormState>();
    String foodName = '';
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double servingSize = 100;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E201E),
          title: const Text('Agregar Alimento Manual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Nombre del alimento',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E302E))),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => foodName = v!,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Porción (g)',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E302E))),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    initialValue: '100',
                    validator: (v) => v == null || double.tryParse(v) == null ? 'Número válido' : null,
                    onSaved: (v) => servingSize = double.parse(v!),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Calorías (kcal)',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E302E))),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || double.tryParse(v) == null ? 'Número válido' : null,
                    onSaved: (v) => calories = double.parse(v!),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Prot (g)', labelStyle: TextStyle(color: Colors.grey)),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || double.tryParse(v) == null ? 'Número' : null,
                          onSaved: (v) => protein = double.parse(v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Carb (g)', labelStyle: TextStyle(color: Colors.grey)),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || double.tryParse(v) == null ? 'Número' : null,
                          onSaved: (v) => carbs = double.parse(v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Gras (g)', labelStyle: TextStyle(color: Colors.grey)),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || double.tryParse(v) == null ? 'Número' : null,
                          onSaved: (v) => fat = double.parse(v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.black),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final success = await context.read<NutritionProvider>().addFoodLog(
                    foodName: foodName,
                    calories: calories,
                    proteinG: protein,
                    carbsG: carbs,
                    fatG: fat,
                    servingSizeG: servingSize,
                    mealType: mealType,
                    date: _selectedDate,
                  );
                  if (success && mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showBarcodeScannerDialog(BuildContext context, String mealType) {
    final manualController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E201E),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2ED573)),
              SizedBox(width: 10),
              Text('Escanear Código de Barras', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apunta la cámara al código de barras del producto:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('scan_with_camera_btn'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.black),
                  onPressed: () async {
                    final code = await _openCameraScanner(context);
                    if (code != null && code.isNotEmpty && context.mounted) {
                      Navigator.pop(ctx);
                      _searchAndShowBarcodeResult(context, code, mealType);
                    }
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Escanear con cámara', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('O ingresa el código manualmente:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              TextField(
                key: const Key('manual_barcode_field'),
                controller: manualController,
                decoration: const InputDecoration(
                  hintText: 'Ej. 7501234567890',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E302E))),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              key: const Key('manual_barcode_search_btn'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.black),
              onPressed: () {
                final code = manualController.text.trim();
                if (code.isEmpty) return;
                Navigator.pop(ctx);
                _searchAndShowBarcodeResult(context, code, mealType);
              },
              child: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Diálogo "Buscar en catálogo" (T17.4.1): busca platos en
  /// `nutrition.food_catalog` y al tocar uno reutiliza el borrador existente
  /// (`_showMealDraft`) prellenado con sus macros para que el usuario confirme.
  void _showFoodCatalogDialog(BuildContext context, String mealType) {
    final controller = TextEditingController();
    final provider = context.read<NutritionProvider>();

    showDialog(
      context: context,
      builder: (ctx) {
        List<Map<String, dynamic>> results = [];
        bool loading = false;

        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> doSearch() async {
              setSt(() => loading = true);
              final r = await provider.searchFoodCatalog(controller.text);
              setSt(() {
                results = r;
                loading = false;
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E201E),
              title: const Text('Buscar en catálogo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('food_catalog_field'),
                            controller: controller,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Ej. Lomo Saltado',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E302E))),
                            ),
                            onSubmitted: (_) => doSearch(),
                          ),
                        ),
                        IconButton(
                          key: const Key('food_catalog_search_btn'),
                          icon: const Icon(Icons.search_rounded, color: Color(0xFF2ED573)),
                          onPressed: doSearch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573))),
                      )
                    else if (results.isEmpty)
                      const Text('Escribe y busca un plato.', style: TextStyle(color: Colors.grey, fontSize: 12))
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final dish = results[i];
                            final calories = (dish['calories'] as num?)?.toDouble() ?? 0;
                            return ListTile(
                              key: Key('food_catalog_item_$i'),
                              title: Text(dish['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                              trailing: Text('${calories.round()} kcal', style: const TextStyle(color: Color(0xFF2ED573), fontSize: 13, fontWeight: FontWeight.bold)),
                              onTap: () {
                                Navigator.pop(ctx);
                                final comp = dish['ingredients'];
                                if (comp is List && comp.isNotEmpty) {
                                  // Plato con composición (T18.8.3): abre la UI
                                  // editable de ingredientes.
                                  showDialog(
                                    context: context,
                                    builder: (_) => ChangeNotifierProvider<NutritionProvider>.value(
                                      value: provider,
                                      child: _ComposableDishDialog(
                                        dish: dish,
                                        mealType: mealType,
                                        date: _selectedDate,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _showMealDraft({
                                  'food_items': [dish['name']?.toString() ?? 'Comida'],
                                  'calories': calories,
                                  'protein': (dish['protein_g'] as num?)?.toDouble() ?? 0,
                                  'carbohydrates': (dish['carbs_g'] as num?)?.toDouble() ?? 0,
                                  'fat': (dish['fat_g'] as num?)?.toDouble() ?? 0,
                                }, initialMealType: mealType);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Abre una pantalla con [MobileScanner] real. Devuelve el primer código
  /// detectado, o `null` si el usuario cancela / no hay cámara disponible.
  Future<String?> _openCameraScanner(BuildContext context) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _BarcodeScannerPage(),
      ),
    );
  }

  void _searchAndShowBarcodeResult(BuildContext context, String barcode, String mealType) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573))),
      ),
    );

    final provider = context.read<NutritionProvider>();
    final result = await provider.searchBarcode(barcode);

    if (context.mounted) {
      Navigator.pop(context); // Close loading
    }

    if (result == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró información del producto en OpenFoodFacts.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Show details and ask to add
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) {
          final double calories = (result['calories'] as num).toDouble();
          final double protein = (result['protein_g'] as num).toDouble();
          final double carbs = (result['carbs_g'] as num).toDouble();
          final double fat = (result['fat_g'] as num).toDouble();
          final double servingSize = (result['serving_size_g'] as num).toDouble();
          final String name = result['food_name'] as String;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E201E),
            title: const Text('Producto Encontrado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Color(0xFF2ED573), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Código: $barcode', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                Text('Tamaño de porción: ${servingSize.round()}g', style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickMacro('Kcal', calories.round().toString(), Colors.white),
                    _buildQuickMacro('Prot', '${protein.round()}g', Colors.orangeAccent),
                    _buildQuickMacro('Carb', '${carbs.round()}g', Colors.blueAccent),
                    _buildQuickMacro('Gras', '${fat.round()}g', Colors.pinkAccent),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.black),
                onPressed: () async {
                  final success = await provider.addFoodLog(
                    foodName: name,
                    calories: calories,
                    proteinG: protein,
                    carbsG: carbs,
                    fatG: fat,
                    servingSizeG: servingSize,
                    mealType: mealType,
                    date: _selectedDate,
                  );
                  if (success && mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Añadir al Diario', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildQuickMacro(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

/// UI de plato componible (T18.8.3): al elegir un plato del catálogo con
/// composición (`ingredients`), muestra su lista de ingredientes editable —
/// cambiar gramos, quitar o agregar otro ingrediente — recalculando los macros
/// EN VIVO con [macrosFromIngredients]. Al confirmar registra con `addFoodLog`
/// usando los macros recalculados y el nombre del plato.
class _ComposableDishDialog extends StatefulWidget {
  const _ComposableDishDialog({
    required this.dish,
    required this.mealType,
    required this.date,
  });

  final Map<String, dynamic> dish;
  final String mealType;
  final DateTime date;

  @override
  State<_ComposableDishDialog> createState() => _ComposableDishDialogState();
}

class _ComposableDishDialogState extends State<_ComposableDishDialog> {
  // Composición editable: cada item {ingredient_id, grams}. Copias mutables.
  late final List<Map<String, dynamic>> _items;
  Map<int, Map<String, dynamic>> _ingredientsById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _items = (widget.dish['ingredients'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    final ids = _items
        .map((e) => (e['ingredient_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet()
        .toList();
    final rows = await context.read<NutritionProvider>().fetchIngredientsByIds(ids);
    if (!mounted) return;
    setState(() {
      _ingredientsById = {
        for (final r in rows) (r['id'] as num).toInt(): r,
      };
      _loading = false;
    });
  }

  Future<void> _addIngredient() async {
    final provider = context.read<NutritionProvider>();
    final controller = TextEditingController();
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        List<Map<String, dynamic>> results = [];
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> doSearch() async {
              setSt(() => loading = true);
              final r = await provider.searchIngredients(controller.text);
              setSt(() {
                results = r;
                loading = false;
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E201E),
              title: const Text('Agregar ingrediente', style: TextStyle(color: Colors.white, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('ingredient_search_field'),
                            controller: controller,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Ej. Arroz',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E302E))),
                            ),
                            onSubmitted: (_) => doSearch(),
                          ),
                        ),
                        IconButton(
                          key: const Key('ingredient_search_btn'),
                          icon: const Icon(Icons.search_rounded, color: Color(0xFF2ED573)),
                          onPressed: doSearch,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573))),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final ing = results[i];
                            return ListTile(
                              key: Key('ingredient_result_$i'),
                              title: Text(ing['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                              onTap: () => Navigator.pop(ctx, ing),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: Colors.grey))),
              ],
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    final id = (picked['id'] as num).toInt();
    setState(() {
      _ingredientsById = {..._ingredientsById, id: picked};
      _items.add({'ingredient_id': id, 'grams': 100});
    });
  }

  @override
  Widget build(BuildContext context) {
    final macros = macrosFromIngredients(_items, _ingredientsById);
    final dishName = widget.dish['name']?.toString() ?? 'Plato';

    return AlertDialog(
      backgroundColor: const Color(0xFF1E201E),
      title: Text(dishName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      content: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573))),
            )
          : SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key: const Key('composable_macros'),
                    '${macros['calories']!.round()} kcal · P ${macros['protein_g']!.round()}g · C ${macros['carbs_g']!.round()}g · G ${macros['fat_g']!.round()}g',
                    style: const TextStyle(color: Color(0xFF2ED573), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final id = (item['ingredient_id'] as num?)?.toInt();
                        final ing = id == null ? null : _ingredientsById[id];
                        final name = ing?['name']?.toString() ?? 'Ingrediente $id';
                        return Padding(
                          key: Key('composable_ingredient_$i'),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13))),
                              SizedBox(
                                width: 64,
                                child: TextFormField(
                                  key: Key('composable_grams_$i'),
                                  initialValue: '${(item['grams'] as num?)?.round() ?? 0}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  textAlign: TextAlign.end,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    suffixText: 'g',
                                    suffixStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  onChanged: (v) => setState(() => item['grams'] = double.tryParse(v) ?? 0),
                                ),
                              ),
                              IconButton(
                                key: Key('composable_remove_$i'),
                                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                                onPressed: () => setState(() => _items.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('composable_add_ingredient'),
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add, size: 18, color: Color(0xFF2ED573)),
                    label: const Text('Agregar ingrediente', style: TextStyle(color: Color(0xFF2ED573), fontSize: 13)),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        FilledButton(
          key: const Key('composable_save'),
          onPressed: () async {
            final ok = await context.read<NutritionProvider>().addFoodLog(
                  foodName: dishName,
                  calories: macros['calories']!,
                  proteinG: macros['protein_g']!,
                  carbsG: macros['carbs_g']!,
                  fatG: macros['fat_g']!,
                  servingSizeG: _items.fold<double>(0, (s, e) => s + ((e['grams'] as num?)?.toDouble() ?? 0)),
                  mealType: widget.mealType,
                  date: widget.date,
                );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Comida añadida' : 'No se pudo guardar')),
              );
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Pantalla de escaneo con cámara real ([MobileScanner]). Al detectar el
/// primer código de barras hace `pop` devolviendo su `rawValue`. Si la cámara
/// no está disponible o el permiso fue denegado, muestra un mensaje amable
/// invitando a usar la entrada manual (mobile_scanner lanza via onDetectError).
class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E201E),
        title: const Text('Escanear con cámara', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        // Errores de decodificación por frame: se ignoran (no rompen la UI).
        onDetectError: (error, stack) {},
        // Cámara no disponible / permiso denegado: mensaje amable en vez de crash.
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_rounded, color: Colors.grey, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo acceder a la cámara.\nUsa la entrada manual de código.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
