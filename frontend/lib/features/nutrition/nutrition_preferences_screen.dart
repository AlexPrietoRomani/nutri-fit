import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'nutrition_provider.dart';

/// Pantalla "Preferencias de nutrición" (T18.2.2): el usuario edita sus
/// alergias, cosas que no le gustan, alimentos a evitar, los que quiere incluir
/// muy poco y sus restricciones (sin refrigerador / utensilios faltantes), como
/// si se lo contara a un nutricionista. El generador de comidas del chat las
/// respeta (las alergias como restricción DURA).
///
/// Carga con [NutritionProvider.fetchPreferences] y guarda con
/// [NutritionProvider.savePreferences]. [fetchOverride]/[saveOverride] son los
/// seams de test (mismo patrón que `ChatScreen.saveMealPlanOverride`, INC-015):
/// evitan instanciar un `SupabaseClient` real.
class NutritionPreferencesScreen extends StatefulWidget {
  const NutritionPreferencesScreen({
    super.key,
    this.fetchOverride,
    this.saveOverride,
    this.userIdOverride,
  });

  final Future<Map<String, dynamic>?> Function()? fetchOverride;
  final Future<void> Function(Map<String, dynamic>)? saveOverride;

  /// Solo para tests: evita que `savePreferences` resuelva el user_id contra
  /// `SupabaseConfig.client` (que no está inicializado en el entorno de test).
  final String? userIdOverride;

  @override
  State<NutritionPreferencesScreen> createState() => _NutritionPreferencesScreenState();
}

class _NutritionPreferencesScreenState extends State<NutritionPreferencesScreen> {
  final List<String> _allergies = [];
  final List<String> _dislikes = [];
  final List<String> _avoid = [];
  final List<String> _rarely = [];
  final List<String> _missingUtensils = [];
  bool _noFridge = false;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final prefs = await context
        .read<NutritionProvider>()
        .fetchPreferences(fetchOverride: widget.fetchOverride);
    List<String> asList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? [];
    if (!mounted) return;
    setState(() {
      if (prefs != null) {
        _allergies.addAll(asList(prefs['allergies']));
        _dislikes.addAll(asList(prefs['dislikes']));
        _avoid.addAll(asList(prefs['avoid']));
        _rarely.addAll(asList(prefs['rarely']));
        final constraints = (prefs['constraints'] as Map?) ?? const {};
        _noFridge = constraints['no_fridge'] == true;
        _missingUtensils.addAll(asList(constraints['missing_utensils']));
      }
      _loading = false;
    });
  }

  Map<String, dynamic> _buildPayload() => {
        'allergies': _allergies,
        'dislikes': _dislikes,
        'avoid': _avoid,
        'rarely': _rarely,
        'constraints': {
          'no_fridge': _noFridge,
          'missing_utensils': _missingUtensils,
        },
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    await context
        .read<NutritionProvider>()
        .savePreferences(_buildPayload(),
            saveOverride: widget.saveOverride, userId: widget.userIdOverride);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferencias guardadas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E201E),
        title: const Text(
          'Preferencias de nutrición',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ED573)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ChipEditor(
                  key: const Key('pref_allergies'),
                  title: 'Alergias',
                  hint: 'Ej. maní, mariscos',
                  subtitle: 'Nunca se incluirán en tus planes (restricción dura).',
                  items: _allergies,
                  onChanged: () => setState(() {}),
                ),
                _ChipEditor(
                  key: const Key('pref_dislikes'),
                  title: 'No me gustan',
                  hint: 'Ej. hígado',
                  items: _dislikes,
                  onChanged: () => setState(() {}),
                ),
                _ChipEditor(
                  key: const Key('pref_avoid'),
                  title: 'Evitar',
                  hint: 'Ej. frituras',
                  subtitle: 'Prefieres no comerlos (no es alergia).',
                  items: _avoid,
                  onChanged: () => setState(() {}),
                ),
                _ChipEditor(
                  key: const Key('pref_rarely'),
                  title: 'Incluir muy poco',
                  hint: 'Ej. azúcar',
                  items: _rarely,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Restricciones de cocina',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const Key('pref_no_fridge'),
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF2ED573),
                  title: const Text('No tengo refrigerador', style: TextStyle(color: Colors.white)),
                  value: _noFridge,
                  onChanged: (v) => setState(() => _noFridge = v),
                ),
                _ChipEditor(
                  key: const Key('pref_missing_utensils'),
                  title: 'Utensilios que me faltan',
                  hint: 'Ej. horno, licuadora',
                  items: _missingUtensils,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('pref_save_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ED573),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }
}

/// Editor de una lista de etiquetas (chips): input + botón añadir + borrar.
/// Muta [items] in-place y notifica con [onChanged] para que el padre repinte.
class _ChipEditor extends StatefulWidget {
  const _ChipEditor({
    super.key,
    required this.title,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String hint;
  final String? subtitle;
  final List<String> items;
  final VoidCallback onChanged;

  @override
  State<_ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<_ChipEditor> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final value = _ctrl.text.trim();
    if (value.isEmpty || widget.items.contains(value)) {
      _ctrl.clear();
      return;
    }
    widget.items.add(value);
    _ctrl.clear();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(widget.subtitle!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2E302E))),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF2ED573)),
                onPressed: _add,
              ),
            ],
          ),
          if (widget.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final item in widget.items)
                  Chip(
                    backgroundColor: const Color(0xFF1E201E),
                    side: const BorderSide(color: Color(0xFF2E302E)),
                    label: Text(item, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    deleteIconColor: Colors.grey,
                    onDeleted: () {
                      widget.items.remove(item);
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
