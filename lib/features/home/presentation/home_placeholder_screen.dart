import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Focus Club')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StatusPill(label: 'Siguiente tanda'),
              const SizedBox(height: 28),
              Text('Dashboard en preparacion', style: textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'El acceso ya queda preparado para continuar con Inicio, Citas y Perfil.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              const _ReadinessPanel(),
              const Spacer(),
              FilledButton(
                onPressed: () {},
                child: const Text('Preparado para empezar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppTheme.emerald),
        ),
      ),
    );
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Siguiente paso', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Construir la navegacion inferior y las pantallas principales con datos mock.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
