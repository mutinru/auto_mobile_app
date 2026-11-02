import 'package:flutter/material.dart';

/// Спиннер в конце ленты; список строит его, только когда до конца
/// докрутили, — тогда и просим следующую страницу. По прокрутке нельзя:
/// короткая первая страница не прокручивается, и спиннер висел бы вечно.
class LoadMore extends StatefulWidget {
  const LoadMore({super.key, required this.onShown});

  final VoidCallback onShown;

  @override
  State<LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<LoadMore> {
  @override
  void initState() {
    super.initState();
    // не во время build: стор уведомит слушателей
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown();
    });
  }

  @override
  Widget build(BuildContext context) => const CircularProgressIndicator();
}
