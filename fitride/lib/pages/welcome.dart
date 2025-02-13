import 'package:flutter/material.dart';
import 'login_register.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage ({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Color(0xffffb678),
      body: Container(
        padding: EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Image(image: AssetImage("assets/startpic.gif"), height:height * 0.5),
            Column(
              children: [
                Text("Get Started", style: TextStyle(
                  color: Colors.black,
                  fontFamily: "Fredoka-Bold",
                  fontSize: 35)
                ),
                Text("Your personal cycling companion for a healthier, more enjoyable ride. Set your goals, track progress, and get insights tailored just for you.", style: TextStyle(
                  color: Colors.black,
                  fontFamily: "Inter",),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    }, 
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      foregroundColor: Color(0xff272727),
                      side: BorderSide(color: Color(0xff272727)),
                      padding: EdgeInsets.symmetric(vertical: 15.0)
                    ),
                    child: Text("Login".toUpperCase(), style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                    ),
                  )
                ),
                const SizedBox(
                  width: 10.0,
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage(startWithSignup: true)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      foregroundColor: Colors.white,
                      backgroundColor: Color(0xff272727),
                      side: BorderSide(color: Color(0xff272727)),
                      padding: EdgeInsets.symmetric(vertical: 15.0),
                    ),
                    child: Text("Signup".toUpperCase(), style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                    ),
                  )
                ),
              ],
            )
          ],
        )
      ),
    );
  }
}