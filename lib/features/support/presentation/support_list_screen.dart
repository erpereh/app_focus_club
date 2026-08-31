import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_segmented_control.dart';
import '../../../theme/app_theme.dart';
import '../application/suggestion_view_model.dart';
import '../application/support_conversations_view_model.dart';
import '../application/support_scope.dart';
import '../domain/support_conversation.dart';
import 'new_support_conversation_screen.dart';
import 'suggestion_form.dart';
import 'support_chat_screen.dart';

class SupportListScreen extends StatefulWidget {
  const SupportListScreen({
    required this.viewModel,
    required this.uid,
    super.key,
  });

  final SupportConversationsViewModel viewModel;
  final String uid;

  @override
  State<SupportListScreen> createState() => _SupportListScreenState();
}

class _SupportListScreenState extends State<SupportListScreen> {
  final _suggestionFormKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  SuggestionViewModel? _suggestionViewModel;
  int _sectionIndex = 0;

  SupportConversationsViewModel get viewModel => widget.viewModel;
  String get uid => widget.uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _suggestionViewModel ??= SuggestionViewModel(
      repository: SupportScope.of(context),
    );
  }

  @override
  void dispose() {
    _suggestionViewModel?.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

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
    final suggestionViewModel = _suggestionViewModel;
    if (suggestionViewModel == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: FocusSegmentedControl<int>(
              options: const [
                FocusSegmentOption(value: 0, label: 'Chat'),
                FocusSegmentOption(value: 1, label: 'Sugerencias'),
              ],
              selectedValue: _sectionIndex,
              onChanged: (value) => setState(() => _sectionIndex = value),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _sectionIndex,
              children: [
                _buildChat(context),
                SuggestionForm(
                  viewModel: suggestionViewModel,
                  subjectController: _subjectController,
                  messageController: _messageController,
                  formKey: _suggestionFormKey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(BuildContext context) {
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final titleStyle = Theme.of(
                          context,
                        ).textTheme.headlineLarge;
                        final title = Text(
                          'Chat',
                          key: const Key('chat-header-title'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        );
                        if (state.conversations.isEmpty) return title;
                        final actionStyle = Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                              color: AppTheme.onLime,
                              fontWeight: FontWeight.w700,
                            );
                        final pill = Material(
                          key: const Key('new-conversation-pill'),
                          color: AppTheme.lime,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                          child: InkWell(
                            onTap: () => _openNewConversation(context),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(
                                'Nueva conversación',
                                maxLines: 1,
                                softWrap: false,
                                textWidthBasis: TextWidthBasis.longestLine,
                                style: actionStyle,
                              ),
                            ),
                          ),
                        );
                        final pillWidth =
                            _singleLineWidth(
                              'Nueva conversación',
                              actionStyle,
                              MediaQuery.textScalerOf(context),
                            ) +
                            24;
                        if (pillWidth + 8 <= constraints.maxWidth) {
                          return Row(
                            children: [
                              Expanded(child: title),
                              const SizedBox(width: 8),
                              pill,
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, const SizedBox(height: 12), pill],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Habla directamente con el equipo de Focus Club.',
                      style: Theme.of(context).textTheme.bodyLarge,
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
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppTheme.border),
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
        : AppTheme.success;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppTheme.black,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(
                  Icons.forum_rounded,
                  color: AppTheme.lime,
                  size: 20,
                ),
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
                    maxLines: 2,
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
                      Flexible(
                        fit: FlexFit.loose,
                        child: _StatusPill(
                          label: conversation.isClosed ? 'Cerrada' : 'Abierta',
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _shortDate(conversation.lastMessageAt),
                          maxLines: 1,
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
          maxLines: 1,
          softWrap: false,
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
        color: AppTheme.lime,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 24,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.onLime,
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

double _singleLineWidth(String text, TextStyle? style, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: textScaler,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
