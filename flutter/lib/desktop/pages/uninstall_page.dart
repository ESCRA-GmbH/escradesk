import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

class UninstallPage extends StatefulWidget {
  const UninstallPage({Key? key}) : super(key: key);

  @override
  State<UninstallPage> createState() => _UninstallPageState();
}

class _UninstallPageState extends State<UninstallPage> {
  final tabController = DesktopTabController(tabType: DesktopTabType.main);

  @override
  void initState() {
    super.initState();
    Get.put<DesktopTabController>(tabController);
    const label = "uninstall";
    tabController.add(TabInfo(
        key: label,
        label: label,
        closable: false,
        page: _UninstallPageBody(
          key: const ValueKey(label),
        )));
  }

  @override
  void dispose() {
    super.dispose();
    Get.delete<DesktopTabController>();
  }

  @override
  Widget build(BuildContext context) {
    return DragToResizeArea(
      resizeEdgeSize: stateGlobal.resizeEdgeSize.value,
      child: Container(
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: DesktopTab(controller: tabController)),
      ),
    );
  }
}

class _UninstallPageBody extends StatefulWidget {
  const _UninstallPageBody({Key? key}) : super(key: key);

  @override
  State<_UninstallPageBody> createState() => _UninstallPageBodyState();
}

class _UninstallPageBodyState extends State<_UninstallPageBody>
    with WindowListener {
  late final TextEditingController controller;
  final RxBool startmenu = true.obs;
  final RxBool desktopicon = true.obs;
  final RxBool driverCert = false.obs;
  final RxBool showProgress = false.obs;
  final RxBool btnEnabled = true.obs;
  // @escra adding the remove user data property   
  final RxBool removeUserData = false.obs;
  final RxBool removeCert = false.obs;


  // todo move to theme.
  final buttonStyle = OutlinedButton.styleFrom(
    textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 12),
  );

  @override
  void initState() {
    windowManager.addListener(this);
    controller = TextEditingController(text: bind.installInstallPath()); // @escra here you change the path for installation 
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    gFFI.close();
    super.onWindowClose();
    windowManager.setPreventClose(false);
    windowManager.close();
  }

  InkWell Option(RxBool option, {String label = ''}) {
    return InkWell(
      // todo mouseCursor: "SystemMouseCursors.forbidden" or no cursor on btnEnabled == false
      borderRadius: BorderRadius.circular(6),
      onTap: () => btnEnabled.value ? option.value = !option.value : null,
      child: Row(
        children: [
          Obx(
            () => Checkbox(
              visualDensity: VisualDensity(horizontal: -4, vertical: -4),
              value: option.value,
              onChanged: (v) =>
                  btnEnabled.value ? option.value = !option.value : null,
            ).marginOnly(right: 8),
          ),
          Expanded(
            child: Text(translate(label)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) { //WILL CHANGE HERE -- namely the translate function and the hardcode things
    final double em = 13;
    final isDarkTheme = MyTheme.currentThemeMode() == ThemeMode.dark;
    return Scaffold(
        backgroundColor: null, // CAN LOOK LATER -- namely why here is null? 
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Uninstall EscraDesk",
                  style: Theme.of(context).textTheme.headlineMedium),
              // Row(
              //   children: [
              //     Text("Annnnnneeeeeeeennnnnn")
              //         .marginOnly(right: 10),
              //     Expanded(
              //       child: TextField(
              //         controller: controller,
              //         readOnly: true,
              //         decoration: InputDecoration(
              //           contentPadding: EdgeInsets.all(0.75 * em),
              //         ),
              //       ).marginOnly(right: 10),
              //     ),
              //     Obx(
              //       () => OutlinedButton.icon(
              //         icon: Icon(Icons.folder_outlined, size: 16),
              //         onPressed: btnEnabled.value ? selectInstallPath : null,
              //         style: buttonStyle,
              //         label: Text(translate('Change Path')),
              //       ),
              //     )
              //   ],
              // ).marginSymmetric(vertical: 2 * em),
              Option(removeUserData, label: 'Remove user data')
                  .marginOnly(bottom: 7),
              Option(removeCert, label: 'Remove certificates'),
              // Offstage(
              //   offstage: !Platform.isWindows,
              //   // child: Option(driverCert, label: 'install_cert_tip'), // @escra here I will assume the user data cleaning option comes... 
              //   child: Option(removeUserData, label: 'clear_user_data'),
              // ).marginOnly(top: 7),
              Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? Color.fromARGB(135, 87, 87, 90)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ), // LOGIC MERGE CHANGE BenutzerDaten bereinigen
                  child: Row(
                    children: [
                      Icon(Icons.hail_outlined, size: 32)
                          .marginOnly(right: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Sorry to see you go...")
                              .marginOnly(bottom: em),
                          // InkWell(
                          //   hoverColor: Colors.transparent,
                          //   onTap: () => launchUrlString(
                          //       'https://escra.de'), // @escra changed the privacy link to escra 'https://rustdesk.com/privacy.html'
                          //   child: Tooltip(
                          //     message: 'https://escra.de',
                          //     child: Row(children: [
                          //       Icon(Icons.launch_outlined, size: 16)
                          //           .marginOnly(right: 5),
                          //       Text(
                          //         translate('End-user license agreement'),
                          //         style: const TextStyle(
                          //             decoration: TextDecoration.underline),
                          //       )
                          //     ]),
                          //   ),
                          // ),
                        ],
                      )
                    ],
                  )).marginSymmetric(vertical: 2 * em),
              Row(
                children: [
                  Expanded(
                    // NOT use Offstage to wrap LinearProgressIndicator
                    child: Obx(() => showProgress.value
                        ? LinearProgressIndicator().marginOnly(right: 10)
                        : Offstage()),
                  ),
                  Obx(
                    () => OutlinedButton.icon(
                      icon: Icon(Icons.close_rounded, size: 16),
                      label: Text(translate('Cancel')),
                      onPressed:
                          btnEnabled.value ? () => windowManager.close() : null,
                      style: buttonStyle,
                    ).marginOnly(right: 10),
                  ),
                  Obx(
                    () => ElevatedButton.icon(
                      icon: Icon(Icons.done_rounded, size: 16),
                      label: Text("Uninstall"),
                      onPressed: btnEnabled.value ? uninstall : null,
                      style: buttonStyle,
                    ),
                  ),
                  // Offstage(
                  //   offstage: bind.installShowRunWithoutInstall(),
                  //   child: Obx(
                  //     () => OutlinedButton.icon(
                  //       icon: Icon(Icons.screen_share_outlined, size: 16),
                  //       label: Text(translate('Run without install')),
                  //       onPressed: btnEnabled.value
                  //           ? () => bind.installRunWithoutInstall()
                  //           : null,
                  //       style: buttonStyle,
                  //     ).marginOnly(left: 10),
                  //   ),
                  // ),
                ],
              )
            ],
          ).paddingSymmetric(horizontal: 4 * em, vertical: 3 * em),
        ));
  } 

  void uninstall() {

  }

  // TODO: need to adapt clearing data here. 
  void install() {
    do_install() {
      btnEnabled.value = false;
      showProgress.value = true;
      String args = '';
      if (startmenu.value) args += ' startmenu';
      if (desktopicon.value) args += ' desktopicon';
      // @escra adding a value to clean user data
      if (removeUserData.value) args +=  ' removeuserdata';
      // if (driverCert.value) args += ' driverCert';
      bind.installInstallMe(options: args, path: controller.text);
    }

    if (driverCert.isTrue) {
      final tag = 'install-info-install-cert-confirm';
      final btns = [
        OutlinedButton.icon(
          icon: Icon(Icons.close_rounded, size: 16),
          label: Text(translate('Cancel')),
          onPressed: () => gFFI.dialogManager.dismissByTag(tag),
          style: buttonStyle,
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.done_rounded, size: 16),
          label: Text(translate('OK')),
          onPressed: () {
            gFFI.dialogManager.dismissByTag(tag);
            do_install();
          },
          style: buttonStyle,
        )
      ];
      gFFI.dialogManager.show(
        (setState, close, context) => CustomAlertDialog(
          title: null,
          content: SelectionArea(
              child:
                  msgboxContent('info', 'Warning', 'confirm_install_cert_tip')),
          actions: btns,
          onCancel: close,
        ),
        tag: tag,
      );
    } else {
      do_install();
    }
  }

  void selectInstallPath() async {
    String? install_path = await FilePicker.platform
        .getDirectoryPath(initialDirectory: controller.text);
    if (install_path != null) {
      controller.text = join(install_path, await bind.mainGetAppName());
    }
  }
}
