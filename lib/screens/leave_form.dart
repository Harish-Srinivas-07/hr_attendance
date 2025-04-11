import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_attendance/components/snackbar.dart';
import 'package:hr_attendance/models/user.dart';
import 'package:hr_attendance/shared/constants.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_dialogs/dialogs.dart';
import 'package:material_dialogs/shared/types.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../models/attendance.dart';
import '../models/leave.dart';
import 'contacts.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  // If a LeaveRecord is passed, the form becomes read-only
  final LeaveRecord? lRecord;

  const ApplyLeaveScreen({super.key, this.lRecord});

  @override
  ApplyLeaveScreenState createState() => ApplyLeaveScreenState();
}

class ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  bool _isLoading = false;
  bool _isProcessing = false;

  final List<String> leaveTypes = [
    'Casual Leave',
    'Paternity Leave',
    'Bereavement Leave',
    'Sick Leave',
    'Compensatory Off',
    'Sabbatical Leave'
  ];
  String? selectedLeaveType;
  DateTime? startDate;
  DateTime? endDate;
  bool get isReadOnly => widget.lRecord != null;

  @override
  void initState() {
    super.initState();
    if (widget.lRecord != null) {
      // Populate fields with passed record values and disable editing
      titleController.text = widget.lRecord!.title;
      contactController.text = widget.lRecord!.contact ?? "";
      reasonController.text = widget.lRecord!.reason ?? "";
      selectedLeaveType = widget.lRecord!.type;
      startDate = widget.lRecord!.fromDate;
      endDate = widget.lRecord!.toDate;
    }
  }

  Future<void> updateLeaveDecision(bool isApproved) async {
    setState(() => _isProcessing = true);

    try {
      final userId = userData.id;
      final updatedAt = DateTime.now().toIso8601String();

      final upsertData = {
        'id': widget.lRecord!.id,
        'user_id': widget.lRecord!.userId,
        'from_date': widget.lRecord!.fromDate.toIso8601String(),
        'to_date': widget.lRecord!.toDate.toIso8601String(),
        'type': widget.lRecord!.type,
        'title': widget.lRecord!.title,
        'decision_by': userId,
        'updated_at': updatedAt,
        if (isApproved) 'status': true,
      };

      final response =
          await sb.pubbase!.from('leave_record').upsert(upsertData).select();

      if (response.isEmpty) throw 'Upsert failed';

      info(isApproved ? 'Leave Approved' : 'Leave Rejected', Severity.success);
      List<int> userIds = manageUsers.map((user) => user.id).toList();

      final updateTeamData = await sb.pubbase!
          .from('leave_record')
          .select()
          .inFilter('user_id', userIds)
          .order('from_date', ascending: false);

      if (updateTeamData.isNotEmpty) {
        teamLeaveRecords =
            updateTeamData.map((data) => LeaveRecord.fromJson(data)).toList();
      }
      setState(() {});
      Navigator.pop(context);
    } catch (e) {
      debugPrint('-- Error: $e');
      info('Oops, something went wrong: $e', Severity.error);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _selectDate(bool isStart) async {
    if (isReadOnly) return; // Disable date selection in read-only mode

    DateTime now = DateTime.now();
    DateTime maxDate = now.add(const Duration(days: 180));
    FocusScope.of(context).unfocus();

    Dialogs.bottomMaterialDialog(
      color: Colors.black,
      context: context,
      customView: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 25),
            Text(
              'Select the Date Range',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: ScreenSize.screenWidth! / 1.1,
              child: SfDateRangePicker(
                backgroundColor: Colors.black,
                view: DateRangePickerView.month,
                initialSelectedRange: PickerDateRange(startDate, endDate),
                selectionMode: DateRangePickerSelectionMode.range,
                showActionButtons: true,
                minDate: now,
                maxDate: maxDate,
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  if (args.value is PickerDateRange) {
                    final PickerDateRange range = args.value;
                    setState(() {
                      if (range.startDate != null && range.endDate == null) {
                        startDate = range.startDate;
                        endDate = range.startDate;
                      } else if (range.startDate != null &&
                          range.endDate != null) {
                        startDate = range.startDate;
                        endDate = range.endDate;
                      }
                    });
                  }
                },
                onSubmit: (value) {
                  if (value is PickerDateRange) {
                    setState(() {
                      startDate = value.startDate;
                      endDate = value.endDate;
                    });
                  }
                  Navigator.pop(context);
                },
                onCancel: () {
                  Navigator.pop(context);
                },
                todayHighlightColor: Colors.blue,
                selectionColor: Colors.blue.shade700,
                startRangeSelectionColor: Colors.blue,
                endRangeSelectionColor: Colors.blue,
                rangeSelectionColor: Colors.blue.withOpacity(0.2),
                selectionTextStyle: const TextStyle(color: Colors.white),
                rangeTextStyle: const TextStyle(color: Colors.white),
                headerStyle: const DateRangePickerHeaderStyle(
                  backgroundColor: Colors.black,
                  textAlign: TextAlign.center,
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                yearCellStyle: const DateRangePickerYearCellStyle(
                  textStyle: TextStyle(color: Colors.white),
                  todayTextStyle: TextStyle(color: Colors.blue),
                  disabledDatesTextStyle: TextStyle(color: Colors.grey),
                ),
                monthCellStyle: const DateRangePickerMonthCellStyle(
                  textStyle: TextStyle(color: Colors.white),
                  todayTextStyle: TextStyle(color: Colors.blue),
                  disabledDatesTextStyle: TextStyle(color: Colors.grey),
                  leadingDatesTextStyle: TextStyle(color: Colors.grey),
                  trailingDatesTextStyle: TextStyle(color: Colors.grey),
                ),
                confirmText: 'APPLY',
                cancelText: 'CANCEL',
              ),
            )
          ],
        ),
      ),
      customViewPosition: CustomViewPosition.BEFORE_TITLE,
    );
  }

  Widget _buildInputContainer({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required TextInputType keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    int? maxline,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 10, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.gabarito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.blueAccent.shade200,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 16, cornerSmoothing: 1),
              ),
              color: const Color.fromARGB(255, 23, 23, 23),
            ),
            child: TextFormField(
              controller: controller,
              cursorColor: Colors.blueAccent,
              keyboardType: keyboardType,
              readOnly: readOnly,
              onTap: onTap,
              maxLines: maxline ?? 1,
              maxLength: maxLength,
              inputFormatters: inputFormatters,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                suffixIcon: suffixIcon,
                counterText: "",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> submitLeave() async {
    FocusScope.of(context).unfocus();
    _isLoading = true;
    if (startDate != null && endDate == null) endDate = startDate;
    setState(() {});

    try {
      if (startDate == null ||
          titleController.text.trim().isEmpty ||
          reasonController.text.trim().isEmpty ||
          selectedLeaveType == null ||
          contactController.text.trim().isEmpty) {
        info('Please fill in all required fields', Severity.warning);
        return;
      }
      String contactNumber = contactController.text.trim();
      if (contactNumber.length < 10 ||
          !RegExp(r'^[0-9]+$').hasMatch(contactNumber)) {
        info('Contact number must be at least 10 digits', Severity.warning);
        return;
      }

      final userId = userData.id;
      final fromDate = DateFormat('yyyy-MM-dd').format(startDate!);
      final toDate = DateFormat('yyyy-MM-dd').format(endDate!);

      // Step 1: Check if a leave record already exists for the given date range
      final existingLeaves = await sb.pubbase!
          .from('leave_record')
          .select()
          .eq('user_id', userId)
          .gte('from_date', fromDate)
          .lte('to_date', toDate);

      if (existingLeaves.isNotEmpty) {
        info('A leave request for the selected date range already exists.',
            Severity.warning);
        return;
      }

      // Step 2: Insert the new leave record
      final List<Map<String, dynamic>> insertedRecords =
          await sb.pubbase!.from('leave_record').insert([
        {
          'user_id': userId,
          'from_date': fromDate,
          'to_date': toDate,
          'title': titleController.text.trim(),
          'contact': contactController.text.trim(),
          'reason': reasonController.text.trim(),
          'type': selectedLeaveType!,
        }
      ]).select();

      if (insertedRecords.isEmpty) {
        throw 'LEAVE Entry failed.';
      }

      debugPrint('Inserted Records: $insertedRecords');
      leaveRecord = await ref.refresh(userLeaveRecordsProvider.future);
      setState(() {});
      info('Leave request submitted successfully', Severity.success);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('-- Error: $e');
      info('Oops, something went wrong: $e', Severity.error);
    } finally {
      _isLoading = false;
      setState(() {});
    }
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
        isReadOnly ? 'Leave Details' : 'Leave form',
        textScaler: TextScaler.linear(1.0),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Find the user who matches this leave record

    bool isSameUser = false;
    bool buttonVisible = false;
    User? user;
    late String statusText;
    late Color statusColor;

    if (widget.lRecord != null) {
      user = manageUsers.firstWhere(
        (u) => u.id == widget.lRecord!.userId,
        orElse: () => User(
          id: 0,
          email: "Unknown",
          role: "N/A",
          createdAt: DateTime.now(),
          fullName: "Unknown User",
          icon: "",
        ),
      );
      isSameUser = widget.lRecord!.userId == userData.id;
      buttonVisible = widget.lRecord!.userId == userData.id ||
          widget.lRecord!.status == true ||
          (widget.lRecord!.decisionBy != null &&
              widget.lRecord!.status == false);

      final isPastPending = !widget.lRecord!.status &&
          widget.lRecord!.decisionBy == null &&
          widget.lRecord!.fromDate.isBefore(DateTime.now());

      if (widget.lRecord!.status) {
        statusText = "APPROVED";
        statusColor = Colors.green;
      } else if (isPastPending) {
        statusText = "PAST";
        statusColor = Colors.grey;
      } else if (widget.lRecord!.decisionBy == null) {
        statusText = "PENDING";
        statusColor = Colors.orange;
      } else {
        statusText = "REJECTED";
        statusColor = Colors.red;
      }
    }
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildAppbar(),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (isReadOnly && !isSameUser && user != null)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: ShapeDecoration(
                            color: const Color.fromARGB(255, 14, 14, 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                  cornerRadius: 50, cornerSmoothing: 1),
                              side: BorderSide(
                                color: const Color.fromARGB(255, 43, 43, 43),
                                width: .5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Profile Picture with fallback logic
                              CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                radius: 26,
                                backgroundImage:
                                    user.icon != null && user.icon!.isNotEmpty
                                        ? NetworkImage(user.icon!)
                                        : null,
                                child: (user.icon == null || user.icon!.isEmpty)
                                    ? Text(
                                        user.email[0].toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
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
                                  // const SizedBox(height: 4),
                                  Text(
                                    user.role,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white30,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (user.phone != null)
                                IconButton(
                                  icon: const Icon(IconlyLight.call,
                                      color: Colors.blueAccent, size: 22),
                                  onPressed: () {
                                    launchPhoneDialer(user!.phone!);
                                  },
                                ),
                              IconButton(
                                icon: const Icon(IconlyLight.send,
                                    color: Colors.blueAccent, size: 22),
                                onPressed: () {
                                  launchEmail(user!.email);
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      _buildInputContainer(
                        label: "Title",
                        hintText: "Enter leave title",
                        controller: titleController,
                        keyboardType: TextInputType.text,
                        readOnly: isReadOnly,
                      ),
                      _buildInputContainer(
                        label: "Contact Number",
                        hintText: "Enter contact number",
                        controller: contactController,
                        keyboardType: TextInputType.number,
                        readOnly: isReadOnly,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      if (!isReadOnly)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 3),
                                child: Text(
                                  'LEAVE  TYPE',
                                  style: GoogleFonts.gabarito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blueAccent.shade200,
                                  ),
                                ),
                              ),
                              CustomDropdown<String>(
                                decoration: const CustomDropdownDecoration(
                                  closedFillColor:
                                      Color.fromARGB(255, 23, 23, 23),
                                  expandedFillColor:
                                      Color.fromARGB(255, 29, 29, 29),
                                  listItemStyle: TextStyle(color: Colors.white),
                                ),
                                hintText: 'Select Leave Type',
                                hintBuilder: (context, hintText, isExpanded) {
                                  return Text(
                                    hintText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                },
                                headerBuilder:
                                    (context, selectedItem, isExpanded) {
                                  return Text(
                                    selectedItem,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                initialItem: selectedLeaveType,
                                items: leaveTypes,
                                onChanged: isReadOnly
                                    ? null
                                    : (String? newValue) {
                                        setState(() {
                                          selectedLeaveType = newValue;
                                        });
                                      },
                                listItemBuilder:
                                    (context, item, isSelected, onTap) {
                                  return GestureDetector(
                                    onTap: onTap,
                                    child: Container(
                                      color: isSelected
                                          ? Colors.grey.withOpacity(0.2)
                                          : Colors.transparent,
                                      child: Text(
                                        item,
                                        style: GoogleFonts.poppins(
                                          color: isSelected
                                              ? Colors.deepOrange
                                              : Colors.white,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w300,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      if (isReadOnly)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 16, right: 10, left: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LEAVE  TYPE',
                                style: GoogleFonts.gabarito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blueAccent.shade200,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 5),
                                decoration: ShapeDecoration(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: SmoothBorderRadius(
                                        cornerRadius: 16, cornerSmoothing: 1),
                                  ),
                                  color: const Color.fromARGB(255, 23, 23, 23),
                                ),
                                child: TextFormField(
                                  cursorColor: Colors.blueAccent,
                                  readOnly: true,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: selectedLeaveType,
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    counterText: "",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _buildInputContainer(
                        label: "Start Date",
                        hintText: startDate != null
                            ? formatDate(startDate)
                            : "Select Start Date",
                        controller: TextEditingController(),
                        keyboardType: TextInputType.datetime,
                        readOnly: true,
                        onTap: () => _selectDate(true),
                        suffixIcon: Icon(
                          IconlyBroken.calendar,
                          size: 20,
                          color: startDate != null ? Colors.blue : Colors.grey,
                        ),
                      ),
                      _buildInputContainer(
                        label: "End Date",
                        hintText: endDate != null
                            ? formatDate(endDate)
                            : "Select End Date",
                        controller: TextEditingController(),
                        keyboardType: TextInputType.datetime,
                        readOnly: true,
                        onTap: () => _selectDate(false),
                        suffixIcon: Icon(
                          IconlyLight.calendar,
                          size: 20,
                          color: endDate != null ? Colors.blue : Colors.grey,
                        ),
                      ),
                      if (!isReadOnly ||
                          (isReadOnly &&
                              reasonController.text.trim().isNotEmpty))
                        _buildInputContainer(
                          label: "Reason for Leave",
                          hintText: "Enter reason",
                          controller: reasonController,
                          keyboardType: TextInputType.text,
                          maxline: 3,
                          readOnly: isReadOnly,
                        ),
                      if (isReadOnly)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'STATUS',
                                style: GoogleFonts.gabarito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blueAccent.shade200,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 5),
                                decoration: ShapeDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  shape: SmoothRectangleBorder(
                                    borderRadius: SmoothBorderRadius(
                                        cornerRadius: 5, cornerSmoothing: 1),
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
                        ),
                      const SizedBox(height: 50)
                    ],
                  ),
                ),
              ),
            ),
            if (!isReadOnly &&
                MediaQuery.of(context).viewInsets.bottom > 0 == false)
              Container(
                margin: const EdgeInsets.only(right: 20, left: 20, bottom: 30),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : submitLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 16, cornerSmoothing: 1),
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.blue),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Validating ...",
                              style: GoogleFonts.poppins(
                                  fontSize: 18, color: Colors.blue),
                            ),
                          ],
                        )
                      : Text(
                          "Apply Leave",
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            if (isReadOnly &&
                !buttonVisible &&
                MediaQuery.of(context).viewInsets.bottom > 0 == false)
              Container(
                margin: const EdgeInsets.only(right: 20, left: 20, bottom: 30),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Reject Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () => updateLeaveDecision(false),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.close,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Reject",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Approve Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () => updateLeaveDecision(true),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.teal,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Accept",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime? date) {
  return date != null ? DateFormat("d MMM yyyy").format(date) : "";
}

class AttendanceDetailsPage extends ConsumerStatefulWidget {
  final Attendance attendance;

  const AttendanceDetailsPage({super.key, required this.attendance});

  @override
  ConsumerState<AttendanceDetailsPage> createState() =>
      _AttendanceDetailsPageState();
}

class _AttendanceDetailsPageState extends ConsumerState<AttendanceDetailsPage> {
  late User user;
  late String checkInDate;
  late String checkOutDate;
  late String status;
  late Color statusColor;
  late double calcDistance;
  String onlyDate = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    user = manageUsers.firstWhere(
      (u) => u.id == widget.attendance.userId,
      orElse: () => User(
        id: 0,
        email: "Unknown",
        role: "N/A",
        createdAt: DateTime.now(),
        fullName: "Unknown User",
        icon: "",
      ),
    );

    final offset = const Duration(hours: 5, minutes: 30);

// Apply offset
    final adjustedCheckIn = widget.attendance.checkIn.toUtc().add(offset);
    final adjustedCheckOut = widget.attendance.checkOut?.toUtc().add(offset);

// Extract and format
    checkInDate = DateFormat('dd MMM yyyy, hh:mm a').format(adjustedCheckIn);
    checkOutDate = adjustedCheckOut != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(adjustedCheckOut)
        : "Not Checked Out";

// If you only want the date from check-in (e.g., to show somewhere else)
    onlyDate = formatWithSuffix(adjustedCheckIn);

    calcDistance = distanceBetween(
        widget.attendance.latitude, widget.attendance.longitude);

    status = getAttendanceStatus(widget.attendance);
    statusColor = switch (status) {
      "Approved" => Colors.green,
      "Pending" => Colors.orange,
      "Rejected" => Colors.red,
      _ => Colors.grey,
    };
  }

  Future<void> updateAttendanceDecision(bool isApproved) async {
    setState(() => _isProcessing = true);

    try {
      final userId = userData.id;

      final updateData = {
        'approved_by': userId,
        if (!isApproved) 'approval_required': false,
      };

      final response = await sb.pubbase!
          .from('attendance')
          .update(updateData)
          .eq('id', widget.attendance.id)
          .select();

      if (response.isEmpty) throw 'Attendance update failed';

      info(isApproved ? 'Attendance Approved' : 'Attendance Rejected',
          Severity.success);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('-- Error: $e');
      info('Oops, something went wrong: $e', Severity.error);
    } finally {
      setState(() => _isProcessing = false);
    }
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
        'Attendance Approval',
        textScaler: TextScaler.linear(1.0),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      centerTitle: true,
    );
  }

  String getAttendanceStatus(Attendance att) {
    if (att.approvalRequired) {
      return att.approvedBy != null ? 'Approved' : 'Pending';
    } else {
      return att.approvedBy != null ? 'Rejected' : 'Unknown';
    }
  }

  double distanceBetween(lat, long) {
    double distanceFromOffice = Geolocator.distanceBetween(
        officeData.latitude!, officeData.longitude!, lat, long);
    return distanceFromOffice;
  }

  Widget buildCard() {
    return Container(
      // margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 28, 28, 28),
        shape: SmoothRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 25, cornerSmoothing: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map Button
          if (userPosition != null) ...[
            _mapCard(
              latitude: widget.attendance.latitude,
              longitude: widget.attendance.longitude,
            ),
          ],
          const SizedBox(height: 10),

          // Top (gray) section
          Container(
            // decoration: BoxDecoration(
            //   gradient: const LinearGradient(colors: [
            //     Color.fromARGB(255, 0, 43, 108),
            //     Colors.transparent,
            //     // Colors.transparent,
            //     Colors.transparent
            //   ], end: Alignment.bottomLeft, begin: Alignment.topRight),
            //   // borderRadius: const BorderRadius.only(
            //   //   topLeft: Radius.circular(20),
            //   //   topRight: Radius.circular(20),
            //   // ),
            // ),
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 16),
            child: Row(
              children: [
                // Circular icon
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(
                        'assets/checkin.png',
                        color: Colors.white,
                        fit: BoxFit.contain,
                      ),
                    )),
                const SizedBox(width: 12),
                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CHECK IN",
                        style: GoogleFonts.gabarito(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        checkInDate,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            // decoration: BoxDecoration(
            //   gradient: const LinearGradient(colors: [
            //     Color.fromARGB(255, 0, 43, 108),
            //     Colors.transparent,
            //     // Colors.transparent,
            //     Colors.transparent
            //   ], end: Alignment.bottomLeft, begin: Alignment.topRight),
            //   // borderRadius: const BorderRadius.only(
            //   //   topLeft: Radius.circular(20),
            //   //   topRight: Radius.circular(20),
            //   // ),
            // ),
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 16),
            child: Row(
              children: [
                // Circular icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/checkout.png',
                      color: Colors.white,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHECK OUT',
                        style: GoogleFonts.gabarito(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        checkOutDate,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info icon
                const Icon(
                  Icons.info,
                  color: Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                // Info text
                Expanded(
                  child: Text(
                    "You are ${calcDistance >= 1000 ? '${(calcDistance / 1000).toStringAsFixed(1)} km' : '${calcDistance.toStringAsFixed(0)} meters'} away from the office",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCard({
    required double latitude,
    required double longitude,
  }) {
    return Container(
      padding: EdgeInsets.all(1),
      height: 180,
      child: ClipRRect(
        borderRadius: SmoothBorderRadius.only(
          topLeft: SmoothRadius(cornerRadius: 21, cornerSmoothing: 1),
          topRight: SmoothRadius(cornerRadius: 21, cornerSmoothing: 1),
        ),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(latitude, longitude),
            initialZoom: 12,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
              subdomains: const ['a', 'b', 'c'],
              retinaMode: RetinaMode.isHighDensity(context),
              maxNativeZoom: 20,
            ),

            // Marker for user's location
            MarkerLayer(
              markers: [
                Marker(
                  width: 10,
                  height: 10,
                  point: LatLng(latitude, longitude),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.blue, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppbar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: ShapeDecoration(
                      color: const Color.fromARGB(255, 14, 14, 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                            cornerRadius: 50, cornerSmoothing: 1),
                        side: BorderSide(
                          color: const Color.fromARGB(255, 43, 43, 43),
                          width: .5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Profile Picture with fallback logic
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 26,
                          backgroundImage:
                              user.icon != null && user.icon!.isNotEmpty
                                  ? NetworkImage(user.icon!)
                                  : null,
                          child: (user.icon == null || user.icon!.isEmpty)
                              ? Text(
                                  user.email[0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
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
                            // const SizedBox(height: 4),
                            Text(
                              user.role,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white30,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (user.phone != null)
                          IconButton(
                            icon: const Icon(IconlyLight.call,
                                color: Colors.blueAccent, size: 22),
                            onPressed: () {
                              launchPhoneDialer(user.phone!);
                            },
                          ),
                        IconButton(
                          icon: const Icon(IconlyLight.send,
                              color: Colors.blueAccent, size: 22),
                          onPressed: () {
                            launchEmail(user.email);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DATE',
                          style: GoogleFonts.gabarito(
                              fontSize: 16,
                              color: Colors.blue,
                              fontWeight: FontWeight.w800),
                        ),
                        Text(
                          onlyDate,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  // const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'STATUS',
                          style: GoogleFonts.gabarito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueAccent.shade200,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          decoration: ShapeDecoration(
                            color: statusColor.withOpacity(0.15),
                            shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                  cornerRadius: 5, cornerSmoothing: 1),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  buildCard(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (MediaQuery.of(context).viewInsets.bottom > 0 == false &&
              status.toLowerCase().contains('pending'))
            Container(
              margin: const EdgeInsets.only(right: 20, left: 20, bottom: 30),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Reject Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => updateAttendanceDecision(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "REJECT",
                                    style: GoogleFonts.gabarito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),
                        // Approve Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => updateAttendanceDecision(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "ACCEPT",
                                    style: GoogleFonts.gabarito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

String formatWithSuffix(DateTime dateTime) {
  final day = dateTime.day;
  final suffix = getDaySuffix(day);
  final monthYear = DateFormat('MMM yyyy').format(dateTime);
  return '$day$suffix $monthYear';
}

String getDaySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}
