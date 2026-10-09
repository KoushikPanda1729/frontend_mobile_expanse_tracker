import 'dart:async';
import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/text/app/views/custom_text_library.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/gain_total_control _of_your_money.png",
      "title": "Gain total control of your money",
      "subtitle": "Become your own money manager\nand make every cent count"
    },
    {
      "image": "assets/images/know_where_your_money_goes.png",
      "title": "Know where your money goes",
      "subtitle": "Track your transactions easily,\nwith categories and dates"
    },
    {
      "image": "assets/images/planning_ahead.png",
      "title": "Plan ahead for your future",
      "subtitle": "Set savings goals and achieve\nfinancial stability"
    },
  ];

  @override
  void initState() {
    super.initState();
    startAutoScroll();
  }

  void startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage < onboardingData.length - 1) {
        _currentPage++;
        _pageController.animateToPage(_currentPage,
            duration: const Duration(seconds: 1), curve: Curves.easeInOut);
      } else {
        _pageController.jumpToPage(0);
        _currentPage = 0;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// **Carousel (Only Image and Text Scrolls)**
            Expanded(
              flex: 4,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: onboardingData.length,
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Image.asset(
                          onboardingData[index]["image"]!,
                          width: 312,
                          height: 312,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 47),
                        child: Title1(
                          text: onboardingData[index]["title"]!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 17),
                      Body3(
                        text: onboardingData[index]["subtitle"]!,
                        textAlign: TextAlign.center,
                        color: AppColors.dark25,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            /// **Page Indicator (Dots)**
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    width: _currentPage == index ? 10 : 8,
                    height: _currentPage == index ? 10 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.violet100
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            /// **Fixed Buttons at Bottom**

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  SolidButtonWidget(
                    label: "Sign Up",
                    onPressed: () {
                      context.push("/signup");
                    },
                  ),
                  const SizedBox(height: 16),
                  SolidButtonWidget(
                    label: "Login",
                    onPressed: () {
                      context.push("/login");
                    },
                    backgroundColor: AppColors.violet20,
                    labelColor: AppColors.violet100,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
