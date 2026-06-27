import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // CONFIGURACIÓN DINÁMICA DE LA URL BASE
  // - Si estás en la web o emulador iOS/Desktop, usa localhost (127.0.0.1).
  // - Si estás en un emulador de Android, usa la IP virtual 10.0.2.2.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    return _token;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<bool> hasActiveSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Cabeceras HTTP estándar
  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (requireAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // 1. REGISTRO DE USUARIO
  Future<Map<String, dynamic>> register(String username, String email, String password, String nombre) async {
    final url = Uri.parse('$baseUrl/register/');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(requireAuth: false),
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'nombre': nombre,
        }),
      );
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'No se pudo conectar al servidor backend. Verifica que esté encendido. ($e)'};
    }
  }

  // 2. LOGIN (OBTENER TOKEN JWT)
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/token/');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(requireAuth: false),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = data['access'];
        await saveToken(token);
        return {'success': true};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Credenciales incorrectas.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión. ($e)'};
    }
  }

  // 3. CONSULTAR EL DASHBOARD (Consolidado patrimonial)
  Future<Map<String, dynamic>> getDashboard() async {
    final url = Uri.parse('$baseUrl/dashboard/');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        await clearSession();
        return {'success': false, 'unauthorized': true, 'message': 'Sesión expirada.'};
      } else {
        return {'success': false, 'message': 'Error al cargar el dashboard.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 4. CREAR UNA CUENTA
  Future<Map<String, dynamic>> createCuenta(String nombreBanco, double saldoActual, String tipoCuenta) async {
    final url = Uri.parse('$baseUrl/cuentas/');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'nombre_banco': nombreBanco,
          'saldo_actual': saldoActual,
          'tipo_cuenta': tipoCuenta,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 5. REGISTRAR UNA TRANSACCIÓN (INGRESO / GASTO)
  Future<Map<String, dynamic>> createTransaccion({
    required int cuentaId,
    required double monto,
    required String tipo,
    required String categoria,
    required String descripcion,
    int? metaId,
    int? deudaId,
  }) async {
    final url = Uri.parse('$baseUrl/transacciones/');
    try {
      final Map<String, dynamic> body = {
        'cuenta': cuentaId,
        'monto': monto,
        'tipo': tipo,
        'categoria': categoria,
        'descripcion': descripcion,
        'fecha': DateTime.now().toUtc().toIso8601String(),
      };
      if (metaId != null) body['meta_ahorro'] = metaId;
      if (deudaId != null) body['deuda'] = deudaId;

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 6. OBTENER METAS DE AHORRO
  Future<Map<String, dynamic>> getMetas() async {
    final url = Uri.parse('$baseUrl/metas/');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Error al cargar las metas.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 7. CREAR META DE AHORRO
  Future<Map<String, dynamic>> createMeta(String nombre, double montoObjetivo, String fechaLimite) async {
    final url = Uri.parse('$baseUrl/metas/');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'nombre': nombre,
          'monto_objetivo': montoObjetivo,
          'monto_ahorrado_actual': 0.0,
          'fecha_limite': fechaLimite,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 8. OBTENER DEUDAS
  Future<Map<String, dynamic>> getDeudas() async {
    final url = Uri.parse('$baseUrl/deudas/');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Error al cargar las deudas.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 9. CREAR DEUDA
  Future<Map<String, dynamic>> createDeuda({
    required String nombre,
    required double montoTotal,
    required double tasaInteres,
    required double cuotaMensual,
    required String fechaProximoPago,
    String? fechaLimite,
  }) async {
    final url = Uri.parse('$baseUrl/deudas/');
    try {
      final Map<String, dynamic> body = {
        'nombre': nombre,
        'monto_total': montoTotal,
        'tasa_interes': tasaInteres,
        'cuota_mensual': cuotaMensual,
        'fecha_proximo_pago': fechaProximoPago,
      };
      if (fechaLimite != null && fechaLimite.isNotEmpty) {
        body['fecha_limite'] = fechaLimite;
      }

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 10. EDITAR META DE AHORRO
  Future<Map<String, dynamic>> updateMeta(int id, String nombre, double montoObjetivo, String fechaLimite) async {
    final url = Uri.parse('$baseUrl/metas/$id/');
    try {
      final response = await http.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'nombre': nombre,
          'monto_objetivo': montoObjetivo,
          'fecha_limite': fechaLimite,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 11. ELIMINAR META DE AHORRO
  Future<Map<String, dynamic>> deleteMeta(int id) async {
    final url = Uri.parse('$baseUrl/metas/$id/');
    try {
      final response = await http.delete(url, headers: await _getHeaders());
      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Error al eliminar la meta.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 12. EDITAR DEUDA
  Future<Map<String, dynamic>> updateDeuda({
    required int id,
    required String nombre,
    required double montoTotal,
    required double tasaInteres,
    required double cuotaMensual,
    required String fechaProximoPago,
    String? fechaLimite,
  }) async {
    final url = Uri.parse('$baseUrl/deudas/$id/');
    try {
      final Map<String, dynamic> body = {
        'nombre': nombre,
        'monto_total': montoTotal,
        'tasa_interes': tasaInteres,
        'cuota_mensual': cuotaMensual,
        'fecha_proximo_pago': fechaProximoPago,
      };
      if (fechaLimite != null && fechaLimite.isNotEmpty) {
        body['fecha_limite'] = fechaLimite;
      } else {
        body['fecha_limite'] = null; // Limpiar si se desactiva
      }

      final response = await http.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 13. ELIMINAR DEUDA
  Future<Map<String, dynamic>> deleteDeuda(int id) async {
    final url = Uri.parse('$baseUrl/deudas/$id/');
    try {
      final response = await http.delete(url, headers: await _getHeaders());
      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Error al eliminar la deuda.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // 14. CONSULTAR ASISTENTE FINANCIERO
  Future<Map<String, dynamic>> consultarAsistente(double monto) async {
    final url = Uri.parse('$baseUrl/asistente/consulta/');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'monto': monto}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': _parseErrors(data)};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión.'};
    }
  }

  // Utilidad para extraer y dar formato a los errores devueltos por DRF
  String _parseErrors(dynamic data) {
    if (data is Map) {
      List<String> messages = [];
      data.forEach((key, value) {
        if (value is List) {
          messages.add('$key: ${value.join(', ')}');
        } else {
          messages.add('$key: $value');
        }
      });
      return messages.join('\n');
    }
    return data.toString();
  }
}
