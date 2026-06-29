import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'theme.dart';

class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({super.key});

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  final _apiService = ApiService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _mensajes = [];
  bool _isWriting = false;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Cargar historial de chat persistido localmente
  Future<void> _cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatData = prefs.getString('fitki_chat_history');
    if (chatData != null) {
      final List<dynamic> decoded = jsonDecode(chatData);
      setState(() {
        _mensajes = decoded.map((m) => Map<String, dynamic>.from(m)).toList();
      });
      _scrollToBottom();
    } else {
      // Mensaje de bienvenida inicial si no hay historial
      setState(() {
        _mensajes = [
          {
            'sender': 'fitki',
            'text': '¡Hola! Soy tu asistente financiero de Fitki.\n\nEscríbeme lo que quieres comprar y su costo (ej: "comprar zapatos 200.000" o "¿puedo comprar una laptop de \$1.200.000?") y calcularé si es viable basándome en tu dinero y metas reales.',
            'status': 'normal',
            'time': DateTime.now().toIsoformatString(),
          }
        ];
      });
    }
  }

  // Persistir historial de chat localmente
  Future<void> _guardarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fitki_chat_history', jsonEncode(_mensajes));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  void _enviarMensaje() async {
    final texto = _textController.text.trim();
    if (texto.isEmpty) return;

    _textController.clear();

    // Agregar mensaje del usuario al chat
    final nuevoMensajeUsuario = {
      'sender': 'user',
      'text': texto,
      'status': 'normal',
      'time': DateTime.now().toIsoformatString(),
    };

    setState(() {
      _mensajes.add(nuevoMensajeUsuario);
      _isWriting = true;
    });
    _scrollToBottom();
    await _guardarHistorial();

    // Consultar a la API de Django con la consulta de texto
    final result = await _apiService.consultarAsistenteTexto(texto);

    setState(() {
      _isWriting = false;
    });

    if (result['success']) {
      final data = result['data'];
      final String status = data['status'] ?? 'normal';
      final String sugerencia = data['sugerencia'] ?? '';

      final respuestaFitki = {
        'sender': 'fitki',
        'text': sugerencia,
        'status': status,
        'time': DateTime.now().toIsoformatString(),
        'cantidad_viable': data['cantidad_viable'],
        'articulo': data['articulo'],
        'precio_unitario': data['precio_unitario'] != null ? double.tryParse(data['precio_unitario'].toString()) : null,
      };

      setState(() {
        _mensajes.add(respuestaFitki);
      });
    } else {
      final respuestaError = {
        'sender': 'fitki',
        'text': result['message'] ?? 'Lo siento, tuve un problema al conectarme al servidor para calcular tus finanzas.',
        'status': 'normal',
        'time': DateTime.now().toIsoformatString(),
      };
      setState(() {
        _mensajes.add(respuestaError);
      });
    }

    _scrollToBottom();
    await _guardarHistorial();
  }

  void _limpiarConversacion() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('Limpiar Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Deseas borrar todo el historial de consultas de Fitki?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('fitki_chat_history');
              setState(() {
                _mensajes = [
                  {
                    'sender': 'fitki',
                    'text': 'Historial borrado. ¡Empecemos de nuevo!\n\n¿Qué compra quieres evaluar hoy?',
                    'status': 'normal',
                    'time': DateTime.now().toIsoformatString(),
                  }
                ];
              });
            },
            child: const Text('Limpiar', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgAsistente,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 18,
              child: const Icon(
                Icons.psychology_rounded,
                size: 20,
                color: Color(0xFF3B4A4A),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fitki Brain', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Consejero Financiero', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.textSecondary),
            onPressed: _limpiarConversacion,
            tooltip: 'Borrar historial',
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _mensajes.length + (_isWriting ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _mensajes.length) {
                  return _buildWritingIndicator();
                }
                final msg = _mensajes[index];
                return _buildChatBubble(msg);
              },
            ),
          ),
          _buildInputPanel(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final bool isUser = msg['sender'] == 'user';
    final String status = msg['status'] ?? 'normal';

    Color bubbleColor;
    BoxShadow shadow;
    Border border;
    BorderRadius borderRadius;

    if (isUser) {
      bubbleColor = AppColors.secondary; // Azul Cielo sólido
      shadow = BoxShadow(
        color: AppColors.secondary.withOpacity(0.35),
        blurRadius: 8,
        offset: const Offset(0, 4),
      );
      border = Border.all(color: Colors.transparent, width: 0);
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      );
    } else {
      if (status == 'approved') {
        bubbleColor = AppColors.primary; // Verde Menta sólido
        shadow = BoxShadow(
          color: AppColors.primary.withOpacity(0.35),
          blurRadius: 8,
          offset: const Offset(0, 4),
        );
        border = Border.all(color: Colors.transparent, width: 0);
      } else if (status == 'rejected') {
        bubbleColor = AppColors.warning; // Rosa Rosado sólido
        shadow = BoxShadow(
          color: AppColors.warning.withOpacity(0.35),
          blurRadius: 8,
          offset: const Offset(0, 4),
        );
        border = Border.all(color: Colors.transparent, width: 0);
      } else if (status == 'partially_approved') {
        bubbleColor = AppColors.butterYellow; // Amarillo Mantequilla sólido
        shadow = BoxShadow(
          color: AppColors.butterYellow.withOpacity(0.45),
          blurRadius: 8,
          offset: const Offset(0, 4),
        );
        border = Border.all(color: Colors.transparent, width: 0);
      } else {
        bubbleColor = AppColors.surface; // Blanco puro
        shadow = BoxShadow(
          color: AppColors.borderAsistente.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        );
        border = Border.all(color: AppColors.borderAsistente, width: 1.0);
      }
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

    final bool hasViableSuggestion = !isUser && 
        status == 'partially_approved' && 
        msg['cantidad_viable'] != null && 
        msg['cantidad_viable'] > 0;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: border,
          boxShadow: [shadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg['text'],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasViableSuggestion) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _agregarSugerenciaAlPlan(
                    msg['articulo'],
                    msg['cantidad_viable'],
                    msg['precio_unitario'],
                  ),
                  icon: const Icon(Icons.add_task_rounded, size: 16, color: AppColors.textPrimary),
                  label: Text(
                    'Agregar ${msg['cantidad_viable']} unidades al Plan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface, // Resaltar
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _agregarSugerenciaAlPlan(String? articulo, int? cantidad, double? precioUnitario) async {
    if (articulo == null || cantidad == null || precioUnitario == null) return;
    
    setState(() {
      _isWriting = true;
    });

    try {
      final resProj = await _apiService.getProyectosCompra();
      if (!resProj['success']) {
        throw Exception(resProj['message'] ?? 'Error al conectar.');
      }
      
      final List<dynamic> proyectos = resProj['data'] ?? [];
      int? proyectoIdSeleccionado;
      
      if (proyectos.isEmpty) {
        proyectoIdSeleccionado = await _crearProyectoNuevoAutomatico(articulo);
      } else {
        proyectoIdSeleccionado = await showDialog<int>(
          context: context,
          builder: (ctx) {
            int? tempId = proyectos.first['id'];
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Asignar a un Proyecto'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Elige el proyecto donde deseas agrupar este producto:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: tempId,
                        items: [
                          ...proyectos.map((p) => DropdownMenuItem<int>(
                            value: p['id'],
                            child: Text(p['nombre'].toString(), overflow: TextOverflow.ellipsis),
                          )),
                          const DropdownMenuItem<int>(
                            value: -1,
                            child: Text('+ Crear nuevo proyecto...', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            tempId = val;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, tempId),
                      child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }
            );
          }
        );
        
        if (proyectoIdSeleccionado == null) {
          setState(() {
            _isWriting = false;
          });
          return;
        }
        
        if (proyectoIdSeleccionado == -1) {
          proyectoIdSeleccionado = await _crearProyectoNuevoAutomatico(articulo);
        }
      }
      
      if (proyectoIdSeleccionado == null || proyectoIdSeleccionado <= 0) {
        throw Exception('No se pudo determinar el proyecto.');
      }
      
      final resItem = await _apiService.createItemProyecto(
        proyectoIdSeleccionado,
        articulo,
        cantidad,
        precioUnitario,
        'MEDIA',
        'Sugerido por Asistente Fitki',
      );
      
      if (!resItem['success']) {
        throw Exception(resItem['message'] ?? 'Error al guardar el producto.');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡"$articulo" agregado al proyecto con éxito!'),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      final msgConfirm = {
        'sender': 'fitki',
        'text': '¡Listo! He agregado "$articulo" ($cantidad unidades) al proyecto de compra por un costo total de \$${_formatMonto(cantidad * precioUnitario)}.',
        'status': 'approved',
        'time': DateTime.now().toIsoformatString(),
      };
      
      setState(() {
        _mensajes.add(msgConfirm);
      });
      _scrollToBottom();
      await _guardarHistorial();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFC0392B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isWriting = false;
      });
    }
  }

  Future<int?> _crearProyectoNuevoAutomatico(String articulo) async {
    final String fechaEjecucion = DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);
    final res = await _apiService.createProyectoCompra(
      'Compra: $articulo',
      'Proyecto creado automáticamente por el Asistente Fitki',
      'No especificado',
      fechaEjecucion,
      'MEDIA',
      'PENDIENTE',
      'Creado desde el chat.',
      '#Sugerido',
    );
    if (res['success']) {
      return res['data']['id'];
    }
    return null;
  }

  String _formatMonto(double monto) {
    return monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  Widget _buildWritingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface, // Blanco puro
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.borderAsistente, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.borderAsistente.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Fitki está calculando...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPanel() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            top: BorderSide(color: AppColors.borderAsistente, width: 1.0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgAsistente, // Fondo amarillo suave
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Pregúntame algo: comprar zapatos 200.000...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (_) => _enviarMensaje(),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _enviarMensaje,
              borderRadius: BorderRadius.circular(24),
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.secondary, // Sky Blue
                foregroundColor: AppColors.textPrimary,
                child: Icon(Icons.send_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extensión para formatear fecha/hora ISO amigablemente
extension DateTimeIso on DateTime {
  String toIsoformatString() {
    return toIso8601String();
  }
}
