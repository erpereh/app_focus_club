import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../application/support_chat_view_model.dart';
import '../application/support_scope.dart';
import '../data/support_repository.dart';
import '../domain/support_conversation.dart';
import '../domain/support_message.dart';
import 'new_support_conversation_screen.dart';

typedef SupportConversationVisibilityChanged =
    void Function(String conversationId, bool isVisible);

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    required this.conversation,
    required this.uid,
    this.onConversationVisibilityChanged,
    super.key,
  });

  final SupportConversation conversation;
  final String uid;
  final SupportConversationVisibilityChanged? onConversationVisibilityChanged;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _messageController = TextEditingController();
  SupportChatViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _notifyConversationVisibility(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel ??= SupportChatViewModel(
      repository: SupportScope.of(context),
      conversation: widget.conversation,
    )..start();
  }

  @override
  void dispose() {
    widget.onConversationVisibilityChanged?.call(widget.conversation.id, false);
    _messageController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  void _notifyConversationVisibility(bool isVisible) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onConversationVisibilityChanged?.call(
        widget.conversation.id,
        isVisible,
      );
    });
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

  void _openNewConversation() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NewSupportConversationScreen(
          uid: widget.uid,
          onConversationVisibilityChanged:
              widget.onConversationVisibilityChanged,
        ),
      ),
    );
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
            final conversation = state.conversation ?? widget.conversation;
            final isClosed = conversation.isClosed;
            return Column(
              children: [
                if (isClosed)
                  _ClosedConversationNotice(
                    onNewConversation: _openNewConversation,
                  ),
                Expanded(
                  child: _MessageList(state: state, uid: widget.uid),
                ),
                if (!isClosed)
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

class _ClosedConversationNotice extends StatelessWidget {
  const _ClosedConversationNotice({required this.onNewConversation});

  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: [
          Text(
            'Esta conversaci\u00f3n est\u00e1 cerrada.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Abre una nueva conversación si necesitas más ayuda.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onNewConversation,
            child: const Text('Nueva conversación'),
          ),
        ],
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
    final background = isCustomer ? AppTheme.black : AppTheme.white;
    final foreground = isCustomer ? AppTheme.onBlack : AppTheme.textPrimary;
    return Align(
      alignment: alignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth * 0.82;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < 300 ? maxWidth : 300,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isCustomer ? 18 : 4),
                  bottomRight: Radius.circular(isCustomer ? 4 : 18),
                ),
                border: isCustomer ? null : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Text(
                  message.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: foreground),
                ),
              ),
            ),
          );
        },
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
          color: AppTheme.white,
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
