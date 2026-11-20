import 'package:flutter/foundation.dart';

import '../datos/repositorio_productos.dart';
import '../datos/repositorio_ventas.dart';
import '../dominio/carrito.dart';
import '../dominio/dinero.dart';
import '../dominio/producto.dart';
import '../dominio/venta.dart';

class CajaViewModel extends ChangeNotifier {
  final RepositorioProductos productos;
  final RepositorioVentas ventas;
  Carrito carrito = Carrito();
  List<Producto> catalogo = [];
  String? mensaje;
  bool mensajeEsError = false;
  Venta? ultimaVenta;
  ResumenDia? corte;
  List<Map<String, Object?>> masVendidos = [];

  CajaViewModel(this.productos, this.ventas);

  Future<void> cargar({String filtro = ''}) async {
    catalogo = await productos.listar(filtro: filtro);
    notifyListeners();
  }

  void agregar(Producto p) {
    try {
      carrito.agregar(p);
      mensaje = null;
    } catch (e) {
      _error(e);
    }
    notifyListeners();
  }

  void quitar(String codigo) {
    carrito.quitar(codigo);
    notifyListeners();
  }

  void descuento(int porcentaje) {
    carrito.aplicarDescuento(porcentaje);
    notifyListeners();
  }

  Future<bool> cobrar(String textoPago) async {
    try {
      final pago = pesosACentavos(textoPago);
      ultimaVenta = await ventas.cobrar(carrito, pago);
      mensaje = 'Cambio: ${formatearPesos(ultimaVenta!.cambioCentavos)}';
      mensajeEsError = false;
      carrito = Carrito();
      await cargar();
      return true;
    } catch (e) {
      _error(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> cargarCorte() async {
    corte = await ventas.corteDelDia(DateTime.now());
    masVendidos = await ventas.masVendidos();
    notifyListeners();
  }

  void _error(Object e) {
    mensaje = e is FormatException ? e.message : e.toString();
    mensajeEsError = true;
  }
}
