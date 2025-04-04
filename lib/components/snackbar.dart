import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

enum Severity { error, warning, info, success }

void info(String message, Severity severity,
    {Alignment alignment = Alignment.bottomCenter}) {
  IconData iconData;
  Color iconColor;

  switch (severity) {
    case Severity.error:
      iconData = Icons.error;
      iconColor = Colors.red;
      break;
    case Severity.warning:
      iconData = Icons.warning;
      iconColor = Colors.yellow;
      break;
    case Severity.info:
      iconData = Icons.info;
      iconColor = Colors.blue;
      break;
    case Severity.success:
      iconData = Icons.check_circle;
      iconColor = Colors.green;
      break;
  }

  toastification.show(
      primaryColor: Colors.transparent,
      title: Text(message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.visible,
          maxLines: 5),
      borderRadius: SmoothBorderRadius(cornerRadius: 20, cornerSmoothing: .8),
      padding: const EdgeInsets.only(bottom: 25, top: 15, left: 20, right: 20),
      margin: const EdgeInsets.only(left: 20, right: 20),
      type: ToastificationType.values[severity.index],
      style: ToastificationStyle.fillColored,
      autoCloseDuration: const Duration(seconds: 5),
      alignment: alignment,
      applyBlurEffect: true,
      icon: Icon(iconData, size: 25, color: iconColor),
      closeButtonShowType: CloseButtonShowType.none,
      progressBarTheme: ProgressIndicatorThemeData(
          color: Colors.blue,
          linearMinHeight: 1.5,
          linearTrackColor: const Color.fromARGB(0, 158, 158, 158)),
      closeOnClick: true,
      dragToClose: true);
}
