import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'states.dart';

/// Paginated, live Firestore list.
///
/// Listens to `query.limit(pageSize × pages)`; "load more" grows the limit.
/// Only the visible pages are ever read, and new/changed documents appear
/// immediately. Items carry their snapshot metadata so pending (not yet
/// synced) writes can be flagged.
class LiveQueryList<T> extends StatefulWidget {
  const LiveQueryList({
    super.key,
    required this.query,
    required this.fromDoc,
    required this.itemBuilder,
    required this.empty,
    this.pageSize = 30,
    this.separated = true,
    this.header,
  });

  final Query<Map<String, dynamic>> query;
  final T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDoc;
  final Widget Function(BuildContext context, T item, SnapshotMetadata meta) itemBuilder;
  final Widget empty;
  final int pageSize;
  final bool separated;
  final Widget? header;

  @override
  State<LiveQueryList<T>> createState() => _LiveQueryListState<T>();
}

class _LiveQueryListState<T> extends State<LiveQueryList<T>> {
  late int _limit = widget.pageSize;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _listen();

  Stream<QuerySnapshot<Map<String, dynamic>>> _listen() =>
      widget.query.limit(_limit).snapshots(includeMetadataChanges: true);

  @override
  void didUpdateWidget(covariant LiveQueryList<T> old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      _limit = widget.pageSize;
      _stream = _listen();
    }
  }

  void _loadMore() {
    setState(() {
      _limit += widget.pageSize;
      _stream = _listen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorState(
            error: snap.error!,
            stackTrace: snap.stackTrace,
            onRetry: () => setState(() => _stream = _listen()),
          );
        }
        if (!snap.hasData) return const LoadingState();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return Card(child: widget.empty);
        final hasMore = docs.length >= _limit;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?widget.header,
              for (var i = 0; i < docs.length; i++) ...[
                if (widget.separated && (i > 0 || widget.header != null)) const Divider(),
                widget.itemBuilder(context, widget.fromDoc(docs[i]), docs[i].metadata),
              ],
              if (hasMore) ...[
                const Divider(),
                TextButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Symbols.expand_more),
                  label: const Text('عرض المزيد'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
