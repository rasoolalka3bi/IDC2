import 'package:flutter/material.dart';

import 'common.dart';

/// قائمة تُحمّل صفحة بعد صفحة عند الوصول لنهايتها، مع السحب للتحديث.
class PagedList<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) fetch;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget empty;
  final EdgeInsetsGeometry padding;
  final Widget? header;
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.empty,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.header,
  });

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final _items = <T>[];
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _done = false;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final next = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        // بعض صفحات الخادم تعيد العناصر نفسها عند نهاية القائمة.
        final fresh = next.where((e) => !_items.contains(e)).toList();
        _items.addAll(fresh);
        _done = fresh.isEmpty;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showHeader = widget.header != null;
    Widget body;
    if (_items.isEmpty && _loading) {
      body = ListView(padding: widget.padding, children: [if (showHeader) widget.header!, const SkeletonList()]);
    } else if (_items.isEmpty && _error != null) {
      body = ListView(children: [if (showHeader) widget.header!, ErrorState(error: _error!, onRetry: refresh)]);
    } else if (_items.isEmpty) {
      body = ListView(padding: widget.padding, children: [if (showHeader) widget.header!, widget.empty]);
    } else {
      final extra = showHeader ? 1 : 0;
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300) _more();
          return false;
        },
        child: ListView.builder(
          padding: widget.padding,
          itemCount: _items.length + extra + 1,
          itemBuilder: (context, i) {
            if (showHeader && i == 0) return widget.header!;
            final idx = i - extra;
            if (idx == _items.length) {
              if (_loading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
                );
              }
              if (_error != null) {
                return Center(child: TextButton(onPressed: _more, child: const Text('تحميل المزيد')));
              }
              return const SizedBox(height: 8);
            }
            return widget.itemBuilder(context, _items[idx]);
          },
        ),
      );
    }
    return RefreshIndicator(onRefresh: refresh, child: body);
  }
}
