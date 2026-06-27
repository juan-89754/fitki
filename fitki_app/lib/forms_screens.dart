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
      if (mounted) Navigator.pop(context, true); // Devuelve true para recargar el dashboard
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
  const RegistrarMovimientoScreen({super.key, required this.cuentas});

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
    if (widget.cuentas.isNotEmpty) {
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
      if (mounted) Navigator.pop(context, result['data']);
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
                      onTap: () {
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
                        ),
                        child: Center(
                          child: Text(
                            'Gasto 💸',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _tipo == 'GASTO' ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
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
                        ),
                        child: Center(
                          child: Text(
                            'Ingreso 📈',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _tipo == 'INGRESO' ? const Color(0xFF3B4A4A) : AppColors.textPrimary,
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
                      child: Text("${cuenta['nombre_banco']} (\$${cuenta['saldo_actual']})"),
                    );
                  }).toList(),
                  onChanged: (val) {
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
