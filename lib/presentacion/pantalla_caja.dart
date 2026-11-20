import 'package:flutter/material.dart';

import '../dominio/dinero.dart';
import 'caja_viewmodel.dart';
import 'pantalla_corte.dart';

class PantallaCaja extends StatefulWidget {
  final CajaViewModel vm;

  const PantallaCaja({super.key, required this.vm});

  @override
  State<PantallaCaja> createState() => _PantallaCajaState();
}

class _PantallaCajaState extends State<PantallaCaja> {
  final _pago = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.vm.cargar();
  }

  @override
  void dispose() {
    _pago.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Caja · Dolores Hidalgo'),
          actions: [
            IconButton(
              tooltip: 'Corte del día',
              icon: const Icon(Icons.receipt_long),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => PantallaCorte(vm: vm))),
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar producto'),
              onChanged: (t) => vm.cargar(filtro: t),
            ),
          ),
          Expanded(
            child: ListView(children: [
              for (final p in vm.catalogo)
                ListTile(
                  leading: Icon(p.existencias <= 5 ? Icons.warning_amber : Icons.icecream,
                      color: p.existencias <= 5 ? Colors.orange : null),
                  title: Text(p.nombre),
                  subtitle: Text('${p.codigo} · ${p.existencias} disponibles'),
                  trailing: Text(formatearPesos(p.precioCentavos)),
                  onTap: p.existencias == 0 ? null : () => vm.agregar(p),
                ),
            ]),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView(shrinkWrap: true, children: [
              for (final l in vm.carrito.lineas)
                ListTile(
                  dense: true,
                  title: Text('${l.cantidad} × ${l.producto.nombre}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(formatearPesos(l.importeCentavos)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => vm.quitar(l.producto.codigo)),
                  ]),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('IVA incluido: ${formatearPesos(vm.carrito.ivaCentavos)}'),
                DropdownButton<int>(
                  value: vm.carrito.descuentoPct,
                  items: const [0, 5, 10, 15]
                      .map((d) => DropdownMenuItem(value: d, child: Text('Desc. $d %')))
                      .toList(),
                  onChanged: (d) => vm.descuento(d ?? 0),
                ),
              ]),
              Text('TOTAL ${formatearPesos(vm.carrito.totalCentavos)}',
                  style: Theme.of(context).textTheme.headlineSmall),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('pago'),
                    controller: _pago,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Paga con \$'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () async {
                    if (await vm.cobrar(_pago.text)) _pago.clear();
                  },
                  child: const Text('Cobrar'),
                ),
              ]),
              if (vm.mensaje != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(vm.mensaje!,
                      style: TextStyle(
                          color: vm.mensajeEsError ? Colors.red.shade700 : Colors.green.shade800,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
