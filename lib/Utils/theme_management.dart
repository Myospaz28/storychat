import '/Configs/app_constants.dart';
import '/Configs/optional_constants.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

class Thm {
  static const THEME_STATUS = "THEMESTATUS";

  static bool isDarktheme(SharedPreferences prefs) {
    return prefs.getBool(THEME_STATUS) ??
        (IsHIDELightDarkModeSwitchInApp == true
            ? false
            : WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
  }
}

class DarkThemePreference {
  static const THEME_STATUS = "THEMESTATUS";

  setDarkTheme(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool(THEME_STATUS, value);
  }

  Future<bool> getTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(THEME_STATUS) ??
        (IsHIDELightDarkModeSwitchInApp == true
            ? false
            : WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
  }
}

class DarkThemeProvider with ChangeNotifier {
  DarkThemePreference darkThemePreference = DarkThemePreference();
  bool _darkTheme = false;

  bool get darkTheme => _darkTheme;

  set darkTheme(bool value) {
    _darkTheme = value;
    darkThemePreference.setDarkTheme(value);
    notifyListeners();
  }
}

MaterialColor getMaterialColor(Color color) {
  final int red = color.red;
  final int green = color.green;
  final int blue = color.blue;

  final Map<int, Color> shades = {
    50: Color.fromRGBO(red, green, blue, .1),
    100: Color.fromRGBO(red, green, blue, .2),
    200: Color.fromRGBO(red, green, blue, .3),
    300: Color.fromRGBO(red, green, blue, .4),
    400: Color.fromRGBO(red, green, blue, .5),
    500: Color.fromRGBO(red, green, blue, .6),
    600: Color.fromRGBO(red, green, blue, .7),
    700: Color.fromRGBO(red, green, blue, .8),
    800: Color.fromRGBO(red, green, blue, .9),
    900: Color.fromRGBO(red, green, blue, 1),
  };

  return MaterialColor(color.value, shades);
}

class Styles {
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return ThemeData(
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: newPrimaryColor,
        onPrimary: Colors.white,
        primaryContainer: newPrimaryColor,
        onPrimaryContainer: Colors.white,
        secondary: newSecondaryPrimaryColor,
        onSecondary: Colors.white,
        secondaryContainer: newSecondaryPrimaryColor,
        onSecondaryContainer: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        errorContainer: Colors.red,
        onErrorContainer: Colors.white,
        background: Color.fromRGBO(255, 247, 240, 1),
        onBackground: newPrimaryColor,
        surface: Colors.white,
        onSurface: newPrimaryColor,
      ),
    );
  }
}
