import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Язык приложения закреплён: все экраны написаны по-русски, и при
/// английском телефоне без этого выбор даты, времени и меню вставки
/// оказались бы по-английски посреди русских экранов. Русская локаль
/// сама даёт 24-часовой формат и неделю с понедельника.
const appLocale = Locale('ru');

const appSupportedLocales = [appLocale];

const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
