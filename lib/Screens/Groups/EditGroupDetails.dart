//*************   © Copyrighted by Thinkcreative_Technologies. An Exclusive item of Envato market. Make sure you have purchased a Regular License OR Extended license for the Source Code from Envato to use this product. See the License Defination attached with source code. *********************

import 'package:cloud_firestore/cloud_firestore.dart';
import '/Configs/Dbkeys.dart';
import '/Configs/Dbpaths.dart';
import '/Configs/app_constants.dart';
import '/Services/Admob/admob.dart';
import '/Services/Providers/Observer.dart';
import '/Services/localization/language_constants.dart';
import '/Screens/calling_screen/pickup_layout.dart';
import '/Utils/color_detector.dart';
import '/Utils/theme_management.dart';
import '/Utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditGroupDetails extends StatefulWidget {
  final String? groupName;
  final String? groupDesc;
  final String? groupType;
  final String? groupID;
  final String currentUserNo;
  final bool isadmin;
  final SharedPreferences prefs;
  EditGroupDetails(
      {this.groupName,
      this.groupDesc,
      required this.isadmin,
      required this.prefs,
      this.groupID,
      this.groupType,
      required this.currentUserNo});
  @override
  State createState() => new EditGroupDetailsState();
}

class EditGroupDetailsState extends State<EditGroupDetails> {
  TextEditingController? controllerName = new TextEditingController();
  TextEditingController? controllerDesc = new TextEditingController();

  bool isLoading = false;

  final FocusNode focusNodeName = new FocusNode();
  final FocusNode focusNodeDesc = new FocusNode();

  String? groupTitle;
  String? groupDesc;
  String? groupType;
  final BannerAd myBanner = BannerAd(
    adUnitId: getBannerAdUnitId()!,
    size: AdSize.mediumRectangle,
    request: AdRequest(),
    listener: BannerAdListener(),
  );
  AdWidget? adWidget;
  @override
  void initState() {
    super.initState();
    Fiberchat.internetLookUp();
    groupDesc = widget.groupDesc;
    groupTitle = widget.groupName;
    groupType = widget.groupType;
    controllerName!.text = groupTitle!;
    controllerDesc!.text = groupDesc!;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final observer = Provider.of<Observer>(this.context, listen: false);
      if (IsBannerAdShow == true && observer.isadmobshow == true) {
        myBanner.load();
        adWidget = AdWidget(ad: myBanner);
        setState(() {});
      }
    });
  }

  void handleUpdateData() {
    focusNodeName.unfocus();
    focusNodeDesc.unfocus();

    setState(() {
      isLoading = true;
    });
    groupTitle =
        controllerName!.text.isEmpty ? groupTitle : controllerName!.text;
    groupDesc = controllerDesc!.text.isEmpty ? groupDesc : controllerDesc!.text;
    setState(() {});
    FirebaseFirestore.instance
        .collection(DbPaths.collectiongroups)
        .doc(widget.groupID)
        .update({
      Dbkeys.groupNAME: groupTitle,
      Dbkeys.groupDESCRIPTION: groupDesc,
      Dbkeys.groupTYPE: groupType,
    }).then((value) async {
      DateTime time = DateTime.now();
      await FirebaseFirestore.instance
          .collection(DbPaths.collectiongroups)
          .doc(widget.groupID)
          .collection(DbPaths.collectiongroupChats)
          .doc(time.millisecondsSinceEpoch.toString() +
              '--' +
              widget.currentUserNo)
          .set({
        Dbkeys.groupmsgCONTENT: widget.isadmin
            ? getTranslated(context, 'grpdetailsupdatebyadmin')
            : '${widget.currentUserNo} ${getTranslated(context, 'hasupdatedgrpdetails')}',
        Dbkeys.groupmsgLISToptional: [],
        Dbkeys.groupmsgTIME: time.millisecondsSinceEpoch,
        Dbkeys.groupmsgSENDBY: widget.currentUserNo,
        Dbkeys.groupmsgISDELETED: false,
        Dbkeys.groupmsgTYPE: Dbkeys.groupmsgTYPEnotificationUpdatedGroupDetails,
      });
      Navigator.of(context).pop();
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fiberchat.toast(err.toString());
    });
  }

  void _handleTypeChange(String value) {
    setState(() {
      groupType = value;
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (IsBannerAdShow == true) {
      myBanner.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final observer = Provider.of<Observer>(this.context, listen: false);
    return PickupLayout(
        prefs: widget.prefs,
        scaffold: Fiberchat.getNTPWrappedWidget(Scaffold(
            backgroundColor: Thm.isDarktheme(widget.prefs)
                ? storychatCONTAINERboxColorDarkMode
                : storychatCONTAINERboxColorLightMode,
            appBar: new AppBar(
              elevation: 0.4,
              leading: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: pickTextColorBasedOnBgColorAdvanced(
                      Thm.isDarktheme(widget.prefs)
                          ? storychatAPPBARcolorDarkMode
                          : storychatAPPBARcolorLightMode),
                ),
              ),
              titleSpacing: 0,
              backgroundColor: Thm.isDarktheme(widget.prefs)
                  ? storychatAPPBARcolorDarkMode
                  : storychatAPPBARcolorLightMode,
              title: new Text(
                getTranslated(this.context, 'editgroup'),
                style: TextStyle(
                  fontSize: 20.0,
                  color: pickTextColorBasedOnBgColorAdvanced(
                      Thm.isDarktheme(widget.prefs)
                          ? storychatAPPBARcolorDarkMode
                          : storychatAPPBARcolorLightMode),
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: handleUpdateData,
                  child: Text(
                    getTranslated(this.context, 'save'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Thm.isDarktheme(widget.prefs)
                          ? storychatPRIMARYcolor
                          : pickTextColorBasedOnBgColorAdvanced(
                              storychatAPPBARcolorLightMode),
                    ),
                  ),
                )
              ],
            ),
            body: Stack(
              children: <Widget>[
                SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: 25,
                      ),
                      ListTile(
                          title: TextFormField(
                        style: TextStyle(
                          color: pickTextColorBasedOnBgColorAdvanced(
                              Thm.isDarktheme(widget.prefs)
                                  ? storychatCONTAINERboxColorDarkMode
                                  : storychatCONTAINERboxColorLightMode),
                        ),
                        autovalidateMode: AutovalidateMode.always,
                        controller: controllerName,
                        validator: (v) {
                          return v!.isEmpty
                              ? getTranslated(this.context, 'validdetails')
                              : null;
                        },
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(6),
                          labelStyle: TextStyle(
                            height: 0.8,
                            color: storychatPRIMARYcolor,
                          ),
                          labelText: getTranslated(this.context, 'groupname'),
                        ),
                      )),
                      SizedBox(
                        height: 30,
                      ),
                      ListTile(
                          title: TextFormField(
                        minLines: 1,
                        maxLines: 10,
                        style: TextStyle(
                          color: pickTextColorBasedOnBgColorAdvanced(
                              Thm.isDarktheme(widget.prefs)
                                  ? storychatCONTAINERboxColorDarkMode
                                  : storychatCONTAINERboxColorLightMode),
                        ),
                        controller: controllerDesc,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(6),
                          labelStyle: TextStyle(
                              height: 0.8, color: storychatPRIMARYcolor),
                          labelText: getTranslated(this.context, 'groupdesc'),
                        ),
                      )),
                      SizedBox(
                        height: 15,
                      ),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(5, 20, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(15, 20, 12, 10),
                                child: Text(
                                  getTranslated(this.context, 'grouptype'),
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                      color: pickTextColorBasedOnBgColorAdvanced(Thm
                                              .isDarktheme(widget.prefs)
                                          ? storychatCONTAINERboxColorDarkMode
                                          : storychatCONTAINERboxColorLightMode),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                ),
                              ),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Both User & Admin Messages Allowed',
                                    groupValue: groupType,
                                    onChanged: (v) {
                                      _handleTypeChange(v!);
                                    },
                                  ),
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width / 1.5,
                                    child: Text(
                                      getTranslated(
                                          this.context, 'bothuseradmin'),
                                    ),
                                  )
                                ],
                              ),
                              SizedBox(
                                height: 7,
                              ),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Only Admin Messages Allowed',
                                    groupValue: groupType,
                                    onChanged: (v) {
                                      _handleTypeChange(v!);
                                    },
                                  ),
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width / 1.5,
                                    child: Text(
                                      getTranslated(this.context, 'onlyadmin'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )),
                      IsBannerAdShow == true &&
                              observer.isadmobshow == true &&
                              adWidget != null
                          ? Container(
                              height: MediaQuery.of(context).size.width - 30,
                              width: MediaQuery.of(context).size.width,
                              margin: EdgeInsets.only(
                                bottom: 5.0,
                                top: 2,
                              ),
                              child: adWidget!)
                          : SizedBox(
                              height: 0,
                            ),
                    ],
                  ),
                  padding: EdgeInsets.only(left: 15.0, right: 15.0),
                ),
                // Loading
                Positioned(
                  child: isLoading
                      ? Container(
                          child: Center(
                            child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    storychatSECONDARYolor)),
                          ),
                          color: pickTextColorBasedOnBgColorAdvanced(
                                  !Thm.isDarktheme(widget.prefs)
                                      ? storychatCONTAINERboxColorDarkMode
                                      : storychatCONTAINERboxColorLightMode)
                              .withOpacity(0.6))
                      : Container(),
                ),
              ],
            ))));
  }
}
