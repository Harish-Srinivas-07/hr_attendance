import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/shimmer.dart';
import '../models/user.dart';
import '../shared/constants.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool isLoading = true;
  List<User> officeContacts = [];
  List<User> filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    officeContacts = await ref.read(officeUsersProvider.future);
    officeContacts.sort((a, b) => a.fullName!.compareTo(b.fullName!));
    filteredContacts = List.from(officeContacts);
    await updateUserAttendanceTimes();
    isLoading = false;
    if (mounted) setState(() {});
  }

Future<void> updateUserAttendanceTimes() async {
    try {
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      List<int> userIds = filteredContacts.map((user) => user.id).toList();

      final List<Map<String, dynamic>> attendanceRecords = await sb.pubbase!
          .from('attendance')
          .select('user_id, check_in, check_out, break_time, lunch_time')
          .inFilter('user_id', userIds)
          .eq('date_stamp', todayDate);

      // Create a map of user_id → attendance data
      Map<int, Map<String, dynamic>> attendanceMap = {
        for (var record in attendanceRecords) record['user_id']: record
      };

      for (var user in filteredContacts) {
        if (attendanceMap.containsKey(user.id)) {
          user.startTime = attendanceMap[user.id]!['check_in'] != null
              ? DateTime.parse(attendanceMap[user.id]!['check_in'])
              : null;
          user.endTime = attendanceMap[user.id]!['check_out'] != null
              ? DateTime.parse(attendanceMap[user.id]!['check_out'])
              : null;
          user.breakTime = attendanceMap[user.id]!['break_time'] != null
              ? DateTime.parse(attendanceMap[user.id]!['break_time'])
              : null;
          user.lunchTime = attendanceMap[user.id]!['lunch_time'] != null
              ? DateTime.parse(attendanceMap[user.id]!['lunch_time'])
              : null;
        }
      }

      // Trigger UI update
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return isLoading
        ? contactScreenShimmer()
        : SafeArea(
            child: Row(
              children: [
                // Contacts List
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      // Search Bar
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.push(
                              context,
                              PageTransition(
                                  type: PageTransitionType.fade,
                                  child: const SearchContact()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              // borderRadius: BorderRadius.circular(22),
                              borderRadius: SmoothBorderRadius(
                                  cornerRadius: 22, cornerSmoothing: 1),
                            ),
                            color: const Color.fromARGB(255, 19, 19, 19),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 5, right: 10),
                                child: Icon(
                                  IconlyLight.search,
                                  color: Colors.blueAccent,
                                  size: 22,
                                ),
                              ),
                              Text(
                                "Search contacts...",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredContacts.length,
                          itemBuilder: (context, index) {
                            final user = filteredContacts[index];
                            return _contactRow(user);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
  }
}

Widget _contactRow(User user) {
  // Determine status color
Color statusColor = const Color.fromARGB(255, 59, 59, 59);
  DateTime now = DateTime.now();

  if (user.breakTime != null) {
    DateTime breakEndTime = user.breakTime!.add(const Duration(minutes: 10));
    if (now.isBefore(breakEndTime)) {
      statusColor = Colors.yellow;
    }
  }
  if (user.lunchTime != null) {
    DateTime lunchEndTime = user.lunchTime!.add(const Duration(minutes: 30));
    if (now.isBefore(lunchEndTime)) {
      statusColor = Colors.orange;
    }
  }
  if (user.startTime != null &&
      statusColor == const Color.fromARGB(255, 59, 59, 59)) {
    statusColor = Colors.green;
  }
  if (user.endTime != null) {
    statusColor = Colors.red;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 22,
            cornerSmoothing: 1,
          ),
        ),
        color: const Color.fromARGB(255, 19, 19, 19),
      ),
      child: Row(
        children: [
          // Profile Picture with Status Indicator
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blueAccent,
                radius: 28,
                backgroundImage: user.icon != null && user.icon!.isNotEmpty
                    ? NetworkImage(user.icon!)
                    : null,
                child: (user.icon == null || user.icon!.isEmpty)
                    ? Text(
                        user.email[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      )
                    : null,
              ),
              // Status Indicator
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Contact Name & Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName ?? "Unknown",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email.split('@')[0],
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade500, fontSize: 13),
                )
              ],
            ),
          ),

          // Call & Email Icons
          Row(
            children: [
              // Phone Call Button
              if (user.phone != null)
                IconButton(
                  icon: const Icon(IconlyLight.call,
                      color: Colors.blueAccent, size: 22),
                  onPressed: () {
                    launchPhoneDialer(user.phone!);
                  },
                ),

              // Email Button
              IconButton(
                icon: const Icon(IconlyLight.send,
                    color: Colors.blueAccent, size: 22),
                onPressed: () {
                  launchEmail(user.email);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void launchPhoneDialer(int phoneNumber) async {
  final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber.toString());
  if (await canLaunchUrl(phoneUri)) {
    await launchUrl(phoneUri);
  } else {
    debugPrint("Could not launch phone dialer");
  }
}

void launchEmail(String email) async {
  final Uri emailUri = Uri(scheme: 'mailto', path: email);
  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  } else {
    debugPrint("Could not launch email app");
  }
}

class SearchContact extends ConsumerStatefulWidget {
  const SearchContact({super.key});

  @override
  ConsumerState<SearchContact> createState() => _SearchContactState();
}

class _SearchContactState extends ConsumerState<SearchContact>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<User> filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    officeContacts = await ref.read(officeUsersProvider.future);
    filteredContacts = List.from(officeContacts);
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _filterContacts(String query) {
    final lowerCaseQuery = query.toLowerCase();
    filteredContacts = officeContacts.where((user) {
      final name = user.fullName?.toLowerCase() ?? "";
      final email = user.email.toLowerCase();
      return name.contains(lowerCaseQuery) || email.contains(lowerCaseQuery);
    }).toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(IconlyLight.arrow_left_2,
                        color: Colors.blue, size: 20),
                    onPressed: () {
                      searchController.clear();
                      FocusScope.of(context).unfocus(
                          disposition:
                              UnfocusDisposition.previouslyFocusedChild);
                      Future.delayed(Duration(milliseconds: 300), () {
                        if (context.mounted) {
                          Navigator.maybePop(context);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: TextField(
                        controller: searchController,
                        // focusNode: _searchFocusNode,
                        cursorColor: Colors.blueAccent,
                        onChanged: _filterContacts,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500),
                        cursorHeight: 18,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: " Type to search...",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: const Color.fromARGB(255, 19, 19, 19),
                          prefixIcon: const Icon(
                            IconlyLight.search,
                            color: Colors.blueAccent,
                            size: 22,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 22,
                              cornerSmoothing: 1,
                            ),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: filteredContacts.isEmpty
                    ? const Center(
                        child: Text(
                          "No contacts found",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          return _contactRow(filteredContacts[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
