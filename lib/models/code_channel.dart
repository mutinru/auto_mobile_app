/// Совпадает с App\Sms\CodeChannel на бекенде: как ушёл код входа (поле
/// `channel` ответа POST /auth/phone/request).
///
/// SigmaSMS шлёт код в Telegram, а не дошёл — звонит ([telegramCall]); или
/// наоборот ([callTelegram]). Какой из двух сработает, сервер не знает.
enum CodeChannel { sms, telegramCall, callTelegram, log }

/// Неизвестный или пустой канал → null: экран покажет подсказку по умолчанию.
CodeChannel? codeChannelFromApi(String? value) => switch (value) {
      'sms' => CodeChannel.sms,
      'telegram_call' => CodeChannel.telegramCall,
      'call_telegram' => CodeChannel.callTelegram,
      'log' => CodeChannel.log,
      _ => null,
    };

/// Откуда ждать код. До запроса канал неизвестен — [codeChannelHint] с null.
String codeChannelHint(CodeChannel? channel) => switch (channel) {
      CodeChannel.callTelegram => 'Мы позвоним и продиктуем код. Если не дозвонимся — пришлём в Telegram',
      CodeChannel.sms => 'Код придёт в SMS',
      // log — ничего не отправлено (разработка); говорим как на проде, где
      // по умолчанию сначала Telegram
      CodeChannel.telegramCall || CodeChannel.log || null =>
        'Код придёт в Telegram. Если Telegram нет — позвоним и продиктуем',
    };
