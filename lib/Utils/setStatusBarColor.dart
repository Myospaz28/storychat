import '/Configs/app_constants.dart';
import '/Utils/color_detector.dart';
import '/Utils/theme_management.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

setStatusBarColor(SharedPreferences prefs) {
  if (Thm.isDarktheme(prefs) == true) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: storychatAPPBARcolorDarkMode,
        statusBarIconBrightness: isDarkColor(storychatAPPBARcolorDarkMode)
            ? Brightness.light
            : Brightness.dark));
  } else {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: storychatAPPBARcolorLightMode,
        statusBarIconBrightness: isDarkColor(storychatAPPBARcolorLightMode)
            ? Brightness.light
            : Brightness.dark));
  }
}
