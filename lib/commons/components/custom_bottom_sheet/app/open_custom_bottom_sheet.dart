import 'dart:ui';
import 'package:flutter/material.dart';

class BottomSheetConstants {
  static const Duration bottomSheetTransitionDuration =
      Duration(milliseconds: 120);
  static Color bottomSheetBackgroundColor =
      const Color(0xff1C1C1E).withOpacity(0.6);
  static const double bottomSheetBlurSigma = 3.0;
}

void openCustomBottomSheet({
  required BuildContext context,
  required Widget child,
  bool enableSwipeDownToClose = true,
  bool enableTapToClose = true,
  Color bottomSheetColor = Colors.white,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      transitionDuration: BottomSheetConstants.bottomSheetTransitionDuration,
      pageBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: enableTapToClose
                      ? () => Navigator.of(context).pop()
                      : null,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: BottomSheetConstants.bottomSheetBlurSigma,
                        sigmaY: BottomSheetConstants.bottomSheetBlurSigma,
                      ),
                      child: Container(
                        color: BottomSheetConstants.bottomSheetBackgroundColor,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onVerticalDragUpdate: enableSwipeDownToClose
                    ? (details) {
                        if (details.primaryDelta! > 5) {
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bottomSheetColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16.0),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                  vertical: 12.0),
                              child: Container(
                                width: 80.0,
                                height: 6.0,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFc5c5c5),
                                  borderRadius: BorderRadius.circular(80.0),
                                ),
                              ),
                            ),
                          ),
                          child,
                          const SizedBox(height: 34.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
