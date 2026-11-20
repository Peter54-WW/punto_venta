import 'package:flutter/material.dart';

import '../dominio/dinero.dart';
import 'caja_viewmodel.dart';

/// Reto: pantalla de "Corte del día" con total, IVA, número de ventas y más vendidos.
class PantallaCorte extends StatefulWidget {
  final CajaViewModel vm;

  const PantallaCorte({super.key, required this.vm});

  @override
  State<PantallaCorte> createState() => _PantallaCorteState();
}

class _PantallaCorteState extends State<PantallaCorte> {
  @override
  void initState() {
    super.initState();
    widget.vm.cargarCorte();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final c = vm.corte;
        return Scaffold(
          appBar: AppBar(title: const Text('Corte del día')),
          body: c == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ventas: ${c.numeroVentas}', style: Theme.of(context).textTheme.titleLarge),
                        Text('Total: ${formatearPesos(c.totalCentavos)}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text('IVA: ${formatearPesos(c.ivaCentavos)}'),
                        Text('Subtotal: ${formatearPesos(c.totalCentavos - c.ivaCentavos)}'),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Más vendidos', style: Theme.of(context).textTheme.titleMedium),
                  if (vm.masVendidos.isEmpty) const Text('Todavía no hay ventas.'),
                  for (final f in vm.masVendidos)
                    ListTile(
                      leading: const Icon(Icons.star),
                      title: Text('${f['nombre']}'),
                      trailing: Text('${f['unidades']} u.'),
                    ),
                ]),
        );
      },
    );
  }
}
