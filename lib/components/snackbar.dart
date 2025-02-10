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
      primaryColor: Colors.black,
      title: Text(message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          overflow: TextOverflow.visible,
          maxLines: 5),
      borderRadius: SmoothBorderRadius(cornerRadius: 20, cornerSmoothing: .8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      type: ToastificationType.values[severity.index],
      style: ToastificationStyle.flat,
      autoCloseDuration: const Duration(seconds: 2),
      alignment: alignment,
      applyBlurEffect: true,
      icon: Icon(iconData, size: 25, color: iconColor),
      closeOnClick: true,
      dragToClose: true);
}
