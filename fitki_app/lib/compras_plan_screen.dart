import 'package:flutter/material.dart';
import 'api_service.dart';
import 'forms_screens.dart';
import 'theme.dart';

class ComprasPlanScreen extends StatefulWidget {
  const ComprasPlanScreen({super.key});

  @override
  State<ComprasPlanScreen> createState() => _ComprasPlanScreenState();
}

class _ComprasPlanScreenState extends State<ComprasPlanScreen> {
  final _apiService = ApiService();

  bool _isLoading = true;
  double _cgl = 0.0;
  double _totalPendienteProyectos = 0.0;
  List<dynamic> _proyectos = [];

  final Color bgPlanificacion = const Color(0xFFF5EBFD);
  final Color borderPlanificacion = const Color(0xFFE3CFFF);
  final Color shadowPlanificacion = const Color(0xFFC099FF);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Obtener CGL
      final resAsistente = await _apiService.consultarAsistenteTexto("");
      if (resAsistente['success']) {
        _cgl = double.tryParse(resAsistente['data']['cgl'].toString()) ?? 0.0;
      }

      // 2. Obtener Proyectos
      final resProyectos = await _apiService.getProyectosCompra();
      if (resProyectos['success']) {
        _proyectos = resProyectos['data'] ?? [];
      }

      // Calcular totales pendientes
      double sumaPendienteProyectos = 0.0;
      for (var proj in _proyectos) {
        if (proj['estado'] == 'PENDIENTE') {
          sumaPendienteProyectos += double.tryParse(proj['costo_total'].toString()) ?? 0.0;
        }
      }
      _totalPendienteProyectos = sumaPendienteProyectos;

    } catch (e) {
      debugPrint("Error al cargar datos de planificación: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _eliminarProyecto(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cotización'),
        content: const Text('¿Deseas eliminar este proyecto de cotización? Se borrarán también todos sus productos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar == true) {
      final res = await _apiService.deleteProyectoCompra(id);
      if (res['success']) {
        _cargarDatos();
      }
    }
  }

  String _formatMonto(double monto) {
    return monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  Color _getPrioridadColor(String prioridad) {
    if (prioridad == 'ALTA') return const Color(0xFFC0392B);
    if (prioridad == 'MEDIA') return const Color(0xFFD35400);
    return const Color(0xFF7F8C8D);
  }

  Color _getEstadoColor(String estado) {
    if (estado == 'COMPRADO') return const Color(0xFF27AE60);
    if (estado == 'COTIZADO') return const Color(0xFFF39C12);
    if (estado == 'CANCELADO') return const Color(0xFF7F8C8D);
    return const Color(0xFF2980B9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPlanificacion,
      appBar: AppBar(
        title: const Text('Proyectos de Cotización'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // PANEL RESUMEN
                  _buildResumenPanel(),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Proyectos de Cotización',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final added = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AgregarEditarProyectoScreen()),
                          );
                          if (added == true) _cargarDatos();
                        },
                        icon: const Icon(Icons.create_new_folder_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: shadowPlanificacion,
                          side: BorderSide(color: borderPlanificacion),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_proyectos.isEmpty)
                    _buildEmptyState('No tienes proyectos de cotización.', 'Crea proyectos para agrupar múltiples productos y cotizaciones.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _proyectos.length,
                      itemBuilder: (context, index) {
                        final project = _proyectos[index];
                        return _buildProyectoCard(project);
                      },
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildResumenPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderPlanificacion, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: shadowPlanificacion.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Capacidad Libre:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '\$${_formatMonto(_cgl)}',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: _cgl >= 0 ? const Color(0xFF27AE60) : const Color(0xFFC0392B)
                ),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total en Cotizaciones Pendientes:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '\$${_formatMonto(_totalPendienteProyectos)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tienes \$${_formatMonto(_cgl)} libres para cubrir tus cotizaciones planeadas',
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w500, 
                color: _cgl >= 0 ? const Color(0xFF27AE60) : const Color(0xFFC0392B),
                fontStyle: FontStyle.italic
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> project) {
    final double total = double.tryParse(project['costo_total'].toString()) ?? 0.0;
    final String prioridad = project['prioridad'] ?? 'MEDIA';
    final String estado = project['estado'] ?? 'PENDIENTE';
    final int numProductos = (project['items'] as List?)?.length ?? 0;
    final String proveedor = project['proveedor'] ?? 'No especificado';
    final String tags = project['etiquetas'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderPlanificacion, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: shadowPlanificacion.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleProyectoScreen(proyecto: project),
            ),
          );
          if (changed == true) _cargarDatos();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      project['nombre'],
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getEstadoColor(estado).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getEstadoColor(estado).withOpacity(0.3)),
                    ),
                    child: Text(
                      estado,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getEstadoColor(estado)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (project['descripcion'] != null && project['descripcion'].toString().isNotEmpty) ...[
                Text(
                  project['descripcion'],
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Proveedor: $proveedor',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    'Total: \$${_formatMonto(total)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                ],
              ),
              const Divider(height: 16, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getPrioridadColor(prioridad).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Prioridad: $prioridad',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getPrioridadColor(prioridad)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$numProductos prod.',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (tags.isNotEmpty) ...[
                        Text(tags, style: TextStyle(fontSize: 10, color: shadowPlanificacion, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                      ],
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AgregarEditarProyectoScreen(proyectoParaEditar: project)),
                          );
                          if (updated == true) _cargarDatos();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFC0392B)),
                        onPressed: () => _eliminarProyecto(project['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String titulo, String subtitulo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderPlanificacion, width: 1.0),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: shadowPlanificacion.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// SCREEN DETALLES PROYECTO (TABLA DE COTIZACIÓN REAL)
class DetalleProyectoScreen extends StatefulWidget {
  final Map<String, dynamic> proyecto;

  const DetalleProyectoScreen({super.key, required this.proyecto});

  @override
  State<DetalleProyectoScreen> createState() => _DetalleProyectoScreenState();
}

class _DetalleProyectoScreenState extends State<DetalleProyectoScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic> _projData = {};
  List<dynamic> _items = [];
  bool _anyChange = false;

  @override
  void initState() {
    super.initState();
    _projData = widget.proyecto;
    _recargarProyecto();
  }

  Future<void> _recargarProyecto() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getProyectosCompra();
      if (res['success']) {
        final List<dynamic> list = res['data'] ?? [];
        final found = list.firstWhere((p) => p['id'] == _projData['id'], orElse: () => null);
        if (found != null) {
          setState(() {
            _projData = found;
            _items = found['items'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error recargando cotización: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _eliminarItem(int itemId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text('¿Deseas remover este producto del proyecto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final res = await _apiService.deleteItemProyecto(itemId);
      if (res['success']) {
        _anyChange = true;
        _recargarProyecto();
      }
    }
  }

  String _formatMonto(double monto) {
    return monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  Color _getPrioridadColor(String prioridad) {
    if (prioridad == 'ALTA') return const Color(0xFFC0392B);
    if (prioridad == 'MEDIA') return const Color(0xFFD35400);
    return const Color(0xFF7F8C8D);
  }

  Color _getEstadoColor(String estado) {
    if (estado == 'COMPRADO') return const Color(0xFF27AE60);
    if (estado == 'COTIZADO') return const Color(0xFFF39C12);
    if (estado == 'CANCELADO') return const Color(0xFF7F8C8D);
    return const Color(0xFF2980B9);
  }

  @override
  Widget build(BuildContext context) {
    final double totalGlobal = double.tryParse(_projData['costo_total']?.toString() ?? '0.0') ?? 0.0;
    final String proveedor = _projData['proveedor'] ?? 'No especificado';
    final String executionDate = _projData['fecha_ejecucion'] ?? 'No especificada';
    final String prioridad = _projData['prioridad'] ?? 'MEDIA';
    final String estado = _projData['estado'] ?? 'PENDIENTE';
    final String notas = _projData['notas'] ?? '';
    final String tags = _projData['etiquetas'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotización de Proyecto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _anyChange),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Editar Información del Proyecto',
            onPressed: () async {
              final edited = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AgregarEditarProyectoScreen(proyectoParaEditar: _projData)),
              );
              if (edited == true) {
                _anyChange = true;
                _recargarProyecto();
              }
            },
          ),
        ],
      ),
      body: _isLoading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA DETALLES PROYECTO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE3CFFF)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC099FF).withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _projData['nombre'],
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getEstadoColor(estado).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _getEstadoColor(estado).withOpacity(0.3)),
                              ),
                              child: Text(
                                estado,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getEstadoColor(estado)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_projData['descripcion'] != null && _projData['descripcion'].toString().isNotEmpty) ...[
                          Text(
                            _projData['descripcion'],
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text('Lugar: $proveedor', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                            const Spacer(),
                            const Icon(Icons.date_range_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text('Límite: $executionDate', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPrioridadColor(prioridad).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Prioridad: $prioridad',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPrioridadColor(prioridad)),
                              ),
                            ),
                            if (tags.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tags,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (notas.isNotEmpty) ...[
                          const Divider(height: 20, thickness: 0.5),
                          const Text('Notas del Proyecto:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            notas,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontStyle: FontStyle.italic),
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TABLA DE PRODUCTOS (COTIZACIÓN)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Líneas de Compra',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final added = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AgregarEditarItemProyectoScreen(proyectoId: _projData['id']),
                            ),
                          );
                          if (added == true) {
                            _anyChange = true;
                            _recargarProyecto();
                          }
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar Producto', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_items.isEmpty)
                    _buildEmptyCotizacion()
                  else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9F9FB),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('Producto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                                Expanded(flex: 1, child: Text('Cant.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary), textAlign: TextAlign.center)),
                                Expanded(flex: 2, child: Text('Unitario', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                                SizedBox(width: 60), // Espacio para botones de acción
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          // List of products
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                            itemBuilder: (ctx, i) {
                              final item = _items[i];
                              final double unit = double.tryParse(item['precio_unitario'].toString()) ?? 0.0;
                              final double subtotal = double.tryParse(item['costo_total'].toString()) ?? 0.0;
                              final int qty = item['cantidad'] ?? 1;
                              final String itemPriority = item['prioridad'] ?? 'MEDIA';
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['articulo'],
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (item['nota'] != null && item['nota'].toString().isNotEmpty)
                                            Text(
                                              item['nota'],
                                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                            ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _getPrioridadColor(itemPriority).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              itemPriority,
                                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _getPrioridadColor(itemPriority)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        qty.toString(),
                                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '\$${_formatMonto(unit)}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '\$${_formatMonto(subtotal)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    // ACCIONES ITEM
                                    SizedBox(
                                      width: 60,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, size: 14, color: AppColors.textSecondary),
                                            onPressed: () async {
                                              final edited = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => AgregarEditarItemProyectoScreen(
                                                    proyectoId: _projData['id'],
                                                    itemParaEditar: item,
                                                  ),
                                                ),
                                              );
                                              if (edited == true) {
                                                _anyChange = true;
                                                _recargarProyecto();
                                              }
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFC0392B)),
                                            onPressed: () => _eliminarItem(item['id']),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Gran Total
                          const Divider(height: 1, thickness: 1),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9F9FB),
                              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total General del Proyecto:',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '\$${_formatMonto(totalGlobal)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyCotizacion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.add_shopping_cart_rounded, size: 40, color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'Este proyecto no tiene productos.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Usa el botón superior para agregar artículos a esta cotización.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
