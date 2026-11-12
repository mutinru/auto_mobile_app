import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/support_config.dart';
import '../data/app_build.dart';
import '../state/app_update.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';

/// Магазин, где лежит приложение.
enum AppStore {
  googlePlay('Google Play'),
  ruStore('RuStore');

  const AppStore(this.label);

  final String label;

  Uri pageFor(String packageName) => switch (this) {
    googlePlay => Uri.https('play.google.com', '/store/apps/details', {
      'id': packageName,
    }),
    ruStore => Uri.https('www.rustore.ru', '/catalog/app/$packageName'),
  };

  /// Куда вести за обновлением: в магазин, откуда поставили. Поставили не
  /// из магазина (APK вручную) — в оба на выбор. На iOS страницы в App
  /// Store ещё нет — пусто.
  static List<AppStore> forInstaller(String? installer, {bool? android}) {
    if (!(android ?? _isAndroid)) return const [];
    return switch (installer) {
      'com.android.vending' => const [googlePlay],
      'ru.vk.store' => const [ruStore],
      _ => const [googlePlay, ruStore],
    };
  }

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
}

/// «Обновите приложение» (ревью №11): встаёт вместо всего приложения, когда
/// сервер сказал, что сборка устарела ([AppUpdate]). Ни «Назад», ни
/// навигации — только в магазин или в поддержку.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, this.appBuild, this.android});

  /// Сборка; null — [AppBuild.info].
  final AppBuildInfo? appBuild;

  /// Платформа для тестов; null — настоящая.
  final bool? android;

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final info = appBuild ?? AppBuild.info;
    final stores = info == null
        ? const <AppStore>[]
        : AppStore.forInstaller(info.installerStore, android: android);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.bg0,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.system_update_rounded, size: 56, color: c.text2),
                const SizedBox(height: 18),
                Text(
                  'Обновите приложение',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.text1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  stores.isEmpty
                      ? 'Эта версия больше не поддерживается. Установите '
                            'новую из магазина приложений.'
                      : 'Эта версия больше не поддерживается. Новая — уже '
                            'в магазине, заказы и отчёты сохранятся.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: c.text2),
                ),
                const Spacer(),
                for (final store in stores) ...[
                  CtaPrimary(
                    label: stores.length == 1
                        ? 'Обновить'
                        : 'Обновить в ${store.label}',
                    icon: Icons.download_rounded,
                    onPressed: () =>
                        _open(context, store.pageFor(info!.packageName)),
                  ),
                  const SizedBox(height: 10),
                ],
                CtaGhost(
                  label: 'Написать в поддержку',
                  onPressed: () => _open(context, SupportConfig.telegramUri),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Над навигатором (`MaterialApp.builder`): сборка устарела — вместо всего
/// приложения [UpdateRequiredScreen], ни «Назад», ни пуш его не обойдут.
class UpdateGate extends StatelessWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: AppUpdate.required,
    builder: (_, required, _) =>
        required ? const UpdateRequiredScreen() : child,
  );
}
