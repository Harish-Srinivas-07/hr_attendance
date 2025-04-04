import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';

/// Shimmer Effect for Contact Row
Widget contactCardShimmer() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
    child: Shimmer.fromColors(
      baseColor: const Color.fromARGB(255, 20, 20, 20),
      highlightColor: const Color.fromARGB(72, 11, 11, 11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
            borderRadius:
                SmoothBorderRadius(cornerRadius: 22, cornerSmoothing: 1),
          ),
          color: Colors.grey[900],
        ),
        child: Row(
          children: [
            // Shimmer Profile Picture
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),

            // Name & Email Shimmer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),

            // Call & Email Icon Shimmer
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget contactScreenShimmer() {
  return SafeArea(
    child: Column(children: [
      const SizedBox(height: 15),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 15),
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
            borderRadius:
                SmoothBorderRadius(cornerRadius: 22, cornerSmoothing: 1),
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
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 15),
      Expanded(
        child: ListView.builder(
          itemCount: 9,
          physics: AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return contactCardShimmer();
          },
        ),
      ),
    ]),
  );
}
