//*************   © Copyrighted by Thinkcreative_Technologies. An Exclusive item of Envato market. Make sure you have purchased a Regular License OR Extended license for the Source Code from Envato to use this product. See the License Defination attached with source code. *********************

import 'dart:io';
import '/Configs/app_constants.dart';
import '/Screens/status/components/VideoPicker/VideoPicker.dart';
import '/Services/Providers/Observer.dart';
import '/Services/localization/language_constants.dart';
import '/Utils/color_detector.dart';
import '/Utils/open_settings.dart';
import '/Utils/theme_management.dart';
import '/Utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class HybridVideoPicker extends StatefulWidget {
  final String title;
  final Function callback;
  final SharedPreferences prefs;
  HybridVideoPicker(
      {required this.callback, required this.title, required this.prefs});
  @override
  _HybridVideoPickerState createState() => _HybridVideoPickerState();
}

class _HybridVideoPickerState extends State<HybridVideoPicker> {
  // File _image;
  // File _cameraImage;
  File? _video;
  // File _video;
  String? error;

  ImagePicker picker = ImagePicker();

  late VideoPlayerController _videoPlayerController;

  // This funcion will helps you to pick a Video File
  _pickVideo() async {
    final observer = Provider.of<Observer>(this.context, listen: false);
    error = null;
    XFile? pickedFile = await (picker.pickVideo(source: ImageSource.gallery));

    _video = File(pickedFile!.path);

    if (_video!.lengthSync() / 1000000 > observer.maxFileSizeAllowedInMB) {
      error =
          '${getTranslated(this.context, 'maxfilesize')} ${observer.maxFileSizeAllowedInMB}MB\n\n${getTranslated(this.context, 'selectedfilesize')} ${(_video!.lengthSync() / 1000000).round()}MB';

      setState(() {
        _video = null;
      });
    } else {
      setState(() {});
      _videoPlayerController = VideoPlayerController.file(_video!)
        ..initialize().then((_) {
          setState(() {});
          _videoPlayerController.play();
        });
    }
  }

  // This funcion will helps you to pick a Video File from Camera
  _pickVideoFromCamera() async {
    final observer = Provider.of<Observer>(this.context, listen: false);
    error = null;
    XFile? pickedFile = await (picker.pickVideo(source: ImageSource.camera));

    _video = File(pickedFile!.path);

    if (_video!.lengthSync() / 1000000 > observer.maxFileSizeAllowedInMB) {
      error =
          '${getTranslated(this.context, 'maxfilesize')} ${observer.maxFileSizeAllowedInMB}MB\n\n${getTranslated(this.context, 'selectedfilesize')} ${(_video!.lengthSync() / 1000000).round()}MB';

      setState(() {
        _video = null;
      });
    } else {
      setState(() {});
      _videoPlayerController = VideoPlayerController.file(_video!)
        ..initialize().then((_) {
          setState(() {});
          _videoPlayerController.play();
        });
    }
  }

  _buildVideo(BuildContext context) {
    if (_video != null) {
      return _videoPlayerController.value.isInitialized
          ? AspectRatio(
              aspectRatio: _videoPlayerController.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController),
            )
          : Container();
    } else {
      return new Text(getTranslated(context, 'takefile'),
          style: new TextStyle(
            fontSize: 18.0,
            color: storychatGrey,
          ));
    }
  }

  Widget _buildButtons() {
    return new ConstrainedBox(
        constraints: BoxConstraints.expand(height: 80.0),
        child: new Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildActionButton(new Key('retake'), Icons.video_library_rounded,
                  () {
                Fiberchat.checkAndRequestPermission(Platform.isIOS
                        ? Permission.mediaLibrary
                        : Permission.storage)
                    .then((res) {
                  if (res) {
                    _pickVideo();
                  } else {
                    Fiberchat.showRationale(
                      getTranslated(context, 'pgv'),
                    );
                    Navigator.pushReplacement(
                        context,
                        new MaterialPageRoute(
                            builder: (context) => OpenSettings(
                                  prefs: widget.prefs,
                                )));
                  }
                });
              }),
              _buildActionButton(new Key('upload'), Icons.photo_camera, () {
                Fiberchat.checkAndRequestPermission(Permission.camera)
                    .then((res) {
                  if (res) {
                    _pickVideoFromCamera();
                  } else {
                    Fiberchat.showRationale(
                      getTranslated(context, 'pcv'),
                    );
                    Navigator.pushReplacement(
                        context,
                        new MaterialPageRoute(
                            builder: (context) => OpenSettings(
                                  prefs: widget.prefs,
                                )));
                  }
                });
              }),
            ]));
  }

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Thm.isDarktheme(widget.prefs)
          ? storychatBACKGROUNDcolorDarkMode
          : storychatBACKGROUNDcolorLightMode,
      appBar: AppBar(
        elevation: 0.4,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.keyboard_arrow_left,
            size: 30,
            color: pickTextColorBasedOnBgColorAdvanced(
                Thm.isDarktheme(widget.prefs)
                    ? storychatAPPBARcolorDarkMode
                    : storychatAPPBARcolorLightMode),
          ),
        ),
        backgroundColor: Thm.isDarktheme(widget.prefs)
            ? storychatAPPBARcolorDarkMode
            : storychatAPPBARcolorLightMode,
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 18,
            color: pickTextColorBasedOnBgColorAdvanced(
                Thm.isDarktheme(widget.prefs)
                    ? storychatAPPBARcolorDarkMode
                    : storychatAPPBARcolorLightMode),
          ),
        ),
        actions: _video != null
            ? <Widget>[
                IconButton(
                    icon: Icon(
                      Icons.check,
                      color: pickTextColorBasedOnBgColorAdvanced(
                          Thm.isDarktheme(widget.prefs)
                              ? storychatAPPBARcolorDarkMode
                              : storychatAPPBARcolorLightMode),
                    ),
                    onPressed: () {
                      _videoPlayerController.pause();

                      setState(() {
                        isLoading = true;
                      });

                      widget.callback(_video).then((videoUrl) {
                        Navigator.pop(context, videoUrl);
                      });
                    }),
                SizedBox(
                  width: 8.0,
                )
              ]
            : [],
      ),
      body: Stack(children: [
        new Column(children: [
          new Expanded(
              child: new Center(
                  child: error != null
                      ? fileSizeErrorWidget(error!)
                      : _buildVideo(context))),
          _buildButtons()
        ]),
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
                      .withOpacity(0.6),
                )
              : Container(),
        )
      ]),
    );
  }

  Widget _buildActionButton(Key key, IconData icon, Function onPressed) {
    return new Expanded(
      // ignore: deprecated_member_use
      child: new IconButton(
          key: key,
          icon: Icon(icon, size: 30.0),
          color: Thm.isDarktheme(widget.prefs)
              ? storychatAPPBARcolorDarkMode
              : storychatAPPBARcolorLightMode,
          onPressed: onPressed as void Function()?),
    );
  }
}
