//*************   © Copyrighted by Thinkcreative_Technologies. An Exclusive item of Envato market. Make sure you have purchased a Regular License OR Extended license for the Source Code from Envato to use this product. See the License Defination attached with source code. *********************

import 'package:cloud_firestore/cloud_firestore.dart';
import '/Configs/Dbkeys.dart';
import '/Configs/Dbpaths.dart';
import '/Configs/app_constants.dart';
import '/Models/DataModel.dart';
import '/Screens/call_history/callhistory.dart';
import '/Screens/profile_settings/profile_view.dart';
import '/Screens/status/components/formatStatusTime.dart';
import '/Services/Providers/SmartContactProviderWithLocalStoreData.dart';
import '/widgets/story_view/controller/story_controller.dart';
import '/widgets/story_view/widgets/story_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatusView extends StatefulWidget {
  final DocumentSnapshot<dynamic> statusDoc;
  final String currentUserNo;
  final String postedbyFullname;
  final String? postedbyPhotourl;
  final Function(String val)? callback;

  final SharedPreferences prefs;
  final DataModel model;

  StatusView({
    required this.statusDoc,
    required this.postedbyFullname,
    required this.currentUserNo,
    required this.prefs,
    required this.model,
    this.postedbyPhotourl,
    this.callback,
  });
  @override
  _StatusViewState createState() => _StatusViewState();
}

class _StatusViewState extends State<StatusView> {
  final storyController = StoryController();
  List<StoryItem?> statusitemslist = [];
  String timeString = '';
  @override
  void initState() {
    super.initState();
    if (widget.statusDoc[Dbkeys.statusITEMSLIST].length > 0) {
      widget.statusDoc[Dbkeys.statusITEMSLIST].forEach((statusMap) {
        if (statusMap[Dbkeys.statusItemTYPE] == Dbkeys.statustypeIMAGE) {
          statusitemslist.add(
            StoryItem.pageImage(
                url: statusMap[Dbkeys.statusItemURL] ??
                    "https://image.ibb.co/cU4WGx/Omotuo-Groundnut-Soup-braperucci-com-1.jpg",
                caption: statusMap[Dbkeys.statusItemCAPTION] ?? "",
                controller: storyController,
                duration: Duration(seconds: 7)),
          );
          setState(() {});
        } else if (statusMap[Dbkeys.statusItemTYPE] == Dbkeys.statustypeVIDEO) {
          statusitemslist.add(
            StoryItem.pageVideo(
                statusMap[Dbkeys.statusItemURL] ??
                    "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                caption: statusMap[Dbkeys.statusItemCAPTION] ?? "",
                controller: storyController,
                duration: Duration(
                    milliseconds:
                        statusMap[Dbkeys.statusItemDURATION].round())),
          );
        } else if (statusMap[Dbkeys.statusItemTYPE] == Dbkeys.statustypeTEXT) {
          int value = int.parse(statusMap[Dbkeys.statusItemBGCOLOR], radix: 16);
          Color finalColor = new Color(value);
          statusitemslist.add(StoryItem.text(
              title: statusMap[Dbkeys.statusItemCAPTION],
              textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.6,
                  fontWeight: FontWeight.w700),
              backgroundColor: finalColor));
        }
      });
    }
  }

  @override
  void dispose() {
    storyController.dispose();
    super.dispose();
  }

  int statusPosition = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StoryView(
            storyItems: statusitemslist,
            onStoryShow: (s) {
              statusPosition = statusPosition + 1;

              if ((statusPosition - 1) <
                  widget.statusDoc[Dbkeys.statusITEMSLIST].length) {
                FirebaseFirestore.instance
                    .collection(DbPaths.collectionnstatus)
                    .doc(widget.statusDoc[Dbkeys.statusPUBLISHERPHONE])
                    .get()
                    .then((doc) {
                  if (doc.exists) {
                    FirebaseFirestore.instance
                        .collection(DbPaths.collectionnstatus)
                        .doc(widget.statusDoc[Dbkeys.statusPUBLISHERPHONE])
                        .set({
                      widget.currentUserNo: FieldValue.arrayUnion([
                        widget.statusDoc[Dbkeys.statusITEMSLIST]
                            [statusPosition - 1][Dbkeys.statusItemID]
                      ])
                    }, SetOptions(merge: true));
                  }
                });
              }
              if (widget.currentUserNo !=
                      widget.statusDoc[Dbkeys.statusPUBLISHERPHONE] &&
                  !widget.statusDoc[Dbkeys.statusVIEWERLIST]
                      .contains(widget.currentUserNo) &&
                  statusPosition == 1) {
                FirebaseFirestore.instance
                    .collection(DbPaths.collectionnstatus)
                    .doc(widget.statusDoc[Dbkeys.statusPUBLISHERPHONE])
                    .get()
                    .then((doc) {
                  if (doc.exists) {
                    //  FirebaseFirestore.instance
                    //                     .collection(DbPaths.collectionnstatus)
                    //                     .doc(widget.statusDoc[Dbkeys.statusPUBLISHERPHONE])
                    //                     .update({
                    //                   Dbkeys.statusVIEWERLIST:
                    //                       FieldValue.arrayUnion([widget.currentUserNo])
                    //                 });
                    FirebaseFirestore.instance
                        .collection(DbPaths.collectionnstatus)
                        .doc(widget.statusDoc[Dbkeys.statusPUBLISHERPHONE])
                        .update({
                      Dbkeys.statusVIEWERLIST:
                          FieldValue.arrayUnion([widget.currentUserNo]),
                      Dbkeys.statusVIEWERLISTWITHTIME: FieldValue.arrayUnion([
                        {
                          'phone': widget.currentUserNo,
                          'time': DateTime.now().millisecondsSinceEpoch
                        }
                      ])
                    });
                  }
                });
              }
            },
            onComplete: () {
              if (widget.currentUserNo ==
                  widget.statusDoc[Dbkeys.statusPUBLISHERPHONE]) {
                Navigator.maybePop(context);
              } else {
                Navigator.maybePop(context);
                widget.callback!(widget.statusDoc[Dbkeys.statusPUBLISHERPHONE]);
              }
            },
            progressPosition: ProgressPosition.top,
            repeat: false,
            controller: storyController,
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              height: 140,
              width: MediaQuery.of(context).size.width,
              decoration: new BoxDecoration(
                gradient: new LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withOpacity(0.5),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: SizedBox(
                      width: 10,
                      child:
                          Icon(Icons.arrow_back, size: 24, color: Colors.white),
                    ),
                  ),
                  SizedBox(
                    width: 19,
                  ),
                  Consumer<SmartContactProviderWithLocalStoreData>(
                    builder: (context, availableContacts, _child) => InkWell(
                      onTap: () async {
                        if (widget.currentUserNo ==
                            widget.statusDoc[Dbkeys.statusPUBLISHERPHONE]) {
                          Navigator.of(context).pop();
                        } else {
                          await availableContacts
                              .fetchFromFiretsoreAndReturnData(widget.prefs,
                                  widget.statusDoc[Dbkeys.statusPUBLISHERPHONE],
                                  (doc) {
                            Navigator.pushAndRemoveUntil(
                                context,
                                new MaterialPageRoute(
                                    builder: (context) => new ProfileView(
                                          doc.data()!,
                                          widget.currentUserNo,
                                          widget.model,
                                          widget.prefs,
                                          [],
                                          firestoreUserDoc: doc,
                                        )),
                                (Route r) => r.isFirst);
                          });
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 7, 0, 7),
                            child: customCircleAvatar(
                                url: widget.postedbyPhotourl, radius: 20),
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 1.45,
                                child: Text(
                                  widget.postedbyFullname,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: storychatWhite,
                                      fontSize: 17.0,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              SizedBox(
                                height: 4,
                              ),
                              Text(
                                getStatusTime(
                                    widget.statusDoc[Dbkeys.statusITEMSLIST][
                                        widget.statusDoc[Dbkeys.statusITEMSLIST]
                                                .length -
                                            1][Dbkeys.statusItemID],
                                    this.context),
                                style: TextStyle(
                                    color: storychatWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              )),
        ],
      ),
    );
  }
}
