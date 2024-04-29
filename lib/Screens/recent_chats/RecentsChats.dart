//*************   © Copyrighted by Thinkcreative_Technologies. An Exclusive item of Envato market. Make sure you have purchased a Regular License OR Extended license for the Source Code from Envato to use this product. See the License Defination attached with source code. *********************

import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storychat/Screens/Broadcast/AddContactsToBroadcast.dart';
import 'package:storychat/Screens/call_history/callhistory.dart';
import 'package:storychat/Screens/calling_screen/pickup_layout.dart';
import 'package:storychat/Screens/contact_screens/SmartContactsPage.dart';
import 'package:storychat/Screens/homepage/homepage.dart';
import 'package:storychat/Screens/notifications/AllNotifications.dart';
import 'package:storychat/Screens/recent_chats/RecentChatsWithoutLastMessage.dart';

import '/Configs/Dbkeys.dart';
import '/Configs/Dbpaths.dart';
import '/Configs/app_constants.dart';
import '/Models/DataModel.dart';
import '/Models/E2EE/e2ee.dart' as e2ee;
import '/Screens/chat_screen/utils/aes_encryption.dart';
import '/Screens/recent_chats/widgets/getBroadcastMessageTile.dart';
import '/Screens/recent_chats/widgets/getGroupMessageTile.dart';
import '/Screens/recent_chats/widgets/getPersonalMessageTile.dart';
import '/Services/Admob/admob.dart';
import '/Services/Providers/BroadcastProvider.dart';
import '/Services/Providers/GroupChatProvider.dart';
import '/Services/Providers/Observer.dart';
import '/Services/Providers/user_provider.dart';
import '/Services/localization/language_constants.dart';
import '/Utils/crc.dart';
import '/Utils/late_load.dart';
import '/Utils/setStatusBarColor.dart';
import '/Utils/theme_management.dart';
import '/Utils/utils.dart';

Color darkGrey = Colors.blueGrey[700]!;
Color lightGrey = Colors.blueGrey[400]!;

class RecentChats extends StatefulWidget {
  RecentChats({
    required this.currentUserNo,
    required this.isSecuritySetupDone,
    required this.prefs,
    required this.doc,
    key,
  }) : super(key: key);
  final String? currentUserNo;
  final SharedPreferences prefs;
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final bool isSecuritySetupDone;

  @override
  State createState() => new RecentChatsState(currentUserNo: this.currentUserNo);
}

class RecentChatsState extends State<RecentChats> {
  RecentChatsState({Key? key, this.currentUserNo}) {
    _filter.addListener(() {
      _userQuery.add(_filter.text.isEmpty ? '' : _filter.text);
    });
  }

  final TextEditingController _filter = new TextEditingController();
  bool isAuthenticating = false;

  // List<StreamSubscription> unreadSubscriptions = [];

  List<StreamController> controllers = [];
  final BannerAd myBanner = BannerAd(
    adUnitId: getBannerAdUnitId()!,
    size: AdSize.banner,
    request: AdRequest(),
    listener: BannerAdListener(),
  );
  AdWidget? adWidget;

  FlutterSecureStorage storage = new FlutterSecureStorage();
  late encrypt.Encrypter cryptor;
  final iv = encrypt.IV.fromLength(8);
  String? privateKey, sharedSecret;

  Future<String?> readPersonalMessage(peer, String inputMssg, bool isAESencryption) async {
    try {
      privateKey = await storage.read(key: Dbkeys.privateKey);
      sharedSecret = (await e2ee.X25519().calculateSharedSecret(
                e2ee.Key.fromBase64(privateKey!, false),
                e2ee.Key.fromBase64(
                  peer![Dbkeys.publicKey],
                  true,
                ),
              ))
          .toBase64();
      final key = encrypt.Key.fromBase64(sharedSecret!);
      cryptor = new encrypt.Encrypter(encrypt.Salsa20(key));
      return isAESencryption == true ? AESEncryptData.decryptAES(inputMssg, sharedSecret) : decryptWithCRC(inputMssg);
    } catch (e) {
      sharedSecret = null;
      return "";
    }
  }

  String decryptWithCRC(String input) {
    try {
      if (input.contains(Dbkeys.crcSeperator)) {
        int idx = input.lastIndexOf(Dbkeys.crcSeperator);
        String msgPart = input.substring(0, idx);
        String crcPart = input.substring(idx + 1);
        int? crc = int.tryParse(crcPart);
        if (crc != null) {
          msgPart = cryptor.decrypt(encrypt.Encrypted.fromBase64(msgPart), iv: iv);
          if (CRC32.compute(msgPart) == crc) return msgPart;
        }
      }
    } on FormatException {
      return '';
    }
    // Fiberchat.toast(getTranslated(this.context, 'msgnotload'));
    return '';
  }

  @override
  void initState() {
    super.initState();
    Fiberchat.internetLookUp();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final observer = Provider.of<Observer>(this.context, listen: false);
      if (IsBannerAdShow == true && observer.isadmobshow == true) {
        myBanner.load();
        adWidget = AdWidget(ad: myBanner);
        setState(() {});
      }
    });
  }

  getuid(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.getUserDetails(currentUserNo);
  }

  // void cancelUnreadSubscriptions() {
  //   unreadSubscriptions.forEach((subscription) {
  //     subscription.cancel();
  //   });
  // }

  DataModel? _cachedModel;
  bool showHidden = false, biometricEnabled = false;

  String? currentUserNo;

  bool isLoading = false;

  _isHidden(phoneNo) {
    Map<String, dynamic> _currentUser = _cachedModel!.currentUser!;
    return _currentUser[Dbkeys.hidden] != null && _currentUser[Dbkeys.hidden].contains(phoneNo);
  }

  StreamController<String> _userQuery = new StreamController<String>.broadcast();

  List<Map<String, dynamic>> _streamDocSnap = [];

  buildPersonalMessage(
    Map<String, dynamic> realTimePeerData,
  ) {
    String chatId = Fiberchat.getChatId(currentUserNo!, realTimePeerData[Dbkeys.phone]);
    return streamLoad(
      stream: FirebaseFirestore.instance.collection(DbPaths.collectionmessages).doc(chatId).snapshots(),
      placeholder: 1 == 2 ? SizedBox() : getPersonalMessageTile(peerSeenStatus: false, unRead: 0, peer: realTimePeerData, context: this.context, cachedModel: _cachedModel!, currentUserNo: currentUserNo!, lastMessage: null, prefs: widget.prefs, readFunction: null, isPeerChatMuted: false),
      onfetchdone: (chatDoc) {
        return streamLoadCollections(
          stream: FirebaseFirestore.instance.collection(DbPaths.collectionmessages).doc(chatId).collection(chatId).where(Dbkeys.timestamp, isGreaterThan: chatDoc[currentUserNo]).snapshots(),
          placeholder: getPersonalMessageTile(
            peerSeenStatus: chatDoc[realTimePeerData[Dbkeys.phone]],
            unRead: 0,
            peer: realTimePeerData,
            context: this.context,
            cachedModel: _cachedModel!,
            currentUserNo: currentUserNo!,
            lastMessage: null,
            prefs: widget.prefs,
            readFunction: null,
            isPeerChatMuted: chatDoc.containsKey("${widget.currentUserNo}-muted") ? chatDoc["${widget.currentUserNo}-muted"] : false,
          ),
          noDataWidget: streamLoadCollections(
            stream: FirebaseFirestore.instance.collection(DbPaths.collectionmessages).doc(chatId).collection(chatId).orderBy(Dbkeys.timestamp, descending: true).limit(1).snapshots(),
            placeholder: getPersonalMessageTile(
              peerSeenStatus: chatDoc[realTimePeerData[Dbkeys.phone]],
              unRead: 0,
              peer: realTimePeerData,
              context: this.context,
              cachedModel: _cachedModel!,
              currentUserNo: currentUserNo!,
              lastMessage: null,
              prefs: widget.prefs,
              readFunction: null,
              isPeerChatMuted: chatDoc.containsKey("${widget.currentUserNo}-muted") ? chatDoc["${widget.currentUserNo}-muted"] : false,
            ),
            noDataWidget: getPersonalMessageTile(
              peerSeenStatus: chatDoc[realTimePeerData[Dbkeys.phone]],
              unRead: 0,
              peer: realTimePeerData,
              context: this.context,
              cachedModel: _cachedModel!,
              currentUserNo: currentUserNo!,
              lastMessage: null,
              prefs: widget.prefs,
              readFunction: null,
              isPeerChatMuted: chatDoc.containsKey("${widget.currentUserNo}-muted") ? chatDoc["${widget.currentUserNo}-muted"] : false,
            ),
            onfetchdone: (messages) {
              return getPersonalMessageTile(
                peerSeenStatus: chatDoc[realTimePeerData[Dbkeys.phone]],
                unRead: 0,
                peer: realTimePeerData,
                context: this.context,
                cachedModel: _cachedModel!,
                currentUserNo: currentUserNo!,
                lastMessage: messages.last,
                prefs: widget.prefs,
                readFunction: readPersonalMessage(realTimePeerData, messages.last[Dbkeys.content], messages.last.data().containsKey(Dbkeys.latestEncrypted)),
                isPeerChatMuted: chatDoc.containsKey("${widget.currentUserNo}-muted") ? chatDoc["${widget.currentUserNo}-muted"] : false,
              );
            },
          ),
          onfetchdone: (messages) {
            return getPersonalMessageTile(
              peerSeenStatus: chatDoc[realTimePeerData[Dbkeys.phone]],
              unRead: messages.length,
              peer: realTimePeerData,
              context: this.context,
              cachedModel: _cachedModel!,
              currentUserNo: currentUserNo!,
              lastMessage: messages.last,
              prefs: widget.prefs,
              readFunction: readPersonalMessage(realTimePeerData, messages.last[Dbkeys.content], messages.last.data().containsKey(Dbkeys.latestEncrypted)),
              isPeerChatMuted: chatDoc.containsKey("${widget.currentUserNo}-muted") ? chatDoc["${widget.currentUserNo}-muted"] : false,
            );
          },
        );
      },
    );
  }

  _chats(Map<String?, Map<String, dynamic>?> _userData, Map<String, dynamic>? currentUser) {
    return Consumer<List<GroupModel>>(
      builder: (context, groupList, _child) => Consumer<List<BroadcastModel>>(
        builder: (context, broadcastList, _child) {
          _streamDocSnap = Map.from(_userData).values.where((_user) => _user.keys.contains(Dbkeys.chatStatus)).toList().cast<Map<String, dynamic>>();
          Map<String?, int?> _lastSpokenAt = _cachedModel!.lastSpokenAt;
          List<Map<String, dynamic>> filtered = List.from(<Map<String, dynamic>>[]);
          groupList.forEach((element) {
            _streamDocSnap.add(element.docmap);
          });
          broadcastList.forEach((element) {
            _streamDocSnap.add(element.docmap);
          });
          _streamDocSnap.sort((a, b) {
            int aTimestamp = a.containsKey(Dbkeys.groupISTYPINGUSERID)
                ? a[Dbkeys.groupLATESTMESSAGETIME]
                : a.containsKey(Dbkeys.broadcastBLACKLISTED)
                    ? a[Dbkeys.broadcastLATESTMESSAGETIME]
                    : _lastSpokenAt[a[Dbkeys.phone]] ?? 0;
            int bTimestamp = b.containsKey(Dbkeys.groupISTYPINGUSERID)
                ? b[Dbkeys.groupLATESTMESSAGETIME]
                : b.containsKey(Dbkeys.broadcastBLACKLISTED)
                    ? b[Dbkeys.broadcastLATESTMESSAGETIME]
                    : _lastSpokenAt[b[Dbkeys.phone]] ?? 0;
            return bTimestamp - aTimestamp;
          });

          if (!showHidden) {
            _streamDocSnap.removeWhere((_user) => !_user.containsKey(Dbkeys.groupISTYPINGUSERID) && !_user.containsKey(Dbkeys.broadcastBLACKLISTED) && _isHidden(_user[Dbkeys.phone]));
          }

          return ListView(
            shrinkWrap: true,
            children: [
              Container(
                child: _streamDocSnap.isNotEmpty
                    ? StreamBuilder(
                        stream: _userQuery.stream.asBroadcastStream(),
                        builder: (context, snapshot) {
                          if (_filter.text.isNotEmpty || snapshot.hasData) {
                            filtered = this._streamDocSnap.where((user) {
                              return user[Dbkeys.nickname].toLowerCase().trim().contains(new RegExp(r'' + _filter.text.toLowerCase().trim() + ''));
                            }).toList();
                            if (filtered.isNotEmpty)
                              return Text('');
                            else
                              return ListView(
                                physics: BouncingScrollPhysics(),
                                shrinkWrap: true,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: MediaQuery.of(context).size.height / 3.5),
                                    child: Center(
                                      child: Text(
                                        getTranslated(context, 'nosearchresult'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: storychatGrey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                          }
                          return ListView.builder(
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(0, 10, 0, 120),
                            itemBuilder: (context, index) {
                              return Column(
                                children: [
                                  if (index != 0)
                                    Padding(
                                      padding: EdgeInsets.all(5),
                                    ),
                                  if (_streamDocSnap[index].containsKey(Dbkeys.groupISTYPINGUSERID))

                                    ///----- Build Group Chat Tile ----
                                    streamLoadCollections(
                                      stream: FirebaseFirestore.instance
                                          .collection(DbPaths.collectiongroups)
                                          .doc(_streamDocSnap[index][Dbkeys.groupID])
                                          .collection(DbPaths.collectiongroupChats)
                                          .where(
                                            Dbkeys.groupmsgTIME,
                                            isGreaterThan: _streamDocSnap[index][currentUserNo],
                                          )
                                          .snapshots(),
                                      placeholder: 1 == 2
                                          ? SizedBox()
                                          : groupMessageTile(
                                              context: context,
                                              streamDocSnap: _streamDocSnap,
                                              index: index,
                                              currentUserNo: widget.currentUserNo!,
                                              prefs: widget.prefs,
                                              cachedModel: _cachedModel!,
                                              unRead: 0,
                                              isGroupChatMuted: _streamDocSnap[index].containsKey(Dbkeys.groupMUTEDMEMBERS) ? _streamDocSnap[index][Dbkeys.groupMUTEDMEMBERS].contains(currentUserNo) : false,
                                            ),
                                      noDataWidget: groupMessageTile(
                                        context: context,
                                        streamDocSnap: _streamDocSnap,
                                        index: index,
                                        currentUserNo: widget.currentUserNo!,
                                        prefs: widget.prefs,
                                        cachedModel: _cachedModel!,
                                        unRead: 0,
                                        isGroupChatMuted: _streamDocSnap[index].containsKey(Dbkeys.groupMUTEDMEMBERS) ? _streamDocSnap[index][Dbkeys.groupMUTEDMEMBERS].contains(currentUserNo) : false,
                                      ),
                                      onfetchdone: (docs) {
                                        return groupMessageTile(
                                          context: context,
                                          streamDocSnap: _streamDocSnap,
                                          index: index,
                                          currentUserNo: widget.currentUserNo!,
                                          prefs: widget.prefs,
                                          cachedModel: _cachedModel!,
                                          unRead: docs.where((mssg) => mssg[Dbkeys.groupmsgSENDBY] != currentUserNo).toList().length,
                                          isGroupChatMuted: _streamDocSnap[index].containsKey(Dbkeys.groupMUTEDMEMBERS) ? _streamDocSnap[index][Dbkeys.groupMUTEDMEMBERS].contains(currentUserNo) : false,
                                        );
                                      },
                                    )
                                  else if (_streamDocSnap[index].containsKey(Dbkeys.broadcastBLACKLISTED))

                                    ///----- Build Broadcast Chat Tile ----
                                    broadcastMessageTile(
                                      context: context,
                                      streamDocSnap: _streamDocSnap,
                                      index: index,
                                      currentUserNo: widget.currentUserNo!,
                                      prefs: widget.prefs,
                                      cachedModel: _cachedModel!,
                                    )
                                  else
                                    buildPersonalMessage(_streamDocSnap.elementAt(index)),
                                ],
                              );
                            },
                            itemCount: _streamDocSnap.length,
                          );
                        },
                      )
                    : ListView(
                        physics: NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: EdgeInsets.all(0),
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: MediaQuery.of(context).size.height / 3.5),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(30.0),
                                child: Text(
                                  groupList.length != 0 ? '' : getTranslated(context, 'startchat'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.59,
                                    color: storychatGrey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildGroupitem() {
    return Text(
      Dbkeys.groupNAME,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  DataModel? getModel() {
    _cachedModel ??= DataModel(currentUserNo);
    return _cachedModel;
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
    setStatusBarColor(widget.prefs);
    return Fiberchat.getNTPWrappedWidget(
      ScopedModel<DataModel>(
        model: getModel()!,
        child: ScopedModelDescendant<DataModel>(
          builder: (context, child, _model) {
            _cachedModel = _model;
            return Scaffold(
              bottomSheet: IsBannerAdShow == true && observer.isadmobshow == true && adWidget != null
                  ? Container(
                      height: 60,
                      margin: EdgeInsets.only(bottom: Platform.isIOS == true ? 25.0 : 5, top: 0),
                      child: Center(child: adWidget),
                    )
                  : SizedBox(
                      height: 0,
                    ),
              backgroundColor: showNewWidgets
                  ? Color.fromRGBO(255, 247, 240, 1)
                  : Thm.isDarktheme(widget.prefs)
                      ? storychatCONTAINERboxColorDarkMode
                      : Colors.white,
              body: SafeArea(
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Container(
                        margin: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(37, 37, 37, 1),
                          borderRadius: BorderRadius.circular(96),
                        ),
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        widget.prefs.setBool("chat_enabled", true);
                                      });
                                    },
                                    child: Icon(
                                      Icons.explore_rounded,
                                      size: 48,
                                      color: newPrimaryColor,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    "Welcome",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Material(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(96),
                                      side: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          new MaterialPageRoute(
                                            builder: (context) => Homepage(
                                              prefs: widget.prefs,
                                              currentUserNo: currentUserNo,
                                              doc: widget.doc,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(96),
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.queue_music_outlined,
                                          size: 32,
                                          color: newPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(96),
                                      side: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          new MaterialPageRoute(
                                            builder: (context) => Profile(
                                              prefs: widget.prefs,
                                              currentUserNo: currentUserNo,
                                              biometricEnabled: biometricEnabled,
                                              doc: widget.doc,
                                              isSecuritySetupDone: widget.isSecuritySetupDone,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(96),
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.person,
                                          size: 32,
                                          color: newPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(96),
                                      side: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          new MaterialPageRoute(
                                            builder: (context) => RecentChatsWithoutLastMessage(
                                              prefs: widget.prefs,
                                              currentUserNo: currentUserNo,
                                              isSecuritySetupDone: widget.isSecuritySetupDone,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(96),
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.groups,
                                          size: 32,
                                          color: newPrimaryColor,
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
                    ),
                    widget.prefs.getBool("chat_enabled") ?? true ? RefreshIndicator(
                      onRefresh: () {
                        isAuthenticating = !isAuthenticating;
                        setState(() {
                          showHidden = !showHidden;
                        });
                        return Future.value(true);
                      },
                      child: _chats(_model.userData, _model.currentUser),
                    ) : Container(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class Profile extends StatefulWidget {
  final SharedPreferences prefs;
  final String? currentUserNo;
  final bool biometricEnabled;
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final bool isSecuritySetupDone;

  const Profile({
    super.key,
    required this.prefs,
    this.currentUserNo,
    required this.biometricEnabled,
    required this.doc,
    required this.isSecuritySetupDone,
  });

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> myDocStream;
  DataModel? _cachedModel;

  @override
  void initState() {
    super.initState();
    myDocStream = FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).snapshots();
  }

  DateTime? currentBackPressTime = DateTime.now();

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime!) > Duration(seconds: 3)) {
      currentBackPressTime = now;
      Fiberchat.toast(getTranslated(this.context, 'doubletaptogoback'));
      return Future.value(false);
    } else {
      return Future.value(true);
    }
  }

  DataModel? getModel() {
    _cachedModel ??= DataModel(widget.currentUserNo);
    return _cachedModel;
  }

  @override
  Widget build(BuildContext context) {
    return PickupLayout(
      prefs: widget.prefs,
      scaffold: Fiberchat.getNTPWrappedWidget(
        WillPopScope(
          onWillPop: onWillPop,
          child: StreamBuilder(
            stream: myDocStream,
            builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
              if (snapshot.hasData && snapshot.data?.exists == true) {
                var myDoc = snapshot.data;
                return ScopedModel<DataModel>(
                  model: getModel()!,
                  child: ScopedModelDescendant<DataModel>(
                    builder: (context, child, _model)
                {
                  _cachedModel = _model;
                  return Scaffold(
                    backgroundColor: Colors.white,
                    body: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      SvgPicture.string(
                                        '<svg xmlns="http://www.w3.org/2000/svg" height="562.3" preserveAspectRatio="xMidYMid meet" viewBox="-14.9 -4.1 554.7 562.3" width="554.7"> <path d="M378.53,0.71c29.98-4.77,57.12,15.32,72.24,39.69c26.03-3.34,55.07,4.59,70.91,26.71c18.19,23.93,14.55,60.33-7.07,80.96 c-35.21,32.81-88.4,36.93-133.95,32.1c-27.6-30.76-52.99-68.41-55.68-110.92C322.5,37.22,345.89,4.56,378.53,0.71z" fill="inherit"/> <path d="M124.63,197.07c1.11-28.63,33.34-49.99,60.17-39.92c40.91,13.15,81.58,27.06,122.32,40.56 c19.79,5.35,34.86,24.44,34.22,45.16c0.17,76,0.29,152.05-0.06,228.11c0.52,48.42-52.02,87.23-98.23,72.39 c-47.37-11.46-72.22-71.75-46.61-113.24c21.47-40.27,78.09-50.86,114.23-24.09c-0.52-37.48-0.06-75.01-0.23-112.48 c-51.73-17.22-103.46-34.45-155.2-51.73c-0.29,56.91,0.58,113.88-0.41,170.79c-1.63,48.47-55.98,84.49-101.43,67.68 c-45.8-13.44-68.26-72.8-42.65-113.12c21.76-39.63,77.8-49.7,113.65-23.16C124.46,295.01,123.59,246.01,124.63,197.07z" fill="inherit"/> <path d="M434.85,295.24c-0.29-16.76,19.03-29.33,34.39-22.81c25.6,8.55,48.07,28.22,58.31,53.42c3.9,13.91-16.41,25.9-25.66,14.08 c-9.66-14.32-20.25-28.05-35.61-36.66c-1.98,36.43,0.58,72.97-1.34,109.4c-2.33,29.04-36.43,48.94-63.02,37.18 c-27.06-9.72-38.41-46.2-21.47-69.42c11.35-17.98,34.39-23.63,54.18-18.68C434.8,339.58,433.98,317.41,434.85,295.24z" fill="inherit"/> <path d="M208.99,32.08c-0.16-9.28,10.53-16.23,19.04-12.63c14.17,4.73,26.6,15.62,32.27,29.57c2.16,7.7-9.08,14.33-14.2,7.79 c-5.35-7.92-11.21-15.52-19.71-20.29c-1.1,20.16,0.32,40.39-0.74,60.55c-1.29,16.07-20.16,27.09-34.88,20.58 c-14.98-5.38-21.26-25.57-11.88-38.42c6.28-9.95,19.04-13.08,29.99-10.34C208.95,56.62,208.5,44.35,208.99,32.08z" fill="inherit"/></svg>',
                                        height: 24,
                                        color: newPrimaryColor,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                        'Story Chat',
                                        style: TextStyle(color: Color.fromRGBO(37, 37, 37, 1), fontSize: 18),
                                      ),
                                    ],
                                  ),
                                  Material(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(96),
                                      side: BorderSide(
                                        color: Color.fromRGBO(232, 232, 232, 1),
                                        width: 2,
                                      ),
                                    ),
                                    color: Colors.transparent,
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      child: Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: newPrimaryColor,
                                              borderRadius: BorderRadius.circular(96),
                                            ),
                                            padding: EdgeInsets.all(2),
                                            child: Icon(
                                              Icons.search,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            " Search here",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 20,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          myDoc![Dbkeys.nickname],
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 20,
                                          ),
                                        ),
                                        Text(
                                          "Tagline",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 10,
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 12,
                                              color: Colors.black,
                                            ),
                                            SizedBox(
                                              width: 8,
                                            ),
                                            Text(
                                              "Description",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      customCircleAvatar(
                                        radius: 40,
                                        url: myDoc[Dbkeys.photoUrl],
                                      ),
                                      SizedBox(
                                        height: 10,
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                                  context,
                                                  new MaterialPageRoute(
                                                      builder: (context) => new SmartContactsPage(
                                                          onTapCreateBroadcast: () {
                                                              Fiberchat.showRationale(
                                                                  getTranslated(this.context, 'disabled'));
                                                          },
                                                          onTapCreateGroup: () {
                                                              Fiberchat.showRationale(
                                                                  getTranslated(this.context, 'disabled'));
                                                          },
                                                          prefs: widget.prefs,
                                                          biometricEnabled: widget.biometricEnabled,
                                                          currentUserNo: widget.currentUserNo!,
                                                          model: _cachedModel!)));                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Color.fromRGBO(225, 170, 53, 1),
                                            borderRadius: BorderRadius.circular(96),
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                              borderRadius: BorderRadius.circular(96),
                                            ),
                                            child: Text(
                                              "Send Invite",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    bottomNavigationBar: IntrinsicHeight(
                      child: Container(
                        margin: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: newPrimaryColor,
                          borderRadius: BorderRadius.circular(96),
                        ),
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.explore_rounded,
                                    size: 48,
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    "Discover",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Color.fromRGBO(37, 37, 37, 1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              width: 3,
                              height: 24,
                              margin: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Material(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(96),
                                      side: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {},
                                      borderRadius: BorderRadius.circular(96),
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.queue_music_outlined,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(96),
                                      side: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          this.context,
                                          new MaterialPageRoute(
                                            builder: (context) =>
                                                AllNotifications(
                                                  prefs: widget.prefs,
                                                ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(96),
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.notifications,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(96),
                                      side: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          new MaterialPageRoute(
                                            builder: (context) =>
                                                RecentChats(
                                                  prefs: widget.prefs,
                                                  currentUserNo: widget.currentUserNo,
                                                  isSecuritySetupDone: true,
                                                  doc: widget.doc,
                                                ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(96),
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.person,
                                          size: 32,
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
                    ),
                  );
                },
              ),
            );
              } else {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
