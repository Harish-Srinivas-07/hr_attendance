import 'package:flutter/material.dart';
import 'snackbar.dart';

class InternetDialogHelper {
  static bool _dialogVisible = false;

  static void showInternetDialog(BuildContext context) {
    if (_dialogVisible) return;
    _dialogVisible = true;
    info('Internet Connection unstable.', Severity.error);
    _dialogVisible = false;
  }
}
