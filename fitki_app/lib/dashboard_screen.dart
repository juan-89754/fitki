import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme.dart';
import 'login_screen.dart';
import 'forms_screens.dart';
import 'metas_screen.dart';
import 'deudas_screen.dart';
import 'asistente_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Datos financieros compartidos
  double _patrimonioNeto = 0.0;
  List<dynamic> _cuentas = [];
  List<dynamic> _transacciones = [];
  List<dynamic> _deudas = [];

  bool _tieneAlertaDeudas = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getDashboard();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      final data = result['data'];
      setState(() {
        _patrimonioNeto = double.tryParse(data['patrimonio_neto'].toString()) ?? 0.0;
        _cuentas = data['cuentas'] ?? [];
        _transacciones = data['ultimas_transacciones'] ?? [];
        _deudas = data['deudas'] ?? [];

        // Comprobar si hay alguna deuda con alerta_pago_proximo activa
        _tieneAlertaDeudas = _deudas.any((deuda) => deuda['alerta_pago_proximo'] == true);
      });
    } else {
      if (result['unauthorized'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Error de conexión.';
        });
      }
    }
  }

  void _cerrarSesion() async {
    await _apiService.clearSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _mostrarSugerenciaAhorroModal(String sugerencia) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 28,
                    color: Color(0xFF3B4A4A),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sugerencia de Fitki',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sugerencia,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('¡Entendido!'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Vistas principales según pestaña
    final List<Widget> vistas = [
      _buildResumenDashboardView(),
      const MetasScreen(),
      const DeudasScreen(),
      const AsistenteScreen(),
    ];

    return Scaffold(
      extendBody: true, // Permite que el cuerpo se dibuje detrás de la barra flotante
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text('FITKI'),
              elevation: 0,
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                  tooltip: 'Cerrar sesión',
                  onPressed: _cerrarSesion,
                ),
              ],
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
          : vistas[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface, // Crema claro
              borderRadius: BorderRadius.circular(30), // Píldora
              border: Border.all(color: const Color(0xFFE0ECEC), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  if (index == 0) {
                    _cargarDatos();
                  }
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: AppColors.textPrimary,
                unselectedItemColor: AppColors.textSecondary,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_rounded),
                    label: 'Patrimonio',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.savings_rounded),
                    label: 'Metas',
                  ),
                  BottomNavigationBarItem(
                    icon: Badge(
                      isLabelVisible: _tieneAlertaDeudas,
                      backgroundColor: AppColors.warning,
                      child: const Icon(Icons.credit_card_rounded),
                    ),
                    label: 'Deudas',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.psychology_rounded),
                    label: 'Asistente',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Vista de la pestaña 0: Resumen Patrimonial consolidado
  Widget _buildResumenDashboardView() {
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: AppColors.secondary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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

            // TARJETA DE PATRIMONIO NETO
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patrimonio Neto',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_formatMonto(_patrimonioNeto)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_rounded, size: 14, color: Color(0xFF3B4A4A)),
                              SizedBox(width: 4),
                              Text(
                                'Centralizado',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B4A4A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Activos - Pasivos',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // SECCIÓN DE CUENTAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis Cuentas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final success = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AgregarCuentaScreen()),
                    );
                    if (success == true) _cargarDatos();
                  },
                  child: const Text(
                    '+ Agregar',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            _cuentas.isEmpty
                ? _buildPlaceholderCard(
                    'No tienes cuentas agregadas.',
                    'Agrega tu primer banco o billetera para registrar tus saldos.',
                    onTap: () async {
                      final success = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AgregarCuentaScreen()),
                      );
                      if (success == true) _cargarDatos();
                    },
                  )
                : SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cuentas.length,
                      itemBuilder: (context, index) {
                        final cuenta = _cuentas[index];
                        return _buildCuentaCard(cuenta);
                      },
                    ),
                  ),
            const SizedBox(height: 28),

            // SECCIÓN DE ÚLTIMOS MOVIMIENTOS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Últimos Movimientos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_cuentas.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      // Al registrar transacción recibimos la respuesta de la API (result es Map o null)
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegistrarMovimientoScreen(cuentas: _cuentas),
                        ),
                      );
                      
                      if (result != null) {
                        _cargarDatos();
                        // Si el movimiento contiene sugerencia de ahorro, mostrar modal
                        if (result is Map && result['sugerencia_ahorro'] != null) {
                          _mostrarSugerenciaAhorroModal(result['sugerencia_ahorro']);
                        }
                      }
                    },
                    child: const Text(
                      '+ Registrar',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            _transacciones.isEmpty
                ? _buildPlaceholderCard(
                    'No hay movimientos registrados.',
                    'Registra tu primer ingreso o gasto presionando el botón superior.',
                    onTap: _cuentas.isEmpty
                        ? null
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegistrarMovimientoScreen(cuentas: _cuentas),
                              ),
                            );
                            if (result != null) {
                              _cargarDatos();
                              if (result is Map && result['sugerencia_ahorro'] != null) {
                                _mostrarSugerenciaAhorroModal(result['sugerencia_ahorro']);
                              }
                            }
                          },
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _transacciones.length,
                    itemBuilder: (context, index) {
                      final tx = _transacciones[index];
                      return _buildTransaccionTile(tx);
                    },
                  ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCuentaCard(Map<String, dynamic> cuenta) {
    IconData icon = Icons.account_balance_rounded;
    if (cuenta['tipo_cuenta'] == 'EFECTIVO') icon = Icons.payments_rounded;
    if (cuenta['tipo_cuenta'] == 'CORRIENTE') icon = Icons.credit_card_rounded;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: AppColors.cardBackground,
        elevation: 0.2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cuenta['nombre_banco'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '\$${_formatMonto(double.tryParse(cuenta['saldo_actual'].toString()) ?? 0.0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransaccionTile(Map<String, dynamic> tx) {
    final bool isGasto = tx['tipo'] == 'GASTO';
    final Color colorMonto = isGasto ? AppColors.warning : AppColors.primary;
    final String prefijo = isGasto ? '- ' : '+ ';
    
    String fechaStr = '';
    try {
      final date = DateTime.parse(tx['fecha']);
      fechaStr = "${date.day}/${date.month} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      fechaStr = tx['fecha'];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: AppColors.cardBackground,
        elevation: 0.1,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGasto ? AppColors.warning.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGasto ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
              color: isGasto ? const Color(0xFFC0392B) : const Color(0xFF27AE60),
              size: 20,
            ),
          ),
          title: Text(
            tx['categoria'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
          subtitle: Text(
            "${tx['cuenta_nombre']} • $fechaStr",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorMonto.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$prefijo\$${_formatMonto(double.tryParse(tx['monto'].toString()) ?? 0.0)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isGasto ? const Color(0xFFC0392B) : const Color(0xFF27AE60),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(String titulo, String subtitulo, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        color: AppColors.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.inbox_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
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
