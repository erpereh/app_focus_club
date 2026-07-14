import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../theme/app_theme.dart';
import '../application/support_conversations_view_model.dart';
import '../domain/support_conversation.dart';
import 'new_support_conversation_screen.dart';
import 'support_chat_screen.dart';

class SupportListScreen extends StatelessWidget {
  const SupportListScreen({
    required this.viewModel,
    required this.uid,
    super.key,
  });

  final SupportConversationsViewModel viewModel;
  final String uid;

  void _openNewConversation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewSupportConversationScreen(
          uid: uid,
          onConversationVisibilityChanged: (conversationId, isVisible) {
            if (isVisible) {
              viewModel.setActiveConversationId(conversationId);
            } else {
              viewModel.clearActiveConversationId(conversationId);
            }
          },
        ),
      ),
    );
  }

  void _openConversation(
    BuildContext context,
    SupportConversation conversation,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportChatScreen(
          conversation: conversation,
          uid: uid,
          onConversationVisibilityChanged: (conversationId, isVisible) {
            if (isVisible) {
              viewModel.setActiveConversationId(conversationId);
            } else {
              viewModel.clearActiveConversationId(conversationId);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final state = viewModel.state;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Chat',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Habla directamente con el equipo de Focus Club.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    FocusPrimaryButton(
                      label: 'Nueva conversación',
                      onPressed: () => _openNewConversation(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _ConversationContent(
                  state: state,
                  onNewConversation: () => _openNewConversation(context),
                  onOpenConversation: (conversation) =>
                      _openConversation(context, conversation),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.state,
    required this.onNewConversation,
    required this.onOpenConversation,
  });

  final SupportConversationsState state;
  final VoidCallback onNewConversation;
  final ValueChanged<SupportConversation> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
        children: const [
          FocusEmptyState(
            title: 'No se pudo cargar el chat',
            description: 'Inténtalo de nuevo en unos minutos.',
            icon: Icons.error_outline_rounded,
          ),
        ],
      );
    }
    if (state.conversations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
        children: [
          const FocusEmptyState(
            title: 'No tienes conversaciones todavía',
            description:
                'Abre una conversación con Focus Club para resolver dudas sobre bonos, reservas o tu cuenta.',
            icon: Icons.forum_outlined,
          ),
          const SizedBox(height: 18),
          FocusPrimaryButton(
            label: 'Nueva conversación',
            onPressed: onNewConversation,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
      itemCount: state.conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final conversation = state.conversations[index];
        return _ConversationCard(
          conversation: conversation,
          onTap: () => onOpenConversation(conversation),
        );
      },
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.onTap});

  final SupportConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = conversation.isClosed
        ? AppTheme.textSecondary
        : AppTheme.emerald;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: FocusGlassCard(
        padding: EdgeInsets.all(conversation.isClosed ? 14 : 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(Icons.forum_rounded, color: statusColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.subject.isEmpty
                        ? 'Conversación con Focus Club'
                        : conversation.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (!conversation.isClosed) ...[
                    const SizedBox(height: 5),
                    Text(
                      conversation.lastMessage.isEmpty
                          ? 'Sin mensajes todavía'
                          : conversation.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 11),
                  ] else
                    const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusPill(
                        label: conversation.isClosed ? 'Cerrada' : 'Abierta',
                        color: statusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _shortDate(conversation.lastMessageAt),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (conversation.unreadCustomerCount > 0) ...[
              const SizedBox(width: 10),
              _UnreadBadge(count: conversation.unreadCustomerCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.emerald,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 24,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.background,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

String _shortDate(DateTime? date) {
  if (date == null) return 'Ahora';
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} · $hour:$minute';
}
