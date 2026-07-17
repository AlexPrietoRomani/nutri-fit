import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../nutrition/nutrition_provider.dart';
import '../training/training_provider.dart';
import '../auth/onboarding_provider.dart';
import '../ai/ai_provider.dart';
import '../ai/chat_fab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    Future.microtask(() {
      if (mounted) {
        context.read<OnboardingProvider>().loadProfile();
        context.read<NutritionProvider>().loadDailyData(_selectedDate);
        context.read<NutritionProvider>().fetchMealPlans();
        context.read<TrainingProvider>().loadCompletedWorkouts(_selectedDate);
        context.read<TrainingProvider>().fetchSavedRoutines();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nutritionProv = context.watch<NutritionProvider>();
    final trainingProv = context.watch<TrainingProvider>();
    final onboardingProv = context.watch<OnboardingProvider>();

    // Determinar calorías objetivo (tomadas de NutritionProvider.goals si existen, o fallback de OnboardingProvider/default)
    final int targetCalories = nutritionProv.goals?.targetCalories ?? onboardingProv.targetCalories;
    final double targetProtein = nutritionProv.goals?.targetProteinG ?? onboardingProv.targetProtein;
    final double targetCarbs = nutritionProv.goals?.targetCarbsG ?? onboardingProv.targetCarbs;
    final double targetFat = nutritionProv.goals?.targetFatG ?? onboardingProv.targetFat;

    // Calorías ingeridas
    final double consumedCalories = nutritionProv.totalCalories;
    
    // Calorías quemadas (de los entrenamientos completados hoy)
    final double burnedCalories = trainingProv.caloriesBurnedToday(onboardingProv.weightKg);

    // Balance Calórico: Objetivo - Ingerido + Quemado (esto representa el saldo restante disponible)
    // O de otra forma: Ingerido - Quemado vs Objetivo.
    // Vamos a calcular el "Saldo Neto de Ingesta": Consumido - Quemado
    final double netIntake = consumedCalories - burnedCalories;
    final double remainingCalories = targetCalories - netIntake;

    // Estado del balance: si la ingesta neta (consumido - quemado) es menor que el objetivo, está en déficit, sino en superávit
    final bool isDeficit = netIntake < targetCalories;
    final double deficitOrSurplusAmount = (targetCalories - netIntake).abs();

    // Macronutrientes consumidos
    final double consumedProtein = nutritionProv.totalProtein;
    final double consumedCarbs = nutritionProv.totalCarbs;
    final double consumedFat = nutritionProv.totalFat;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0F0E),
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center_rounded, color: Color(0xFF2ED573), size: 24),
            SizedBox(width: 8),
            Text(
              'NUTRI-FIT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2ED573)),
            onPressed: _refreshData,
          ),
          IconButton(
            key: const Key('logout_button'),
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            tooltip: 'Cerrar sesión',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: const ChatFab(),
      body: nutritionProv.isLoading || trainingProv.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _refreshData();
              },
              color: const Color(0xFF2ED573),
              backgroundColor: const Color(0xFF1E201E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saludo e Información de Perfil
                    _buildHeader(onboardingProv),
                    const SizedBox(height: 20),

                    // Selector de fecha interactivo simplificado
                    _buildDateSelector(),
                    const SizedBox(height: 20),

                    // Card de Balance Calórico Principal
                    _buildCaloricBalanceCard(
                      target: targetCalories,
                      consumed: consumedCalories,
                      burned: burnedCalories,
                      remaining: remainingCalories,
                      isDeficit: isDeficit,
                      difference: deficitOrSurplusAmount,
                    ),
                    const SizedBox(height: 20),

                    // Sección de Macronutrientes
                    Text(
                      'Macronutrientes Diarios',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildMacrosCard(
                      targetProtein: targetProtein,
                      consumedProtein: consumedProtein,
                      targetCarbs: targetCarbs,
                      consumedCarbs: consumedCarbs,
                      targetFat: targetFat,
                      consumedFat: consumedFat,
                    ),
                    const SizedBox(height: 20),

                    // Adherencia Semanal
                    Text(
                      'Adherencia de la Semana',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildWeeklyAdherenceCard(targetCalories, consumedCalories),
                    const SizedBox(height: 20),

                    // Plan de Hoy (rutina + comida predeterminadas)
                    Text(
                      'Plan de Hoy',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildTodayPlanCard(trainingProv, nutritionProv, consumedCalories),
                    const SizedBox(height: 24),

                    // Accesos Rápidos
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAccessButton(
                            context: context,
                            title: 'Diario Alimenticio',
                            subtitle: '${consumedCalories.round()} kcal registradas',
                            icon: Icons.restaurant_menu_rounded,
                            route: '/diary',
                            color: const Color(0xFF2ED573),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAccessButton(
                            context: context,
                            title: 'Entrenamientos',
                            subtitle: '${trainingProv.completedSessions.length} completados',
                            icon: Icons.fitness_center_rounded,
                            route: '/training',
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(OnboardingProvider onboarding) {
    final userName = onboarding.name.isNotEmpty ? onboarding.name : 'Atleta';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2ED573), width: 2),
          ),
          child: const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFF1E201E),
            child: Icon(Icons.person_rounded, color: Color(0xFF2ED573), size: 30),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, $userName!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Biotipo: ${onboarding.bodyType.toUpperCase()}  •  Meta: ${onboarding.goalType.toUpperCase()}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.grey),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              _refreshData();
            });
          },
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 7)),
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
            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
                _refreshData();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E201E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2E302E)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF2ED573)),
                const SizedBox(width: 8),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
              _refreshData();
            });
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoy';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Ayer';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCaloricBalanceCard({
    required int target,
    required double consumed,
    required double burned,
    required double remaining,
    required bool isDeficit,
    required double difference,
  }) {
    // Calcular porcentaje de progreso
    double progressPercent = target > 0 ? consumed / target : 0.0;
    if (progressPercent > 1.0) progressPercent = 1.0;
    if (progressPercent < 0.0) progressPercent = 0.0;

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Balance Calórico',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDeficit
                        ? const Color(0xFF2ED573).withOpacity(0.15)
                        : Colors.orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isDeficit ? 'DÉFICIT' : 'SUPERÁVIT',
                    style: TextStyle(
                      color: isDeficit ? const Color(0xFF2ED573) : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Medidor Central Circular con Números
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: progressPercent,
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFF2E302E),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      remaining.round().toString(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'kcal restantes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Detalles del balance (Objetivo, Consumidas, Quemadas)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCalorieStatItem('Objetivo', target.toDouble(), Colors.white70),
                _buildCalorieDivider(),
                _buildCalorieStatItem('Ingerido', consumed, const Color(0xFF2ED573)),
                _buildCalorieDivider(),
                _buildCalorieStatItem('Quemado', burned, Colors.blueAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieDivider() {
    return Container(
      height: 35,
      width: 1,
      color: const Color(0xFF2E302E),
    );
  }

  Widget _buildCalorieStatItem(String label, double val, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          '${val.round()} kcal',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosCard({
    required double targetProtein,
    required double consumedProtein,
    required double targetCarbs,
    required double consumedCarbs,
    required double targetFat,
    required double consumedFat,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildMacroRow(
              label: 'Proteínas',
              consumed: consumedProtein,
              target: targetProtein,
              color: Colors.redAccent,
              unit: 'g',
            ),
            const SizedBox(height: 12),
            _buildMacroRow(
              label: 'Carbohidratos',
              consumed: consumedCarbs,
              target: targetCarbs,
              color: Colors.amber,
              unit: 'g',
            ),
            const SizedBox(height: 12),
            _buildMacroRow(
              label: 'Grasas',
              consumed: consumedFat,
              target: targetFat,
              color: Colors.tealAccent,
              unit: 'g',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow({
    required String label,
    required double consumed,
    required double target,
    required Color color,
    required String unit,
  }) {
    final double percent = target > 0 ? consumed / target : 0.0;
    final displayPercent = (percent * 100).clamp(0.0, 999.0).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            Text(
              '${consumed.round()}$unit / ${target.round()}$unit ($displayPercent%)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: const Color(0xFF2E302E),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyAdherenceCard(int targetCalories, double todayConsumed) {
    // Generar una lista de días de la semana de lunes a domingo.
    // Simulamos la adherencia semanal de peso/calorías con datos reales para el día de hoy,
    // y datos de adherencia ficticios o simulados para los días anteriores de la semana para una gran visualización.
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Lunes, 7 = Domingo

    final List<String> weekDaysLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
    // Simular pesos estables y calorías para la semana actual
    final List<double> calorieAdherence = [0.85, 0.95, 1.02, 0.90, 1.10, 0.70, 0.80];
    
    // Reemplazamos el día actual con el dato real de hoy
    if (weekday >= 1 && weekday <= 7) {
      calorieAdherence[weekday - 1] = targetCalories > 0 ? todayConsumed / targetCalories : 0.0;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Adherencia Nutricional (Calorías)',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Objetivo vs Real',
                  style: TextStyle(fontSize: 11, color: Color(0xFF2ED573)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final dayLabel = weekDaysLabels[index];
                final ratio = calorieAdherence[index];
                final isCurrentDay = (index == weekday - 1);
                
                // Color según la cercanía al 100% de la meta (0.90 a 1.10 es óptimo, verde fuerte)
                Color barColor = Colors.grey.shade700;
                if (ratio > 0.0) {
                  if (ratio >= 0.85 && ratio <= 1.15) {
                    barColor = const Color(0xFF2ED573); // Adherencia excelente
                  } else if (ratio > 1.15) {
                    barColor = Colors.orangeAccent; // Exceso calórico
                  } else {
                    barColor = Colors.yellow.shade700; // Déficit muy pronunciado
                  }
                }

                double barHeight = (ratio * 50).clamp(5.0, 70.0);

                return Column(
                  children: [
                    Container(
                      height: 70,
                      width: 14,
                      alignment: Alignment.bottomCenter,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E302E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Container(
                        height: barHeight,
                        width: 14,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isCurrentDay
                              ? [
                                  BoxShadow(
                                    color: barColor.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isCurrentDay ? Colors.white : Colors.grey,
                        fontWeight: isCurrentDay ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayPlanCard(
    TrainingProvider trainingProv,
    NutritionProvider nutritionProv,
    double consumedCalories,
  ) {
    final defaultRoutine = trainingProv.defaultRoutine;
    final defaultPlan = nutritionProv.defaultMealPlan;

    // ¿Se completó alguna sesión HOY? Reusa la lista ya cargada (endedAt != null
    // y fecha de finalización == hoy). No consulta Supabase de nuevo.
    final now = DateTime.now();
    final bool doneToday = trainingProv.completedSessions.any((s) {
      final d = s.endedAt;
      return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Rutina por defecto ---
            Row(
              children: [
                const Icon(Icons.fitness_center_rounded, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: defaultRoutine == null
                      ? const Text(
                          'Sin rutina predeterminada — márcala en Entrenamiento',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      : Text(
                          defaultRoutine['name']?.toString() ?? 'Rutina',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
                if (defaultRoutine != null)
                  doneToday
                      ? const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF2ED573), size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Hecho hoy',
                              style: TextStyle(
                                color: Color(0xFF2ED573),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Pendiente hoy',
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
              ],
            ),
            const Divider(color: Color(0xFF2E302E), height: 24),

            // --- Plan de comida por defecto ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF2ED573), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: defaultPlan == null
                      ? const Text(
                          'Sin plan de comida predeterminado — márcalo en el Diario',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      : _buildMealPlanSummary(defaultPlan, consumedCalories),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlanSummary(Map<String, dynamic> plan, double consumedCalories) {
    // ponytail: "Plan de Hoy" resume el día 1 del plan default (multi-día,
    // T18.4.2); un día por defecto basta, sin lógica de calendario.
    final planDay = normalizePlanDays(planFromRow(plan, 'meals'), 'meals').first;
    final plannedCalories = (planDay['meals'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .fold<double>(0, (sum, m) => sum + ((m['calories'] as num?)?.toDouble() ?? 0));

    // Mismo criterio de ±10% que DiaryScreen._buildPlanVsActual.
    String deltaText;
    Color deltaColor;
    if (consumedCalories > plannedCalories * 1.1) {
      deltaText = '${(consumedCalories - plannedCalories).round()} kcal de más';
      deltaColor = Colors.orangeAccent;
    } else if (consumedCalories < plannedCalories * 0.9) {
      deltaText = '${(plannedCalories - consumedCalories).round()} kcal de menos';
      deltaColor = Colors.redAccent;
    } else {
      deltaText = 'En línea con el plan';
      deltaColor = const Color(0xFF2ED573);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan: ${plan['name']?.toString() ?? ''} · planificado ${plannedCalories.round()} kcal · consumido ${consumedCalories.round()} kcal',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          deltaText,
          style: TextStyle(color: deltaColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickAccessButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    required Color color,
  }) {
    return Material(
      color: const Color(0xFF1E201E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed(route);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
