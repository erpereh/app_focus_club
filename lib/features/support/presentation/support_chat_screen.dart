import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../application/support_chat_view_model.dart';
import '../application/support_scope.dart';
import '../data/support_repository.dart';
import '../domain/support_conversation.dart';
import '../domain/support_message.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    required this.conversation,
    required this.uid,
    super.key,
  });

  final SupportConversation conversation;
  final String uid;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _messageController = TextEditingController();
  SupportChatViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel ??= SupportChatViewModel(
      repository: SupportScope.of(context),
      conversationId: widget.conversation.id,
    )..start();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final viewModel = _viewModel!;
    final didSend = await viewModel.sendMessage(_messageController.text);
    if (!mounted) return;
    if (didSend) {
      _messageController.clear();
    } else if (viewModel.state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(supportErrorMessage(viewModel.state.error!))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.conversation.subject.isEmpty
              ? 'Conversación'
              : widget.conversation.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final state = viewModel.state;
            return Column(
              children: [
                if (widget.conversation.isClosed)
                  const _ClosedConversationLabel(),
                Expanded(
                  child: _MessageList(state: state, uid: widget.uid),
                ),
                _Composer(
                  controller: _messageController,
                  isSending: state.isSending,
                  onSend: _send,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClosedConversationLabel extends StatelessWidget {
  const _ClosedConversationLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.input,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Text(
        'Conversación cerrada',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state, required this.uid});

  final SupportChatState state;
  final String uid;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudo cargar la conversación. Inténtalo de nuevo en unos minutos.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    if (state.messages.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay mensajes.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      itemCount: state.messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _MessageBubble(
        message: state.messages[index],
        isCustomer: state.messages[index].senderId == uid,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isCustomer});

  final SupportMessage message;
  final bool isCustomer;

  @override
  Widget build(BuildContext context) {
    final alignment = isCustomer ? Alignment.centerRight : Alignment.centerLeft;
    final background = isCustomer ? AppTheme.emerald : AppTheme.surfaceElevated;
    final foreground = isCustomer ? AppTheme.background : AppTheme.textPrimary;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isCustomer ? 18 : 4),
              bottomRight: Radius.circular(isCustomer ? 4 : 18),
            ),
            border: isCustomer ? null : Border.all(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(
              message.text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Enviar mensaje',
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
