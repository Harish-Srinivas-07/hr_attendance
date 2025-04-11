import 'dart:ui';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';

import '../models/attendance.dart';
import '../models/leave.dart';
import '../models/user.dart';
import '../shared/constants.dart';
import 'dashboard.dart';
import 'discover.dart';
import 'leave_form.dart';
import 'profile.dart';

class LeaveRequests extends ConsumerStatefulWidget {
  const LeaveRequests({super.key});

  @override
  ConsumerState<LeaveRequests> createState() => _LeaveRequestsState();
}

class _LeaveRequestsState extends ConsumerState<LeaveRequests> {
  int selectedTabIndex = 0;
  // int selectedStatusindex = 1;
  int? selectedStatusindex;
  User? selectedUser;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    userData = await ref.read(userInfoProvider.future);
    if (userData.officeId != null) {
      officeData = await ref.read(officeInfoProvider.future);
      managerInfo = await fetchManagerInfo();
      attendances = await ref.read(userAttendanceProvider.future);
      leaveRecord = await ref.refresh(userLeaveRecordsProvider.future);
      manageUsers = await ref.refresh(managedUsersProvider.future);
      teamLeaveRecords = await fetchTeamLeaveRecords();
    }
    setState(() {});
  }

// 2. Modify the filtering function to apply status filter only if selectedStatusindex is not null
  List<LeaveRecord> getFilteredLeaveRecords(List<LeaveRecord> records) {
    final now = DateTime.now();

    // Time-based filter: Upcoming or Past
    List<LeaveRecord> filtered = selectedTabIndex == 0
        ? records
            .where((leave) =>
                leave.toDate.isAfter(now) ||
                leave.fromDate.isAtSameMomentAs(now))
            .toList()
        : records.where((leave) => leave.toDate.isBefore(now)).toList();

    // Status filter (if one has been chosen)
    if (selectedStatusindex != null) {
      filtered = filtered.where((leave) {
        switch (selectedStatusindex) {
          case 0: // Approved
            return leave.decisionBy != null && leave.status;
          case 1: // Pending
            return leave.decisionBy == null;
          case 2: // Rejected
            return leave.decisionBy != null && !leave.status;
          default:
            return true;
        }
      }).toList();
    }

    // Filter by user if selected
    if (selectedUser != null) {
      filtered =
          filtered.where((leave) => leave.userId == selectedUser!.id).toList();
    }

    // Sort records: priority (pending > approved > rejected) then by nearest fromDate
    filtered.sort((a, b) {
      int priority(LeaveRecord leave) {
        if (leave.decisionBy == null) return 0; // Pending
        if (leave.status) return 1; // Approved
        return 2; // Rejected
      }

      final p1 = priority(a);
      final p2 = priority(b);
      if (p1 != p2) return p1.compareTo(p2);
      final aDiff = (a.fromDate.difference(now)).abs();
      final bDiff = (b.fromDate.difference(now)).abs();
      return aDiff.compareTo(bDiff);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = getFilteredLeaveRecords(teamLeaveRecords);
    return Scaffold(
      appBar: _buildAppbar(),
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    filteredRecords.isEmpty
                        ? Center(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 50),
                                Image.asset(
                                  'assets/empty.png',
                                  height: 200,
                                ),
                                Text(
                                  selectedTabIndex == 0
                                      ? 'No Upcoming\nrecords found.'
                                      : 'No Past\nrecords found.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: filteredRecords.length,
                            itemBuilder: (context, index) {
                              final leave = filteredRecords[index];
                              return leaveRequestCard(lRecord: leave);
                            },
                          ),
                    const SizedBox(height: 60)
                  ],
                ),
              ),
            ),
            if (selectedTabIndex == 1)
              infoCard(
                text:
                    'Past Requests are assumed as rejected, as the past dates can\'t be processed anyway.',
              ),
          ],
        ),
      ),
    );
  }

// 3. In the filter bottom sheet use a local nullable status variable
  void showUserFilterBottomSheet(BuildContext context) {
    int? localStatusIndex = selectedStatusindex; // local filter may be null
    User? localSelectedUser = selectedUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter Leave Records',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'select filter & click apply.',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white30),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Status Tab (pass -1 when no status is selected)
                  buildStatusTab(
                    selectedIndex: localStatusIndex ?? -1,
                    onChanged: (index) {
                      setModalState(() {
                        localStatusIndex = index;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // User dropdown remains unchanged…
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select User',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomDropdown<User>.search(
                    key: const ValueKey('user_dropdown'),
                    items: manageUsers,
                    onChanged: (user) {
                      setModalState(() {
                        localSelectedUser = user;
                      });
                    },
                    initialItem: localSelectedUser,
                    hintText: 'Search & select user',
                    searchHintText: 'Type to search user...',
                    noResultFoundText: 'No user found',
                    // validator: (user) =>
                    //     user == null ? 'Please select a user' : null,
                    validateOnChange: true,
                    excludeSelected: false,
                    canCloseOutsideBounds: true,
                    overlayHeight: 300,
                    maxlines: 1,
                    itemsListPadding: const EdgeInsets.symmetric(vertical: 8),
                    listItemPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: CustomDropdownDecoration(
                      closedFillColor: const Color.fromARGB(255, 35, 35, 35),
                      expandedFillColor: const Color.fromARGB(255, 29, 29, 29),
                      closedBorder: Border.all(color: Colors.white24),
                      closedBorderRadius: BorderRadius.circular(10),
                      expandedBorder: Border.all(color: Colors.white24),
                      expandedBorderRadius: BorderRadius.circular(10),
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 14),
                      headerStyle: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 14),
                      listItemStyle:
                          GoogleFonts.poppins(color: Colors.blue, fontSize: 14),
                      searchFieldDecoration: SearchFieldDecoration(
                        fillColor: const Color(0xFF1C1C1C),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        textStyle: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 14),
                        hintStyle: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white60),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(82, 31, 113, 255),
                              width: 1),
                        ),
                      ),
                      listItemDecoration: ListItemDecoration(
                        selectedColor: const Color.fromARGB(159, 33, 65, 135),
                        selectedIconColor: Colors.blueAccent,
                        selectedIconBorder:
                            const BorderSide(color: Colors.transparent),
                        selectedIconShape: const CircleBorder(),
                      ),
                    ),
                    headerBuilder: (context, user, isOpened) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        child: Text(
                          user.fullName ?? user.email,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    listItemBuilder: (context, user, isSelected, onItemTapped) {
                      final fallbackLetter = (user.fullName ?? user.email)
                          .substring(0, 1)
                          .toUpperCase();
                      return ListTile(
                        onTap: onItemTapped,
                     leading: user.icon != null && user.icon!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  user.icon!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => CircleAvatar(
                                    backgroundColor: Colors.blueAccent,
                                    child: Text(
                                      fallbackLetter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Text(
                                  fallbackLetter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
 title: Text(
                          user.fullName ?? user.email,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: user.position != null
                            ? Text(
                                user.position!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  // Buttons: Reset and Apply.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              localStatusIndex = null;
                              localSelectedUser = null;
                            });
                            setState(() {
                              selectedStatusindex = localStatusIndex;
                              selectedUser = localSelectedUser;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                                color: Color(0xFF3A3A3A), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('RESET',
                              style: GoogleFonts.gabarito(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedStatusindex = localStatusIndex;
                              selectedUser = localSelectedUser;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('APPLY',
                              style: GoogleFonts.gabarito(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

// 4. Update the status tab widget to show only three options (Approved, Pending, Rejected).
// When no status is selected (i.e. selectedIndex == -1), no tab is highlighted.
  Widget buildStatusTab({
    required int selectedIndex,
    required void Function(int) onChanged,
  }) {
    // This list is fixed (3 items) and does not include "All"
    final List<String> statuses = ["Approved", "Pending", "Rejected"];
    final int tabCount = statuses.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double tabWidth = constraints.maxWidth / tabCount;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    left: (selectedIndex >= 0 ? selectedIndex : 0) * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: selectedIndex >= 0
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent.shade200,
                                  Colors.blueAccent.shade700
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Row(
                    children: List.generate(tabCount, (index) {
                      final String title = statuses[index];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onChanged(index),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: (selectedIndex == index)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: (selectedIndex == index)
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  AppBar _buildAppbar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: ScreenSize.screenHeight! / 6.2,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0C0C0C),
              Color.fromARGB(255, 12, 38, 88),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF2C2F3F),
              width: 0.8,
            ),
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Back button + Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        IconlyBroken.arrow_left_2,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Team Leaves',
                      style: GoogleFonts.gabarito(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => showUserFilterBottomSheet(context),
                  child: const Icon(
                    IconlyLight.filter,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Tab bar
            _buildTabBar(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    const int tabCount = 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double tabWidth = constraints.maxWidth / tabCount;
                return Stack(
                  children: [
                    // Animated selection indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      left: selectedTabIndex * tabWidth,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.shade200,
                              Colors.blueAccent.shade700
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    // Tab items
                    Row(
                      children: List.generate(tabCount, (index) {
                        final String title = index == 0 ? "Upcoming" : "Past";
                        return Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              selectedTabIndex = index;
                              // Optionally refresh team leave records if needed.
                              if (selectedTabIndex == 2) {
                                teamLeaveRecords =
                                    await fetchTeamLeaveRecords();
                              }
                              setState(() {});
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              height: 40,
                              alignment: Alignment.center,
                              child: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: selectedTabIndex == index
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selectedTabIndex == index
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget leaveRequestCard({
    required LeaveRecord lRecord,
  }) {
    // Find the user who matches this leave record.
    User? user = manageUsers.firstWhere(
      (u) => u.id == lRecord.userId,
      orElse: () => User(
        id: 0,
        email: "Unknown",
        role: "N/A",
        createdAt: DateTime.now(),
        fullName: "Unknown User",
        icon: "",
      ),
    );

    // Determine the leave status display.
    late String statusText;
    late Color statusColor;
    if (lRecord.status) {
      statusText = "ACCEPTED";
      statusColor = Colors.green;
    } else if (lRecord.decisionBy == null) {
      statusText = "PENDING";
      statusColor = Colors.orange;
    } else {
      statusText = "REJECTED";
      statusColor = Colors.red;
    }

    final int applyDays =
        lRecord.toDate.difference(lRecord.fromDate).inDays + 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 14, 14, 14),
        shape: RoundedRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 18, cornerSmoothing: 1),
          side: BorderSide(
            color: const Color.fromARGB(255, 43, 43, 43),
            width: .5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// --- Profile & Name
          Row(
            children: [
              // Profile Picture with fallback logic
              CircleAvatar(
                backgroundColor: Colors.blueAccent,
                radius: 20,
                backgroundImage: user.icon != null && user.icon!.isNotEmpty
                    ? NetworkImage(user.icon!)
                    : null,
                child: (user.icon == null || user.icon!.isEmpty)
                    ? Text(
                        user.email[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              // User Name & Leave Dates
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName ?? "Unknown User",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    applyDays <= 1
                        ? DateFormat('dd MMM yyyy').format(lRecord.fromDate)
                        : "${DateFormat('dd MMM').format(lRecord.fromDate)} to ${DateFormat('dd MMM yyyy').format(lRecord.toDate)}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color.fromARGB(255, 33, 33, 33)),
          const SizedBox(height: 3),

          // Status Display Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                user.role,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white30,
                ),
              ),
              const Spacer(),
              // Display Status Label
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(
                  color: statusColor.withOpacity(.15),
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 8, cornerSmoothing: 1)),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Display button (only one button is shown)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.rightToLeftWithFade,
                    child: ApplyLeaveScreen(lRecord: lRecord),
                  ),
                ).then((_) async {
                  leaveRecord =
                      await ref.refresh(userLeaveRecordsProvider.future);
                  teamLeaveRecords = await fetchTeamLeaveRecords();
                  setState(() {});
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: ShapeDecoration(
                    color: const Color.fromARGB(255, 32, 32, 32),
                    shape: SmoothRectangleBorder(
                        side: BorderSide(
                            color: const Color.fromARGB(255, 47, 47, 47),
                            width: 1),
                        borderRadius: SmoothBorderRadius(
                            cornerRadius: 8, cornerSmoothing: 1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'View',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PendingApprovalPage extends ConsumerStatefulWidget {
  const PendingApprovalPage({super.key});

  @override
  ConsumerState<PendingApprovalPage> createState() =>
      _PendingApprovalPageState();
}

class _PendingApprovalPageState extends ConsumerState<PendingApprovalPage> {
  // 0: This Week, 1: This Month
  int selectedTimeFilter = 0;

  int? selectedStatusindex;
  User? selectedUser;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Assume userData, officeData, etc. are loaded similarly.
    userData = await ref.read(userInfoProvider.future);
    if (userData.officeId != null) {
      manageUsers = await ref.refresh(managedUsersProvider.future);
      // Use your attendance fetch function.
      teamAttendance = await fetchPendingApprovalAttendances();
    }
    setState(() {});
  }

  String getAttendanceStatus(Attendance att) {
    if (att.approvalRequired) {
      if (att.approvedBy != null) return 'Approved';
      return 'Pending';
    } else {
      if (att.approvedBy != null) return 'Rejected';
      return 'Unknown';
    }
  }

  List<Attendance> getFilteredAttendances(List<Attendance> allAtts) {
    final now = DateTime.now();

    // ✅ Exclude entries where checkIn or checkOut is null
    List<Attendance> filtered =
        allAtts.where((att) => att.checkOut != null).toList();

    // Time-range filter.
    filtered = filtered.where((att) {
      if (selectedTimeFilter == 0) {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return att.createdAt.isAfter(startOfWeek) &&
            att.createdAt.isBefore(endOfWeek.add(const Duration(days: 1)));
      } else {
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        return att.createdAt.isAfter(startOfMonth) &&
            att.createdAt.isBefore(endOfMonth.add(const Duration(days: 1)));
      }
    }).toList();

    // Status filter if set
    if (selectedStatusindex != null) {
      filtered = filtered.where((att) {
        String status = getAttendanceStatus(att);
        switch (selectedStatusindex) {
          case 0:
            return status == 'Approved';
          case 1:
            return status == 'Pending';
          case 2:
            return status == 'Rejected';
          default:
            return true;
        }
      }).toList();
    }

    // Filter by user if selected.
    if (selectedUser != null) {
      filtered =
          filtered.where((att) => att.userId == selectedUser!.id).toList();
    }

    // Sorting: Approved (0), Rejected (1), Pending (2), then by date
    filtered.sort((a, b) {
      int priority(Attendance att) {
        String status = getAttendanceStatus(att);
        if (status == 'Approved') return 0;
        if (status == 'Rejected') return 1;
        if (status == 'Pending') return 2;
        return 3;
      }

      final p1 = priority(a);
      final p2 = priority(b);
      if (p1 != p2) return p1.compareTo(p2);
      return a.createdAt
          .difference(now)
          .abs()
          .compareTo(b.createdAt.difference(now).abs());
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredAtts = getFilteredAttendances(teamAttendance);
    return Scaffold(
      appBar: _buildAppbar(),
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // List of filtered attendance cards.
            Expanded(
              child: filteredAtts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/empty.png', height: 200),
                          const SizedBox(height: 20),
                          Text(
                            selectedTimeFilter == 0
                                ? 'No attendance records for this week.'
                                : 'No attendance records for this month.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredAtts.length,
                      itemBuilder: (context, index) {
                        final att = filteredAtts[index];
                        return attendanceCard(att: att);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void showAttendanceFilterBottomSheet(BuildContext context) {
    int? localStatusIndex = selectedStatusindex;
    User? localSelectedUser = selectedUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter Attendances',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'select filter & click apply',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white30,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Status Tab for teamAttendance:
                  buildStatusTab(
                    selectedIndex: localStatusIndex ?? -1,
                    onChanged: (index) {
                      setModalState(() {
                        localStatusIndex = index;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // User dropdown:
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select User',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomDropdown<User>.search(
                    key: const ValueKey('user_dropdown_att'),
                    items: manageUsers,
                    onChanged: (user) {
                      setModalState(() {
                        localSelectedUser = user;
                      });
                    },
                    initialItem: localSelectedUser,
                    hintText: 'Search & select user',
                    searchHintText: 'Type to search user...',
                    noResultFoundText: 'No user found',
                    validateOnChange: true,
                    excludeSelected: false,
                    canCloseOutsideBounds: true,
                    overlayHeight: 300,
                    maxlines: 1,
                    itemsListPadding: const EdgeInsets.symmetric(vertical: 8),
                    listItemPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: CustomDropdownDecoration(
                      closedFillColor: const Color.fromARGB(255, 35, 35, 35),
                      expandedFillColor: const Color.fromARGB(255, 29, 29, 29),
                      closedBorder: Border.all(color: Colors.white24),
                      closedBorderRadius: BorderRadius.circular(10),
                      expandedBorder: Border.all(color: Colors.white24),
                      expandedBorderRadius: BorderRadius.circular(10),
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 14),
                      headerStyle: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 14),
                      listItemStyle:
                          GoogleFonts.poppins(color: Colors.blue, fontSize: 14),
                      searchFieldDecoration: SearchFieldDecoration(
                        fillColor: const Color(0xFF1C1C1C),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        textStyle: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 14),
                        hintStyle: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white60),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(82, 31, 113, 255),
                              width: 1),
                        ),
                      ),
                      listItemDecoration: ListItemDecoration(
                        selectedColor: const Color.fromARGB(159, 33, 65, 135),
                        selectedIconColor: Colors.blueAccent,
                        selectedIconBorder:
                            const BorderSide(color: Colors.transparent),
                        selectedIconShape: const CircleBorder(),
                      ),
                    ),
                    headerBuilder: (context, user, isOpened) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        child: Text(
                          user.fullName ?? user.email,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    listItemBuilder: (context, user, isSelected, onItemTapped) {
                      final fallbackLetter = (user.fullName ?? user.email)
                          .substring(0, 1)
                          .toUpperCase();
                      return ListTile(
                        onTap: onItemTapped,
                      leading: user.icon != null && user.icon!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  user.icon!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => CircleAvatar(
                                    backgroundColor: Colors.blueAccent,
                                    child: Text(
                                      fallbackLetter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Text(
                                  fallbackLetter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
  title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName ?? user.email,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              user.role,
                              style: GoogleFonts.poppins(
                                  color: Colors.white30,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        subtitle: user.position != null
                            ? Text(
                                user.position!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  // Buttons: Reset and Apply.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              localStatusIndex = null;
                              localSelectedUser = null;
                            });
                            setState(() {
                              selectedStatusindex = localStatusIndex;
                              selectedUser = localSelectedUser;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                                color: Color(0xFF3A3A3A), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'RESET',
                            style: GoogleFonts.gabarito(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedStatusindex = localStatusIndex;
                              selectedUser = localSelectedUser;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'APPLY',
                            style: GoogleFonts.gabarito(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildStatusTab({
    required int selectedIndex,
    required void Function(int) onChanged,
  }) {
    final List<String> statuses = ["Approved", "Pending", "Rejected"];
    final int tabCount = statuses.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double tabWidth = constraints.maxWidth / tabCount;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    left: (selectedIndex >= 0 ? selectedIndex : 0) * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: selectedIndex >= 0
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent.shade200,
                                  Colors.blueAccent.shade700
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Row(
                    children: List.generate(tabCount, (index) {
                      final String title = statuses[index];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onChanged(index),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: (selectedIndex == index)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: (selectedIndex == index)
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  AppBar _buildAppbar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: ScreenSize.screenHeight! / 6.2,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0C0C0C), Color.fromARGB(255, 12, 38, 88)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF2C2F3F),
              width: 0.8,
            ),
          ),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Back button + Title row
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        IconlyBroken.arrow_left_2,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pending Approval',
                      style: GoogleFonts.gabarito(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => showAttendanceFilterBottomSheet(context),
                  child: const Icon(
                    IconlyLight.filter,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double tabWidth = constraints.maxWidth / 2;
                        return Stack(
                          children: [
                            // Smooth animated indicator
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              left: selectedTimeFilter * tabWidth,
                              top: 0,
                              bottom: 0,
                              width: tabWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blueAccent.shade200,
                                      Colors.blueAccent.shade700,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            // Interactive tab labels
                            Row(
                              children: List.generate(2, (index) {
                                final String label =
                                    index == 0 ? "This Week" : "This Month";
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedTimeFilter = index;
                                      });
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      height: 40,
                                      alignment: Alignment.center,
                                      child: Text(
                                        label,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight:
                                              selectedTimeFilter == index
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                          color: selectedTimeFilter == index
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget attendanceCard({required Attendance att}) {
    // Find the user that matches this attendance record.
    User? user = manageUsers.firstWhere(
      (u) => u.id == att.userId,
      orElse: () => User(
        id: 0,
        email: "Unknown",
        role: "N/A",
        createdAt: DateTime.now(),
        fullName: "Unknown User",
        icon: "",
      ),
    );

    // Determine the attendance status.
    String status = getAttendanceStatus(att);
    late Color statusColor;
    if (status == 'Approved') {
      statusColor = Colors.green;
    } else if (status == 'Pending') {
      statusColor = Colors.orange;
    } else if (status == 'Rejected') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

// Apply +5:30 offset and format with AM/PM
    final Duration offset = const Duration(hours: 5, minutes: 30);

    final String checkInTime =
        DateFormat('hh:mm a').format(att.checkIn.toUtc().add(offset));

    final String checkOutTime =
        DateFormat('hh:mm a').format(att.checkOut!.toUtc().add(offset));

    final String fullDate =
        DateFormat('dd MMM yyyy').format(att.checkIn.toUtc().add(offset));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 14, 14, 14),
        shape: RoundedRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 18, cornerSmoothing: 1),
          side: const BorderSide(
            color: Color.fromARGB(255, 43, 43, 43),
            width: .5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// --- Profile & Name Row
          Row(
            children: [
              // Profile picture with fallback
              CircleAvatar(
                backgroundColor: Colors.blueAccent,
                radius: 20,
                backgroundImage: user.icon != null && user.icon!.isNotEmpty
                    ? NetworkImage(user.icon!)
                    : null,
                child: (user.icon == null || user.icon!.isEmpty)
                    ? Text(
                        user.email[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              // User name and check-in date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName ?? "Unknown User",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$fullDate · $checkInTime - $checkOutTime',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color.fromARGB(255, 33, 33, 33)),
          const SizedBox(height: 3),
          // Status display row with "View" button.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                user.role,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white30,
                ),
              ),
              const Spacer(),
              // Status Label
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: ShapeDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: SmoothRectangleBorder(
                    borderRadius:
                        SmoothBorderRadius(cornerRadius: 8, cornerSmoothing: 1),
                  ),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // View Button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.rightToLeftWithFade,
                    child: AttendanceDetailsPage(attendance: att),
                  ),
                ).then((_) async {
                  teamAttendance = await fetchPendingApprovalAttendances();
                  setState(() {});
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: ShapeDecoration(
                    color: const Color.fromARGB(255, 32, 32, 32),
                    shape: SmoothRectangleBorder(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 47, 47, 47),
                        width: 1,
                      ),
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 8, cornerSmoothing: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'View',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
