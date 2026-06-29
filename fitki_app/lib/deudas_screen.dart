import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme.dart';

class DeudasScreen extends StatefulWidget {
  const DeudasScreen({super.key});

  @override
  State<DeudasScreen> createState() => _DeudasScreenState();
}

class _DeudasScreenState extends State<DeudasScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _deudas = [];
  List<dynamic> _cuentas = [];

  @override
  void initState() {
    super.initState();
    _cargarDeudas();
  }

  Future<void> _cargarDeudas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getDeudas();
    final dashResult = await _apiService.getDashboard();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      setState(() {
        _deudas = result['data'] ?? [];
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Error al cargar las deudas.';
      });
    }

    if (dashResult['success']) {
      setState(() {
        _cuentas = dashResult['data']['cuentas'] ?? [];
      });
    }
  }

  void _abrirFormularioNuevaDeuda({Map<String, dynamic>? deudaParaEditar}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: NuevaDeudaFormModal(deuda: deudaParaEditar),
      ),
    ).then((val) {
      if (val == true) {
        _cargarDeudas();
      }
    });
  }

  void _abrirPagoDeuda(Map<String, dynamic> deuda) {
    if (_cuentas.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Text('Sin Cuentas', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Necesitas crear al menos una cuenta con saldo (ej. Bancolombia o Efectivo) para poder pagar tus cuotas.'),
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
        child: PagarDeudaFormModal(deuda: deuda, cuentas: _cuentas),
      ),
    ).then((val) {
      if (val == true) {
        _cargarDeudas();
      }
    });
  }

  void _abrirDetallesDeuda(Map<String, dynamic> deuda) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DetallesDeudaModal(deuda: deuda),
    );
  }

  void _confirmarEliminarDeuda(Map<String, dynamic> deuda) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('¿Eliminar obligación?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas eliminar la obligación "${deuda['nombre']}"? Los movimientos asociados seguirán registrados, pero la obligación desaparecerá.'),
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
              final res = await _apiService.deleteDeuda(deuda['id']);
              if (res['success']) {
                _cargarDeudas();
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
      backgroundColor: AppColors.bgDeudas,
      appBar: AppBar(
        title: const Text('Mis Obligaciones'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28, color: AppColors.textPrimary),
            tooltip: 'Nueva Obligación',
            onPressed: () => _abrirFormularioNuevaDeuda(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
          : RefreshIndicator(
              onRefresh: _cargarDeudas,
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
                      'Mis Deudas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Rastrea tus tarjetas y préstamos para evitar cobros de intereses.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _deudas.isEmpty
                        ? _buildPlaceholderCard()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _deudas.length,
                            itemBuilder: (context, index) {
                              final deuda = _deudas[index];
                              return _buildDeudaCard(deuda);
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDeudaCard(Map<String, dynamic> deuda) {
    final bool alerta = deuda['alerta_pago_proximo'] == true;
    final double total = double.tryParse(deuda['monto_total'].toString()) ?? 0.0;
    final double cuota = double.tryParse(deuda['cuota_mensual'].toString()) ?? 0.0;
    final String? limite = deuda['fecha_limite'];
    
    // Calcular días restantes de forma rápida
    String diasRestantesText = '';
    try {
      final vencimiento = DateTime.parse(deuda['fecha_proximo_pago']);
      final hoy = DateTime.now();
      final diff = vencimiento.difference(hoy).inDays + 1;
      if (diff == 0) {
        diasRestantesText = 'Vence hoy';
      } else if (diff == 1) {
        diasRestantesText = 'Vence mañana';
      } else if (diff > 1) {
        diasRestantesText = 'Vence en $diff días';
      } else {
        diasRestantesText = 'Vencida';
      }
    } catch (_) {}

    // Dinamismo cromático: Rosa Suave para alertas, Amarillo Mantequilla para normal
    final Color borderCol = alerta ? AppColors.borderDeudasAlerta : AppColors.borderDeudasNormal;
    final Color shadowCol = alerta ? AppColors.warning.withOpacity(0.25) : AppColors.accent.withOpacity(0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface, // Blanco Puro
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: shadowCol, // Sombra con brillo a juego (rosa o amarillo)
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
                    deuda['nombre'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    if (alerta)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface, // Blanco
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderDeudasAlerta, width: 1.0),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFC0392B)),
                            SizedBox(width: 4),
                            Text(
                              'Pago Próximo',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC0392B),
                                ),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (val) {
                        if (val == 'ver') {
                          _abrirDetallesDeuda(deuda);
                        } else if (val == 'editar') {
                          _abrirFormularioNuevaDeuda(deudaParaEditar: deuda);
                        } else if (val == 'eliminar') {
                          _confirmarEliminarDeuda(deuda);
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
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo Pendiente',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_formatMonto(total)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Cuota Mensual',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_formatMonto(cuota)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 24, thickness: 0.5, color: borderCol),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Interés: ${deuda['tasa_interes']}% mensual',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  diasRestantesText.isNotEmpty 
                      ? "$diasRestantesText (${deuda['fecha_proximo_pago']})" 
                      : "Próximo: ${deuda['fecha_proximo_pago']}",
                  style: TextStyle(
                    fontSize: 11, 
                    color: alerta ? const Color(0xFFC0392B) : AppColors.textSecondary,
                    fontWeight: alerta ? FontWeight.bold : FontWeight.normal
                  ),
                ),
              ],
            ),

            if (limite != null && limite.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Fecha Límite Final: $limite',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            Divider(height: 24, thickness: 0.5, color: borderCol),
            
            // BOTÓN PARA PAGAR CUOTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: total <= 0 ? null : () => _abrirPagoDeuda(deuda),
                icon: const Icon(Icons.payment_rounded, size: 18, color: AppColors.textPrimary),
                label: const Text('Pagar cuota', style: TextStyle(color: AppColors.textPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface, // Blanco para contraste premium
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: borderCol, width: 1.0),
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
                Icons.thumb_up_alt_rounded,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin deudas registradas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mantente libre de deudas. Si adquieres un préstamo o tarjeta, regístralo aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _abrirFormularioNuevaDeuda(),
                child: const Text('Agregar una tarjeta o crédito'),
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

// Modal interactivo de Detalles de Deuda (Simulación)
class DetallesDeudaModal extends StatelessWidget {
  final Map<String, dynamic> deuda;
  const DetallesDeudaModal({super.key, required this.deuda});

  @override
  Widget build(BuildContext context) {
    final double balance = double.tryParse(deuda['monto_total'].toString()) ?? 0.0;
    final double interesAcumulado = double.tryParse(deuda['total_intereses_estimado'].toString()) ?? 0.0;
    final double totalAPagar = double.tryParse(deuda['total_a_pagar_estimado'].toString()) ?? 0.0;
    final int cuotas = int.tryParse(deuda['cuotas_pendientes_estimadas'].toString()) ?? 0;

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
                'Plan de Amortización Estimado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deuda['nombre'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 20),

          if (cuotas == -1)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Atención: Tu cuota mensual no cubre los intereses del mes. La deuda crecerá de forma indefinida.',
                      style: TextStyle(color: Color(0xFFC0392B), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cuotas Restantes:', style: TextStyle(color: AppColors.textSecondary)),
                Text('$cuotas meses', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Abono a Capital (Sin Intereses):', style: TextStyle(color: AppColors.textSecondary)),
                Text('\$${_formatMonto(balance)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Abono a Intereses Acumulados:', style: TextStyle(color: AppColors.textSecondary)),
                Text('\$${_formatMonto(interesAcumulado)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC0392B))),
              ],
            ),
            const Divider(height: 24, thickness: 0.5, color: AppColors.background),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Proyectado a Pagar:', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                Text('\$${_formatMonto(totalAPagar)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
              ],
            ),
          ],
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

// Modal para pagar cuota de deuda
class PagarDeudaFormModal extends StatefulWidget {
  final Map<String, dynamic> deuda;
  final List<dynamic> cuentas;

  const PagarDeudaFormModal({super.key, required this.deuda, required this.cuentas});

  @override
  State<PagarDeudaFormModal> createState() => _PagarDeudaFormModalState();
}

class _PagarDeudaFormModalState extends State<PagarDeudaFormModal> {
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
    // Precargar con el monto de la cuota mensual
    _montoController.text = widget.deuda['cuota_mensual'].toString();
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  void _guardarPago() async {
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
      categoria: 'Deudas',
      descripcion: 'Pago a obligación: ${widget.deuda['nombre']}',
      deudaId: widget.deuda['id'], // Asociamos el ID de la deuda
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Error al registrar el pago.';
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
                    'Pagar "${widget.deuda['nombre']}"',
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
              '¿De qué cuenta debitar el dinero?',
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
              'Monto del Pago',
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
                
                // Validar que no pague más de lo que debe
                final saldoDeuda = double.tryParse(widget.deuda['monto_total'].toString()) ?? 0.0;
                if (val > saldoDeuda) {
                  return 'El monto no puede superar el saldo pendiente (\$${_formatMonto(saldoDeuda)}).';
                }

                // Validar saldo de cuenta de origen
                final cSelected = widget.cuentas.firstWhere((c) => c['id'] == _cuentaOrigenId);
                final saldoDisponible = double.tryParse(cSelected['saldo_actual'].toString()) ?? 0.0;
                if (val > saldoDisponible) {
                  return 'Saldo insuficiente en la cuenta seleccionada.';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _guardarPago,
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.textPrimary)
                    : const Text('Confirmar Pago'),
              ),
            ),
          ],
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

// Widget Modal para registrar o editar una deuda
class NuevaDeudaFormModal extends StatefulWidget {
  final Map<String, dynamic>? deuda;
  const NuevaDeudaFormModal({super.key, this.deuda});

  @override
  State<NuevaDeudaFormModal> createState() => _NuevaDeudaFormModalState();
}

class _NuevaDeudaFormModalState extends State<NuevaDeudaFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _nombreController = TextEditingController();
  final _montoController = TextEditingController();
  final _tasaController = TextEditingController();
  final _cuotaController = TextEditingController();
  DateTime? _fechaPago;
  DateTime? _fechaLimite;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.deuda != null) {
      _nombreController.text = widget.deuda!['nombre'];
      _montoController.text = widget.deuda!['monto_total'].toString();
      _tasaController.text = widget.deuda!['tasa_interes'].toString();
      _cuotaController.text = widget.deuda!['cuota_mensual'].toString();
      try {
        _fechaPago = DateTime.parse(widget.deuda!['fecha_proximo_pago']);
        if (widget.deuda!['fecha_limite'] != null) {
          _fechaLimite = DateTime.parse(widget.deuda!['fecha_limite']);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    _tasaController.dispose();
    _cuotaController.dispose();
    super.dispose();
  }

  void _seleccionarFechaPago() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPago ?? DateTime.now().add(const Duration(days: 15)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        _fechaPago = picked;
        if (_fechaLimite != null && _fechaLimite!.isBefore(_fechaPago!)) {
          _fechaLimite = null;
        }
      });
    }
  }

  void _seleccionarFechaLimite() async {
    if (_fechaPago == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Text('Definir Próximo Pago primero', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Para seleccionar la fecha límite del crédito, debes seleccionar primero la fecha de tu próximo pago.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido', style: TextStyle(color: AppColors.textPrimary)),
            )
          ],
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? _fechaPago!.add(const Duration(days: 30)),
      firstDate: _fechaPago!,
      lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
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

  void _guardarDeuda() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaPago == null) {
      setState(() {
        _errorMessage = 'Por favor selecciona la fecha de próximo pago.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final nombre = _nombreController.text.trim();
    final monto = double.tryParse(_montoController.text) ?? 0.0;
    final tasa = double.tryParse(_tasaController.text) ?? 0.0;
    final cuota = double.tryParse(_cuotaController.text) ?? 0.0;
    
    final fechaPagoStr = "${_fechaPago!.year}-${_fechaPago!.month.toString().padLeft(2, '0')}-${_fechaPago!.day.toString().padLeft(2, '0')}";
    
    String? fechaLimiteStr;
    if (_fechaLimite != null) {
      fechaLimiteStr = "${_fechaLimite!.year}-${_fechaLimite!.month.toString().padLeft(2, '0')}-${_fechaLimite!.day.toString().padLeft(2, '0')}";
    }

    Map<String, dynamic> result;
    if (widget.deuda != null) {
      result = await _apiService.updateDeuda(
        id: widget.deuda!['id'],
        nombre: nombre,
        montoTotal: monto,
        tasaInteres: tasa,
        cuotaMensual: cuota,
        fechaProximoPago: fechaPagoStr,
        fechaLimite: fechaLimiteStr,
      );
    } else {
      result = await _apiService.createDeuda(
        nombre: nombre,
        montoTotal: monto,
        tasaInteres: tasa,
        cuotaMensual: cuota,
        fechaProximoPago: fechaPagoStr,
        fechaLimite: fechaLimiteStr,
      );
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
                Text(widget.deuda != null ? '¡Obligación actualizada!' : '¡Obligación registrada con éxito!'),
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
        _errorMessage = result['message'] ?? 'Error al guardar la deuda.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.deuda != null;
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
                  esEdicion ? 'Editar Obligación' : 'Registrar Obligación',
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
              'Concepto / Nombre',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(hintText: 'Ej. Tarjeta Visa, Crédito Libre Inversión'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Ingresa el nombre de la obligación.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo Pendiente',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _montoController,
                        decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa el saldo.';
                          final val = double.tryParse(value);
                          if (val == null || val <= 0) return 'Monto inválido.';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cuota Mensual',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cuotaController,
                        decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa la cuota.';
                          final val = double.tryParse(value);
                          if (val == null || val <= 0) return 'Cuota inválida.';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tasa de Interés (% mensual)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tasaController,
                        decoration: const InputDecoration(hintText: 'Ej. 2.5'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa la tasa.';
                          final val = double.tryParse(value);
                          if (val == null || val < 0) return 'Tasa inválida.';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Próximo Pago',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _seleccionarFechaPago,
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
                              Expanded(
                                child: Text(
                                  _fechaPago == null 
                                      ? 'Seleccionar' 
                                      : "${_fechaPago!.day}/${_fechaPago!.month}",
                                  style: TextStyle(
                                    fontSize: 14, 
                                    color: _fechaPago == null ? AppColors.textSecondary : AppColors.textPrimary,
                                    fontWeight: _fechaPago == null ? FontWeight.normal : FontWeight.bold
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Fecha Límite Final (Opcional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _seleccionarFechaLimite,
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
                          ? 'Seleccionar Vencimiento Total' 
                          : "${_fechaLimite!.day}/${_fechaLimite!.month}/${_fechaLimite!.year}",
                      style: TextStyle(
                        fontSize: 14, 
                        color: _fechaLimite == null ? AppColors.textSecondary : AppColors.textPrimary,
                        fontWeight: _fechaLimite == null ? FontWeight.normal : FontWeight.bold
                      ),
                    ),
                    const Icon(Icons.event_available_rounded, color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _guardarDeuda,
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.textPrimary)
                    : Text(esEdicion ? 'Actualizar Obligación' : 'Registrar Obligación'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
