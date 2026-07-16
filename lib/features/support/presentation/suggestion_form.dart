import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../application/suggestion_view_model.dart';

class SuggestionForm extends StatelessWidget {
  const SuggestionForm({
    required this.viewModel,
    required this.subjectController,
    required this.messageController,
    required this.formKey,
    super.key,
  });

  final SuggestionViewModel viewModel;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final GlobalKey<FormState> formKey;

  Future<void> _submit(BuildContext context) async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final succeeded = await viewModel.submit();
    if (succeeded && context.mounted) {
      subjectController.clear();
      messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        return Form(
          key: formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            children: [
              Text(
                'Buzón de sugerencias',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Tu opinión nos ayuda a mejorar Focus Club. Envíanos cualquier sugerencia o comentario.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              TextFormField(
                key: const Key('suggestion-subject'),
                controller: subjectController,
                enabled: !state.isSubmitting,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                onChanged: viewModel.updateSubject,
                decoration: const InputDecoration(
                  labelText: 'Asunto (opcional)',
                  hintText: 'Ej. Horarios o nuevas actividades',
                ),
                validator: (value) => (value?.trim().length ?? 0) > 120
                    ? 'El asunto no puede superar 120 caracteres.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('suggestion-message'),
                controller: messageController,
                enabled: !state.isSubmitting,
                minLines: 5,
                maxLines: 8,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onChanged: viewModel.updateMessage,
                decoration: const InputDecoration(
                  labelText: 'Sugerencia o comentario',
                  alignLabelWithHint: true,
                  hintText: 'Cuéntanos qué podríamos mejorar.',
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 3) return 'Escribe al menos 3 caracteres.';
                  if (length > 2000) {
                    return 'El mensaje no puede superar 2.000 caracteres.';
                  }
                  return null;
                },
              ),
              if (state.isSuccess) ...[
                const SizedBox(height: 6),
                const FocusStatusMessage(
                  message: 'Gracias. Hemos recibido tu sugerencia.',
                  type: FocusStatusType.success,
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 6),
                FocusStatusMessage(
                  message: state.errorMessage!,
                  type: FocusStatusType.error,
                ),
              ],
              const SizedBox(height: 22),
              FocusPrimaryButton(
                label: 'Enviar sugerencia',
                isLoading: state.isSubmitting,
                onPressed: state.isSubmitting ? null : () => _submit(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
