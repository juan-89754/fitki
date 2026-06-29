import 'package:flutter/material.dart';
import 'api_service.dart';
import 'theme.dart';
import 'login_screen.dart';
import 'forms_screens.dart';
import 'metas_screen.dart';
import 'deudas_screen.dart';
import 'package:fitki_app/asistente_screen.dart';
import 'compras_plan_screen.dart';

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
  double _totalCuentas = 0.0;
  double _totalDeudas = 0.0;
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

        // Calcular Patrimonio Neto (suma de cuentas)
        double sumaCuentas = 0.0;
        for (var c in _cuentas) {
          sumaCuentas += double.tryParse(c['saldo_actual'].toString()) ?? 0.0;
        }
        _totalCuentas = sumaCuentas;

        // Calcular Dinero por Pagar (suma de deudas)
        double sumaDeudas = 0.0;
        for (var d in _deudas) {
          sumaDeudas += double.tryParse(d['monto_total'].toString()) ?? 0.0;
        }
        _totalDeudas = sumaDeudas;

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

  void _verPerfilYPresupuestos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.25,
          maxChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface, // Blanco Puro
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24.0),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.person_rounded, size: 28, color: AppColors.secondary),
                      SizedBox(width: 12),
                      Text(
                        'Mi Perfil',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgDashboard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDashboard),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre: Usuario Fitki',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Email: usuario@fitki.com',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
      const ComprasPlanScreen(),
      const AsistenteScreen(),
    ];

    return Scaffold(
      extendBody: true, // Permite que el cuerpo se dibuje detrás de la barra flotante
      backgroundColor: AppColors.bgDashboard,
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text('FITKI'),
              elevation: 0,
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
                  tooltip: 'Mi Perfil',
                  onPressed: _verPerfilYPresupuestos,
                ),
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
              color: AppColors.surface, // Blanco
              borderRadius: BorderRadius.circular(24), // Elegante píldora redondeada
              border: Border.all(color: AppColors.borderDashboard, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x060F172A),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
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
                    icon: Icon(Icons.request_quote_rounded),
                    label: 'Cotización',
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

            // DOS ETIQUETAS INICIALES (PATRIMONIO NETO Y DINERO POR PAGAR)
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.borderDashboard, width: 1.0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.skyBlue,
                            AppColors.mintTeal,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.skyBlue.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Patrimonio Neto',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$${_formatMonto(_totalCuentas)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.borderDeudasAlerta, width: 1.0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.blushPink,
                            AppColors.rosePink,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.rosePink.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dinero por Pagar',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$${_formatMonto(_totalDeudas)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
      child: GestureDetector(
        onTap: () => _mostrarDetallesCuenta(cuenta),
        child: Card(
          color: AppColors.surface, // Blanco
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderDashboard, width: 1.0),
          ),
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
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12), // Azul suave de la paleta
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 16, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_formatMonto(double.tryParse(cuenta['saldo_actual'].toString()) ?? 0.0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransaccionTile(Map<String, dynamic> tx) {
    final bool isGasto = tx['tipo'] == 'GASTO';
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
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDashboard, width: 0.8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGasto ? AppColors.warning.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGasto ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
              color: isGasto ? AppColors.warning : AppColors.primary,
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
              color: isGasto ? AppColors.warning.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$prefijo\$${_formatMonto(double.tryParse(tx['monto'].toString()) ?? 0.0)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isGasto ? const Color(0xFFC0392B) : const Color(0xFF107C41), // Verde legible para finanzas
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

  void _mostrarDetallesCuenta(Map<String, dynamic> cuenta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final double saldo = double.tryParse(cuenta['saldo_actual'].toString()) ?? 0.0;
        final String nombre = cuenta['nombre_banco'] ?? 'Cuenta';
        final String tipo = cuenta['tipo_cuenta'] ?? 'AHORRO';
        final int id = cuenta['id'];
        
        // Filtrar transacciones para esta cuenta
        final listTx = _transacciones.where((tx) => tx['cuenta'] == id).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24.0),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.bgDashboard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDashboard),
                        ),
                        child: Text(
                          tipo,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Saldo grande
                  const Text('Saldo Disponible', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_formatMonto(saldo)}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botones de acción Agregar / Retirar
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx); // Cerrar bottom sheet
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegistrarMovimientoScreen(
                                  cuentas: _cuentas,
                                  preselectedCuentaId: id,
                                  preselectedTipo: 'INGRESO',
                                ),
                              ),
                            );
                            if (result != null) {
                              _cargarDatos();
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Agregar Dinero'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary, // Verde
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx); // Cerrar bottom sheet
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegistrarMovimientoScreen(
                                  cuentas: _cuentas,
                                  preselectedCuentaId: id,
                                  preselectedTipo: 'GASTO',
                                ),
                              ),
                            );
                            if (result != null) {
                              _cargarDatos();
                            }
                          },
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          label: const Text('Retirar Dinero'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning, // Rojo
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  const Text(
                    'Historial Reciente de la Cuenta',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  
                  if (listTx.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'No hay movimientos para esta cuenta.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: listTx.length,
                      separatorBuilder: (_, __) => const Divider(height: 16, thickness: 0.5),
                      itemBuilder: (context, i) {
                        final tx = listTx[i];
                        final bool isGasto = tx['tipo'] == 'GASTO';
                        final double montoTx = double.tryParse(tx['monto'].toString()) ?? 0.0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx['categoria'] ?? 'General',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                if (tx['descripcion'] != null && tx['descripcion'].toString().isNotEmpty)
                                  Text(
                                    tx['descripcion'],
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                            Text(
                              "${isGasto ? '-' : '+'}\$${_formatMonto(montoTx)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isGasto ? const Color(0xFFC0392B) : const Color(0xFF107C41),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          }
        );
      }
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
