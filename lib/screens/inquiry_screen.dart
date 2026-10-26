import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class InquiryScreen extends StatefulWidget {
  final Inquiry inquiry;
  const InquiryScreen({super.key, required this.inquiry});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final _text = TextEditingController();
  late final List<InquiryReply> _replies = [...widget.inquiry.replies];
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<AppState>().repo.sendReply(widget.inquiry.id, t);
      setState(() {
        _replies.add(InquiryReply(text: t, fromEmployee: true, date: DateTime.now()));
        _text.clear();
      });
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = widget.inquiry;
    return Scaffold(
      appBar: AppBar(title: Text(q.title)),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
            if (q.body.isNotEmpty) _Bubble(text: q.body, mine: true, date: q.date),
            for (final r in _replies) _Bubble(text: r.text, mine: r.fromEmployee, date: r.date),
            if (_replies.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('لا يوجد رد بعد', textAlign: TextAlign.center, style: TextStyle(color: c.ink3)),
              ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(hintText: 'اكتب الرد هنا...'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: c.accent, minimumSize: const Size(48, 48)),
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, textDirection: TextDirection.rtl),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  final DateTime? date;
  const _Bubble({required this.text, required this.mine, this.date});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? c.brand : c.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: Radius.circular(mine ? 4 : 18),
            bottomEnd: Radius.circular(mine ? 18 : 4),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('الموارد البشرية', style: TextStyle(color: c.accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          Text(text, style: TextStyle(color: mine ? Colors.white : c.ink, height: 1.6)),
          const SizedBox(height: 4),
          Text(timeAgo(date), style: TextStyle(color: mine ? Colors.white60 : c.ink3, fontSize: 11)),
        ]),
      ),
    );
  }
}
