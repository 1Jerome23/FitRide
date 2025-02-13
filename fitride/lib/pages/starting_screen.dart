import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_register.dart'; // Import your login page

class StartingScreen extends StatefulWidget {
  const StartingScreen({Key? key}) : super(key: key);

  @override
  _StartingScreenState createState() => _StartingScreenState();
}

class _StartingScreenState extends State<StartingScreen> {
  final LiquidController _controller = LiquidController();
  int _currentPage = 0;

  void onPageChangedCallback(int activePageIndex) {
    setState(() {
      _currentPage = activePageIndex;
    });
  }

  void goToNextPage() {
    final nextPage = _currentPage + 1;
    if (nextPage < 3) {  
      _controller.animateToPage(page: nextPage, duration: 600);
    } else { 
      navigateToLogin();
    }
  }

  void navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pages = [
      buildPage(
        size,
        "assets/goalspic.png",
        "Set and Track Goals",
        "Define your health and fitness goals - whether it's improving endurance, staying fit, or simply enjoying the ride.",
        "1/3",
        [Color(0xFFD9A17E), Color(0xFF6E6E6E)],
      ),
      buildPage(
        size,
        "assets/recopic.png",
        "Get Personalized Insights",
        "Receive customized recommendations based on your cycling data and health metrics.",
        "2/3",
        [Color(0xFF6E6E6E), Color(0xFFFFA65A)],
      ),
      buildPage(
        size,
        "assets/userdatapic.png",
        "Monitor Your Progress",
        "Analyze trends, track progress, and stay motivated with real-time data insights.",
        "3/3",
        [Color(0xFF6E6E6E), Color(0xFFFFA726)],
      )
    ];

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          LiquidSwipe(
            pages: pages,
            liquidController: _controller,
            onPageChangeCallback: onPageChangedCallback,
            slideIconWidget: _currentPage == 2 ? null : const Icon(Icons.arrow_back_ios),
            enableSideReveal: true,
          ),
          Positioned(
            bottom: 60.0,
            child: OutlinedButton(
              onPressed: goToNextPage,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black26),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: Color(0xff272727), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              ),
            ),
          ),
          if (_currentPage != 2)  // Hide on last page
            Positioned(
              top: 50,
              right: 20,
              child: TextButton(
                onPressed: () {
                  _controller.jumpToPage(page: 2);
                },
                child: const Text("Skip", style: TextStyle(color: Colors.grey)),
              ),
            ),
          Positioned(
            bottom: 10,
            child: AnimatedSmoothIndicator(
              activeIndex: _currentPage,
              count: 3,
              effect: const WormEffect(
                activeDotColor: Color(0xff272727),
                dotHeight: 5.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPage(
    Size size,
    String image,
    String title,
    String description,
    String pageNumber,
    List<Color> gradientColors,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Image(image: AssetImage(image), height: size.height * 0.4),
            Column(
              children: [
                Text(title, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.black)),
                Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black)),
              ],
            ),
            Text(pageNumber, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 80.0),
          ],
        ),
      ),
    );
  }
}
