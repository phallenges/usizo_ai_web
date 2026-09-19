import 'package:flutter/material.dart';

import '../l10n/localized.dart';
import '../models/remedy.dart';
import '../services/app_store.dart';
import '../services/backend_api.dart';
import '../services/symptom_checker.dart';
import '../widgets/premium_banner.dart';
import '../widgets/usizo_logo.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({
    required this.store,
    required this.remedies,
    required this.checker,
    this.onUpgrade,
    super.key,
  });

  final AppStore store;
  final List<Remedy> remedies;
  final SymptomChecker checker;
  final VoidCallback? onUpgrade;

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _ChatTurn {
  const _ChatTurn({required this.role, required this.content});

  final String role;
  final String content;
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _turns = <_ChatTurn>[
    const _ChatTurn(
      role: 'assistant',
      content:
          'I’m your UsizoAI guide. Tell me about a symptom or ask how to use the app. I can offer educational next steps grounded in the remedy library, but I cannot diagnose or prescribe.',
    ),
  ];
  var _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showUpgradeDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly chat limit reached'),
        content: const Text(
          'Free accounts get three health-chat requests per month. Upgrade to UsizoAI Plus for unlimited guidance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onUpgrade?.call();
            },
            child: const Text('Upgrade to Plus'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!widget.store.isPremium && widget.store.chatRequestsRemaining <= 0) {
      await _showUpgradeDialog();
      return;
    }

    setState(() {
      _turns.add(_ChatTurn(role: 'user', content: text));
      _controller.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      final result = await widget.store.backendApi.sendChat(
        messages: _turns
            .map((turn) => {'role': turn.role, 'content': turn.content})
            .toList(),
      );
      if (!mounted) return;
      if (!result.scopeRefused) widget.store.updateChatUsage(result);
      setState(
        () => _turns.add(
          _ChatTurn(role: 'assistant', content: result.reply),
        ),
      );
      _scrollToEnd();
    } on BackendApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 429) {
        await _showUpgradeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.detail)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The guidance service is unavailable. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                const UsizoLogo(size: 44, showText: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _timeGreeting,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        widget.store.profile.name.isEmpty
                            ? 'Your health, in context.'
                            : widget.store.profile.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xff153f36),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff153f36),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) => PremiumBanner(
                isPremium: widget.store.isPremium,
                onPressed: widget.onUpgrade ?? () {},
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) => Text(
                  widget.store.isPremium
                      ? 'Unlimited health chat with UsizoAI Plus'
                      : '${widget.store.chatRequestsRemaining} free chat checks left this month',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              itemCount: _turns.length,
              itemBuilder: (context, index) {
                final turn = _turns[index];
                final isUser = turn.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xff153f36)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: isUser
                          ? null
                          : Border.all(color: const Color(0x14153f36)),
                    ),
                    child: Text(
                      turn.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xff24352f),
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: context.tr('checker.hint'),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    if (hour < 22) return 'Good evening';
    return 'Good night';
  }
}
