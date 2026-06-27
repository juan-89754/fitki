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

  double? _extraerMonto(String texto) {
    // Regex robusta para capturar números con formato de moneda:
    // Captura números planos o con puntos (ej: 200.000, 1.200.000, 50000)
    final RegExp regex = RegExp(r'(?:[\$]?\s*)(\d{1,3}(?:\.\d{3})+|\d+)');
    final match = regex.firstMatch(texto);
    
    if (match != null) {
      String valorDetectado = match.group(1)!;
      // Remover puntos de formato de miles
      valorDetectado = valorDetectado.replaceAll('.', '');
      return double.tryParse(valorDetectado);
    }
    return null;
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

    // Extraer monto del texto usando regex
    final double? monto = _extraerMonto(texto);

    if (monto == null) {
      // Respuesta si no se detectó monto
      await Future.delayed(const Duration(milliseconds: 800));
      final respuestaSinMonto = {
        'sender': 'fitki',
        'text': 'No logré identificar el precio de la compra en tu mensaje. Por favor, asegúrate de incluir el valor con puntos o plano. Ej: "comprar reloj 350.000" o "comprar bolso 150000".',
        'status': 'normal',
        'time': DateTime.now().toIsoformatString(),
      };
      setState(() {
        _mensajes.add(respuestaSinMonto);
        _isWriting = false;
      });
      _scrollToBottom();
      await _guardarHistorial();
      return;
    }

    // Consultar a la API de Django
    final result = await _apiService.consultarAsistente(monto);

    setState(() {
      _isWriting = false;
    });

    if (result['success']) {
      final data = result['data'];
      final bool aprobado = data['aprobado'] == true;
      final String sugerencia = data['sugerencia'] ?? '';

      final respuestaFitki = {
        'sender': 'fitki',
        'text': sugerencia,
        'status': aprobado ? 'approved' : 'rejected',
        'time': DateTime.now().toIsoformatString(),
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
      appBar: AppBar(
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
      body: Container(
        color: AppColors.background,
        child: Column(
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
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final bool isUser = msg['sender'] == 'user';
    final String status = msg['status'] ?? 'normal';

    Color bubbleColor;
    Color textColor = AppColors.textPrimary;
    BorderRadius borderRadius;

    if (isUser) {
      bubbleColor = const Color(0xFFC7CEEA); // Lavanda Grisáceo
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      );
    } else {
      if (status == 'approved') {
        bubbleColor = const Color(0xFFB5EAD7); // Verde menta pastel
      } else if (status == 'rejected') {
        bubbleColor = const Color(0xFFFF9AA2); // Rosa suave pastel
      } else {
        bubbleColor = const Color(0xFFFFFFD8); // Crema claro
      }
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg['text'],
          style: TextStyle(
            color: textColor,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWritingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFD8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
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
            top: BorderSide(color: AppColors.background, width: 1.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
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
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.textPrimary,
                child: const Icon(Icons.send_rounded, size: 18),
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
