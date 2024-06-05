//*************   © Copyrighted by Thinkcreative_Technologies. An Exclusive item of Envato market. Make sure you have purchased a Regular License OR Extended license for the Source Code from Envato to use this product. See the License Defination attached with source code. *********************

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storychat/Screens/auth_screens/login.dart';
import 'package:storychat/Screens/auth_screens/register.dart';
import 'package:storychat/Services/localization/language_constants.dart';
import '/Configs/app_constants.dart';

class Splashscreen extends StatelessWidget {
  final bool? isShowOnlySpinner;
  final DocumentSnapshot<Map<String, dynamic>>? doc;

  Splashscreen({this.isShowOnlySpinner = false, this.doc});

  @override
  Widget build(BuildContext context) {
    return IsSplashOnlySolidColor == true || this.isShowOnlySpinner == true
        ? Scaffold(
            backgroundColor: SplashBackgroundSolidColor,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(storychatSECONDARYolor),
              ),
            ),
          )
        : Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(flex: 20, child: Container()),
                  Image.asset(
                    "assets/appicon/appicon.png",
                    width: 150,
                    height: 150,
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Text(
                    "Chat Privately",
                    style: TextStyle(
                      fontSize: 24,
                      color: Color.fromRGBO(122, 107, 188, 1),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(
                    height: 4,
                  ),
                  Text(
                    "Express your thought!",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color.fromRGBO(251, 127, 121, 1),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Expanded(flex: 10, child: Container()),
                  if (doc != null) ...[
                  InkWell(
                    onTap: () async {
                      SharedPreferences prefs = await SharedPreferences.getInstance();

                      Navigator.push(context, MaterialPageRoute(builder: (context) {
                        return LoginScreen(
                        prefs: prefs,
                        accountApprovalMessage: null,
                        isaccountapprovalbyadminneeded: null,
                        isblocknewlogins: null,
                        title: getTranslated(context, 'signin'),
                        doc: doc!,
                      );
                      }));
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        "Existing user? Sign in",
                        style: TextStyle(
                          color: Color.fromRGBO(77, 88, 164, 1),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: Container()),
                  InkWell(
                    onTap: () async {
                      SharedPreferences prefs = await SharedPreferences.getInstance();

                      Navigator.push(context, MaterialPageRoute(builder: (context) {
                        return RegisterScreen(
                        prefs: prefs,
                        accountApprovalMessage: null,
                        isaccountapprovalbyadminneeded: null,
                        isblocknewlogins: null,
                        title: getTranslated(context, 'signin'),
                        doc: doc!,
                      );
                      }));
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        "Don't Have an Account? Sign Up",
                        style: TextStyle(
                          color: Color.fromRGBO(77, 88, 164, 1),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ],
                  Expanded(flex: 10, child: Container()),
                ],
              ),
            )
          );
  }
}
