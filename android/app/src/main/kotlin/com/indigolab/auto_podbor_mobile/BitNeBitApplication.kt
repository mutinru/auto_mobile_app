package com.indigolab.auto_podbor_mobile

import android.app.Application
import ru.rustore.sdk.pushclient.RuStorePushClient

/**
 * Инициализация SDK пушей RuStore — только в главном процессе и только если
 * у сборки есть проект RuStore (BuildConfig.RUSTORE_PUSH_PROJECT_ID, задаётся
 * во flavor). Без проекта приложение получает пуши через Firebase — выбирает
 * AutoPushMessaging в Dart, спрашивая MainActivity.
 */
class BitNeBitApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (isRuStorePushConfigured) {
            RuStorePushClient.init(this, BuildConfig.RUSTORE_PUSH_PROJECT_ID)
        }
    }

    companion object {
        val isRuStorePushConfigured: Boolean
            get() = BuildConfig.RUSTORE_PUSH_PROJECT_ID.isNotBlank()
    }
}
