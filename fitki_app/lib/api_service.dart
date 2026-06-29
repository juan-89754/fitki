import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  bool _initialized = false;

  // Colecciones en memoria
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _cuentas = [];
  List<Map<String, dynamic>> _transacciones = [];
  List<Map<String, dynamic>> _metas = [];
  List<Map<String, dynamic>> _deudas = [];
  List<Map<String, dynamic>> _proyectos = [];
  List<Map<String, dynamic>> _itemsProyecto = [];

  // Contadores de IDs incrementales
  int _nextCuentaId = 1;
  int _nextTransaccionId = 1;
  int _nextMetaId = 1;
  int _nextDeudaId = 1;
  int _nextProyectoId = 1;
  int _nextItemId = 1;

  // Inicialización de base de datos local
  Future<void> _init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    // Perfil del usuario
    final userStr = prefs.getString('user_profile');
    if (userStr != null) {
      try {
        _userProfile = Map<String, dynamic>.from(jsonDecode(userStr));
      } catch (_) {}
    }

    // Listas de datos
    _cuentas = _loadList(prefs, 'cuentas');
    _transacciones = _loadList(prefs, 'transacciones');
    _metas = _loadList(prefs, 'metas');
    _deudas = _loadList(prefs, 'deudas');
    _proyectos = _loadList(prefs, 'proyectos');
    _itemsProyecto = _loadList(prefs, 'items_proyecto');

    // Determinar próximos IDs únicos
    _nextCuentaId = _maxId(_cuentas) + 1;
    _nextTransaccionId = _maxId(_transacciones) + 1;
    _nextMetaId = _maxId(_metas) + 1;
    _nextDeudaId = _maxId(_deudas) + 1;
    _nextProyectoId = _maxId(_proyectos) + 1;
    _nextItemId = _maxId(_itemsProyecto) + 1;

    _initialized = true;
  }

  List<Map<String, dynamic>> _loadList(SharedPreferences prefs, String key) {
    final str = prefs.getString(key);
    if (str == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(str);
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  int _maxId(List<Map<String, dynamic>> list) {
    int maxVal = 0;
    for (var item in list) {
      final id = item['id'];
      if (id is int && id > maxVal) {
        maxVal = id;
      }
    }
    return maxVal;
  }

  Future<void> _save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  // Comprobar si una fecha está en el mes y año actuales
  bool _isInCurrentMonth(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      return date.year == now.year && date.month == now.month;
    } catch (_) {
      return false;
    }
  }

  // Avanzar exactamente un mes de forma segura
  DateTime _avanzarUnMes(DateTime fecha) {
    int mesSiguiente = fecha.month + 1;
    int anoSiguiente = fecha.year;
    if (mesSiguiente > 12) {
      mesSiguiente = 1;
      anoSiguiente += 1;
    }
    int dia = fecha.day;
    DateTime? nuevaFecha;
    while (nuevaFecha == null && dia >= 28) {
      try {
        nuevaFecha = DateTime(anoSiguiente, mesSiguiente, dia);
      } catch (_) {
        dia -= 1;
      }
    }
    nuevaFecha ??= DateTime(anoSiguiente, mesSiguiente, dia);
    return nuevaFecha;
  }

  // Verificación de dígitos
  bool _isDigit(String char) {
    if (char.isEmpty) return false;
    final int code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  // Formatear valor como moneda colombiana (puntos como miles)
  String _formatearPesos(double monto) {
    final int valorEntero = monto.toInt();
    final String str = valorEntero.toString();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return "\$" + str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  // Cálculo del aporte mensual requerido de una meta
  double _calcularAporteMetaMensual(Map<String, dynamic> meta) {
    final double objetivo = double.tryParse(meta['monto_objetivo'].toString()) ?? 0.0;
    final double ahorrado = double.tryParse(meta['monto_ahorrado_actual'].toString()) ?? 0.0;
    final double faltante = objetivo - ahorrado;
    if (faltante <= 0) return 0.0;

    final String limStr = meta['fecha_limite'] ?? '';
    final DateTime? limite = DateTime.tryParse(limStr);
    final hoy = DateTime.now();
    final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);

    if (limite == null || limite.isBefore(hoyDate) || limite.isAtSameMomentAs(hoyDate)) {
      return faltante;
    }

    int meses = (limite.year - hoyDate.year) * 12 + (limite.month - hoyDate.month);
    if (meses <= 0) meses = 1;

    return double.parse((faltante / meses).toStringAsFixed(2));
  }

  // Analizar la consulta en lenguaje natural
  Map<String, dynamic> _parseConsulta(String texto) {
    // Remover símbolo de pesos
    String cleaned = texto.replaceAll('\$', '');

    // Quitar puntos que actúan como separadores de miles
    String textClean = '';
    for (int i = 0; i < cleaned.length; i++) {
      if (cleaned[i] == '.' &&
          i > 0 &&
          i < cleaned.length - 1 &&
          _isDigit(cleaned[i - 1]) &&
          _isDigit(cleaned[i + 1])) {
        // Ignorar el punto
      } else {
        textClean += cleaned[i];
      }
    }

    // Extraer todos los números del texto limpio
    final numRegExp = RegExp(r'\b\d+(?:\.\d+)?\b');
    final matches = numRegExp.allMatches(textClean).map((m) => m.group(0)!).toList();

    int cantidad = 1;
    double precioUnitario = 0.0;
    String articulo = "artículo";

    if (matches.length >= 2) {
      try {
        final double val1 = double.parse(matches[0]);
        final double val2 = double.parse(matches[1]);

        if (val1 == val1.toInt() && val1 < 1000) {
          cantidad = val1.toInt();
          precioUnitario = val2;
        } else {
          precioUnitario = val1;
          cantidad = (val2 == val2.toInt() && val2 < 1000) ? val2.toInt() : 1;
        }
      } catch (_) {}
    } else if (matches.length == 1) {
      try {
        precioUnitario = double.parse(matches[0]);
      } catch (_) {}
    }

    // Extraer artículo (buscar palabras tras comprar/adquirir/para)
    final RegExp artRegExp = RegExp(
      r'(?:comprar|adquirir|para)\s+([a-zA-Z\s]+?)(?:\s+de\s+|\s+a\s+|\s+\d)',
      caseSensitive: false,
    );
    final match = artRegExp.firstMatch(textClean);
    if (match != null) {
      articulo = match.group(1)!.trim();
    } else {
      final RegExp artAlt = RegExp(r'(?:comprar|adquirir|para)\s+([a-zA-Z]+)', caseSensitive: false);
      final matchAlt = artAlt.firstMatch(textClean);
      if (matchAlt != null) {
        articulo = matchAlt.group(1)!.trim();
      }
    }

    return {
      'articulo': articulo,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }

  // Serializadores y enriquecedores dinámicos locales
  Map<String, dynamic> _serializeMeta(Map<String, dynamic> meta) {
    final double objetivo = double.tryParse(meta['monto_objetivo'].toString()) ?? 0.0;
    final double ahorrado = double.tryParse(meta['monto_ahorrado_actual'].toString()) ?? 0.0;

    double progreso = 0.0;
    if (objetivo > 0) {
      progreso = (ahorrado / objetivo) * 100;
      if (progreso > 100) progreso = 100.0;
      progreso = double.parse(progreso.toStringAsFixed(1));
    }

    double mesesRestantes = -1.0;
    if (ahorrado >= objetivo) {
      mesesRestantes = 0.0;
    } else if (ahorrado > 0) {
      final DateTime fechaCreacion = DateTime.tryParse(meta['fecha_creacion']?.toString() ?? '') ?? DateTime.now();
      int diasDesdeCreacion = DateTime.now().difference(fechaCreacion).inDays;
      if (diasDesdeCreacion <= 0) diasDesdeCreacion = 1;

      final double faltante = objetivo - ahorrado;
      final double ritmoDiario = ahorrado / diasDesdeCreacion;
      final double ritmoMensual = ritmoDiario * 30.0;

      if (ritmoMensual > 0) {
        mesesRestantes = double.parse((faltante / ritmoMensual).toStringAsFixed(1));
      }
    }

    return {
      ...meta,
      'porcentaje_progreso': progreso,
      'meses_restantes_estimados': mesesRestantes,
    };
  }

  Map<String, dynamic> _serializeDeuda(Map<String, dynamic> deuda) {
    final double saldo = double.tryParse(deuda['monto_total'].toString()) ?? 0.0;
    final double tasa = double.tryParse(deuda['tasa_interes'].toString()) ?? 0.0;
    final double cuota = double.tryParse(deuda['cuota_mensual'].toString()) ?? 0.0;
    final String prPagoStr = deuda['fecha_proximo_pago'] ?? '';

    bool alerta = false;
    if (saldo > 0 && prPagoStr.isNotEmpty) {
      final DateTime? prPago = DateTime.tryParse(prPagoStr);
      if (prPago != null) {
        final hoy = DateTime.now();
        final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);
        final prPagoDate = DateTime(prPago.year, prPago.month, prPago.day);
        final dif = prPagoDate.difference(hoyDate).inDays;
        alerta = dif >= 0 && dif <= 5;
      }
    }

    int cuotasPendientes = 0;
    double interesTotal = 0.0;

    if (saldo > 0 && cuota > 0) {
      final double tasaDecimal = tasa / 100.0;
      if (cuota <= saldo * tasaDecimal) {
        cuotasPendientes = -1;
      } else {
        int cuotas = 0;
        double tempSaldo = saldo;
        while (tempSaldo > 0.01 && cuotas < 360) {
          final interesMes = tempSaldo * tasaDecimal;
          final abonoCapital = cuota - interesMes;
          if (abonoCapital <= 0) {
            cuotas = -1;
            break;
          }
          interesTotal += interesMes;
          if (tempSaldo < cuota) {
            tempSaldo = 0;
          } else {
            tempSaldo -= abonoCapital;
          }
          cuotas++;
        }
        cuotasPendientes = cuotas;
      }
    }

    interesTotal = double.parse(interesTotal.toStringAsFixed(2));
    final double totalAPagar = double.parse((saldo + (cuotasPendientes == -1 ? 0 : interesTotal)).toStringAsFixed(2));

    return {
      ...deuda,
      'alerta_pago_proximo': alerta,
      'cuotas_pendientes_estimadas': cuotasPendientes,
      'total_intereses_estimado': cuotasPendientes == -1 ? 0.0 : interesTotal,
      'total_a_pagar_estimado': totalAPagar,
    };
  }

  Map<String, dynamic> _serializeProyecto(Map<String, dynamic> proj) {
    final int projId = proj['id'];
    final List<Map<String, dynamic>> items = _itemsProyecto.where((item) => item['proyecto'] == projId).toList();
    double total = 0.0;
    for (var item in items) {
      final double qty = double.tryParse(item['cantidad'].toString()) ?? 0.0;
      final double price = double.tryParse(item['precio_unitario'].toString()) ?? 0.0;
      total += qty * price;
    }
    return {
      ...proj,
      'items': items,
      'costo_total': total,
    };
  }

  // SUGERENCIA DE AHORRO AL REGISTRAR INGRESO
  String? _getSugerenciaAhorro(String tipo, String categoria, double valMonto) {
    if (tipo != 'INGRESO') return null;

    final hoy = DateTime.now();
    final hoyDate = DateTime(hoy.year, hoy.month, hoy.day);
    Map<String, dynamic>? deudaUrgente;

    for (var d in _deudas) {
      final double totalDeuda = double.tryParse(d['monto_total'].toString()) ?? 0.0;
      final String prPagoStr = d['fecha_proximo_pago'] ?? '';
      if (totalDeuda > 0 && prPagoStr.isNotEmpty) {
        final prPago = DateTime.tryParse(prPagoStr);
        if (prPago != null) {
          final prPagoDate = DateTime(prPago.year, prPago.month, prPago.day);
          final dif = prPagoDate.difference(hoyDate).inDays;
          if (dif >= 0 && dif <= 5) {
            deudaUrgente = d;
            break;
          }
        }
      }
    }

    if (deudaUrgente != null) {
      final double totalD = double.tryParse(deudaUrgente['monto_total'].toString()) ?? 0.0;
      return "¡Atención! Fitki sugiere priorizar el pago de tu deuda '${deudaUrgente['nombre']}' por ${_formatearPesos(totalD)}. Considera abonar antes de ahorrar.";
    }

    if (_metas.isEmpty) {
      return "Crea una meta de ahorro para sugerirte aportes.";
    }

    final catUpper = categoria.toUpperCase();
    final sortedMetas = List<Map<String, dynamic>>.from(_metas);
    sortedMetas.sort((a, b) {
      final limA = DateTime.tryParse(a['fecha_limite'] ?? '') ?? DateTime(3000);
      final limB = DateTime.tryParse(b['fecha_limite'] ?? '') ?? DateTime(3000);
      final cmp = limA.compareTo(limB);
      if (cmp != 0) return cmp;
      final int idA = a['id'] ?? 0;
      final int idB = b['id'] ?? 0;
      return idA.compareTo(idB);
    });

    if (catUpper == 'SALARIO') {
      if (sortedMetas.length >= 2) {
        final m1 = sortedMetas[0];
        final m2 = sortedMetas[1];
        final sug1 = valMonto * 0.30;
        final sug2 = valMonto * 0.10;
        return "Fitki sugiere: Destina el 30% (${_formatearPesos(sug1)}) a tu meta '${m1['nombre']}' y el 10% (${_formatearPesos(sug2)}) a '${m2['nombre']}' por ser tu salario mensual.";
      } else {
        final m = sortedMetas[0];
        final sug = valMonto * 0.40;
        return "Fitki sugiere: Destina el 40% (${_formatearPesos(sug)}) a tu meta '${m['nombre']}' por ser tu salario mensual.";
      }
    } else if (catUpper == 'FREELANCE') {
      if (sortedMetas.length >= 2) {
        final m1 = sortedMetas[0];
        final m2 = sortedMetas[1];
        final sug1 = valMonto * 0.20;
        final sug2 = valMonto * 0.10;
        return "¡Buen trabajo en tu freelance! Fitki sugiere ahorrar un 30% total: destina 20% (${_formatearPesos(sug1)}) a '${m1['nombre']}' y 10% (${_formatearPesos(sug2)}) a '${m2['nombre']}'.";
      } else {
        final m = sortedMetas[0];
        final sug = valMonto * 0.30;
        return "¡Buen trabajo en tu freelance! Fitki sugiere destinar el 30% (${_formatearPesos(sug)}) a tu meta '${m['nombre']}'.";
      }
    } else {
      final m = sortedMetas[0];
      final sug = valMonto * 0.50;
      return "¡Dinero extra! Fitki sugiere destinar el 50% (${_formatearPesos(sug)}) a tu meta '${m['nombre']}' para alcanzarla más rápido.";
    }
  }

  // --- API DE AUTENTICACIÓN Y SESIONES ---

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

  Future<Map<String, dynamic>> register(String username, String email, String password, String nombre) async {
    await _init();
    _userProfile = {
      'username': username,
      'email': email,
      'password': password,
      'nombre': nombre,
    };
    await _save('user_profile', _userProfile);
    return {'success': true, 'data': _userProfile};
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    await _init();
    if (_userProfile == null) {
      return {'success': false, 'message': 'Usuario no registrado.'};
    }
    if (_userProfile!['username'] == username && _userProfile!['password'] == password) {
      await saveToken('dummy_local_token');
      return {'success': true};
    }
    return {'success': false, 'message': 'Credenciales incorrectas.'};
  }

  // --- API DEL DASHBOARD ---

  Future<Map<String, dynamic>> getDashboard() async {
    await _init();

    double totalCuentas = 0.0;
    for (var c in _cuentas) {
      totalCuentas += double.tryParse(c['saldo_actual'].toString()) ?? 0.0;
    }

    double totalDeudas = 0.0;
    for (var d in _deudas) {
      totalDeudas += double.tryParse(d['monto_total'].toString()) ?? 0.0;
    }

    double patrimonioNeto = totalCuentas - totalDeudas;

    double ingresosMes = 0.0;
    double gastosMes = 0.0;
    for (var tx in _transacciones) {
      if (_isInCurrentMonth(tx['fecha'])) {
        final monto = double.tryParse(tx['monto'].toString()) ?? 0.0;
        if (tx['tipo'] == 'INGRESO') {
          ingresosMes += monto;
        } else if (tx['tipo'] == 'GASTO') {
          gastosMes += monto;
        }
      }
    }

    final serializedCuentas = _cuentas;
    final serializedMetas = _metas.map((m) => _serializeMeta(m)).toList();
    final serializedDeudas = _deudas.map((d) => _serializeDeuda(d)).toList();

    // Ordenar movimientos por fecha e ID descendente
    final sortedTx = List<Map<String, dynamic>>.from(_transacciones);
    sortedTx.sort((a, b) {
      final DateTime dateA = DateTime.tryParse(a['fecha'] ?? '') ?? DateTime(1970);
      final DateTime dateB = DateTime.tryParse(b['fecha'] ?? '') ?? DateTime(1970);
      final cmp = dateB.compareTo(dateA);
      if (cmp != 0) return cmp;
      final int idA = a['id'] ?? 0;
      final int idB = b['id'] ?? 0;
      return idB.compareTo(idA);
    });

    final ultimasTransacciones = sortedTx.take(10).map((tx) {
      final account = _cuentas.firstWhere((c) => c['id'] == tx['cuenta'], orElse: () => {});
      return {
        ...tx,
        'cuenta_nombre': account['nombre_banco'] ?? 'Desconocida',
      };
    }).toList();

    return {
      'success': true,
      'data': {
        'patrimonio_neto': patrimonioNeto,
        'saldo_total_cuentas': totalCuentas,
        'total_deudas': totalDeudas,
        'ingresos_mes_actual': ingresosMes,
        'gastos_mes_actual': gastosMes,
        'cuentas': serializedCuentas,
        'metas': serializedMetas,
        'deudas': serializedDeudas,
        'ultimas_transacciones': ultimasTransacciones,
      }
    };
  }

  // --- API DE CUENTAS ---

  Future<Map<String, dynamic>> createCuenta(String nombreBanco, double saldoActual, String tipoCuenta) async {
    await _init();
    final newCuenta = {
      'id': _nextCuentaId++,
      'nombre_banco': nombreBanco,
      'saldo_actual': saldoActual,
      'tipo_cuenta': tipoCuenta,
      'fecha_actualizacion': DateTime.now().toUtc().toIso8601String(),
    };
    _cuentas.add(newCuenta);
    await _save('cuentas', _cuentas);
    return {'success': true, 'data': newCuenta};
  }

  // --- API DE TRANSACCIONES ---

  Future<Map<String, dynamic>> createTransaccion({
    required int cuentaId,
    required double monto,
    required String tipo,
    required String categoria,
    required String descripcion,
    int? metaId,
    int? deudaId,
  }) async {
    await _init();

    final cIdx = _cuentas.indexWhere((c) => c['id'] == cuentaId);
    if (cIdx == -1) {
      return {'success': false, 'message': 'La cuenta seleccionada no existe.'};
    }

    final double valMonto = monto;
    double saldo = double.tryParse(_cuentas[cIdx]['saldo_actual'].toString()) ?? 0.0;
    if (tipo == 'INGRESO') {
      saldo += valMonto;
    } else {
      saldo -= valMonto;
    }
    _cuentas[cIdx]['saldo_actual'] = saldo;
    _cuentas[cIdx]['fecha_actualizacion'] = DateTime.now().toUtc().toIso8601String();
    await _save('cuentas', _cuentas);

    // Si tiene meta de ahorro asociada y es un gasto (aporte a bolsillo)
    if (metaId != null && tipo == 'GASTO') {
      final mIdx = _metas.indexWhere((m) => m['id'] == metaId);
      if (mIdx != -1) {
        double ahorrado = double.tryParse(_metas[mIdx]['monto_ahorrado_actual'].toString()) ?? 0.0;
        ahorrado += valMonto;
        _metas[mIdx]['monto_ahorrado_actual'] = ahorrado;
        await _save('metas', _metas);
      }
    }

    // Si tiene deuda asociada y es un gasto (abono a deuda)
    if (deudaId != null && tipo == 'GASTO') {
      final dIdx = _deudas.indexWhere((d) => d['id'] == deudaId);
      if (dIdx != -1) {
        double totalDeuda = double.tryParse(_deudas[dIdx]['monto_total'].toString()) ?? 0.0;
        totalDeuda -= valMonto;
        if (totalDeuda < 0) totalDeuda = 0.0;
        _deudas[dIdx]['monto_total'] = totalDeuda;

        // Desplazamiento del próximo pago un mes
        final prPagoStr = _deudas[dIdx]['fecha_proximo_pago'] ?? '';
        if (totalDeuda > 0 && prPagoStr.isNotEmpty) {
          final DateTime? prPago = DateTime.tryParse(prPagoStr);
          if (prPago != null) {
            final DateTime nuevaFecha = _avanzarUnMes(prPago);
            final limStr = _deudas[dIdx]['fecha_limite'] ?? '';
            final DateTime? lim = DateTime.tryParse(limStr);
            if (lim == null || nuevaFecha.isBefore(lim) || nuevaFecha.isAtSameMomentAs(lim)) {
              _deudas[dIdx]['fecha_proximo_pago'] = nuevaFecha.toIso8601String().substring(0, 10);
            }
          }
        }
        await _save('deudas', _deudas);
      }
    }

    final String? sugAhorro = _getSugerenciaAhorro(tipo, categoria, valMonto);

    final newTx = {
      'id': _nextTransaccionId++,
      'cuenta': cuentaId,
      'monto': valMonto,
      'tipo': tipo,
      'categoria': categoria,
      'descripcion': descripcion,
      'fecha': DateTime.now().toUtc().toIso8601String(),
      if (metaId != null) 'meta_ahorro': metaId,
      if (deudaId != null) 'deuda': deudaId,
      'sugerencia_ahorro': sugAhorro,
    };
    _transacciones.add(newTx);
    await _save('transacciones', _transacciones);

    return {
      'success': true,
      'data': {
        ...newTx,
        'cuenta_nombre': _cuentas[cIdx]['nombre_banco'],
      }
    };
  }

  // --- API DE METAS DE AHORRO ---

  Future<Map<String, dynamic>> getMetas() async {
    await _init();
    final serialized = _metas.map((m) => _serializeMeta(m)).toList();
    return {'success': true, 'data': serialized};
  }

  Future<Map<String, dynamic>> createMeta(String nombre, double montoObjetivo, String fechaLimite) async {
    await _init();
    final newMeta = {
      'id': _nextMetaId++,
      'nombre': nombre,
      'monto_objetivo': montoObjetivo,
      'monto_ahorrado_actual': 0.0,
      'fecha_limite': fechaLimite,
      'fecha_creacion': DateTime.now().toUtc().toIso8601String(),
    };
    _metas.add(newMeta);
    await _save('metas', _metas);
    return {'success': true, 'data': _serializeMeta(newMeta)};
  }

  Future<Map<String, dynamic>> updateMeta(int id, String nombre, double montoObjetivo, String fechaLimite) async {
    await _init();
    final idx = _metas.indexWhere((m) => m['id'] == id);
    if (idx == -1) return {'success': false, 'message': 'Meta no encontrada.'};
    _metas[idx]['nombre'] = nombre;
    _metas[idx]['monto_objetivo'] = montoObjetivo;
    _metas[idx]['fecha_limite'] = fechaLimite;
    await _save('metas', _metas);
    return {'success': true, 'data': _serializeMeta(_metas[idx])};
  }

  Future<Map<String, dynamic>> deleteMeta(int id) async {
    await _init();
    _metas.removeWhere((m) => m['id'] == id);
    await _save('metas', _metas);
    return {'success': true};
  }

  // --- API DE DEUDAS ---

  Future<Map<String, dynamic>> getDeudas() async {
    await _init();
    final serialized = _deudas.map((d) => _serializeDeuda(d)).toList();
    return {'success': true, 'data': serialized};
  }

  Future<Map<String, dynamic>> createDeuda({
    required String nombre,
    required double montoTotal,
    required double tasaInteres,
    required double cuotaMensual,
    required String fechaProximoPago,
    String? fechaLimite,
  }) async {
    await _init();
    final newDeuda = {
      'id': _nextDeudaId++,
      'nombre': nombre,
      'monto_total': montoTotal,
      'tasa_interes': tasaInteres,
      'cuota_mensual': cuotaMensual,
      'fecha_proximo_pago': fechaProximoPago,
      if (fechaLimite != null && fechaLimite.isNotEmpty) 'fecha_limite': fechaLimite,
      'fecha_creacion': DateTime.now().toUtc().toIso8601String(),
    };
    _deudas.add(newDeuda);
    await _save('deudas', _deudas);
    return {'success': true, 'data': _serializeDeuda(newDeuda)};
  }

  Future<Map<String, dynamic>> updateDeuda({
    required int id,
    required String nombre,
    required double montoTotal,
    required double tasaInteres,
    required double cuotaMensual,
    required String fechaProximoPago,
    String? fechaLimite,
  }) async {
    await _init();
    final idx = _deudas.indexWhere((d) => d['id'] == id);
    if (idx == -1) return {'success': false, 'message': 'Deuda no encontrada.'};
    _deudas[idx]['nombre'] = nombre;
    _deudas[idx]['monto_total'] = montoTotal;
    _deudas[idx]['tasa_interes'] = tasaInteres;
    _deudas[idx]['cuota_mensual'] = cuotaMensual;
    _deudas[idx]['fecha_proximo_pago'] = fechaProximoPago;
    if (fechaLimite != null && fechaLimite.isNotEmpty) {
      _deudas[idx]['fecha_limite'] = fechaLimite;
    } else {
      _deudas[idx].remove('fecha_limite');
    }
    await _save('deudas', _deudas);
    return {'success': true, 'data': _serializeDeuda(_deudas[idx])};
  }

  Future<Map<String, dynamic>> deleteDeuda(int id) async {
    await _init();
    _deudas.removeWhere((d) => d['id'] == id);
    await _save('deudas', _deudas);
    return {'success': true};
  }

  // --- API DE ASISTENTE FINANCIERO (MOTOR DE REGLAS LOCAL) ---

  Future<Map<String, dynamic>> consultarAsistente(double monto) async {
    await _init();

    double saldoTotal = 0.0;
    for (var c in _cuentas) {
      saldoTotal += double.tryParse(c['saldo_actual'].toString()) ?? 0.0;
    }

    double gastosFijos = 0.0;
    for (var tx in _transacciones) {
      if (_isInCurrentMonth(tx['fecha']) && tx['tipo'] == 'GASTO') {
        final String cat = tx['categoria'] ?? '';
        if (cat == 'Vivienda' || cat == 'Servicios') {
          gastosFijos += double.tryParse(tx['monto'].toString()) ?? 0.0;
        }
      }
    }

    double cuotaDeudas = 0.0;
    for (var d in _deudas) {
      final double totalD = double.tryParse(d['monto_total'].toString()) ?? 0.0;
      if (totalD > 0) {
        cuotaDeudas += double.tryParse(d['cuota_mensual'].toString()) ?? 0.0;
      }
    }

    double aporteMetas = 0.0;
    for (var m in _metas) {
      aporteMetas += _calcularAporteMetaMensual(m);
    }

    final double cgl = saldoTotal - gastosFijos - cuotaDeudas - aporteMetas;
    final double montoCompra = monto;

    if (montoCompra <= cgl) {
      final double sobrante = cgl - montoCompra;
      final String sugerencia = "¡Dale! Te sobran ${_formatearPesos(sobrante)} después de cubrir tus metas y obligaciones.";
      return {
        'success': true,
        'data': {
          'aprobado': true,
          'status': 'approved',
          'cgl': cgl,
          'sobrante': sobrante,
          'articulo': 'artículo',
          'cantidad': 1,
          'precio_unitario': montoCompra,
          'monto': montoCompra,
          'sugerencia': sugerencia,
        }
      };
    } else {
      int cantidadViable = 0;
      if (cgl > 0) {
        cantidadViable = (cgl / montoCompra).floor();
      }

      String conflictoMsg = '';
      final sortedProyectos = List<Map<String, dynamic>>.from(_proyectos.where((p) => p['estado'] == 'PENDIENTE'));
      sortedProyectos.sort((a, b) {
        final dateA = DateTime.tryParse(a['fecha_ejecucion'] ?? '') ?? DateTime(3000);
        final dateB = DateTime.tryParse(b['fecha_ejecucion'] ?? '') ?? DateTime(3000);
        return dateA.compareTo(dateB);
      });

      for (var proj in sortedProyectos) {
        double cost = 0.0;
        final pId = proj['id'];
        for (var item in _itemsProyecto) {
          if (item['proyecto'] == pId) {
            final double qty = double.tryParse(item['cantidad'].toString()) ?? 0.0;
            final double price = double.tryParse(item['precio_unitario'].toString()) ?? 0.0;
            cost += qty * price;
          }
        }
        if (cgl + cost >= montoCompra) {
          final String pExec = proj['fecha_ejecucion'] ?? '';
          conflictoMsg = "Alerta: Si compras esto hoy, chocarás con el proyecto '${proj['nombre']}' planeado para el $pExec y no podrás pagarlo.";
          break;
        }
      }

      String retrasoMsg = '';
      final sortedMetas = List<Map<String, dynamic>>.from(_metas);
      sortedMetas.sort((a, b) {
        final limA = DateTime.tryParse(a['fecha_limite'] ?? '') ?? DateTime(3000);
        final limB = DateTime.tryParse(b['fecha_limite'] ?? '') ?? DateTime(3000);
        final cmp = limA.compareTo(limB);
        if (cmp != 0) return cmp;
        final int idA = a['id'] ?? 0;
        final int idB = b['id'] ?? 0;
        return idA.compareTo(idB);
      });

      if (sortedMetas.isNotEmpty) {
        final metaPrincipal = sortedMetas.first;
        final DateTime fechaCreacion = DateTime.tryParse(metaPrincipal['fecha_creacion']?.toString() ?? '') ?? DateTime.now();
        int diasCreacion = DateTime.now().difference(fechaCreacion).inDays;
        if (diasCreacion <= 0) diasCreacion = 1;

        final double ahorradoMeta = double.tryParse(metaPrincipal['monto_ahorrado_actual'].toString()) ?? 0.0;
        double ritmoMensual = 0.0;
        if (ahorradoMeta > 0) {
          final double ritmoDiario = ahorradoMeta / diasCreacion;
          ritmoMensual = ritmoDiario * 30.0;
        }

        if (ritmoMensual <= 0) {
          double ingresos = 0.0;
          for (var tx in _transacciones) {
            if (_isInCurrentMonth(tx['fecha']) && tx['tipo'] == 'INGRESO') {
              ingresos += double.tryParse(tx['monto'].toString()) ?? 0.0;
            }
          }
          ritmoMensual = ingresos * 0.10;
        }

        if (ritmoMensual <= 0) {
          ritmoMensual = 100000.0;
        }

        double mesesRetraso = montoCompra / ritmoMensual;
        if (mesesRetraso < 1) {
          mesesRetraso = 1.0;
        }
        String mesesRetrasoStr = '';
        if (mesesRetraso % 1 == 0) {
          mesesRetrasoStr = mesesRetraso.toInt().toString();
        } else {
          mesesRetrasoStr = mesesRetraso.toStringAsFixed(1);
        }
        retrasoMsg = "Alto. Si compras esto, retrasarás tu meta de '${metaPrincipal['nombre']}' $mesesRetrasoStr meses.";
      }

      String statusVeredicto = "rejected";
      String sugerencia = '';
      if (cantidadViable > 0) {
        statusVeredicto = "partially_approved";
        sugerencia = "No puedes comprar 1 unidades de 'artículo' (cuestan ${_formatearPesos(montoCompra)}), pero te alcanza para comprar $cantidadViable unidades.";
      } else {
        sugerencia = "No puedes comprar 'artículo' (cuesta ${_formatearPesos(montoCompra)}). Excede tu capacidad libre actual.";
      }

      if (conflictoMsg.isNotEmpty) {
        sugerencia += " $conflictoMsg";
      } else if (retrasoMsg.isNotEmpty) {
        sugerencia = retrasoMsg;
      }

      return {
        'success': true,
        'data': {
          'aprobado': false,
          'status': statusVeredicto,
          'cgl': cgl,
          'cantidad_viable': cantidadViable,
          'articulo': 'artículo',
          'precio_unitario': montoCompra,
          'monto': montoCompra,
          'sugerencia': sugerencia,
          'conflicto_detectado': conflictoMsg.isNotEmpty,
        }
      };
    }
  }

  Future<Map<String, dynamic>> consultarAsistenteTexto(String query, {double? saldoPrueba}) async {
    await _init();

    final String queryLower = query.toLowerCase();
    final bool isProjectQuery = queryLower.contains('proyecto');

    // 1. Obtener balance total de cuentas (o saldo_prueba si se provee)
    double saldoTotal = 0.0;
    if (saldoPrueba != null) {
      saldoTotal = saldoPrueba;
    } else {
      for (var c in _cuentas) {
        saldoTotal += double.tryParse(c['saldo_actual'].toString()) ?? 0.0;
      }
    }

    // 2. Gastos fijos (Vivienda + Servicios in this month)
    double gastosFijos = 0.0;
    for (var tx in _transacciones) {
      if (_isInCurrentMonth(tx['fecha']) && tx['tipo'] == 'GASTO') {
        final String cat = tx['categoria'] ?? '';
        if (cat == 'Vivienda' || cat == 'Servicios') {
          gastosFijos += double.tryParse(tx['monto'].toString()) ?? 0.0;
        }
      }
    }

    // 3. Cuotas de deudas activas
    double cuotaDeudas = 0.0;
    for (var d in _deudas) {
      final double totalD = double.tryParse(d['monto_total'].toString()) ?? 0.0;
      if (totalD > 0) {
        cuotaDeudas += double.tryParse(d['cuota_mensual'].toString()) ?? 0.0;
      }
    }

    // 4. Aporte metas
    double aporteMetas = 0.0;
    for (var m in _metas) {
      aporteMetas += _calcularAporteMetaMensual(m);
    }

    final double cgl = saldoTotal - gastosFijos - cuotaDeudas - aporteMetas;

    if (isProjectQuery) {
      String? projectName;
      final projQuotesReg = RegExp(r'''proyecto\s+['"]([^'"]+)['"]''', caseSensitive: false);
      final matchQuotes = projQuotesReg.firstMatch(query);
      if (matchQuotes != null) {
        projectName = matchQuotes.group(1)!.trim();
      } else {
        for (var p in _proyectos) {
          final pName = (p['nombre'] ?? '').toString().toLowerCase();
          if (pName.isNotEmpty && queryLower.contains(pName)) {
            projectName = p['nombre'];
            break;
          }
        }
        if (projectName == null) {
          final projWordsReg = RegExp(r'proyecto\s+(?:de\s+)?([a-zA-Z0-9_ ]+)', caseSensitive: false);
          final matchWords = projWordsReg.firstMatch(query);
          if (matchWords != null) {
            projectName = matchWords.group(1)!.trim();
          }
        }
      }

      Map<String, dynamic>? proyecto;
      if (projectName != null) {
        final String nameLower = projectName.toLowerCase();
        for (var p in _proyectos) {
          if ((p['nombre'] ?? '').toString().toLowerCase() == nameLower) {
            proyecto = p;
            break;
          }
        }
        if (proyecto == null) {
          for (var p in _proyectos) {
            if ((p['nombre'] ?? '').toString().toLowerCase().contains(nameLower)) {
              proyecto = p;
              break;
            }
          }
        }
      }

      if (proyecto == null) {
        return {
          'success': true,
          'data': {
            'aprobado': false,
            'status': 'rejected',
            'sugerencia': projectName == null
                ? "No logré identificar el nombre del proyecto en tu consulta. Por favor, especifícalo entre comillas simples o dobles. Ej: 'analiza mi proyecto \"Remodelación de Sala\"'."
                : "No encontré ningún proyecto con el nombre '$projectName'. Verifica que esté creado."
          }
        };
      }

      final int projId = proyecto['id'];
      double proyectoCosto = 0.0;
      int numItems = 0;
      for (var item in _itemsProyecto) {
        if (item['proyecto'] == projId) {
          final double qty = double.tryParse(item['cantidad'].toString()) ?? 0.0;
          final double price = double.tryParse(item['precio_unitario'].toString()) ?? 0.0;
          proyectoCosto += qty * price;
          numItems++;
        }
      }

      if (proyectoCosto <= cgl) {
        final otrosPendientes = _proyectos.where((p) => p['id'] != projId && p['estado'] == 'PENDIENTE').toList();
        double costoOtrosProyectos = 0.0;
        for (var op in otrosPendientes) {
          final opId = op['id'];
          for (var item in _itemsProyecto) {
            if (item['proyecto'] == opId) {
              final double qty = double.tryParse(item['cantidad'].toString()) ?? 0.0;
              final double price = double.tryParse(item['precio_unitario'].toString()) ?? 0.0;
              costoOtrosProyectos += qty * price;
            }
          }
        }

        final String dateStr = proyecto['fecha_ejecucion'] ?? '';

        String sugerencia = '';
        if (proyectoCosto + costoOtrosProyectos > cgl && otrosPendientes.isNotEmpty) {
          final conflictProj = otrosPendientes.first;
          sugerencia = "El proyecto '${proyecto['nombre']}' tiene un costo total de ${_formatearPesos(proyectoCosto)} (agrupando $numItems productos). Comparado con tu capacidad libre actual (${_formatearPesos(cgl)}), este proyecto es VIABLE de forma individual. Sin embargo, ten en cuenta que también tienes el proyecto '${conflictProj['nombre']}' pendiente (por ${_formatearPesos(costoOtrosProyectos)}). No podrás ejecutar ambos, ya que juntos suman ${_formatearPesos(proyectoCosto + costoOtrosProyectos)} y exceden tu capacidad de gasto libre. Te sugiero priorizar.";
        } else {
          sugerencia = "El proyecto '${proyecto['nombre']}' tiene un costo total de ${_formatearPesos(proyectoCosto)} (agrupando $numItems productos). Comparado con tu capacidad libre actual (${_formatearPesos(cgl)}), este proyecto es VIABLE. Te sobrarían ${_formatearPesos(cgl - proyectoCosto)} después de ejecutarlo. Sin embargo, ten en cuenta que la fecha límite es el $dateStr, asegúrate de tener el flujo de efectivo listo.";
        }

        return {
          'success': true,
          'data': {
            'aprobado': true,
            'status': 'approved',
            'cgl': cgl,
            'monto': proyectoCosto,
            'sugerencia': sugerencia,
          }
        };
      } else {
        double costoAlta = 0.0;
        for (var item in _itemsProyecto) {
          if (item['proyecto'] == projId && item['prioridad'] == 'ALTA') {
            final double qty = double.tryParse(item['cantidad'].toString()) ?? 0.0;
            final double price = double.tryParse(item['precio_unitario'].toString()) ?? 0.0;
            costoAlta += qty * price;
          }
        }

        String sugerencia = '';
        if (costoAlta > 0 && costoAlta <= cgl) {
          sugerencia = "El proyecto cuesta ${_formatearPesos(proyectoCosto)}, pero tu capacidad libre es ${_formatearPesos(cgl)}. No puedes ejecutarlo completo. Te sugiero priorizar los productos de 'Alta' prioridad dentro de este proyecto, que suman ${_formatearPesos(costoAlta)}, y dejar los de menor prioridad para el próximo mes.";
        } else {
          sugerencia = "El proyecto cuesta ${_formatearPesos(proyectoCosto)}, pero tu capacidad libre es ${_formatearPesos(cgl)}. No puedes ejecutarlo completo y tu capacidad no cubre los productos prioritarios. Considera aplazarlo.";
        }

        return {
          'success': true,
          'data': {
            'aprobado': false,
            'status': 'rejected',
            'cgl': cgl,
            'monto': proyectoCosto,
            'sugerencia': sugerencia,
          }
        };
      }
    }

    final parsed = _parseConsulta(query);
    final String articulo = parsed['articulo'];
    final int cantidad = parsed['cantidad'];
    final double precioUnitario = parsed['precio_unitario'];
    final double montoCompra = cantidad * precioUnitario;

    if (precioUnitario == 0.0) {
      return {
        'success': true,
        'data': {
          'aprobado': false,
          'status': 'rejected',
          'sugerencia': "No logré identificar el precio de la compra en tu mensaje. Por favor, asegúrate de incluir el valor con puntos o plano. Ej: 'comprar reloj 350.000' o 'comprar bolso 150000'."
        }
      };
    }

    if (montoCompra <= cgl) {
      final double sobrante = cgl - montoCompra;
      final String sugerencia = "¡Dale! Te sobran ${_formatearPesos(sobrante)} después de cubrir tus metas y obligaciones.";
      return {
        'success': true,
        'data': {
          'aprobado': true,
          'status': 'approved',
          'cgl': cgl,
          'sobrante': sobrante,
          'articulo': articulo,
          'cantidad': cantidad,
          'precio_unitario': precioUnitario,
          'monto': montoCompra,
          'sugerencia': sugerencia,
        }
      };
    } else {
      int cantidadViable = 0;
      if (precioUnitario > 0 && cgl > 0) {
        cantidadViable = (cgl / precioUnitario).floor();
      }

      String conflictoMsg = '';
      final sortedProyectos = List<Map<String, dynamic>>.from(_proyectos.where((p) => p['estado'] == 'PENDIENTE'));
      sortedProyectos.sort((a, b) {
        final dateA = DateTime.tryParse(a['fecha_ejecucion'] ?? '') ?? DateTime(3000);
        final dateB = DateTime.tryParse(b['fecha_ejecucion'] ?? '') ?? DateTime(3000);
        return dateA.compareTo(dateB);
      });

      for (var proj in sortedProyectos) {
        double cost = 0.0;
        final pId = proj['id'];
        for (var item in _itemsProyecto) {
          if (item['proyecto'] == pId) {
            final double qty = double.tryParse(item['cantidad'].toString()) ?? 0.0;
            final double price = double.tryParse(item['precio_unitario'].toString()) ?? 0.0;
            cost += qty * price;
          }
        }
        if (cgl + cost >= montoCompra) {
          final String pExec = proj['fecha_ejecucion'] ?? '';
          conflictoMsg = "Alerta: Si compras esto hoy, chocarás con el proyecto '${proj['nombre']}' planeado para el $pExec y no podrás pagarlo.";
          break;
        }
      }

      String retrasoMsg = '';
      final sortedMetas = List<Map<String, dynamic>>.from(_metas);
      sortedMetas.sort((a, b) {
        final limA = DateTime.tryParse(a['fecha_limite'] ?? '') ?? DateTime(3000);
        final limB = DateTime.tryParse(b['fecha_limite'] ?? '') ?? DateTime(3000);
        final cmp = limA.compareTo(limB);
        if (cmp != 0) return cmp;
        final int idA = a['id'] ?? 0;
        final int idB = b['id'] ?? 0;
        return idA.compareTo(idB);
      });

      if (sortedMetas.isNotEmpty) {
        final metaPrincipal = sortedMetas.first;
        final DateTime fechaCreacion = DateTime.tryParse(metaPrincipal['fecha_creacion']?.toString() ?? '') ?? DateTime.now();
        int diasCreacion = DateTime.now().difference(fechaCreacion).inDays;
        if (diasCreacion <= 0) diasCreacion = 1;

        final double ahorradoMeta = double.tryParse(metaPrincipal['monto_ahorrado_actual'].toString()) ?? 0.0;
        double ritmoMensual = 0.0;
        if (ahorradoMeta > 0) {
          final double ritmoDiario = ahorradoMeta / diasCreacion;
          ritmoMensual = ritmoDiario * 30.0;
        }

        if (ritmoMensual <= 0) {
          double ingresos = 0.0;
          for (var tx in _transacciones) {
            if (_isInCurrentMonth(tx['fecha']) && tx['tipo'] == 'INGRESO') {
              ingresos += double.tryParse(tx['monto'].toString()) ?? 0.0;
            }
          }
          ritmoMensual = ingresos * 0.10;
        }

        if (ritmoMensual <= 0) {
          ritmoMensual = 100000.0;
        }

        double mesesRetraso = montoCompra / ritmoMensual;
        if (mesesRetraso < 1) {
          mesesRetraso = 1.0;
        }
        String mesesRetrasoStr = '';
        if (mesesRetraso % 1 == 0) {
          mesesRetrasoStr = mesesRetraso.toInt().toString();
        } else {
          mesesRetrasoStr = mesesRetraso.toStringAsFixed(1);
        }
        retrasoMsg = "Alto. Si compras esto, retrasarás tu meta de '${metaPrincipal['nombre']}' $mesesRetrasoStr meses.";
      }

      String statusVeredicto = "rejected";
      String sugerencia = '';
      if (cantidadViable > 0) {
        statusVeredicto = "partially_approved";
        sugerencia = "No puedes comprar $cantidad unidades de '$articulo' (cuestan ${_formatearPesos(montoCompra)}), pero te alcanza para comprar $cantidadViable unidades.";
      } else {
        sugerencia = "No puedes comprar '$articulo' (cuesta ${_formatearPesos(montoCompra)}). Excede tu capacidad libre actual.";
      }

      if (conflictoMsg.isNotEmpty) {
        sugerencia += " $conflictoMsg";
      } else if (retrasoMsg.isNotEmpty) {
        sugerencia = retrasoMsg;
      }

      return {
        'success': true,
        'data': {
          'aprobado': false,
          'status': statusVeredicto,
          'cgl': cgl,
          'cantidad_viable': cantidadViable,
          'articulo': articulo,
          'precio_unitario': precioUnitario,
          'monto': montoCompra,
          'sugerencia': sugerencia,
          'conflicto_detectado': conflictoMsg.isNotEmpty,
        }
      };
    }
  }

  // --- API DE PROYECTOS DE COMPRA (COTIZACIONES) ---

  Future<Map<String, dynamic>> getProyectosCompra() async {
    await _init();
    final serialized = _proyectos.map((p) => _serializeProyecto(p)).toList();
    return {'success': true, 'data': serialized};
  }

  Future<Map<String, dynamic>> createProyectoCompra(
    String nombre,
    String descripcion,
    String proveedor,
    String fechaEjecucion,
    String prioridad,
    String estado,
    String notas,
    String etiquetas,
  ) async {
    await _init();
    final newProj = {
      'id': _nextProyectoId++,
      'nombre': nombre,
      'descripcion': descripcion,
      'proveedor': proveedor,
      'fecha_ejecucion': fechaEjecucion,
      'prioridad': prioridad,
      'estado': estado,
      'notas': notas,
      'etiquetas': etiquetas,
      'fecha_creacion': DateTime.now().toUtc().toIso8601String(),
    };
    _proyectos.add(newProj);
    await _save('proyectos', _proyectos);
    return {'success': true, 'data': _serializeProyecto(newProj)};
  }

  Future<Map<String, dynamic>> updateProyectoCompra(
    int id,
    String nombre,
    String descripcion,
    String proveedor,
    String fechaEjecucion,
    String prioridad,
    String estado,
    String notas,
    String etiquetas,
  ) async {
    await _init();
    final idx = _proyectos.indexWhere((p) => p['id'] == id);
    if (idx == -1) return {'success': false, 'message': 'Proyecto no encontrado.'};
    _proyectos[idx]['nombre'] = nombre;
    _proyectos[idx]['descripcion'] = descripcion;
    _proyectos[idx]['proveedor'] = proveedor;
    _proyectos[idx]['fecha_ejecucion'] = fechaEjecucion;
    _proyectos[idx]['prioridad'] = prioridad;
    _proyectos[idx]['estado'] = estado;
    _proyectos[idx]['notas'] = notas;
    _proyectos[idx]['etiquetas'] = etiquetas;
    await _save('proyectos', _proyectos);
    return {'success': true, 'data': _serializeProyecto(_proyectos[idx])};
  }

  Future<Map<String, dynamic>> deleteProyectoCompra(int id) async {
    await _init();
    _proyectos.removeWhere((p) => p['id'] == id);
    _itemsProyecto.removeWhere((item) => item['proyecto'] == id);
    await _save('proyectos', _proyectos);
    await _save('items_proyecto', _itemsProyecto);
    return {'success': true};
  }

  // --- API DE PRODUCTOS DE PROYECTO ---

  Future<Map<String, dynamic>> createItemProyecto(
    int proyectoId,
    String articulo,
    int cantidad,
    double precioUnitario,
    String prioridad,
    String nota,
  ) async {
    await _init();
    final double cost = cantidad * precioUnitario;
    final newItem = {
      'id': _nextItemId++,
      'proyecto': proyectoId,
      'articulo': articulo,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'costo_total': cost,
      'prioridad': prioridad,
      'nota': nota,
      'fecha_creacion': DateTime.now().toUtc().toIso8601String(),
    };
    _itemsProyecto.add(newItem);
    await _save('items_proyecto', _itemsProyecto);
    return {'success': true, 'data': newItem};
  }

  Future<Map<String, dynamic>> updateItemProyecto(
    int id,
    int proyectoId,
    String articulo,
    int cantidad,
    double precioUnitario,
    String prioridad,
    String nota,
  ) async {
    await _init();
    final idx = _itemsProyecto.indexWhere((item) => item['id'] == id);
    if (idx == -1) return {'success': false, 'message': 'Producto no encontrado.'};
    final double cost = cantidad * precioUnitario;
    _itemsProyecto[idx]['proyecto'] = proyectoId;
    _itemsProyecto[idx]['articulo'] = articulo;
    _itemsProyecto[idx]['cantidad'] = cantidad;
    _itemsProyecto[idx]['precio_unitario'] = precioUnitario;
    _itemsProyecto[idx]['costo_total'] = cost;
    _itemsProyecto[idx]['prioridad'] = prioridad;
    _itemsProyecto[idx]['nota'] = nota;
    await _save('items_proyecto', _itemsProyecto);
    return {'success': true, 'data': _itemsProyecto[idx]};
  }

  Future<Map<String, dynamic>> deleteItemProyecto(int id) async {
    await _init();
    _itemsProyecto.removeWhere((item) => item['id'] == id);
    await _save('items_proyecto', _itemsProyecto);
    return {'success': true};
  }
}
