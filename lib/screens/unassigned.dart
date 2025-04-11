import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_attendance/components/snackbar.dart';
import 'package:iconly/iconly.dart';

import '../models/user.dart';
import '../shared/constants.dart';
import 'contacts.dart';

class UnAssignedUsers extends ConsumerStatefulWidget {
  const UnAssignedUsers({super.key});

  @override
  UnAssignedUsersState createState() => UnAssignedUsersState();
}

class UnAssignedUsersState extends ConsumerState<UnAssignedUsers> {
  User? selectedUser;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Fetch data asynchronously from the providers.
  Future<void> _init() async {
    officeContacts = await ref.refresh(officeUsersProvider.future);
    notManagedUsers = await ref.refresh(officeUsersWithoutAdminProvider.future);
    officeContacts.sort((a, b) => a.fullName!.compareTo(b.fullName!));
    if (mounted) setState(() {});
  }

  AppBar _buildAppbar() {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: const Color.fromARGB(51, 41, 41, 41),
      titleSpacing: 0,
      leadingWidth: 100,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(IconlyBroken.arrow_left_2, size: 26, color: Colors.blue),
          ],
        ),
      ),
      title: Text(
        'UnAssigned Employees',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppbar(),
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          children: [
            // List of unassigned user contact cards.
            Expanded(
              child: notManagedUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_off,
                              size: 60, color: Colors.white54),
                          const SizedBox(height: 20),
                          Text(
                            'No users available',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: notManagedUsers.length,
                      itemBuilder: (context, index) {
                        final user = notManagedUsers[index];
                        return GestureDetector(
                          onTap: () => _showUserDetailsBottomSheet(user),
                          child: contactCard(user),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Contact card widget. Tapping this will open a bottom sheet.
  Widget contactCard(User user) {
    final fallbackLetter =
        (user.fullName ?? user.email).substring(0, 1).toUpperCase();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 14, 14, 14),
        shape: RoundedRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 18, cornerSmoothing: 1),
          side: const BorderSide(
            color: Color.fromARGB(255, 43, 43, 43),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Profile image with fallback text.
          CircleAvatar(
            backgroundColor: Colors.blueAccent,
            radius: 25,
            backgroundImage: user.icon != null && user.icon!.isNotEmpty
                ? NetworkImage(user.icon!)
                : null,
            child: (user.icon == null || user.icon!.isEmpty)
                ? Text(
                    fallbackLetter,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // User details.
          Expanded(
            child: Column(
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
                // const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email.split('@')[0],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          user.role,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                    if (user.phone != null)
                      IconButton(
                        icon: const Icon(IconlyLight.call,
                            color: Colors.blueAccent, size: 18),
                        onPressed: () {
                          launchPhoneDialer(user.phone!);
                        },
                      ),
                    if (user.phone == null)
                      IconButton(
                        icon: const Icon(IconlyLight.send,
                            color: Colors.blueAccent, size: 18),
                        onPressed: () {
                          launchEmail(user.email);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsBottomSheet(User employee) {
    // localSelectedManager must not be the employee itself.
    User? localSelectedManager;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          // Create a filtered list that excludes the employee.
          List<User> managers =
              officeContacts.where((u) => u.id != employee.id).toList();

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: Employee details.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.fullName ?? employee.email,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            employee.email,
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
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Manager selection dropdown.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Manager',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomDropdown<User>.search(
                    key: const ValueKey('user_bottom_sheet_dropdown'),
                    items: managers,
                    onChanged: (selected) {
                      setModalState(() {
                        localSelectedManager = selected;
                      });
                    },
                    initialItem: managers.contains(localSelectedManager)
                        ? localSelectedManager
                        : null,
                    hintText: 'Search & select manager',
                    searchHintText: 'Type to search user...',
                    noResultFoundText: 'No user found',
                    validateOnChange: true,
                    excludeSelected: false,
                    canCloseOutsideBounds: true,
                    overlayHeight: 550,
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
                    headerBuilder: (context, item, isOpened) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        child: Text(item.fullName ?? item.email,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      );
                    },
                    listItemBuilder: (context, item, isSelected, onItemTapped) {
                      final fallbackLetter = (item.fullName ?? item.email)
                          .substring(0, 1)
                          .toUpperCase();
                      return ListTile(
                        onTap: onItemTapped,
                        leading: item.icon != null && item.icon!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  item.icon!,
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
                              item.fullName ?? item.email,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                               Text(item.role,
                                style: GoogleFonts.poppins(
                                    color: Colors.white30,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)
                              ),
                          ],
                        ),
                        subtitle: item.position != null
                            ? Text(
                                item.position!,
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
                  // Full width ASSIGN button.
                  SizedBox(
                    width: double.infinity,
                    child: _isProcessing
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 20, 20, 20),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Processing...",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: localSelectedManager == null
                                ? null
                                : () {
                                    _assignManagerAndRefresh(
                                      employee: employee,
                                      manager: localSelectedManager!,
                                      setModalState: setModalState,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2962FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'ASSIGN',
                              style: GoogleFonts.gabarito(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _assignManagerAndRefresh({
    required User employee,
    required User manager,
    required void Function(void Function()) setModalState,
  }) async {
    setModalState(() => _isProcessing = true);

    try {
      final response = await sb.pubbase!
          .from('users')
          .update({'manager_id': manager.id})
          .eq('id', employee.id)
          .select();

      if (response.isEmpty) {
        info('Something went Wrong', Severity.error);
      }

      info('Manager assigned successfully', Severity.success);

      // Refresh related data
      officeContacts = await ref.refresh(officeUsersProvider.future);
      notManagedUsers =
          await ref.refresh(officeUsersWithoutAdminProvider.future);

      officeContacts.sort((a, b) => a.fullName!.compareTo(b.fullName!));

      if (mounted) setState(() {});
      Navigator.pop(context);
    } catch (e) {
      debugPrint('-- Error: $e');
      info('Oops, something went wrong: $e', Severity.error);
    } finally {
      setModalState(() => _isProcessing = false);
    }
  }
}
