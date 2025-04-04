import 'package:flashy_tab_bar2/flashy_tab_bar2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:iconly/iconly.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/dashboard.dart';
import '../models/user.dart';
import '../shared/constants.dart';
import 'discover.dart';
import 'profile.dart';
import 'contacts.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key});
  static String routeName = "/home";

  @override
  HomeState createState() => HomeState();
}

class HomeState extends ConsumerState<Home> {
  bool canPop = false;
  bool isLoading = false;

  // @override
  // bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!mounted) return;
    userData = await ref.read(userInfoProvider.future);
    officeContacts = await ref.read(officeUsersProvider.future);
    tabIndex = ref.read(tabIndexProvider);

    await _loadIndexValue();
    isLoading = false;
  }

  Future<void> _loadIndexValue() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var lastIndex = prefs.getInt('last_index');
    if (lastIndex != null && lastIndex != tabIndex) {
      setState(() {
        tabIndex = lastIndex;
      });
    }
  }

  static const List<Widget> _screens = [
    Dashboard(),
    Discover(),
    ContactsPage(),
    Profile()
  ];
  void _onWillPop() {
    setState(() => canPop = true);
    Fluttertoast.showToast(
        msg: " Press again to close  ",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: const Color.fromARGB(255, 26, 26, 26),
        textColor: Colors.white,
        fontSize: 16.0);
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) setState(() => canPop = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // super.build(context);
    isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    tabIndex = ref.watch(tabIndexProvider);

    return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          _onWillPop();
        },
        child: Scaffold(
            body: isLoading
                ? Center(
                    child: LoadingAnimationWidget.flickr(
                        leftDotColor: Colors.blue,
                        rightDotColor:
                            isDarkMode ? Colors.white : Colors.lightBlueAccent,
                        size: 50))
                : IndexedStack(index: tabIndex, children: _screens),
            bottomNavigationBar: BottomnavBar()));
  }
}

class BottomnavBar extends ConsumerStatefulWidget {
  const BottomnavBar({super.key});

  @override
  ConsumerState<BottomnavBar> createState() => _BottomnavBarState();
}

class _BottomnavBarState extends ConsumerState<BottomnavBar> {
  @override
  Widget build(BuildContext context) {
    int tabIndex = ref.watch(tabIndexProvider);

    return FlashyTabBar(
      selectedIndex: tabIndex,
      showElevation: true,
      height: 55,
      backgroundColor: const Color.fromARGB(255, 21, 21, 21),
      iconSize: 28,
      animationCurve: Curves.easeOutExpo,
      onItemSelected: (index) async {
        ref.read(tabIndexProvider.notifier).state = index;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setInt('last_index', index);
      },
      items: [
        FlashyTabBarItem(
          icon: const Icon(IconlyBroken.home),
          title: const Text('Home'),
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
        ),
        FlashyTabBarItem(
          icon: const Icon(IconlyLight.discovery),
          title: const Text('Discover'),
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
        ),
        FlashyTabBarItem(
          icon: const Icon(IconlyLight.work),
          title: const Text('Contacts'),
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
        ),
        FlashyTabBarItem(
          icon: const Icon(IconlyBroken.profile),
          title: const Text('Profile'),
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
        ),
      ],
    );
  }

}

