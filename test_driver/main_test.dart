import 'dart:async';

import 'package:emulators/emulators.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:frigoligo/widget_keys.dart';
import 'package:test/test.dart';

// this is obviously not versioned
import '../tools/test_credentials.local.dart';

const captureDebug = false;

Future<void> main() async {
  final locale = Environment.getString('locale')!;
  final darkModeLabel = switch (locale.split('-').first) {
    'en' => 'Dark',
    'fr' => 'Sombre',
    _ => throw UnimplementedError('dark mode not supported for $locale')
  };
  final backTooltip = switch (locale.split('-').first) {
    'en' => 'Back',
    'fr' => 'Retour',
    _ => throw UnimplementedError('back tooltip not supported for $locale')
  };
  final okCancelLabel = switch (locale.split('-').first) {
    'en' => 'OK',
    'fr' => 'OK',
    _ => throw UnimplementedError('ok/cancel label not supported for $locale')
  };

  final deviceName = Environment.getString('deviceName')!;
  final deviceType = Environment.getString('deviceType')!;
  final deviceIsAndroid = deviceName.startsWith('android_');

  final driver = await FlutterDriver.connect();
  final emulators = await Emulators.build();

  final androidImageDirectory =
      deviceType == 'phone' ? 'phoneScreenshots' : 'tenInchScreenshots';
  final screenshots = emulators.screenshotHelper(
    iosPath: 'ios/fastlane/screenshots/$locale',
    androidPath:
        'fastlane/metadata/android/$locale/images/$androidImageDirectory',
  );

  setUpAll(() async {
    await driver.waitUntilFirstFrameRasterized();
    await screenshots.cleanStatusBar();
  });

  tearDownAll(() async {
    await driver.close();
  });

  int debugStep = 1;

  Future<void> takeScreenshot(String label, [bool debug = true]) async {
    if (debug && !captureDebug) return;
    final name = debug ? 'd${debugStep++}_$label' : label;
    // ignore: avoid_print
    print('📸 $name');
    await driver.waitUntilNoTransientCallbacks();
    await screenshots.capture(name);
  }

  group('screenshots stroll', () {
    test('init', () async {
      await takeScreenshot('init');
    });

    test('login', () async {
      await driver.enterText(TestCredentials.server.toString());
      await driver.sendTextInputAction(TextInputAction.done);
      await takeScreenshot('loginflow-server');

      await driver.waitFor(find.byValueKey(wkLoginFlowClientId));
      await driver.enterText(TestCredentials.clientId);
      await driver.sendTextInputAction(TextInputAction.next);
      await driver.enterText(TestCredentials.clientSecret);
      await driver.sendTextInputAction(TextInputAction.next);
      await driver.enterText(TestCredentials.user);
      await driver.sendTextInputAction(TextInputAction.next);
      await driver.enterText(TestCredentials.password);
      await driver.sendTextInputAction(TextInputAction.next);
      await takeScreenshot('loginflow-credentials');
      await driver.tap(find.byValueKey(wkLoginFlowLogIn));
    });

    test('listing', () async {
      await takeScreenshot('listing-loading');
      // hold until the progess indicator is gone
      // this is sub-optimal but will do for now...
      await Future.delayed(const Duration(seconds: 10));
      await takeScreenshot('1-listing', false);

      await driver.tap(find.byValueKey(wkListingFiltersButton));
      await takeScreenshot('2-filters', false);

      await driver.tap(find.byValueKey(wkListingFiltersCount));
      await takeScreenshot('listing-filters-dismissed');
    });

    openArticle() async {
      await driver.tap(find.text('wallabag turns 10'));
    }

    toggleExpander() async {
      await driver.tap(find.byValueKey(wkArticleExpanderToggle));
    }

    openReadingSettings() async {
      await driver.tap(find.text('wallabag turns 10'));
      await driver.tap(find.byValueKey(wkArticlePopupMenu));
      await driver.tap(find.byValueKey(wkArticlePopupMenuSettings));
    }

    test('reading settings', () async {
      if (deviceType == 'phone') {
        await openArticle();
      } else {
        await toggleExpander();
      }
      await openReadingSettings();
      await takeScreenshot('3-reading-settings', false);

      await driver.tap(find.byType('ModalBarrier'));
      await takeScreenshot('article-settings-dismissed');

      if (deviceType == 'phone') {
        await driver.tap(find.byTooltip(backTooltip));
      } else {
        await toggleExpander();
      }
      await takeScreenshot('listing-back-from-article');
    });

    test('settings and dark mode', () async {
      await driver.tap(find.byValueKey(wkListingSettings));
      await takeScreenshot('4-settings', false);

      await driver.tap(find.byValueKey(wkSettingsTheme));
      await driver.tap(find.text(darkModeLabel));
      if (deviceIsAndroid) {
        await driver.tap(find.text(okCancelLabel));
      }
      await takeScreenshot('settings-dark-theme');

      await driver.tap(find.byTooltip(backTooltip));
      await takeScreenshot('listing-back-from-settings');
    });

    test('reading settings (dark)', () async {
      if (deviceType == 'phone') {
        await openArticle();
      } else {
        await toggleExpander();
      }
      await openReadingSettings();
      await takeScreenshot('5-reading-settings-dark', false);
    });
  });
}
