import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta_dolores/datos/base_datos.dart';
import 'package:punto_venta_dolores/datos/repositorio_productos.dart';
import 'package:punto_venta_dolores/datos/repositorio_ventas.dart';
import 'package:punto_venta_dolores/dominio/carrito.dart';
import 'package:punto_venta_dolores/dominio/excepciones.dart';
import 'package:punto_venta_dolores/dominio/producto.dart';
import 'package:punto_venta_dolores/presentacion/caja_viewmodel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi; // SQLite en la computadora

  late Database db;
  late RepositorioProductos productos;
  late RepositorioVentas ventas;

  setUp(() async {
    db = await BaseDatos.abrir(ruta: inMemoryDatabasePath);
    productos = RepositorioProductos(db);
    ventas = RepositorioVentas(db);
    await productos.agregar(
        const Producto(codigo: 'NV-001', nombre: 'Nieve de limón', precioCentavos: 2500, existencias: 5));
  });

  tearDown(() => db.close());

  group('RepositorioProductos', () {
    test('guarda y busca producto', () async {
      final p = await productos.buscarPorCodigo('NV-001');
      expect(p!.nombre, 'Nieve de limón');
      expect(p.id, isNotNull);
    });

    test('código duplicado lanza excepción de dominio', () {
      expect(
          () => productos.agregar(
              const Producto(codigo: 'NV-001', nombre: 'Otra', precioCentavos: 100, existencias: 1)),
          throwsA(isA<CodigoDuplicadoException>()));
    });

    test('listar filtra por nombre o código', () async {
      await productos.agregar(
          const Producto(codigo: 'DU-001', nombre: 'Cajeta', precioCentavos: 1800, existencias: 50));
      expect((await productos.listar(filtro: 'caj')).single.codigo, 'DU-001');
      expect((await productos.listar()).length, 2);
    });

    test('bajo inventario: 2 y 50 existencias, límite 5 → solo 1 (reto)', () async {
      await productos.agregar(
          const Producto(codigo: 'X-2', nombre: 'Pocas', precioCentavos: 100, existencias: 2));
      await productos.agregar(
          const Producto(codigo: 'X-50', nombre: 'Muchas', precioCentavos: 100, existencias: 50));
      final bajos = await productos.bajoInventario();
      expect(bajos.map((p) => p.codigo), containsAll(['X-2', 'NV-001']));
      expect(bajos.any((p) => p.codigo == 'X-50'), false);
    });

    test('sembrarEjemplos no duplica si ya hay datos', () async {
      await productos.sembrarEjemplos();
      expect((await productos.listar()).length, 1);
    });
  });

  group('RepositorioVentas', () {
    test('cobrar descuenta inventario y registra venta', () async {
      final p = (await productos.buscarPorCodigo('NV-001'))!;
      final carrito = Carrito()..agregar(p, cantidad: 2);
      final venta = await ventas.cobrar(carrito, 10000);
      expect(venta.cambioCentavos, 5000);
      expect((await productos.buscarPorCodigo('NV-001'))!.existencias, 3);
    });

    test('si falla el cobro NO se descuenta inventario', () async {
      final p = (await productos.buscarPorCodigo('NV-001'))!;
      final carrito = Carrito()..agregar(p, cantidad: 2);
      await expectLater(ventas.cobrar(carrito, 100), throwsA(isA<PagoInsuficienteException>()));
      expect((await productos.buscarPorCodigo('NV-001'))!.existencias, 5);
    });

    test('vender las 5 y luego 1 más: la transacción revalida (reto)', () async {
      final p = (await productos.buscarPorCodigo('NV-001'))!;
      await ventas.cobrar(Carrito()..agregar(p, cantidad: 5), 20000);
      // el carrito usa el producto "viejo" (decía 5 existencias)
      final carritoViejo = Carrito()..agregar(p);
      await expectLater(
          ventas.cobrar(carritoViejo, 5000), throwsA(isA<ExistenciasInsuficientesException>()));
      final r = await ventas.corteDelDia(DateTime.now());
      expect(r.numeroVentas, 1); // la venta fallida no se guardó
    });

    test('corte del día suma ventas de hoy', () async {
      final p = (await productos.buscarPorCodigo('NV-001'))!;
      await ventas.cobrar(Carrito()..agregar(p), 2500);
      await ventas.cobrar(Carrito()..agregar(p, cantidad: 2), 5000);
      final r = await ventas.corteDelDia(DateTime.now());
      expect(r.numeroVentas, 2);
      expect(r.totalCentavos, 7500);
    });

    test('corte de otro día no cuenta las de hoy', () async {
      final p = (await productos.buscarPorCodigo('NV-001'))!;
      await ventas.cobrar(Carrito()..agregar(p), 2500);
      final r = await ventas.corteDelDia(DateTime.now().subtract(const Duration(days: 1)));
      expect(r.numeroVentas, 0);
      expect(r.totalCentavos, 0);
    });

    test('más vendidos ordena por unidades', () async {
      await productos.agregar(
          const Producto(codigo: 'DU-001', nombre: 'Cajeta', precioCentavos: 1800, existencias: 50));
      final nieve = (await productos.buscarPorCodigo('NV-001'))!;
      final cajeta = (await productos.buscarPorCodigo('DU-001'))!;
      await ventas.cobrar(Carrito()..agregar(cajeta, cantidad: 3), 10000);
      await ventas.cobrar(Carrito()..agregar(nieve), 2500);
      final top = await ventas.masVendidos();
      expect(top.first['nombre'], 'Cajeta');
      expect(top.first['unidades'], 3);
    });

    test('bajo inventario alerta', () async {
      expect((await productos.bajoInventario()).length, 1);
    });
  });

  group('CajaViewModel', () {
    test('cobrar con texto calcula el cambio y vacía el carrito', () async {
      final vm = CajaViewModel(productos, ventas);
      await vm.cargar();
      vm.agregar(vm.catalogo.first);
      vm.agregar(vm.catalogo.first);
      expect(await vm.cobrar('100'), true);
      expect(vm.mensaje, 'Cambio: \$50.00');
      expect(vm.carrito.estaVacio, true);
      expect(vm.catalogo.first.existencias, 3);
    });

    test('pago corto muestra mensaje y no cobra', () async {
      final vm = CajaViewModel(productos, ventas);
      await vm.cargar();
      vm.agregar(vm.catalogo.first);
      expect(await vm.cobrar('10'), false);
      expect(vm.mensaje, contains('Faltan'));
      expect(vm.carrito.estaVacio, false);
    });

    test('agregar más de lo que hay muestra mensaje', () async {
      final vm = CajaViewModel(productos, ventas);
      await vm.cargar();
      for (var i = 0; i < 6; i++) {
        vm.agregar(vm.catalogo.first);
      }
      expect(vm.mensaje, 'Solo quedan 5 de Nieve de limón');
      expect(vm.carrito.lineas.single.cantidad, 5);
    });

    test('pago con texto inválido muestra mensaje amable', () async {
      final vm = CajaViewModel(productos, ventas);
      await vm.cargar();
      vm.agregar(vm.catalogo.first);
      expect(await vm.cobrar('abc'), false);
      expect(vm.mensaje, 'Monto inválido: abc');
    });
  });
}
