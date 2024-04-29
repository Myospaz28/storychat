//*************   © Copyrighted by Thinkcreative_Technologies. An Exclusive item of Envato market. Make sure you have purchased a Regular License OR Extended license for the Source Code from Envato to use this product. See the License Defination attached with source code. *********************

import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as local;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/Configs/Dbkeys.dart';
import '/Configs/Dbpaths.dart';
import '/Configs/app_constants.dart';
import '/Configs/optional_constants.dart';
import '/Models/DataModel.dart';
import '/Screens/Broadcast/AddContactsToBroadcast.dart';
import '/Screens/Groups/AddContactsToGroup.dart';
import '/Screens/SettingsOption/settingsOption.dart';
import '/Screens/auth_screens/login.dart';
import '/Screens/call_history/callhistory.dart';
import '/Screens/calling_screen/pickup_layout.dart';
import '/Screens/homepage/Setupdata.dart';
import '/Screens/notifications/AllNotifications.dart';
import '/Screens/profile_settings/profileSettings.dart';
import '/Screens/recent_chats/RecentChatsWithoutLastMessage.dart';
import '/Screens/recent_chats/RecentsChats.dart';
import '/Screens/search_chats/SearchRecentChat.dart';
import '/Screens/sharing_intent/SelectContactToShare.dart';
import '/Screens/splash_screen/splash_screen.dart';
import '/Screens/status/status.dart';
import '/Services/Providers/Observer.dart';
import '/Services/Providers/SmartContactProviderWithLocalStoreData.dart';
import '/Services/Providers/StatusProvider.dart';
import '/Services/Providers/call_history_provider.dart';
import '/Services/Providers/currentchat_peer.dart';
import '/Services/Providers/user_provider.dart';
import '/Services/localization/language.dart';
import '/Services/localization/language_constants.dart';
import '/Utils/color_detector.dart';
import '/Utils/custom_url_launcher.dart';
import '/Utils/error_codes.dart';
import '/Utils/phonenumberVariantsGenerator.dart';
import '/Utils/theme_management.dart';
import '/Utils/unawaited.dart';
import '/Utils/utils.dart';
import '/main.dart';
import '/widgets/DynamicBottomSheet/dynamic_modal_bottomsheet.dart';

class Homepage extends StatefulWidget {
  Homepage({required this.currentUserNo, required this.prefs, required this.doc, this.isShowOnlyCircularSpin = false, key}) : super(key: key);
  final String? currentUserNo;
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final bool? isShowOnlyCircularSpin;
  final SharedPreferences prefs;

  @override
  State createState() => new HomepageState(doc: this.doc);
}

class HomepageState extends State<Homepage> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  HomepageState({Key? key, doc}) {
    _filter.addListener(() {
      _userQuery.add(_filter.text.isEmpty ? '' : _filter.text);
    });
  }

  TabController? controllerIfcallallowed;
  TabController? controllerIfcallNotallowed;
  late StreamSubscription _intentDataStreamSubscription;
  List<SharedMediaFile>? _sharedFiles = [];
  String? _sharedText;

  @override
  bool get wantKeepAlive => true;

  bool isFetching = true;
  List phoneNumberVariants = [];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      setIsActive();
    else
      setLastSeen();
  }

  void setIsActive() async {
    if (widget.currentUserNo != null)
      await FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).update(
        {Dbkeys.lastSeen: true, Dbkeys.lastOnline: DateTime.now().millisecondsSinceEpoch},
      );
  }

  void setLastSeen() async {
    if (widget.currentUserNo != null)
      await FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).update(
        {Dbkeys.lastSeen: DateTime.now().millisecondsSinceEpoch},
      );
  }

  final TextEditingController _filter = new TextEditingController();
  bool isAuthenticating = false;

  StreamSubscription? spokenSubscription;
  List<StreamSubscription> unreadSubscriptions = List.from(<StreamSubscription>[]);

  List<StreamController> controllers = List.from(<StreamController>[]);
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  String? deviceid;
  var mapDeviceInfo = {};
  String? maintainanceMessage;
  bool isNotAllowEmulator = false;
  bool? isblockNewlogins = false;
  bool? isApprovalNeededbyAdminForNewUser = false;
  String? accountApprovalMessage = 'Account Approved';
  String? accountstatus;
  String? accountactionmessage;
  String? userPhotourl;
  String? userFullname;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> myDocStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> playlistsStream;

  @override
  void initState() {
    listenToSharingintent();
    listenToNotification();
    super.initState();
    getSignedInUserOrRedirect();
    setdeviceinfo();
    registerNotification();

    controllerIfcallallowed = TabController(length: IsShowSearchTab ? 4 : 3, vsync: this);
    controllerIfcallallowed!.index = IsShowSearchTab ? 1 : 0;
    controllerIfcallNotallowed = TabController(length: IsShowSearchTab ? 3 : 2, vsync: this);
    controllerIfcallNotallowed!.index = IsShowSearchTab ? 1 : 0;

    Fiberchat.internetLookUp();
    WidgetsBinding.instance.addObserver(this);

    LocalAuthentication().canCheckBiometrics.then((res) {
      if (res) biometricEnabled = true;
    });
    getModel();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controllerIfcallallowed!.addListener(() {
        if (IsShowSearchTab == true) {
          if (controllerIfcallallowed!.index == 2) {
            final statusProvider = Provider.of<StatusProvider>(context, listen: false);
            final contactsProvider = Provider.of<SmartContactProviderWithLocalStoreData>(context, listen: false);
            statusProvider.searchContactStatus(widget.currentUserNo!, FutureGroup(), contactsProvider.alreadyJoinedSavedUsersPhoneNameAsInServer);
          }
        } else {
          if (controllerIfcallallowed!.index == 1) {
            final statusProvider = Provider.of<StatusProvider>(context, listen: false);
            final contactsProvider = Provider.of<SmartContactProviderWithLocalStoreData>(context, listen: false);
            statusProvider.searchContactStatus(widget.currentUserNo!, FutureGroup(), contactsProvider.alreadyJoinedSavedUsersPhoneNameAsInServer);
          }
        }
      });
      controllerIfcallNotallowed!.addListener(() {
        if (IsShowSearchTab == true) {
          if (controllerIfcallNotallowed!.index == 2) {
            final statusProvider = Provider.of<StatusProvider>(context, listen: false);
            final contactsProvider = Provider.of<SmartContactProviderWithLocalStoreData>(context, listen: false);
            statusProvider.searchContactStatus(widget.currentUserNo!, FutureGroup(), contactsProvider.alreadyJoinedSavedUsersPhoneNameAsInServer);
          }
        } else {
          if (controllerIfcallNotallowed!.index == 1) {
            final statusProvider = Provider.of<StatusProvider>(context, listen: false);
            final contactsProvider = Provider.of<SmartContactProviderWithLocalStoreData>(context, listen: false);
            statusProvider.searchContactStatus(widget.currentUserNo!, FutureGroup(), contactsProvider.alreadyJoinedSavedUsersPhoneNameAsInServer);
          }
        }
      });
    });
    myDocStream = FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).snapshots();
    playlistsStream = FirebaseFirestore.instance.collection("playlists").doc("Popular Songs").snapshots();
  }

  // detectLocale() async {
  //   await Devicelocale.currentLocale.then((locale) async {
  //     if (locale == 'ja_JP' &&
  //         (widget.prefs.getBool('islanguageselected') == false ||
  //             widget.prefs.getBool('islanguageselected') == null)) {
  //       Locale _locale = await setLocale('ja');
  //       FiberchatWrapper.setLocale(context, _locale);
  //       setState(() {});
  //     }
  //   }).catchError((onError) {
  //     Fiberchat.toast(
  //       'Error occured while fetching Locale :$onError',
  //     );
  //   });
  // }

  incrementSessionCount(String myphone) async {
    final StatusProvider statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final SmartContactProviderWithLocalStoreData contactsProvider = Provider.of<SmartContactProviderWithLocalStoreData>(context, listen: false);
    final FirestoreDataProviderCALLHISTORY firestoreDataProviderCALLHISTORY = Provider.of<FirestoreDataProviderCALLHISTORY>(context, listen: false);
    await FirebaseFirestore.instance.collection(DbPaths.collectiondashboard).doc(DbPaths.docuserscount).set(
        Platform.isAndroid
            ? {
                Dbkeys.totalvisitsANDROID: FieldValue.increment(1),
              }
            : {
                Dbkeys.totalvisitsIOS: FieldValue.increment(1),
              },
        SetOptions(merge: true));
    await FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).set(
        Platform.isAndroid
            ? {
                Dbkeys.isNotificationStringsMulitilanguageEnabled: true,
                Dbkeys.notificationStringsMap: getTranslateNotificationStringsMap(this.context),
                Dbkeys.totalvisitsANDROID: FieldValue.increment(1),
              }
            : {
                Dbkeys.isNotificationStringsMulitilanguageEnabled: true,
                Dbkeys.notificationStringsMap: getTranslateNotificationStringsMap(this.context),
                Dbkeys.totalvisitsIOS: FieldValue.increment(1),
              },
        SetOptions(merge: true));
    firestoreDataProviderCALLHISTORY.fetchNextData('CALLHISTORY', FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).collection(DbPaths.collectioncallhistory).orderBy('TIME', descending: true).limit(10), true);
    if (OnlyPeerWhoAreSavedInmyContactCanMessageOrCallMe == false) {
      await contactsProvider.fetchContacts(context, _cachedModel, myphone, widget.prefs, false, currentuserphoneNumberVariants: phoneNumberVariants);
    }

    //  await statusProvider.searchContactStatus(
    //       myphone, contactsProvider.joinedUserPhoneStringAsInServer);
    statusProvider.triggerDeleteMyExpiredStatus(myphone);
    statusProvider.triggerDeleteOtherUsersExpiredStatus(myphone);
    if (_sharedFiles!.length > 0 || _sharedText != null) {
      triggerSharing();
    }
  }

  triggerSharing() {
    final observer = Provider.of<Observer>(this.context, listen: false);
    if (_sharedText != null) {
      Navigator.push(context, new MaterialPageRoute(builder: (context) => new SelectContactToShare(prefs: widget.prefs, model: _cachedModel!, currentUserNo: widget.currentUserNo, sharedFiles: _sharedFiles!, sharedText: _sharedText)));
    } else if (_sharedFiles != null) {
      if (_sharedFiles!.length > observer.maxNoOfFilesInMultiSharing) {
        Fiberchat.toast(getTranslated(context, 'maxnooffiles') + ' ' + '${observer.maxNoOfFilesInMultiSharing}');
      } else {
        Navigator.push(context, new MaterialPageRoute(builder: (context) => new SelectContactToShare(prefs: widget.prefs, model: _cachedModel!, currentUserNo: widget.currentUserNo, sharedFiles: _sharedFiles!, sharedText: _sharedText)));
      }
    }
  }

  listenToSharingintent() {
    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
      setState(() {
        _sharedFiles = value;
      });
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      setState(() {
        _sharedFiles = value;
      });
    });

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() {
        _sharedText = value;
      });
    }, onError: (err) {
      debugPrint("getLinkStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String? value) {
      setState(() {
        _sharedText = value;
      });
    });
  }

  unsubscribeToNotification(String? userphone) async {
    if (userphone != null) {
      await FirebaseMessaging.instance.unsubscribeFromTopic('${userphone.replaceFirst(new RegExp(r'\+'), '')}');
    }

    await FirebaseMessaging.instance.unsubscribeFromTopic(Dbkeys.topicUSERS).catchError((err) {
      debugPrint(err.toString());
    });
    await FirebaseMessaging.instance
        .unsubscribeFromTopic(Platform.isAndroid
            ? Dbkeys.topicUSERSandroid
            : Platform.isIOS
                ? Dbkeys.topicUSERSios
                : Dbkeys.topicUSERSweb)
        .catchError((err) {
      debugPrint(err.toString());
    });
  }

  void registerNotification() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );
  }

  setdeviceinfo() async {
    if (Platform.isAndroid == true) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() {
        deviceid = androidInfo.id + androidInfo.device;
        mapDeviceInfo = {
          Dbkeys.deviceInfoMODEL: androidInfo.model,
          Dbkeys.deviceInfoOS: 'android',
          Dbkeys.deviceInfoISPHYSICAL: androidInfo.isPhysicalDevice,
          Dbkeys.deviceInfoDEVICEID: androidInfo.id,
          Dbkeys.deviceInfoOSID: androidInfo.id,
          Dbkeys.deviceInfoOSVERSION: androidInfo.version.baseOS,
          Dbkeys.deviceInfoMANUFACTURER: androidInfo.manufacturer,
          Dbkeys.deviceInfoLOGINTIMESTAMP: DateTime.now(),
        };
      });
    } else if (Platform.isIOS == true) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      setState(() {
        deviceid = "${iosInfo.systemName}${iosInfo.model}${iosInfo.systemVersion}";
        mapDeviceInfo = {
          Dbkeys.deviceInfoMODEL: iosInfo.model,
          Dbkeys.deviceInfoOS: 'ios',
          Dbkeys.deviceInfoISPHYSICAL: iosInfo.isPhysicalDevice,
          Dbkeys.deviceInfoDEVICEID: iosInfo.identifierForVendor,
          Dbkeys.deviceInfoOSID: iosInfo.name,
          Dbkeys.deviceInfoOSVERSION: iosInfo.name,
          Dbkeys.deviceInfoMANUFACTURER: iosInfo.name,
          Dbkeys.deviceInfoLOGINTIMESTAMP: DateTime.now(),
        };
      });
    }
  }

  getuid(BuildContext context) {
    final UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.getUserDetails(widget.currentUserNo);
  }

  logout(BuildContext context) async {
    final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
    await firebaseAuth.signOut();

    await widget.prefs.clear();

    FlutterSecureStorage storage = new FlutterSecureStorage();
    // ignore: await_only_futures
    await storage.delete;
    if (widget.currentUserNo != null) {
      await FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).update({
        Dbkeys.notificationTokens: [],
      });
    }

    await widget.prefs.setBool(Dbkeys.isTokenGenerated, false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (BuildContext context) => FiberchatWrapper(),
      ),
      (Route route) => false,
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    controllers.forEach((controller) {
      controller.close();
    });
    _filter.dispose();
    spokenSubscription?.cancel();
    _userQuery.close();
    cancelUnreadSubscriptions();
    setLastSeen();

    _intentDataStreamSubscription.cancel();
  }

  void cancelUnreadSubscriptions() {
    unreadSubscriptions.forEach((subscription) {
      subscription.cancel();
    });
  }

  void listenToNotification() async {
    //FOR ANDROID & IOS  background notification is handled at the very top of main.dart ------

    //ANDROID & iOS  OnMessage callback
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // ignore: unnecessary_null_comparison
      flutterLocalNotificationsPlugin..cancelAll();

      if (message.data['title'] != 'Call Ended' && message.data['title'] != 'Missed Call' && message.data['title'] != 'You have new message(s)' && message.data['title'] != 'Incoming Video Call...' && message.data['title'] != 'Incoming Audio Call...' && message.data['title'] != 'Incoming Call ended' && message.data['title'] != 'New message in Group') {
        Fiberchat.toast(getTranslated(this.context, 'newnotifications'));
      } else {
        if (message.data['title'] == 'New message in Group') {
          // var currentpeer =
          //     Provider.of<CurrentChatPeer>(this.context, listen: false);
          // if (currentpeer.groupChatId != message.data['groupid']) {
          //   flutterLocalNotificationsPlugin..cancelAll();

          //   showOverlayNotification((context) {
          //     return Card(
          //       margin: const EdgeInsets.symmetric(horizontal: 4),
          //       child: SafeArea(
          //         child: ListTile(
          //           title: Text(
          //             message.data['titleMultilang'],
          //             maxLines: 1,
          //             overflow: TextOverflow.ellipsis,
          //           ),
          //           subtitle: Text(
          //             message.data['bodyMultilang'],
          //             maxLines: 2,
          //             overflow: TextOverflow.ellipsis,
          //           ),
          //           trailing: IconButton(
          //               icon: Icon(Icons.close),
          //               onPressed: () {
          //                 OverlaySupportEntry.of(context)!.dismiss();
          //               }),
          //         ),
          //       ),
          //     );
          //   }, duration: Duration(milliseconds: 2000));
          // }
        } else if (message.data['title'] == 'Call Ended') {
          flutterLocalNotificationsPlugin..cancelAll();
        } else {
          if (message.data['title'] == 'Incoming Audio Call...' || message.data['title'] == 'Incoming Video Call...') {
            final data = message.data;
            final title = data['title'];
            final body = data['body'];
            final titleMultilang = data['titleMultilang'];
            final bodyMultilang = data['bodyMultilang'];
            await showNotificationWithDefaultSound(title, body, titleMultilang, bodyMultilang);
          } else if (message.data['title'] == 'You have new message(s)') {
            var currentpeer = Provider.of<CurrentChatPeer>(this.context, listen: false);
            if (currentpeer.peerid != message.data['peerid']) {
              // FlutterRingtonePlayer.playNotification();
              showOverlayNotification((context) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: SafeArea(
                    child: ListTile(
                      title: Text(
                        message.data['titleMultilang'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        message.data['bodyMultilang'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            OverlaySupportEntry.of(context)!.dismiss();
                          }),
                    ),
                  ),
                );
              }, duration: Duration(milliseconds: 2000));
            }
          } else {
            showOverlayNotification((context) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: SafeArea(
                  child: ListTile(
                    leading: message.data.containsKey("image")
                        ? null
                        : message.data["image"] == null
                            ? SizedBox()
                            : Image.network(
                                message.data['image'],
                                width: 50,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                    title: Text(
                      message.data['titleMultilang'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      message.data['bodyMultilang'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          OverlaySupportEntry.of(context)!.dismiss();
                        }),
                  ),
                ),
              );
            }, duration: Duration(milliseconds: 2000));
          }
        }
      }
    });
    //ANDROID & iOS  onMessageOpenedApp callback
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      flutterLocalNotificationsPlugin..cancelAll();
      Map<String, dynamic> notificationData = message.data;
      AndroidNotification? android = message.notification?.android;
      if (android != null) {
        if (notificationData['title'] == 'Call Ended') {
          flutterLocalNotificationsPlugin..cancelAll();
        } else if (notificationData['title'] != 'Call Ended' && notificationData['title'] != 'You have new message(s)' && notificationData['title'] != 'Missed Call' && notificationData['title'] != 'Incoming Video Call...' && notificationData['title'] != 'Incoming Audio Call...' && notificationData['title'] != 'Incoming Call ended' && notificationData['title'] != 'New message in Group') {
          flutterLocalNotificationsPlugin..cancelAll();

          Navigator.push(
              context,
              new MaterialPageRoute(
                  builder: (context) => AllNotifications(
                        prefs: widget.prefs,
                      )));
        } else {
          flutterLocalNotificationsPlugin..cancelAll();
        }
      }
    });
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        flutterLocalNotificationsPlugin..cancelAll();
        Map<String, dynamic>? notificationData = message.data;
        if (notificationData['title'] != 'Call Ended' && notificationData['title'] != 'You have new message(s)' && notificationData['title'] != 'Missed Call' && notificationData['title'] != 'Incoming Video Call...' && notificationData['title'] != 'Incoming Audio Call...' && notificationData['title'] != 'Incoming Call ended' && notificationData['title'] != 'New message in Group') {
          flutterLocalNotificationsPlugin..cancelAll();

          Navigator.push(
              context,
              new MaterialPageRoute(
                  builder: (context) => AllNotifications(
                        prefs: widget.prefs,
                      )));
        }
      }
    });
  }

  DataModel? _cachedModel;
  bool showHidden = false, biometricEnabled = false;

  DataModel? getModel() {
    _cachedModel ??= DataModel(widget.currentUserNo);
    return _cachedModel;
  }

  getSignedInUserOrRedirect() async {
    try {
      setState(() {
        isblockNewlogins = widget.doc.data()![Dbkeys.isblocknewlogins];
        isApprovalNeededbyAdminForNewUser = widget.doc[Dbkeys.isaccountapprovalbyadminneeded];
        accountApprovalMessage = widget.doc[Dbkeys.accountapprovalmessage];
      });
      if (widget.doc.data()![Dbkeys.isemulatorallowed] == false && mapDeviceInfo[Dbkeys.deviceInfoISPHYSICAL] == false) {
        setState(() {
          isNotAllowEmulator = true;
        });
      } else {
        if (widget.doc[Platform.isAndroid
                ? Dbkeys.isappunderconstructionandroid
                : Platform.isIOS
                    ? Dbkeys.isappunderconstructionios
                    : Dbkeys.isappunderconstructionweb] ==
            true) {
          await unsubscribeToNotification(widget.currentUserNo);
          maintainanceMessage = widget.doc[Dbkeys.maintainancemessage];
          setState(() {});
        } else {
          final PackageInfo info = await PackageInfo.fromPlatform();
          widget.prefs.setString('app_version', info.version);

          int currentAppVersionInPhone = int.tryParse(info.version.trim().split(".")[0].toString().padLeft(3, '0') + info.version.trim().split(".")[1].toString().padLeft(3, '0') + info.version.trim().split(".")[2].toString().padLeft(3, '0')) ?? 0;
          int currentNewAppVersionInServer = int.tryParse(widget.doc[Platform.isAndroid
                          ? Dbkeys.latestappversionandroid
                          : Platform.isIOS
                              ? Dbkeys.latestappversionios
                              : Dbkeys.latestappversionweb]
                      .trim()
                      .split(".")[0]
                      .toString()
                      .padLeft(3, '0') +
                  widget.doc[Platform.isAndroid
                          ? Dbkeys.latestappversionandroid
                          : Platform.isIOS
                              ? Dbkeys.latestappversionios
                              : Dbkeys.latestappversionweb]
                      .trim()
                      .split(".")[1]
                      .toString()
                      .padLeft(3, '0') +
                  widget.doc[Platform.isAndroid
                          ? Dbkeys.latestappversionandroid
                          : Platform.isIOS
                              ? Dbkeys.latestappversionios
                              : Dbkeys.latestappversionweb]
                      .trim()
                      .split(".")[2]
                      .toString()
                      .padLeft(3, '0')) ??
              0;
          if (currentAppVersionInPhone < currentNewAppVersionInServer) {
            showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                String title = getTranslated(context, 'updateavl');
                String message = getTranslated(context, 'updateavlmsg');

                String btnLabel = getTranslated(context, 'updatnow');

                return new WillPopScope(
                    onWillPop: () async => false,
                    child: AlertDialog(
                      backgroundColor: Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode,
                      title: Text(
                        title,
                        style: TextStyle(
                          color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                        ),
                      ),
                      content: Text(message),
                      actions: <Widget>[
                        TextButton(
                            child: Text(
                              btnLabel,
                              style: TextStyle(color: storychatPRIMARYcolor),
                            ),
                            onPressed: () => custom_url_launcher(widget.doc[Platform.isAndroid
                                ? Dbkeys.newapplinkandroid
                                : Platform.isIOS
                                    ? Dbkeys.newapplinkios
                                    : Dbkeys.newapplinkweb])),
                      ],
                    ));
              },
            );
          } else {
            final observer = Provider.of<Observer>(this.context, listen: false);

            observer.setObserver(
              getuserAppSettingsDoc: widget.doc,
              getisWebCompatible: widget.doc.data()!.containsKey('is_web_compatible') ? widget.doc.data()!['is_web_compatible'] : false,
              getandroidapplink: widget.doc[Dbkeys.newapplinkandroid],
              getiosapplink: widget.doc[Dbkeys.newapplinkios],
              getisadmobshow: widget.doc[Dbkeys.isadmobshow],
              getismediamessagingallowed: widget.doc[Dbkeys.ismediamessageallowed],
              getistextmessagingallowed: widget.doc[Dbkeys.istextmessageallowed],
              getiscallsallowed: widget.doc[Dbkeys.iscallsallowed],
              gettnc: widget.doc[Dbkeys.tnc],
              gettncType: widget.doc[Dbkeys.tncTYPE],
              getprivacypolicy: widget.doc[Dbkeys.privacypolicy],
              getprivacypolicyType: widget.doc[Dbkeys.privacypolicyTYPE],
              getis24hrsTimeformat: widget.doc[Dbkeys.is24hrsTimeformat],
              getmaxFileSizeAllowedInMB: widget.doc[Dbkeys.maxFileSizeAllowedInMB],
              getisPercentProgressShowWhileUploading: widget.doc[Dbkeys.isPercentProgressShowWhileUploading],
              getisCallFeatureTotallyHide: widget.doc[Dbkeys.isCallFeatureTotallyHide],
              getgroupMemberslimit: widget.doc[Dbkeys.groupMemberslimit],
              getbroadcastMemberslimit: widget.doc[Dbkeys.broadcastMemberslimit],
              getstatusDeleteAfterInHours: widget.doc[Dbkeys.statusDeleteAfterInHours],
              getfeedbackEmail: widget.doc[Dbkeys.feedbackEmail],
              getisLogoutButtonShowInSettingsPage: widget.doc[Dbkeys.isLogoutButtonShowInSettingsPage],
              getisAllowCreatingGroups: widget.doc[Dbkeys.isAllowCreatingGroups],
              getisAllowCreatingBroadcasts: widget.doc[Dbkeys.isAllowCreatingBroadcasts],
              getisAllowCreatingStatus: widget.doc[Dbkeys.isAllowCreatingStatus],
              getmaxNoOfFilesInMultiSharing: widget.doc[Dbkeys.maxNoOfFilesInMultiSharing],
              getmaxNoOfContactsSelectForForward: widget.doc[Dbkeys.maxNoOfContactsSelectForForward],
              getappShareMessageStringAndroid: widget.doc[Dbkeys.appShareMessageStringAndroid],
              getappShareMessageStringiOS: widget.doc[Dbkeys.appShareMessageStringiOS],
              getisCustomAppShareLink: widget.doc[Dbkeys.isCustomAppShareLink],
            );

            if (widget.currentUserNo == null || widget.currentUserNo!.isEmpty) {
              // await unsubscribeToNotification(widget.currentUserNo);

              unawaited(
                Navigator.pushReplacement(
                  context,
                  new MaterialPageRoute(
                    builder: (context) => new LoginScreen(
                      prefs: widget.prefs,
                      accountApprovalMessage: accountApprovalMessage,
                      isaccountapprovalbyadminneeded: isApprovalNeededbyAdminForNewUser,
                      isblocknewlogins: isblockNewlogins,
                      title: getTranslated(context, 'signin'),
                      doc: widget.doc,
                    ),
                  ),
                ),
              );
            } else {
              await FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo ?? widget.currentUserNo).get().then((userDoc) async {
                if (deviceid != userDoc[Dbkeys.currentDeviceID] || !userDoc.data()!.containsKey(Dbkeys.currentDeviceID)) {
                  if (ConnectWithAdminApp == true) {
                    await unsubscribeToNotification(widget.currentUserNo);
                  }
                  await logout(context);
                } else {
                  if (!userDoc.data()!.containsKey(Dbkeys.accountstatus)) {
                    await logout(context);
                  } else if (userDoc[Dbkeys.accountstatus] != Dbkeys.sTATUSallowed) {
                    if (userDoc[Dbkeys.accountstatus] == Dbkeys.sTATUSdeleted) {
                      setState(() {
                        accountstatus = userDoc[Dbkeys.accountstatus];
                        accountactionmessage = userDoc[Dbkeys.actionmessage];
                      });
                    } else {
                      setState(() {
                        accountstatus = userDoc[Dbkeys.accountstatus];
                        accountactionmessage = userDoc[Dbkeys.actionmessage];
                      });
                    }
                  } else {
                    setState(() {
                      userFullname = userDoc[Dbkeys.nickname];
                      userPhotourl = userDoc[Dbkeys.photoUrl];
                      phoneNumberVariants = phoneNumberVariantsList(countrycode: userDoc[Dbkeys.countryCode], phonenumber: userDoc[Dbkeys.phoneRaw]);
                      isFetching = false;
                    });
                    getuid(context);
                    setIsActive();

                    incrementSessionCount(userDoc[Dbkeys.phone]);
                  }
                }
              });
            }
          }
        }
      }
    } catch (e) {
      showERRORSheet(this.context, "", message: e.toString());
    }
  }

  StreamController<String> _userQuery = new StreamController<String>.broadcast();

  void _changeLanguage(Language language) async {
    Locale _locale = await setLocale(language.languageCode);
    FiberchatWrapper.setLocale(context, _locale);
    if (widget.currentUserNo != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo).update({
          Dbkeys.notificationStringsMap: getTranslateNotificationStringsMap(this.context),
        });
      });
    }
    setState(() {
      // seletedlanguage = language;
    });

    await widget.prefs.setBool('islanguageselected', true);
  }

  DateTime? currentBackPressTime = DateTime.now();

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime!) > Duration(seconds: 3)) {
      currentBackPressTime = now;
      Fiberchat.toast(getTranslated(this.context, 'doubletaptogoback'));
      return Future.value(false);
    } else {
      if (!isAuthenticating) setLastSeen();
      return Future.value(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return isNotAllowEmulator == true
        ? errorScreen('Emulator Not Allowed.', ' Please use any real device & Try again.')
        : accountstatus != null
            ? errorScreen(accountstatus, accountactionmessage)
            : ConnectWithAdminApp == true && maintainanceMessage != null
                ? errorScreen('App Under maintainance', maintainanceMessage)
                : ConnectWithAdminApp == true && isFetching == true
                    ? Splashscreen(
                        isShowOnlySpinner: widget.isShowOnlyCircularSpin,
                      )
                    : PickupLayout(
                        prefs: widget.prefs,
                        scaffold: Fiberchat.getNTPWrappedWidget(
                          WillPopScope(
                            onWillPop: onWillPop,
                            child: StreamBuilder(
                              stream: myDocStream,
                              builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
                                if (snapshot.hasData && snapshot.data?.exists == true) {
                                  var myDoc = snapshot.data;
                                  return Scaffold(
                                    backgroundColor: Color.fromRGBO(37, 37, 37, 1),
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
                                                        style: TextStyle(color: Colors.white, fontSize: 18),
                                                      ),
                                                    ],
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        new MaterialPageRoute(
                                                          builder: (context) => SettingsOption(
                                                            prefs: widget.prefs,
                                                            onTapLogout: () async {
                                                              await logout(context);
                                                            },
                                                            onTapEditProfile: () {
                                                              Navigator.push(
                                                                context,
                                                                new MaterialPageRoute(
                                                                  builder: (context) => ProfileSetting(
                                                                    prefs: widget.prefs,
                                                                    biometricEnabled: biometricEnabled,
                                                                    type: Fiberchat.getAuthenticationType(biometricEnabled, _cachedModel),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            currentUserNo: widget.currentUserNo!,
                                                            biometricEnabled: biometricEnabled,
                                                            type: Fiberchat.getAuthenticationType(biometricEnabled, _cachedModel),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    borderRadius: BorderRadius.circular(20),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(4),
                                                      child: Icon(
                                                        Icons.settings,
                                                        size: 24,
                                                        color: newPrimaryColor,
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
                                                          "Welcome back,",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          myDoc![Dbkeys.nickname],
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 20,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        Row(
                                                          children: () {
                                                            DateTime? since = FirebaseAuth.instance.currentUser?.metadata.creationTime;

                                                            if (since != null) {
                                                              return [
                                                                Icon(
                                                                  Icons.circle,
                                                                  size: 12,
                                                                  color: Colors.white,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  "Since ${since.year}",
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 14,
                                                                  ),
                                                                ),
                                                              ];
                                                            }

                                                            return <Widget>[];
                                                          }(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  customCircleAvatar(
                                                    radius: 40,
                                                    url: myDoc[Dbkeys.photoUrl],
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: 20,
                                              ),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: newPrimaryColor,
                                                  borderRadius: BorderRadius.circular(24),
                                                ),
                                                padding: EdgeInsets.all(20),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            "Latest Playlist",
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height: 10,
                                                          ),
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              color: Color.fromRGBO(37, 37, 37, 1),
                                                              borderRadius: BorderRadius.circular(16),
                                                            ),
                                                            height: 3,
                                                            width: 24,
                                                          ),
                                                          SizedBox(
                                                            height: 10,
                                                          ),
                                                          Text(
                                                            "Enjoy trending and latest Playlist",
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    FutureBuilder(
                                                      future: () async {
                                                        return FirebaseStorage.instance.ref("Playlists/Latest Playlist.webp").getDownloadURL();
                                                      }(),
                                                      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                                        if (snapshot.hasData) {
                                                          return Image.network(
                                                            snapshot.data ?? "",
                                                            height: 64,
                                                            width: 64,
                                                            fit: BoxFit.cover,
                                                          );
                                                        } else {
                                                          return Container();
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                height: 20,
                                              ),
                                              StreamBuilder(
                                                stream: playlistsStream,
                                                builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
                                                  if (snapshot.hasData) {
                                                    var myDoc = snapshot.data!;

                                                    return Column(
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons.local_fire_department,
                                                                    size: 24,
                                                                    color: Colors.white,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    "Popular Songs",
                                                                    style: TextStyle(
                                                                      color: Colors.white,
                                                                      fontSize: 16,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons.tune,
                                                              size: 24,
                                                              color: Colors.white,
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(
                                                          height: 20,
                                                        ),
                                                        MasonryGridView(
                                                          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                                            crossAxisCount: 2,
                                                          ),
                                                          physics: NeverScrollableScrollPhysics(),
                                                          shrinkWrap: true,
                                                          mainAxisSpacing: 12,
                                                          crossAxisSpacing: 12,
                                                          children: [
                                                            for (var entry in (myDoc.data() ?? {}).entries)
                                                              () {
                                                                var data = entry.value;

                                                                return FutureBuilder(
                                                                  future: () async {
                                                                    return FirebaseStorage.instance.ref("Playlists/Images/${data['thumbnail']}").getDownloadURL();
                                                                  }(),
                                                                  builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                                                    if (snapshot.hasData) {
                                                                      return Container(
                                                                        decoration: BoxDecoration(
                                                                          borderRadius: BorderRadius.circular(16),
                                                                          image: DecorationImage(
                                                                            image: NetworkImage(snapshot.data ?? ""),
                                                                            fit: BoxFit.cover,
                                                                          ),
                                                                        ),
                                                                        padding: EdgeInsets.all(12),
                                                                        child: Column(
                                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                                          children: [
                                                                            Icon(
                                                                              Icons.play_circle_fill,
                                                                              size: 48,
                                                                              color: Colors.white,
                                                                            ),
                                                                            Text(
                                                                              data['title'],
                                                                              style: TextStyle(
                                                                                color: Colors.white,
                                                                                fontSize: 12,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                            Text(
                                                                              data['subtitle'],
                                                                              style: TextStyle(
                                                                                color: Colors.white,
                                                                                fontSize: 12,
                                                                              ),
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      );
                                                                    } else {
                                                                      return Center(child: CircularProgressIndicator());
                                                                    }
                                                                  },
                                                                );
                                                              }(),
                                                          ],
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    return Center(
                                                      child: CircularProgressIndicator(),
                                                    );
                                                  }
                                                },
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
                                                  GestureDetector(
                                                    onTap: () async {
                                                      widget.prefs.setBool("chat_enabled", false);
                                                      var _userData = _cachedModel!.userData;
                                                      Map.from(_userData)
                                                          .values
                                                          .where((_user) {
                                                            return _user.keys.contains(Dbkeys.chatStatus);
                                                          })
                                                          .cast<Map<String, dynamic>>()
                                                          .forEach((targetUser) async {
                                                            String chatId = Fiberchat.getChatId(widget.currentUserNo!, targetUser[Dbkeys.phone]);

                                                            if (targetUser[Dbkeys.phone] != null) {
                                                              await FirebaseFirestore.instance.collection(DbPaths.collectionmessages).doc(chatId).delete().then((v) async {
                                                                await FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(widget.currentUserNo!).collection(Dbkeys.chatsWith).doc(Dbkeys.chatsWith).set({
                                                                  targetUser[Dbkeys.phone]: FieldValue.delete(),
                                                                }, SetOptions(merge: true));

                                                                await FirebaseFirestore.instance.collection(DbPaths.collectionusers).doc(targetUser[Dbkeys.phone]).collection(Dbkeys.chatsWith).doc(Dbkeys.chatsWith).set({
                                                                  widget.currentUserNo!: FieldValue.delete(),
                                                                }, SetOptions(merge: true));
                                                              }).then((value) {});
                                                            } else {
                                                              Fiberchat.toast('Error Occured. Could not delete !');
                                                            }
                                                          });
                                                      setState(() {});
                                                    },
                                                    child: Icon(
                                                      Icons.explore_rounded,
                                                      size: 48,
                                                    ),
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
                                                                builder: (context) => AllNotifications(
                                                                      prefs: widget.prefs,
                                                                    )));
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
                                                            builder: (context) => RecentChats(
                                                              prefs: widget.prefs,
                                                              currentUserNo: widget.currentUserNo,
                                                              doc: widget.doc,
                                                              isSecuritySetupDone: true,
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

    super.build(context);

    final observer = Provider.of<Observer>(context, listen: true);

    return isNotAllowEmulator == true
        ? errorScreen('Emulator Not Allowed.', ' Please use any real device & Try again.')
        : accountstatus != null
            ? errorScreen(accountstatus, accountactionmessage)
            : ConnectWithAdminApp == true && maintainanceMessage != null
                ? errorScreen('App Under maintainance', maintainanceMessage)
                : ConnectWithAdminApp == true && isFetching == true
                    ? Splashscreen(
                        isShowOnlySpinner: widget.isShowOnlyCircularSpin,
                      )
                    : PickupLayout(
                        prefs: widget.prefs,
                        scaffold: Fiberchat.getNTPWrappedWidget(WillPopScope(
                          onWillPop: onWillPop,
                          child: Scaffold(
                              backgroundColor: Thm.isDarktheme(widget.prefs) ? storychatBACKGROUNDcolorDarkMode : storychatBACKGROUNDcolorLightMode,
                              appBar: AppBar(
                                  elevation: 0.4,
                                  backgroundColor: Thm.isDarktheme(widget.prefs) ? storychatAPPBARcolorDarkMode : storychatAPPBARcolorLightMode,
                                  title: IsShowAppLogoInHomepage == false
                                      ? Text(
                                          Appname,
                                          style: TextStyle(color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatAPPBARcolorDarkMode : storychatAPPBARcolorLightMode), fontSize: 20.0, fontFamily: FONTFAMILY_NAME_ONLY_LOGO == '' ? null : FONTFAMILY_NAME_ONLY_LOGO),
                                        )
                                      : Align(
                                          alignment: Alignment.centerLeft,
                                          child: Image.asset(
                                              !Thm.isDarktheme(widget.prefs)
                                                  ? isDarkColor(storychatAPPBARcolorLightMode)
                                                      ? AppLogoPathDarkModeLogo
                                                      : AppLogoPathLightModeLogo
                                                  : AppLogoPathDarkModeLogo,
                                              height: 80,
                                              width: 140,
                                              fit: BoxFit.fitHeight),
                                        ),
                                  titleSpacing: IsShowAppLogoInHomepage ? 10 : 17,
                                  actions: <Widget>[
                                    //
                                    if (IsShowLanguageChangeButtonInSettings == false)
                                      Language.languageList().length < 2 || IsShowLanguageChangeButtonInLoginAndHome == false
                                          ? SizedBox()
                                          : InkWell(
                                              onTap: () {
                                                showDynamicModalBottomSheet(
                                                    isdark: Thm.isDarktheme(widget.prefs),
                                                    context: context,
                                                    widgetList: Language.languageList()
                                                        .map(
                                                          (e) => InkWell(
                                                            onTap: () {
                                                              Navigator.of(context).pop();
                                                              _changeLanguage(e);
                                                            },
                                                            child: Container(
                                                              margin: EdgeInsets.all(14),
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: <Widget>[
                                                                  Text(
                                                                    IsShowLanguageNameInNativeLanguage == true ? e.flag + ' ' + '    ' + e.name : e.flag + ' ' + '    ' + e.languageNameInEnglish,
                                                                    style: TextStyle(color: Thm.isDarktheme(widget.prefs) ? storychatWhite : storychatBlack, fontWeight: FontWeight.w500, fontSize: 16),
                                                                  ),
                                                                  Language.languageList().length < 2
                                                                      ? SizedBox()
                                                                      : Icon(
                                                                          Icons.done,
                                                                          color: e.languageCode == widget.prefs.getString(LAGUAGE_CODE) ? storychatSECONDARYolor : Colors.transparent,
                                                                        )
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    title: "");
                                              },
                                              child: Container(
                                                width: 60,
                                                height: 30,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.language_outlined,
                                                      color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatAPPBARcolorDarkMode : storychatAPPBARcolorLightMode),
                                                      size: 22,
                                                    ),
                                                    SizedBox(
                                                      width: 5,
                                                    ),
                                                    Icon(
                                                      Icons.keyboard_arrow_down,
                                                      color: Thm.isDarktheme(widget.prefs)
                                                          ? storychatSECONDARYolor
                                                          : isDarkColor(storychatBACKGROUNDcolorLightMode) == true
                                                              ? storychatWhite.withOpacity(0.6)
                                                              : pickTextColorBasedOnBgColorAdvanced(storychatAPPBARcolorLightMode).withOpacity(0.65),
                                                      size: 27,
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
// // //---- All localizations settings----
                                    PopupMenuButton(
                                        padding: EdgeInsets.all(0),
                                        icon: Padding(
                                          padding: const EdgeInsets.only(right: 1),
                                          child: Icon(
                                            Icons.more_vert_outlined,
                                            color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatAPPBARcolorDarkMode : storychatAPPBARcolorLightMode),
                                          ),
                                        ),
                                        color: Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode,
                                        onSelected: (dynamic val) async {
                                          switch (val) {
                                            case 'rate':
                                              break;
                                            case 'tutorials':
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return SimpleDialog(
                                                      backgroundColor: Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode,
                                                      contentPadding: EdgeInsets.all(20),
                                                      children: <Widget>[
                                                        ListTile(
                                                          title: Text(
                                                            getTranslated(context, 'swipeview'),
                                                            style: TextStyle(
                                                              color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        ListTile(
                                                            title: Text(
                                                          getTranslated(context, 'swipehide'),
                                                          style: TextStyle(
                                                            color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                                                          ),
                                                        )),
                                                        SizedBox(
                                                          height: 10,
                                                        ),
                                                        ListTile(
                                                            title: Text(
                                                          getTranslated(context, 'lp_setalias'),
                                                          style: TextStyle(
                                                            color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                                                          ),
                                                        ))
                                                      ],
                                                    );
                                                  });
                                              break;
                                            case 'privacy':
                                              break;
                                            case 'tnc':
                                              break;
                                            case 'share':
                                              break;
                                            case 'notifications':
                                              Navigator.push(
                                                  context,
                                                  new MaterialPageRoute(
                                                      builder: (context) => AllNotifications(
                                                            prefs: widget.prefs,
                                                          )));

                                              break;
                                            case 'feedback':
                                              break;
                                            case 'logout':
                                              break;
                                            case 'settings':
                                              Navigator.push(
                                                  context,
                                                  new MaterialPageRoute(
                                                      builder: (context) => SettingsOption(
                                                            prefs: widget.prefs,
                                                            onTapLogout: () async {
                                                              await logout(context);
                                                            },
                                                            onTapEditProfile: () {
                                                              Navigator.push(
                                                                  context,
                                                                  new MaterialPageRoute(
                                                                      builder: (context) => ProfileSetting(
                                                                            prefs: widget.prefs,
                                                                            biometricEnabled: biometricEnabled,
                                                                            type: Fiberchat.getAuthenticationType(biometricEnabled, _cachedModel),
                                                                          )));
                                                            },
                                                            currentUserNo: widget.currentUserNo!,
                                                            biometricEnabled: biometricEnabled,
                                                            type: Fiberchat.getAuthenticationType(biometricEnabled, _cachedModel),
                                                          )));

                                              break;
                                            case 'group':
                                              if (observer.isAllowCreatingGroups == false) {
                                                Fiberchat.showRationale(getTranslated(this.context, 'disabled'));
                                              } else {
                                                final SmartContactProviderWithLocalStoreData dbcontactsProvider = Provider.of<SmartContactProviderWithLocalStoreData>(context, listen: false);
                                                dbcontactsProvider.fetchContacts(context, _cachedModel, widget.currentUserNo!, widget.prefs, false);
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) => AddContactsToGroup(
                                                              currentUserNo: widget.currentUserNo,
                                                              model: _cachedModel,
                                                              biometricEnabled: false,
                                                              prefs: widget.prefs,
                                                              isAddingWhileCreatingGroup: true,
                                                            )));
                                              }
                                              break;

                                            case 'broadcast':
                                              if (observer.isAllowCreatingBroadcasts == false) {
                                                Fiberchat.showRationale(getTranslated(this.context, 'disabled'));
                                              } else {
                                                final SmartContactProviderWithLocalStoreData dbcontactsProvider = Provider.of<SmartContactProviderWithLocalStoreData>(context, listen: false);
                                                dbcontactsProvider.fetchContacts(context, _cachedModel, widget.currentUserNo!, widget.prefs, false);
                                                await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) => AddContactsToBroadcast(
                                                              currentUserNo: widget.currentUserNo,
                                                              model: _cachedModel,
                                                              biometricEnabled: false,
                                                              prefs: widget.prefs,
                                                              isAddingWhileCreatingBroadcast: true,
                                                            )));
                                              }
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) => <PopupMenuItem<String>>[
                                              PopupMenuItem<String>(
                                                  value: 'group',
                                                  child: Text(
                                                    getTranslated(context, 'newgroup'),
                                                    style: TextStyle(
                                                      color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                                                    ),
                                                  )),
                                              PopupMenuItem<String>(
                                                  value: 'broadcast',
                                                  child: Text(
                                                    getTranslated(context, 'newbroadcast'),
                                                    style: TextStyle(
                                                      color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                                                    ),
                                                  )),
                                              PopupMenuItem<String>(
                                                value: 'tutorials',
                                                child: Text(
                                                  getTranslated(context, 'tutorials'),
                                                  style: TextStyle(
                                                    color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                                                  ),
                                                ),
                                              ),
                                              PopupMenuItem<String>(
                                                  value: 'settings',
                                                  child: Text(
                                                    getTranslated(context, 'settingsoption'),
                                                    style: TextStyle(
                                                      color: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatDIALOGColorDarkMode : storychatDIALOGColorLightMode),
                                                    ),
                                                  )),
                                            ]),
                                  ],
                                  bottom: TabBar(
                                    isScrollable: IsAdaptiveWidthTab == true
                                        ? true
                                        : DEFAULT_LANGUAGE_FILE_CODE == "en" && (widget.prefs.getString(LAGUAGE_CODE) == null || widget.prefs.getString(LAGUAGE_CODE) == "en")
                                            ? false
                                            : widget.prefs.getString(LAGUAGE_CODE) == 'pt' || widget.prefs.getString(LAGUAGE_CODE) == 'my' || widget.prefs.getString(LAGUAGE_CODE) == 'nl' || widget.prefs.getString(LAGUAGE_CODE) == 'vi' || widget.prefs.getString(LAGUAGE_CODE) == 'tr' || widget.prefs.getString(LAGUAGE_CODE) == 'id' || widget.prefs.getString(LAGUAGE_CODE) == 'ka' || widget.prefs.getString(LAGUAGE_CODE) == 'fr' || widget.prefs.getString(LAGUAGE_CODE) == 'es'
                                                ? true
                                                : false,
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: FONTFAMILY_NAME == '' ? null : FONTFAMILY_NAME,
                                    ),
                                    unselectedLabelStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: FONTFAMILY_NAME == '' ? null : FONTFAMILY_NAME,
                                    ),
                                    labelColor: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatAPPBARcolorDarkMode : storychatAPPBARcolorLightMode),
                                    unselectedLabelColor: pickTextColorBasedOnBgColorAdvanced(Thm.isDarktheme(widget.prefs) ? storychatAPPBARcolorDarkMode : storychatAPPBARcolorLightMode).withOpacity(0.6),
                                    indicatorWeight: 3,
                                    indicatorColor: Thm.isDarktheme(widget.prefs)
                                        ? storychatSECONDARYolor
                                        : storychatAPPBARcolorLightMode == Colors.white
                                            ? storychatSECONDARYolor
                                            : storychatWhite,
                                    controller: observer.isCallFeatureTotallyHide == false ? controllerIfcallallowed : controllerIfcallNotallowed,
                                    tabs: observer.isCallFeatureTotallyHide == false
                                        ? (IsShowSearchTab
                                                ? <Widget>[
                                                    Tab(
                                                      icon: Icon(
                                                        Icons.search,
                                                        size: 22,
                                                      ),
                                                    ),
                                                  ]
                                                : <Widget>[]) +
                                            <Widget>[
                                              Tab(
                                                child: Text(
                                                  getTranslated(context, 'chats'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: FONTFAMILY_NAME == '' ? null : FONTFAMILY_NAME,
                                                  ),
                                                ),
                                              ),
                                              Tab(
                                                child: Text(
                                                  getTranslated(context, 'status'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: FONTFAMILY_NAME == '' ? null : FONTFAMILY_NAME,
                                                  ),
                                                ),
                                              ),
                                              Tab(
                                                child: Text(
                                                  getTranslated(context, 'calls'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: FONTFAMILY_NAME == '' ? null : FONTFAMILY_NAME,
                                                  ),
                                                ),
                                              ),
                                            ]
                                        : (IsShowSearchTab
                                                ? <Widget>[
                                                    Tab(
                                                      icon: Icon(
                                                        Icons.search,
                                                        size: 22,
                                                      ),
                                                    ),
                                                  ]
                                                : <Widget>[]) +
                                            <Widget>[
                                              Tab(
                                                child: Text(
                                                  getTranslated(context, 'chats'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: FONTFAMILY_NAME == '' ? null : FONTFAMILY_NAME,
                                                  ),
                                                ),
                                              ),
                                              Tab(
                                                child: Text(
                                                  getTranslated(context, 'status'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: FONTFAMILY_NAME == '' ? null : FONTFAMILY_NAME,
                                                  ),
                                                ),
                                              ),
                                            ],
                                  )),
                              body: TabBarView(
                                controller: observer.isCallFeatureTotallyHide == false ? controllerIfcallallowed : controllerIfcallNotallowed,
                                children: observer.isCallFeatureTotallyHide == false
                                    ? (IsShowSearchTab
                                            ? <Widget>[
                                                SearchChats(prefs: widget.prefs, currentUserNo: widget.currentUserNo, isSecuritySetupDone: false),
                                              ]
                                            : <Widget>[]) +
                                        <Widget>[
                                          IsShowLastMessageInChatTileWithTime == false ? RecentChatsWithoutLastMessage(prefs: widget.prefs, currentUserNo: widget.currentUserNo, isSecuritySetupDone: false) : RecentChats(prefs: widget.prefs, currentUserNo: widget.currentUserNo, isSecuritySetupDone: false, doc: widget.doc),
                                          Status(currentUserFullname: userFullname, currentUserPhotourl: userPhotourl, phoneNumberVariants: this.phoneNumberVariants, currentUserNo: widget.currentUserNo, model: _cachedModel, biometricEnabled: biometricEnabled, prefs: widget.prefs),
                                          CallHistory(
                                            model: _cachedModel,
                                            userphone: widget.currentUserNo,
                                            prefs: widget.prefs,
                                          ),
                                        ]
                                    : (IsShowSearchTab
                                            ? <Widget>[
                                                SearchChats(prefs: widget.prefs, currentUserNo: widget.currentUserNo, isSecuritySetupDone: false),
                                              ]
                                            : <Widget>[]) +
                                        <Widget>[
                                          IsShowLastMessageInChatTileWithTime == false ? RecentChatsWithoutLastMessage(prefs: widget.prefs, currentUserNo: widget.currentUserNo, isSecuritySetupDone: false) : RecentChats(prefs: widget.prefs, currentUserNo: widget.currentUserNo, isSecuritySetupDone: false, doc: widget.doc),
                                          Status(currentUserFullname: userFullname, currentUserPhotourl: userPhotourl, phoneNumberVariants: this.phoneNumberVariants, currentUserNo: widget.currentUserNo, model: _cachedModel, biometricEnabled: biometricEnabled, prefs: widget.prefs),
                                        ],
                              )),
                        )));
  }
}

// Future<dynamic> myBackgroundMessageHandlerIos(RemoteMessage message) async {
//   await Firebase.initializeApp();

//   if (message.data['title'] == 'Call Ended') {
//     final data = message.data;

//     final titleMultilang = data['titleMultilang'];
//     final bodyMultilang = data['bodyMultilang'];
//     flutterLocalNotificationsPlugin..cancelAll();
//     await showNotificationWithDefaultSound(
//         'Missed Call', 'You have Missed a Call', titleMultilang, bodyMultilang);
//   } else {
//     if (message.data['title'] == 'You have new message(s)') {
//     } else if (message.data['title'] == 'Incoming Audio Call...' ||
//         message.data['title'] == 'Incoming Video Call...') {
//       final data = message.data;
//       final title = data['title'];
//       final body = data['body'];
//       final titleMultilang = data['titleMultilang'];
//       final bodyMultilang = data['bodyMultilang'];
//       await showNotificationWithDefaultSound(
//           title, body, titleMultilang, bodyMultilang);
//     }
//   }

//   return Future<void>.value();
// }

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future showNotificationWithDefaultSound(String? title, String? message, String? titleMultilang, String? bodyMultilang) async {
  if (Platform.isAndroid) {
    flutterLocalNotificationsPlugin.cancelAll();
  }

  var initializationSettingsAndroid = new AndroidInitializationSettings('@mipmap/ic_launcher');
  var initializationSettingsIOS = DarwinInitializationSettings();
  var initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  flutterLocalNotificationsPlugin.initialize(initializationSettings);
  var androidPlatformChannelSpecifics = title == 'Missed Call' || title == 'Call Ended'
      ? local.AndroidNotificationDetails('channel_id', 'channel_name', importance: local.Importance.max, priority: local.Priority.high, sound: RawResourceAndroidNotificationSound('whistle2'), playSound: true, ongoing: true, visibility: NotificationVisibility.public, timeoutAfter: 28000)
      : local.AndroidNotificationDetails('channel_id', 'channel_name', sound: RawResourceAndroidNotificationSound('ringtone'), playSound: true, ongoing: true, importance: local.Importance.max, priority: local.Priority.high, visibility: NotificationVisibility.public, timeoutAfter: 28000);
  var iOSPlatformChannelSpecifics = local.DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    sound: title == 'Missed Call' || title == 'Call Ended' ? '' : 'ringtone.caf',
    presentSound: true,
  );
  var platformChannelSpecifics = local.NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin
      .show(
    0,
    '$titleMultilang',
    '$bodyMultilang',
    platformChannelSpecifics,
    payload: 'payload',
  )
      .catchError((err) {
    debugPrint('ERROR DISPLAYING NOTIFICATION: $err');
  });
}

Widget errorScreen(String? title, String? subtitle) {
  return Scaffold(
    backgroundColor: storychatPRIMARYcolor,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_outlined,
              size: 60,
              color: Colors.yellowAccent,
            ),
            SizedBox(
              height: 30,
            ),
            Text(
              '$title',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: storychatWhite, fontWeight: FontWeight.w700),
            ),
            SizedBox(
              height: 20,
            ),
            Text(
              '$subtitle',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: storychatWhite.withOpacity(0.7), fontWeight: FontWeight.w400),
            )
          ],
        ),
      ),
    ),
  );
}
