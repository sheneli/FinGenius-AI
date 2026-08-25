import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../app/config/feature_flags.dart';
import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/networking/connectivity_provider.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/ai_gateway.dart';
import '../data/fallback_factory.dart';
import '../domain/assistant_engine.dart';

class _ChatMessage {
  const _ChatMessage(this.role, this.text, {this.retryText});
  final String role; // user | model | action | error
  final String text;

  /// For error bubbles: the original question, so Retry can resend it.
  final String? retryText;
}

final aiGatewayProvider = Provider<AiGateway?>((ref) {
  final boxes = ref.watch(userBoxesProvider).valueOrNull;
  if (boxes == null) return null;
  return AiGateway(
    flags: ref.watch(featureFlagsProvider),
    metaBox: boxes.meta,
    // The proxy authenticates callers with the signed-in user's Firebase ID
    // token, so it needs a way to mint one on demand. Read lazily rather than
    // watched: a token is only wanted at request time, and refreshing one must
    // not rebuild this provider.
    fallback: createFallbackProvider(
      idTokenProvider: () async =>
          ref.read(firebaseAuthProvider).currentUser?.getIdToken(),
    ),
  );
});

/// Conversational assistant: voice or text in, text + speech out.
///
/// App commands ("add an expense of 500 for groceries", "delete the second
/// one", "open reports") run locally through [AssistantEngine] against the
/// signed-in user's own repositories — nothing is sent to the AI provider.
/// Free-form questions fall through to Gemini, grounded only in aggregates.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  final List<_ChatMessage> _messages = [];

  AssistantEngine? _engine;
  bool _thinking = false;
  bool _listening = false;
  bool _speechAvailable = true;
  bool _handsFree = false;
  bool _speakReplies = true;
  String _liveTranscript = '';

  static const _suggestions = [
    'Add an expense of 500 for groceries',
    'Show my expenses for this month',
    'How much did I spend on food?',
    'Why did I spend more this month?',
    'Give me my monthly summary',
  ];

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Engine wiring: same uid-scoped repos as the manual UI ───────────────
  AssistantEngine _buildEngine() {
    final currency =
        ref.read(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';
    return _engine ??= AssistantEngine(
      currency: currency,
      transactions: () =>
          ref.read(transactionsStreamProvider).valueOrNull ?? const [],
      categories: () =>
          ref.read(categoriesStreamProvider).valueOrNull ?? Category.seeds,
      defaultAccountId: () {
        final accounts =
            ref.read(accountsStreamProvider).valueOrNull ?? const [];
        return accounts.isNotEmpty ? accounts.first.id : 'acc_cash_default';
      },
      upsertTransaction: (tx) async {
        final txRepo = ref.read(transactionsRepoProvider);
        if (txRepo == null) throw StateError('Not signed in');
        // First transaction with no accounts: create the default Cash
        // account on the fly (same behaviour as the manual Add screen).
        final accounts =
            ref.read(accountsStreamProvider).valueOrNull ?? const [];
        if (accounts.isEmpty && tx.accountId == 'acc_cash_default') {
          await ref.read(accountsRepoProvider)?.upsert(
                Account(
                  id: 'acc_cash_default',
                  name: 'Cash',
                  type: AccountType.cash,
                  balanceMinor: 0,
                  currency: currency,
                ),
                docId: 'acc_cash_default',
              );
        }
        final accountsRepo = ref.read(accountsRepoProvider);
        if (accountsRepo != null && tx.accountId.isNotEmpty) {
          final acc = await accountsRepo.getById(tx.accountId);
          if (acc != null) {
            await accountsRepo.upsert(
              acc.copyWith(balanceMinor: acc.balanceMinor + tx.signedMinor),
              docId: acc.id,
            );
          }
        }
        await txRepo.upsert(tx, docId: tx.id);
      },
      deleteTransaction: (id) async {
        final txRepo = ref.read(transactionsRepoProvider);
        if (txRepo == null) throw StateError('Not signed in');
        final currentTxs = ref.read(transactionsStreamProvider).valueOrNull ?? const [];
        final tx = currentTxs.where((t) => t.id == id).firstOrNull;
        if (tx != null && tx.accountId.isNotEmpty) {
          final accountsRepo = ref.read(accountsRepoProvider);
          if (accountsRepo != null) {
            final acc = await accountsRepo.getById(tx.accountId);
            if (acc != null) {
              await accountsRepo.upsert(
                acc.copyWith(balanceMinor: acc.balanceMinor - tx.signedMinor),
                docId: acc.id,
              );
            }
          }
        }
        await txRepo.delete(id);
      },
    );
  }

  // ── Send pipeline ───────────────────────────────────────────────────────
  /// Grants AI-processing consent from the Assistant itself.
  ///
  /// This is real consent, not a shortcut: the sheet states exactly what leaves
  /// the device before anything is enabled, and declining changes nothing. The
  /// write goes to the same Firestore field the Preferences toggle uses, so the
  /// two screens can never disagree, and it persists across restarts because it
  /// lives on the user document rather than in memory.
  Future<void> _enableAiProcessing(String? pendingQuestion) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Turn on AI processing?',
      message: 'Free-form questions are answered by an AI service. Only '
          'aggregated figures are sent — monthly totals, category sums and your '
          'health score. Individual transactions, merchant names, account '
          'numbers and receipts are never sent. You can turn this off again at '
          'any time in Preferences → Privacy & consent.',
      confirmLabel: 'Turn on',
    );
    if (!confirmed || !mounted) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      await ref.read(firestoreProvider).doc('users/$uid').set({
        'consent': {
          'aiProcessing': true,
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (e) {
      // Already applied to the local cache and reported by the snapshot
      // listener; it syncs when the connection allows.
      debugPrint('consent change queued locally: $e');
    }
    if (!mounted) return;
    // Re-ask what they originally typed, so enabling consent answers the
    // question instead of just clearing the message.
    if (pendingQuestion != null && pendingQuestion.trim().isNotEmpty) {
      await _send(pendingQuestion);
    }
  }

  Future<void> _send(String text, {bool fromVoice = false}) async {
    final question = text.trim();
    if (question.isEmpty || _thinking) return;
    await _tts.stop();

    setState(() {
      _messages.add(_ChatMessage('user', question));
      _thinking = true;
      _input.clear();
      _liveTranscript = '';
    });
    _autoScroll();

    String? spokenReply;
    try {
      // 1) Local command engine — CRUD, queries, navigation. Free, offline,
      //    and never sends anything to the AI provider.
      final engineReply = await _buildEngine().handle(question);
      if (engineReply.handled) {
        setState(() {
          _messages.add(_ChatMessage('action', engineReply.text));
          _thinking = false;
        });
        spokenReply = engineReply.text;
        if (engineReply.navigateTo != null && mounted) {
          context.go(engineReply.navigateTo!);
        }
      } else {
        // 2) Free-form question → Gemini (requires consent + connection).
        final consent =
            ref.read(userProfileProvider).valueOrNull?.consent.aiProcessing ??
                false;
        final gateway = ref.read(aiGatewayProvider);
        if (!consent) {
          // Names the real location (the toggle lives under Preferences →
          // "Privacy & consent"; there is no "Privacy" screen) and carries the
          // question so it can be re-sent the moment consent is granted.
          setState(() {
            _messages.add(_ChatMessage(
                'consent',
                'AI processing is off, so free-form questions are not sent '
                    'anywhere. Turn it on to ask this — voice commands like "add an '
                    'expense" keep working either way.',
                retryText: question));
            _thinking = false;
          });
        } else if (gateway == null) {
          setState(() {
            _messages.add(const _ChatMessage('error',
                'The assistant is still starting up. Try again in a moment.'));
            _thinking = false;
          });
        } else {
          final aggregates = ref.read(financialAggregatesProvider);
          final result = await gateway.ask(question, aggregates);
          if (!mounted) return;
          setState(() {
            result.when(
              ok: (reply) {
                _messages.add(_ChatMessage('model', reply));
                spokenReply = reply;
              },
              err: (f) => _messages
                  .add(_ChatMessage('error', f.message, retryText: question)),
            );
            _thinking = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
            'error', 'Something went wrong performing that action. Try again.',
            retryText: question));
        _thinking = false;
      });
    }
    _autoScroll();

    // Voice out: speak replies for voice interactions / hands-free mode.
    if (spokenReply != null && _speakReplies && (fromVoice || _handsFree)) {
      await _tts.speak(_stripForSpeech(spokenReply!));
    }
    // Hands-free: keep the conversation going without pressing the mic.
    if (_handsFree && mounted && !_listening) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted && _handsFree) await _startListening();
    }
  }

  String _stripForSpeech(String text) => text
      .replaceAll(RegExp(r'[*_#`]'), '')
      .replaceAll(
          'This is educational guidance, not professional financial advice.',
          '')
      .trim();

  // ── Speech to text ──────────────────────────────────────────────────────

  /// Set whenever the platform recogniser reports an error.
  ///
  /// Android's `SpeechRecognizer` degrades after repeated sessions — it starts
  /// answering `ERROR_RECOGNIZER_BUSY` / `ERROR_CLIENT` — but `isAvailable`
  /// keeps reporting true, because it only records that `initialize` once
  /// succeeded. The old code re-initialised *only* when `isAvailable` was
  /// false, so once the recogniser broke it was never rebuilt: `listen()` was
  /// still called, still returned normally, and simply never produced a result.
  /// The mic looked dead until the process was killed, which is exactly the
  /// "works about four times, then nothing until I clear the app" report.
  bool _needsSpeechReinit = false;

  Future<bool> _ensureSpeechReady() async {
    if (_speech.isAvailable && !_needsSpeechReinit) return true;

    // Release any half-open session before rebuilding; starting a new one on
    // top of a busy recogniser is what wedges it in the first place.
    try {
      await _speech.cancel();
    } catch (_) {
      // Nothing to cancel — fine, we are about to re-initialise anyway.
    }

    final ok = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (e) {
        // Any error invalidates the recogniser, not just a permanent one:
        // a transient "busy" leaves it unusable for the next session too.
        if (mounted) {
          setState(() {
            _listening = false;
            _needsSpeechReinit = true;
            _speechAvailable = e.permanent ? false : _speechAvailable;
          });
        } else {
          _needsSpeechReinit = true;
        }
      },
    );
    _needsSpeechReinit = !ok;
    return ok;
  }

  Future<void> _startListening() async {
    await _tts.stop();

    final ready = await _ensureSpeechReady();
    if (!ready) {
      if (mounted) {
        setState(() => _speechAvailable = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Microphone unavailable — check the app\'s microphone permission.')));
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _listening = true;
      _liveTranscript = '';
    });

    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 30),
        ),
        onResult: (SpeechRecognitionResult result) {
          if (!mounted) return;
          setState(() {
            _liveTranscript = result.recognizedWords;
            _input.text = result.recognizedWords;
            _input.selection =
                TextSelection.collapsed(offset: _input.text.length);
          });
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            setState(() => _listening = false);
            _send(result.recognizedWords, fromVoice: true);
          }
        },
      );
    } catch (e) {
      // A throwing `listen` leaves the recogniser unusable; flag it so the next
      // attempt rebuilds rather than repeating a doomed call, and never strand
      // the UI in the listening state.
      debugPrint('Speech listen failed: ${e.runtimeType}');
      _needsSpeechReinit = true;
      if (mounted) {
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't start listening — try the mic again.")));
      }
    }
  }

  Future<void> _stopListening() async {
    // `cancel` rather than `stop`: stop leaves the session open awaiting a
    // final result, and a user who taps stop wants the recogniser released so
    // the next session starts clean.
    try {
      await _speech.cancel();
    } catch (_) {
      _needsSpeechReinit = true;
    }
    if (mounted) setState(() => _listening = false);
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: FgTokens.dMed, curve: Curves.easeOut);
      }
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = ref.watch(isOnlineProvider);
    final flags = ref.watch(featureFlagsProvider);
    final remaining = ref.watch(aiGatewayProvider)?.remainingQuota();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          IconButton(
            tooltip:
                _speakReplies ? 'Mute voice replies' : 'Speak replies aloud',
            icon: Icon(_speakReplies ? Icons.volume_up : Icons.volume_off,
                size: FgTokens.iconMd),
            onPressed: () {
              if (_speakReplies) _tts.stop();
              setState(() => _speakReplies = !_speakReplies);
            },
          ),
          IconButton(
            tooltip:
                _handsFree ? 'Exit hands-free mode' : 'Hands-free conversation',
            icon: Icon(
              _handsFree ? Icons.record_voice_over : Icons.voice_over_off,
              size: FgTokens.iconMd,
              color: _handsFree ? theme.colorScheme.primary : null,
            ),
            onPressed: !_speechAvailable
                ? null
                : () {
                    final turningOn = !_handsFree;
                    setState(() => _handsFree = turningOn);
                    if (turningOn && !_listening) _startListening();
                    if (!turningOn) _stopListening();
                  },
          ),
          if (remaining != null)
            Padding(
              padding: const EdgeInsets.only(right: FgTokens.s4),
              child: Center(
                child: Text('$remaining left today',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Material(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: FgTokens.s4, vertical: FgTokens.s2),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: FgTokens.iconSm,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: FgTokens.s2),
                  Expanded(
                    child: Text(
                      'Educational guidance only — not professional financial advice.',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: !flags.aiAssistant
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(FgTokens.s8),
                        child: Text(
                          'The assistant is currently unavailable. Everything else in FinGenius keeps working.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _messages.isEmpty
                      ? _EmptyChat(
                          suggestions: _suggestions,
                          online: online,
                          onSuggestion: _send,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(FgTokens.s4),
                          itemCount: _messages.length + (_thinking ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _messages.length) {
                              return const Padding(
                                padding: EdgeInsets.all(FgTokens.s4),
                                child: Row(children: [
                                  SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  SizedBox(width: FgTokens.s3),
                                  Text('Thinking…'),
                                ]),
                              );
                            }
                            return _MessageBubble(
                              message: _messages[i],
                              onRetry: _messages[i].retryText == null
                                  ? null
                                  : () => _send(_messages[i].retryText!),
                              onEnableAi: _messages[i].role != 'consent'
                                  ? null
                                  : () => _enableAiProcessing(
                                      _messages[i].retryText),
                            );
                          },
                        ),
            ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: FgTokens.s4),
                child: Row(children: [
                  _PulsingMic(color: theme.colorScheme.primary),
                  const SizedBox(width: FgTokens.s2),
                  Expanded(
                    child: Text(
                      _liveTranscript.isEmpty
                          ? 'Listening… speak now'
                          : _liveTranscript,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.all(FgTokens.s4),
              child: Row(children: [
                IconButton.filledTonal(
                  tooltip: _listening ? 'Stop listening' : 'Speak',
                  onPressed: !_speechAvailable || !flags.aiAssistant
                      ? null
                      : _listening
                          ? _stopListening
                          : _startListening,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  style: _listening
                      ? IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer)
                      : null,
                ),
                const SizedBox(width: FgTokens.s2),
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: _listening
                          ? 'Listening…'
                          : 'Ask, or say "add an expense…"',
                      enabled: flags.aiAssistant,
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: FgTokens.s2),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: flags.aiAssistant && !_thinking
                      ? () => _send(_input.text)
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat(
      {required this.suggestions,
      required this.online,
      required this.onSuggestion});

  final List<String> suggestions;
  final bool online;
  final void Function(String) onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(FgTokens.s6),
      children: [
        Icon(Icons.auto_awesome, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: FgTokens.s4),
        Text('Ask — or just say it',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: FgTokens.s2),
        Text(
          'Manage expenses by voice ("add an expense of 500 for groceries") or '
          'ask about your money. Commands run on your device; questions use '
          'only aggregated totals — never raw transactions.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FgTokens.s6),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: FgTokens.s2),
            child: ActionChip(
              avatar:
                  const Icon(Icons.chat_bubble_outline, size: FgTokens.iconSm),
              label: Text(s),
              onPressed: () => onSuggestion(s),
            ),
          ),
        if (!online)
          Padding(
            padding: const EdgeInsets.only(top: FgTokens.s4),
            child: Text(
                'You appear to be offline — voice commands still work; '
                'free-form questions need a connection.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: FgTokens.warning),
                textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onRetry, this.onEnableAi});

  final _ChatMessage message;
  final VoidCallback? onRetry;

  /// Present only on a 'consent' bubble: turning AI processing on from here
  /// saves the user hunting through Preferences for a toggle the old message
  /// pointed at by the wrong name.
  final VoidCallback? onEnableAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final isConsent = message.role == 'consent';
    final isError = message.role == 'error' || isConsent;
    final isAction = message.role == 'action';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: FgTokens.s3),
        padding: const EdgeInsets.all(FgTokens.s4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : isError
                  ? theme.colorScheme.error.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(FgTokens.rLg),
          border: isAction
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAction)
              Padding(
                padding: const EdgeInsets.only(bottom: FgTokens.s1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.task_alt,
                      size: FgTokens.iconSm, color: theme.colorScheme.primary),
                  const SizedBox(width: FgTokens.s1),
                  Text('Action',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ]),
              ),
            Text(message.text, style: theme.textTheme.bodyMedium),
            if (isConsent && onEnableAi != null)
              Padding(
                padding: const EdgeInsets.only(top: FgTokens.s2),
                child: FilledButton.icon(
                  onPressed: onEnableAi,
                  icon: const Icon(Icons.auto_awesome, size: FgTokens.iconSm),
                  label: const Text('Turn on AI processing'),
                ),
              ),
            if (!isConsent && onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: FgTokens.s2),
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: FgTokens.iconSm),
                  label: const Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small pulsing dot indicating active listening.
class _PulsingMic extends StatefulWidget {
  const _PulsingMic({required this.color});
  final Color color;

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Icon(Icons.mic, size: FgTokens.iconSm, color: widget.color);
    }
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Icon(Icons.mic, size: FgTokens.iconSm, color: widget.color),
    );
  }
}
