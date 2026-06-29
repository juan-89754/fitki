import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme.dart';

class AgregarCuentaScreen extends StatefulWidget {
  const AgregarCuentaScreen({super.key});

  @override
  State<AgregarCuentaScreen> createState() => _AgregarCuentaScreenState();
}

class _AgregarCuentaScreenState extends State<AgregarCuentaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _nombreBancoController = TextEditingController();
  final _saldoInicialController = TextEditingController();
  String _tipoCuenta = 'AHORRO';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nombreBancoController.dispose();
    _saldoInicialController.dispose();
    super.dispose();
  }

  void _guardarCuenta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final nombreBanco = _nombreBancoController.text.trim();
    final saldo = double.tryParse(_saldoInicialController.text) ?? 0.0;

    final result = await _apiService.createCuenta(nombreBanco, saldo, _tipoCuenta);

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('¡Cuenta creada con éxito!'),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Devuelve true para recargar el dashboard
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Error al guardar la cuenta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Cuenta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
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
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
                  ),
                ),

              const Text(
                'Nombre del Banco o Cuenta',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombreBancoController,
                decoration: const InputDecoration(hintText: 'Ej. Bancolombia, Nequi, Efectivo'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Ingresa el nombre del banco.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Saldo Inicial',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _saldoInicialController,
                decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa el saldo.';
                  if (double.tryParse(value) == null) return 'Ingresa un número válido.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Tipo de Cuenta',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _tipoCuenta,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'AHORRO', child: Text('Ahorros')),
                  DropdownMenuItem(value: 'CORRIENTE', child: Text('Corriente')),
                  DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _tipoCuenta = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarCuenta,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.textPrimary)
                      : const Text('Crear Cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class RegistrarMovimientoScreen extends StatefulWidget {
  final List<dynamic> cuentas;
  final int? preselectedCuentaId;
  final String? preselectedTipo;
  
  const RegistrarMovimientoScreen({
    super.key,
    required this.cuentas,
    this.preselectedCuentaId,
    this.preselectedTipo,
  });

  @override
  State<RegistrarMovimientoScreen> createState() => _RegistrarMovimientoScreenState();
}

class _RegistrarMovimientoScreenState extends State<RegistrarMovimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();
  
  String _tipo = 'GASTO'; // INGRESO o GASTO
  int? _cuentaSeleccionadaId;
  String _categoria = 'Comida';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _categoriasGastos = ['Comida', 'Transporte', 'Vivienda', 'Ocio', 'Servicios', 'Ahorro', 'Deudas', 'Otros'];
  final List<String> _categoriasIngresos = ['Salario', 'Freelance', 'Rendimientos', 'Otros'];

  @override
  void initState() {
    super.initState();
    _tipo = widget.preselectedTipo ?? 'GASTO';
    if (widget.preselectedCuentaId != null) {
      _cuentaSeleccionadaId = widget.preselectedCuentaId;
    } else if (widget.cuentas.isNotEmpty) {
      _cuentaSeleccionadaId = widget.cuentas.first['id'];
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _guardarMovimiento() async {
    if (_cuentaSeleccionadaId == null) {
      setState(() {
        _errorMessage = 'Por favor crea una cuenta primero.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final monto = double.tryParse(_montoController.text) ?? 0.0;
    final descripcion = _descripcionController.text.trim();

    final result = await _apiService.createTransaccion(
      cuentaId: _cuentaSeleccionadaId!,
      monto: monto,
      tipo: _tipo,
      categoria: _categoria,
      descripcion: descripcion,
    );

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
                Text('¡${_tipo == 'GASTO' ? 'Gasto' : 'Ingreso'} registrado con éxito!'),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, result['data']);
      }
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Error al guardar la transacción.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = _tipo == 'GASTO' ? _categoriasGastos : _categoriasIngresos;
    
    // Asegurar que la categoría seleccionada sea válida para la lista actual
    if (!categorias.contains(_categoria)) {
      _categoria = categorias.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Movimiento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
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
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
                  ),
                ),

              // Alternador de Gasto / Ingreso
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.preselectedTipo != null ? null : () {
                        setState(() {
                          _tipo = 'GASTO';
                          _categoria = _categoriasGastos.first;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _tipo == 'GASTO' ? AppColors.warning : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _tipo == 'GASTO' ? AppColors.warning : AppColors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Gasto 💸',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.preselectedTipo != null ? null : () {
                        setState(() {
                          _tipo = 'INGRESO';
                          _categoria = _categoriasIngresos.first;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _tipo == 'INGRESO' ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _tipo == 'INGRESO' ? AppColors.primary : AppColors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Ingreso 📈',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Monto del Movimiento',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _montoController,
                decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa el monto.';
                  final val = double.tryParse(value);
                  if (val == null) return 'Ingresa un número válido.';
                  if (val <= 0) return 'El monto debe ser mayor a cero.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Cuenta Originaria / Destinataria',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              if (widget.cuentas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No tienes cuentas creadas. Agrégala antes de registrar un movimiento.',
                    style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: _cuentaSeleccionadaId,
                  items: widget.cuentas.map<DropdownMenuItem<int>>((cuenta) {
                    return DropdownMenuItem<int>(
                      value: cuenta['id'],
                      child: Text("${cuenta['nombre_banco']} (\$${formatMonto(double.tryParse(cuenta['saldo_actual'].toString()) ?? 0.0)})"),
                    );
                  }).toList(),
                   onChanged: widget.preselectedCuentaId != null ? null : (val) {
                    setState(() {
                      _cuentaSeleccionadaId = val;
                    });
                  },
                ),
              const SizedBox(height: 20),

              const Text(
                'Categoría',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _categoria,
                items: categorias.map<DropdownMenuItem<String>>((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _categoria = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Descripción (Opcional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(hintText: 'Ej. Almuerzo, Salario Freelance, etc.'),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarMovimiento,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.textPrimary)
                      : const Text('Guardar Movimiento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class AgregarEditarProyectoScreen extends StatefulWidget {
  final Map<String, dynamic>? proyectoParaEditar;

  const AgregarEditarProyectoScreen({super.key, this.proyectoParaEditar});

  @override
  State<AgregarEditarProyectoScreen> createState() => _AgregarEditarProyectoScreenState();
}

class _AgregarEditarProyectoScreenState extends State<AgregarEditarProyectoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _notasController = TextEditingController();
  final _etiquetasController = TextEditingController();
  
  String _fechaEjecucion = '';
  String _prioridad = 'MEDIA';
  String _estado = 'PENDIENTE';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fechaEjecucion = DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);

    if (widget.proyectoParaEditar != null) {
      final p = widget.proyectoParaEditar!;
      _nombreController.text = p['nombre'] ?? '';
      _descripcionController.text = p['descripcion'] ?? '';
      _proveedorController.text = p['proveedor'] ?? '';
      _notasController.text = p['notas'] ?? '';
      _etiquetasController.text = p['etiquetas'] ?? '';
      _fechaEjecucion = p['fecha_ejecucion'] ?? _fechaEjecucion;
      _prioridad = p['prioridad'] ?? 'MEDIA';
      _estado = p['estado'] ?? 'PENDIENTE';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _proveedorController.dispose();
    _notasController.dispose();
    _etiquetasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_fechaEjecucion),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _fechaEjecucion = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  void _guardarProyecto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isEditing = widget.proyectoParaEditar != null;
    final Map<String, dynamic> res;

    if (isEditing) {
      res = await _apiService.updateProyectoCompra(
        widget.proyectoParaEditar!['id'],
        _nombreController.text.trim(),
        _descripcionController.text.trim(),
        _proveedorController.text.trim(),
        _fechaEjecucion,
        _prioridad,
        _estado,
        _notasController.text.trim(),
        _etiquetasController.text.trim(),
      );
    } else {
      res = await _apiService.createProyectoCompra(
        _nombreController.text.trim(),
        _descripcionController.text.trim(),
        _proveedorController.text.trim(),
        _fechaEjecucion,
        _prioridad,
        _estado,
        _notasController.text.trim(),
        _etiquetasController.text.trim(),
      );
    }

    if (res['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(isEditing ? '¡Proyecto actualizado!' : '¡Proyecto de compra creado!'),
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
        _errorMessage = res['message'] ?? 'Error al guardar el proyecto.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.proyectoParaEditar != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Proyecto' : 'Nuevo Proyecto de Compra'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
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
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
                  ),
                ),

              const Text('Nombre del Proyecto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(hintText: 'Ej. Remodelación de Cocina, Compra de Tecnología 2026'),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el nombre del proyecto.' : null,
              ),
              const SizedBox(height: 20),

              const Text('Descripción / Contexto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcionController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Ej. Cosas necesarias para el nuevo apartamento'),
              ),
              const SizedBox(height: 20),

              const Text('Proveedor / Establecimiento', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _proveedorController,
                decoration: const InputDecoration(hintText: 'Ej. Amazon, Homecenter, Éxito o Cotización #321'),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fecha de Ejecución', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _seleccionarFecha,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border, width: 1.0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_fechaEjecucion, style: const TextStyle(fontSize: 14)),
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prioridad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _prioridad,
                          items: const [
                            DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                            DropdownMenuItem(value: 'MEDIA', child: Text('Media')),
                            DropdownMenuItem(value: 'BAJA', child: Text('Baja')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _prioridad = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _estado,
                          items: const [
                            DropdownMenuItem(value: 'PENDIENTE', child: Text('Pendiente')),
                            DropdownMenuItem(value: 'COTIZADO', child: Text('Cotizado')),
                            DropdownMenuItem(value: 'COMPRADO', child: Text('Comprado')),
                            DropdownMenuItem(value: 'CANCELADO', child: Text('Cancelado')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _estado = val);
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
                        const Text('Etiquetas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _etiquetasController,
                          decoration: const InputDecoration(hintText: 'Ej. #Hogar #Oficina'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text('Notas del Proyecto (Área libre)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notasController,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Pega observaciones, cotizaciones detalladas, especificaciones, enlaces o notas libres aquí...',
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarProyecto,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.textPrimary)
                      : Text(isEditing ? 'Guardar Cambios' : 'Crear Proyecto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgregarEditarItemProyectoScreen extends StatefulWidget {
  final int proyectoId;
  final Map<String, dynamic>? itemParaEditar;

  const AgregarEditarItemProyectoScreen({super.key, required this.proyectoId, this.itemParaEditar});

  @override
  State<AgregarEditarItemProyectoScreen> createState() => _AgregarEditarItemProyectoScreenState();
}

class _AgregarEditarItemProyectoScreenState extends State<AgregarEditarItemProyectoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _articuloController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController();
  final _notaController = TextEditingController();
  
  String _prioridad = 'MEDIA';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.itemParaEditar != null) {
      final i = widget.itemParaEditar!;
      _articuloController.text = i['articulo'] ?? '';
      _cantidadController.text = (i['cantidad'] ?? 1).toString();
      _precioController.text = double.parse(i['precio_unitario'].toString()).toStringAsFixed(0);
      _notaController.text = i['nota'] ?? '';
      _prioridad = i['prioridad'] ?? 'MEDIA';
    }
  }

  @override
  void dispose() {
    _articuloController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  void _guardarItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isEditing = widget.itemParaEditar != null;
    final Map<String, dynamic> res;

    final String articulo = _articuloController.text.trim();
    final int cantidad = int.tryParse(_cantidadController.text) ?? 1;
    final double precio = double.tryParse(_precioController.text) ?? 0.0;
    final String nota = _notaController.text.trim();

    if (isEditing) {
      res = await _apiService.updateItemProyecto(
        widget.itemParaEditar!['id'],
        widget.proyectoId,
        articulo,
        cantidad,
        precio,
        _prioridad,
        nota,
      );
    } else {
      res = await _apiService.createItemProyecto(
        widget.proyectoId,
        articulo,
        cantidad,
        precio,
        _prioridad,
        nota,
      );
    }

    if (res['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(isEditing ? '¡Producto actualizado!' : '¡Producto agregado con éxito!'),
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
        _errorMessage = res['message'] ?? 'Error al guardar el producto.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemParaEditar != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Agregar Producto al Proyecto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
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
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
                  ),
                ),

              const Text('Nombre del Producto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _articuloController,
                decoration: const InputDecoration(hintText: 'Ej. Silla Gamer, Nevera, Escritorio'),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el nombre del producto.' : null,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cantidad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cantidadController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'Ej. 2'),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Ingresa cantidad.';
                            if (int.tryParse(val) == null || int.parse(val) <= 0) return 'Cantidad > 0.';
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
                        const Text('Precio Unitario', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _precioController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(hintText: 'Ej. 300000', prefixText: '\$ '),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Ingresa el precio.';
                            if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Precio > 0.';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prioridad del Producto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _prioridad,
                          items: const [
                            DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                            DropdownMenuItem(value: 'MEDIA', child: Text('Media')),
                            DropdownMenuItem(value: 'BAJA', child: Text('Baja')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _prioridad = val);
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
                        const Text('Notas del Producto (ej. link de compra, color, modelo)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notaController,
                          decoration: const InputDecoration(hintText: 'Ej. https://amazon.com/item o Color negro'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarItem,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: AppColors.textPrimary)
                      : Text(isEditing ? 'Guardar Cambios' : 'Agregar Producto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


