import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';

import '../models/leave.dart';
import '../models/user.dart';
import '../shared/constants.dart';
import 'leave_form.dart';

class Discover extends ConsumerStatefulWidget {
  const Discover({super.key});

  @override
  ConsumerState<Discover> createState() => _DiscoverState();
}

class _DiscoverState extends ConsumerState<Discover> {
  int selectedTabIndex = 0;
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

  Future<User> fetchManagerInfo() async {
    try {
      if (userData.managerId == null) {
        return userData;
      }

      final List<Map<String, dynamic>> response = await sb.pubbase!
          .from('users')
          .select()
          .eq('id', userData.managerId!)
          .limit(1);

      if (response.isEmpty) {
        return userData;
      }

      return User.fromJson(response.first);
    } catch (e) {
      debugPrint("Error fetching manager info: $e");
      return userData;
    }
  }

  Future<List<LeaveRecord>> fetchTeamLeaveRecords() async {
    if (manageUsers.isEmpty) return [];

    // Extract user IDs
    List<int> userIds = manageUsers.map((user) => user.id).toList();

    try {
      final response = await sb.pubbase!
          .from('leave_record')
          .select()
          .inFilter('user_id', userIds)
          .order('from_date', ascending: false);

      if (response.isNotEmpty) {
        return response.map((data) => LeaveRecord.fromJson(data)).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint("Error fetching team leave records: $e");
      return [];
    }
  }

  List<LeaveRecord> getFilteredLeaveRecords() {
    DateTime today = DateTime.now();
    DateTime todayWithoutTime = DateTime(today.year, today.month, today.day);

    List<LeaveRecord> filteredRecords;
    if (selectedTabIndex == 0) {
      // Upcoming Leaves (including today)
      filteredRecords = leaveRecord
          .where((record) =>
              record.fromDate.isAfter(todayWithoutTime) ||
              record.fromDate.isAtSameMomentAs(todayWithoutTime))
          .toList();
    } else if (selectedTabIndex == 1) {
      // Past Leaves (before today)
      filteredRecords = leaveRecord
          .where((record) => record.fromDate.isBefore(todayWithoutTime))
          .toList();
    } else {
      filteredRecords = teamLeaveRecords;
    }

    // Sorting Logic:
    filteredRecords.sort((a, b) {
      // 1. Pending Leaves First (status == false & decisionBy == null)
      if (!a.status &&
          a.decisionBy == null &&
          (b.status || b.decisionBy != null)) {
        return -1;
      }
      if (!b.status &&
          b.decisionBy == null &&
          (a.status || a.decisionBy != null)) {
        return 1;
      }

      // 2. Approved Leaves Next (status == true)
      if (a.status && !b.status) return -1;
      if (b.status && !a.status) return 1;

      // 3. Rejected Leaves Last (status == false but decisionBy != null)
      if (!a.status &&
          a.decisionBy != null &&
          (b.status || b.decisionBy == null)) {
        return 1;
      }
      if (!b.status &&
          b.decisionBy != null &&
          (a.status || a.decisionBy == null)) {
        return -1;
      }

      // 4. If same status, sort by fromDate (earliest first)
      return a.fromDate.compareTo(b.fromDate);
    });

    return filteredRecords;
  }

  @override
  Widget build(BuildContext context) {
    leaveRecord = ref.watch(userLeaveRecordsProvider).asData?.value ?? [];
    List<LeaveRecord> filteredRecords = getFilteredLeaveRecords();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    buildStatsGrid(),
                    const SizedBox(height: 25),
                    _buildTabBar(),
                    const SizedBox(height: 8),
                    filteredRecords.isEmpty
                    // no data empty
                        ? Center(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 50),
                                Image.asset(
                                  'assets/doubt.png',
                                  height: 80,
                                ),
                                Text(
                                  selectedTabIndex == 0
                                      ? 'No Upcoming\nrecords found.'
                                      : selectedTabIndex == 1
                                          ? 'No Past\nrecords found.'
                                          : "No Records",
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
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: filteredRecords.length,
                            itemBuilder: (context, index) {
                              final leave = filteredRecords[index];

                              // If "Team Leave" tab is selected → Use leaveRequestCard
                              if (selectedTabIndex == 2) {
                                return leaveRequestCard(lRecord: leave);
                              }

                              return GestureDetector(
                                  onTap: () => Navigator.push(
                                              context,
                                              PageTransition(
                                                  type: PageTransitionType
                                                      .rightToLeftWithFade,
                                                  child: ApplyLeaveScreen(
                                                      lRecord: leave)))
                                          .then((_) async {
                                        leaveRecord = await ref.refresh(
                                            userLeaveRecordsProvider.future);
                                        teamLeaveRecords =
                                            await fetchTeamLeaveRecords();
                                        setState(() {});
                                      }),
                                  child: leaveCard(lRecord: leave));
                            },
                          ),
                    const SizedBox(height: 60)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Text(
            "All Leaves",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Add Button
          GestureDetector(
              onTap: () {
                Navigator.push(
                        context,
                        PageTransition(
                            type: PageTransitionType.rightToLeftWithFade,
                            child: const ApplyLeaveScreen()))
                    .then((_) async {
                  leaveRecord =
                      await ref.refresh(userLeaveRecordsProvider.future);
                  teamLeaveRecords = await fetchTeamLeaveRecords();
                  setState(() {});
                });
              },
              child:
                  const Icon(IconlyLight.plus, color: Colors.white, size: 30)),
        ],
      ),
    );
  }

  Widget buildStatsGrid() {
    // Calculate statistics
    int totalBalance = 12;
    final int approved =
        leaveRecord.where((record) => record.status == true).length;
    final int pending =
        leaveRecord.where((record) => record.decisionBy == null).length;
    final int cancelled = leaveRecord
        .where((record) => record.status == false && record.decisionBy != null)
        .length;
    totalBalance = totalBalance - approved;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: buildStatCard(
                  title: "Leave\nBalance",
                  value: totalBalance.toString(),
                  color: Colors.blue,
                  icon: IconlyLight.graph,
                  subtitle: "Days Available",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildStatCard(
                  title: "Leave\nApproved",
                  value: approved.toString(),
                  color: Colors.greenAccent,
                  icon: IconlyLight.shield_done,
                  subtitle: "Requests",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: buildStatCard(
                  title: "Leave\nPending",
                  value: pending.toString(),
                  color: Colors.amber,
                  icon: IconlyLight.danger,
                  subtitle: "Awaiting Approval",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildStatCard(
                  title: "Leave\nCancelled",
                  value: cancelled.toString(),
                  color: Colors.redAccent,
                  icon: IconlyLight.shield_fail,
                  subtitle: "Rejected",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required String subtitle,
  }) {
    return Container(
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 22, 22, 22),
        shadows: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 20,
            cornerSmoothing: 0.8,
          ),
          side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: color, size: 30),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          // const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final int tabCount = isAdmin ? 3 : 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: ShapeDecoration(
          color: const Color.fromARGB(255, 19, 19, 19),
          shape: SmoothRectangleBorder(
            side: BorderSide(
              color: const Color.fromARGB(148, 38, 38, 38),
              width: 1,
            ),
            borderRadius:
                SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1),
          ),
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
                    decoration: ShapeDecoration(
                      color: Colors.blue,
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                          cornerRadius: 8,
                          cornerSmoothing: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                // Tab items
                Row(
                  children: List.generate(tabCount, (index) {
                    final String title = index == 0
                        ? "Upcoming"
                        : index == 1
                            ? "Past"
                            : "Team Leave";

                    return Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          selectedTabIndex = index;
                          if (selectedTabIndex == 2) {
                            teamLeaveRecords = await fetchTeamLeaveRecords();
                          }
                          setState(() {});
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          // padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: selectedTabIndex == index
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selectedTabIndex == index
                                  ? Colors.white
                                  : Colors.grey,
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
    );
  }

  Widget leaveCard({
    required LeaveRecord lRecord,
  }) {
    // Determine status and corresponding text/color
    late String statusText;
    late Color statusColor;

    if (lRecord.status) {
      statusText = "APPROVED";
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

    final int leaveBalance = 12;
    final int approved =
        leaveRecord.where((record) => record.status == true).length;

    // If pending, show "—" as approvedBy, otherwise show decisionBy
    final String approvedBy = statusText == "PENDING"
        ? "—"
        : (managerInfo == null || managerInfo!.id == userData.id
            ? 'Unknown'
            : managerInfo!.fullName ?? 'Unknown');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 14, 14, 14),
        shape: RoundedRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 24, cornerSmoothing: 1),
          side: BorderSide(
            color: const Color.fromARGB(255, 43, 43, 43),
            width: .5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// --- Top row: "Date" label (left) & status badge (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Date",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade300,
                    ),
                  ),

                  /// --- Middle row: Date range in larger text
                  Text(
                    applyDays <= 1
                        ? DateFormat('dd MMM yyyy').format(lRecord.fromDate)
                        : "${DateFormat('dd MMM').format(lRecord.fromDate)} to ${DateFormat('dd MMM yyyy').format(lRecord.toDate)}",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: ShapeDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: SmoothRectangleBorder(
                    borderRadius:
                        SmoothBorderRadius(cornerRadius: 5, cornerSmoothing: 1),
                  ),
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
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: Color.fromARGB(255, 22, 22, 22)),
          const SizedBox(height: 3),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Apply Days
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Apply Days",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$applyDays Days",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Leave Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Leave Balance",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${leaveBalance - approved}",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Approved By
              if (approvedBy != 'Unknown')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Approved By",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color.fromARGB(255, 128, 128, 128),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      approvedBy,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget leaveRequestCard({
    required LeaveRecord lRecord,
  }) {
    // Find the user who matches this leave record
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

    // Determine status and corresponding text/color
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
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 14, 14, 14),
        shape: RoundedRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 24, cornerSmoothing: 1),
          // side: BorderSide(
          //   color: const Color.fromARGB(255, 43, 43, 43),
          //   width: .5,
          // ),
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
          const SizedBox(height: 5),
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
                      side: BorderSide(
                          color: statusColor.withValues(alpha: 200), width: .4),
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
                            child: ApplyLeaveScreen(lRecord: lRecord)))
                    .then((_) async {
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
