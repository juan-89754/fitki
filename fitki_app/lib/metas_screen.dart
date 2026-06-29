import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _metas = [];
  List<dynamic> _cuentas = [];

  @override
  void initState() {
    super.initState();
    _cargarMetas();
  }

  Future<void> _cargarMetas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getMetas();
    final dashResult = await _apiService.getDashboard();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      setState(() {
        _metas = result['data'] ?? [];
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Error al cargar las metas.';
      });
    }

    if (dashResult['success']) {
      setState(() {
        _cuentas = dashResult['data']['cuentas'] ?? [];
      });
    }
  }

  void _abrirFormularioNuevaMeta({Map<String, dynamic>? metaParaEditar}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: NuevaMetaFormModal(meta: metaParaEditar),
      ),
    ).then((val) {
      if (val == true) {
        _cargarMetas();
      }
    });
  }

  void _abrirAbonoMeta(Map<String, dynamic> meta) {
    if (_cuentas.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Text('Sin Cuentas', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Necesitas crear al menos una cuenta con saldo (ej. Bancolombia o Efectivo) para poder abonar dinero a tus metas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppColors.textPrimary)),
            )
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: AbonarMetaFormModal(meta: meta, cuentas: _cuentas),
      ),
    ).then((val) {
      if (val == true) {
        _cargarMetas();
      }
    });
  }

  void _abrirDetallesMeta(Map<String, dynamic> meta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DetallesMetaModal(meta: meta),
    );
  }

  void _confirmarEliminarMeta(Map<String, dynamic> meta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('¿Eliminar bolsillo?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas eliminar el bolsillo "${meta['nombre']}"? Los movimientos asociados seguirán registrados, pero el bolsillo desaparecerá.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              final res = await _apiService.deleteMeta(meta['id']);
              if (res['success']) {
                _cargarMetas();
              } else {
                setState(() {
                  _isLoading = false;
                  _errorMessage = res['message'] ?? 'Error al eliminar.';
                });
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMetas,
      appBar: AppBar(
        title: const Text('Bolsillos de Ahorro'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28, color: AppColors.textPrimary),
            tooltip: 'Nuevo Bolsillo',
            onPressed: () => _abrirFormularioNuevaMeta(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
          : RefreshIndicator(
              onRefresh: _cargarMetas,
              color: AppColors.secondary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFC0392B))),
                      ),

                    const Text(
                      'Mis Metas Activas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Separa tu dinero en bolsillos virtuales para alcanzar tus sueños.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _metas.isEmpty
                        ? _buildPlaceholderCard()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _metas.length,
                            itemBuilder: (context, index) {
                              final meta = _metas[index];
                              return _buildMetaCard(meta);
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetaCard(Map<String, dynamic> meta) {
    final double progreso = double.tryParse(meta['porcentaje_progreso'].toString()) ?? 0.0;
    final double objetivo = double.tryParse(meta['monto_objetivo'].toString()) ?? 0.0;
    final double ahorrado = double.tryParse(meta['monto_ahorrado_actual'].toString()) ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface, // Blanco Puro
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderMetas, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25), // Brillo verde menta
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    meta['nombre'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'ver') {
                      _abrirDetallesMeta(meta);
                    } else if (val == 'editar') {
                      _abrirFormularioNuevaMeta(metaParaEditar: meta);
                    } else if (val == 'eliminar') {
                      _confirmarEliminarMeta(meta);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'ver', child: Row(children: [Icon(Icons.query_stats_rounded, size: 18), SizedBox(width: 8), Text('Ver Detalles')])),
                    const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Editar')])),
                    const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFC0392B)), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Color(0xFFC0392B)))]))
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${_formatMonto(ahorrado)} ahorrados',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface, // Blanco Puro
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderMetas, width: 1.0),
                  ),
                  child: Text(
                    '${progreso.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Barra de Progreso Lineal
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso / 100.0,
                minHeight: 8,
                backgroundColor: AppColors.background, // Gris claro neutro
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary), // Azul Cielo para contraste
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Objetivo: \$${_formatMonto(objetivo)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Límite: ${meta['fecha_limite']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5, color: AppColors.borderMetas),
            
            // BOTÓN PARA ABONAR DINERO
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _abrirAbonoMeta(meta),
                icon: const Icon(Icons.add_card_rounded, size: 18, color: AppColors.textPrimary),
                label: const Text('Abonar a bolsillo', style: TextStyle(color: AppColors.textPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface, // Blanco para contraste premium
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.borderMetas, width: 1.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard() {
    return Card(
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.beach_access_rounded,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aún no tienes bolsillos creados',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Presiona el botón de abajo para empezar a separar tu dinero para viajes, fondos u otros.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _abrirFormularioNuevaMeta(),
                child: const Text('Crear mi primer bolsillo'),
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatMonto(double monto) {
    if (monto % 1 == 0) {
      return monto.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
    }
    return monto.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}

// Modal interactivo de Detalles de Meta
class DetallesMetaModal extends StatelessWidget {
  final Map<String, dynamic> meta;
  const DetallesMetaModal({super.key, required this.meta});

  @override
  Widget build(BuildContext context) {
    final double objetivo = double.tryParse(meta['monto_objetivo'].toString()) ?? 0.0;
    final double ahorrado = double.tryParse(meta['monto_ahorrado_actual'].toString()) ?? 0.0;
    final double faltante = objetivo - ahorrado;
    
    final double mesesEstimados = double.tryParse(meta['meses_restantes_estimados'].toString()) ?? -1.0;

    String mensajeProyeccion = '';
    if (ahorrado >= objetivo) {
      mensajeProyeccion = '¡Felicidades! Has completado esta meta.';
    } else if (mesesEstimados == -1.0) {
      mensajeProyeccion = 'Aún no has registrado abonos para estimar el tiempo de cumplimiento. ¡Haz tu primer aporte!';
    } else {
      final DateTime fechaProyectada = DateTime.now().add(Duration(days: (mesesEstimados * 30.4).toInt()));
      final List<String> meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
      mensajeProyeccion = 'Al ritmo de ahorro actual, completarás tu meta en aproximadamente $mesesEstimados meses (${meses[fechaProyectada.month - 1]} de ${fechaProyectada.year}).';
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detalle de Meta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            meta['nombre'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 20),

          // BALANCE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ahorrado:', style: TextStyle(color: AppColors.textSecondary)),
              Text('\$${_formatMonto(ahorrado)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Objetivo:', style: TextStyle(color: AppColors.textSecondary)),
              Text('\$${_formatMonto(objetivo)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Faltante:', style: TextStyle(color: AppColors.textSecondary)),
              Text('\$${_formatMonto(faltante < 0 ? 0.0 : faltante)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC0392B))),
            ],
          ),
          const Divider(height: 28, thickness: 0.5, color: AppColors.background),

          // PROYECCIÓN DE TIEMPO
          const Text(
            'Proyección de Tiempo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: Text(
              mensajeProyeccion,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatMonto(double monto) {
    if (monto % 1 == 0) {
      return monto.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
    }
    return monto.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}

// Modal para abonar a bolsillo
class AbonarMetaFormModal extends StatefulWidget {
  final Map<String, dynamic> meta;
  final List<dynamic> cuentas;

  const AbonarMetaFormModal({super.key, required this.meta, required this.cuentas});

  @override
  State<AbonarMetaFormModal> createState() => _AbonarMetaFormModalState();
}

class _AbonarMetaFormModalState extends State<AbonarMetaFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _montoController = TextEditingController();
  int? _cuentaOrigenId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.cuentas.isNotEmpty) {
      _cuentaOrigenId = widget.cuentas.first['id'];
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  void _guardarAbono() async {
    if (!_formKey.currentState!.validate() || _cuentaOrigenId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final monto = double.tryParse(_montoController.text) ?? 0.0;

    final result = await _apiService.createTransaccion(
      cuentaId: _cuentaOrigenId!,
      monto: monto,
      tipo: 'GASTO',
      categoria: 'Ahorro',
      descripcion: 'Aporte a bolsillo: ${widget.meta['nombre']}',
      metaId: widget.meta['id'],
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Error al registrar el abono.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Abonar a "${widget.meta['nombre']}"',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFC0392B))),
              ),
            
            const Text(
              '¿De qué cuenta sale el dinero?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _cuentaOrigenId,
              items: widget.cuentas.map<DropdownMenuItem<int>>((cuenta) {
                return DropdownMenuItem<int>(
                  value: cuenta['id'],
                  child: Text("${cuenta['nombre_banco']} (\$${cuenta['saldo_actual']})"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _cuentaOrigenId = val;
                });
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'Monto a Ahorrar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _montoController,
              decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa el monto.';
                final val = double.tryParse(value);
                if (val == null || val <= 0) return 'Monto inválido mayor a 0.';
                
                final cSelected = widget.cuentas.firstWhere((c) => c['id'] == _cuentaOrigenId);
                final saldoDisponible = double.tryParse(cSelected['saldo_actual'].toString()) ?? 0.0;
                if (val > saldoDisponible) {
                  return 'Saldo insuficiente en la cuenta.';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _guardarAbono,
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.textPrimary)
                    : const Text('Confirmar Ahorro'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget Modal para crear o editar una meta
class NuevaMetaFormModal extends StatefulWidget {
  final Map<String, dynamic>? meta;
  const NuevaMetaFormModal({super.key, this.meta});

  @override
  State<NuevaMetaFormModal> createState() => _NuevaMetaFormModalState();
}

class _NuevaMetaFormModalState extends State<NuevaMetaFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _nombreController = TextEditingController();
  final _objetivoController = TextEditingController();
  DateTime? _fechaLimite;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.meta != null) {
      _nombreController.text = widget.meta!['nombre'];
      _objetivoController.text = widget.meta!['monto_objetivo'].toString();
      try {
        _fechaLimite = DateTime.parse(widget.meta!['fecha_limite']);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _objetivoController.dispose();
    super.dispose();
  }

  void _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.secondary, 
              onPrimary: AppColors.textPrimary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _fechaLimite = picked;
      });
    }
  }

  void _guardarMeta() async {
    if (!_formKey.currentState!.validate()) return;
    final esEdicion = widget.meta != null;
    if (_fechaLimite == null) {
      setState(() {
        _errorMessage = 'Por favor selecciona una fecha límite.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final nombre = _nombreController.text.trim();
    final objetivo = double.tryParse(_objetivoController.text) ?? 0.0;
    final fechaStr = "${_fechaLimite!.year}-${_fechaLimite!.month.toString().padLeft(2, '0')}-${_fechaLimite!.day.toString().padLeft(2, '0')}";

    Map<String, dynamic> result;
    if (widget.meta != null) {
      result = await _apiService.updateMeta(widget.meta!['id'], nombre, objetivo, fechaStr);
    } else {
      result = await _apiService.createMeta(nombre, objetivo, fechaStr);
    }

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(esEdicion ? '¡Bolsillo de ahorro actualizado!' : '¡Bolsillo de ahorro creado con éxito!'),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Error al guardar la meta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.meta != null;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  esEdicion ? 'Editar Bolsillo' : 'Crear Bolsillo de Ahorro',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFC0392B))),
              ),
            
            const Text(
              'Nombre del Bolsillo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(hintText: 'Ej. Viaje a Europa, Fondo Emergencia'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Ingresa el nombre.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'Monto Objetivo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _objetivoController,
              decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa el objetivo.';
                final val = double.tryParse(value);
                if (val == null || val <= 0) return 'Ingresa un monto válido mayor a 0.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'Fecha Límite',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fechaLimite == null 
                          ? 'Seleccionar Fecha' 
                          : "${_fechaLimite!.day}/${_fechaLimite!.month}/${_fechaLimite!.year}",
                      style: TextStyle(
                        fontSize: 14, 
                        color: _fechaLimite == null ? AppColors.textSecondary : AppColors.textPrimary,
                        fontWeight: _fechaLimite == null ? FontWeight.normal : FontWeight.bold
                      ),
                    ),
                    const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _guardarMeta,
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.textPrimary)
                    : Text(esEdicion ? 'Actualizar Bolsillo' : 'Crear Bolsillo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
