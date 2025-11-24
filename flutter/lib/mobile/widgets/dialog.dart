import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/common/widgets/toolbar.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

void _showSuccess() {
  showToast(translate("Successful"));
}

void _showError() {
  showToast(translate("Error"));
}

void setPermanentPasswordDialog(OverlayDialogManager dialogManager) async {
  final pw = await bind.mainGetPermanentPassword();
  final p0 = TextEditingController(text: pw);
  final p1 = TextEditingController(text: pw);
  var validateLength = false;
  var validateSame = false;
  dialogManager.show((setState, close, context) {
    submit() async {
      close();
      dialogManager.showLoading(translate("Waiting"));
      if (await gFFI.serverModel.setPermanentPassword(p0.text)) {
        dialogManager.dismissAll();
        _showSuccess();
      } else {
        dialogManager.dismissAll();
        _showError();
      }
    }

    return CustomAlertDialog(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.password_rounded, color: MyTheme.accent),
          Text(translate('Set your own password')).paddingOnly(left: 10),
        ],
      ),
      content: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: translate('Password'),
              ),
              controller: p0,
              validator: (v) {
                if (v == null) return null;
                final val = v.trim().length > 5;
                if (validateLength != val) {
                  // use delay to make setState success
                  Future.delayed(Duration(microseconds: 1),
                      () => setState(() => validateLength = val));
                }
                return val
                    ? null
                    : translate('Too short, at least 6 characters.');
              },
            ).workaroundFreezeLinuxMint(),
            TextFormField(
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: translate('Confirmation'),
              ),
              controller: p1,
              validator: (v) {
                if (v == null) return null;
                final val = p0.text == v;
                if (validateSame != val) {
                  Future.delayed(Duration(microseconds: 1),
                      () => setState(() => validateSame = val));
                }
                return val
                    ? null
                    : translate('The confirmation is not identical.');
              },
            ).workaroundFreezeLinuxMint(),
          ])),
      onCancel: close,
      onSubmit: (validateLength && validateSame) ? submit : null,
      actions: [
        dialogButton(
          'Cancel',
          icon: Icon(Icons.close_rounded),
          onPressed: close,
          isOutline: true,
        ),
        dialogButton(
          'OK',
          icon: Icon(Icons.done_rounded),
          onPressed: (validateLength && validateSame) ? submit : null,
        ),
      ],
    );
  });
}

void setTemporaryPasswordLengthDialog(
    OverlayDialogManager dialogManager) async {
  List<String> lengths = ['6', '8', '10'];
  String length = await bind.mainGetOption(key: "temporary-password-length");
  var index = lengths.indexOf(length);
  if (index < 0) index = 0;
  length = lengths[index];
  dialogManager.show((setState, close, context) {
    setLength(newValue) {
      final oldValue = length;
      if (oldValue == newValue) return;
      setState(() {
        length = newValue;
      });
      bind.mainSetOption(key: "temporary-password-length", value: newValue);
      bind.mainUpdateTemporaryPassword();
      Future.delayed(Duration(milliseconds: 200), () {
        close();
        _showSuccess();
      });
    }

    return CustomAlertDialog(
      title: Text(translate("Set one-time password length")),
      content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: lengths
              .map(
                (value) => Row(
                  children: [
                    Text(value),
                    Radio(
                        value: value, groupValue: length, onChanged: setLength),
                  ],
                ),
              )
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showServerSettings(OverlayDialogManager dialogManager,
    void Function(VoidCallback) setState) async {
  Map<String, dynamic> options = {};
  try {
    options = jsonDecode(await bind.mainGetOptions());
  } catch (e) {
    print("Invalid server config: $e");
  }
  showServerSettingsWithValue(
      ServerConfig.fromOptions(options), dialogManager, setState);
}

void showServerSettingsWithValue(
    ServerConfig serverConfig,
    OverlayDialogManager dialogManager,
    void Function(VoidCallback)? upSetState) async {
  var isInProgress = false;
  final idCtrl = TextEditingController(text: serverConfig.idServer);
  final relayCtrl = TextEditingController(text: serverConfig.relayServer);
  final apiCtrl = TextEditingController(text: serverConfig.apiServer);
  final keyCtrl = TextEditingController(text: serverConfig.key);

  RxString idServerMsg = ''.obs;
  RxString relayServerMsg = ''.obs;
  RxString apiServerMsg = ''.obs;

//// Addition Starts
  String connectionType = await bind.mainGetOption(key: "connection-type");

  var selectedConfig = serverConfig;
  var externalIdServer = bind.mainGetOptionSync(key: "external-id-server");
  var externalRelayServer = bind.mainGetOptionSync(key: "external-relay-server");
  var externalApiServer = bind.mainGetOptionSync(key: "external-api-server");
  var externalKey = bind.mainGetOptionSync(key: "external-key");
  ServerConfig external = ServerConfig(idServer: externalIdServer, relayServer: externalRelayServer, apiServer: externalApiServer, key: externalKey);



  var internalIdServer = bind.mainGetOptionSync(key: "internal-id-server");
  var internalRelayServer = bind.mainGetOptionSync(key: "internal-relay-server");
  var internalApiServer = bind.mainGetOptionSync(key: "internal-api-server");
  var internalKey = bind.mainGetOptionSync(key: "internal-key");
  ServerConfig internal = ServerConfig(idServer: internalIdServer, relayServer: internalRelayServer, apiServer:internalApiServer, key: internalKey);
//// Addition Ends

  final controllers = [idCtrl, relayCtrl, apiCtrl, keyCtrl];
  final errMsgs = [
    idServerMsg,
    relayServerMsg,
    apiServerMsg,
  ];

  dialogManager.show((setState, close, context) {
    Future<bool> submit() async {
      setState(() {
        isInProgress = true;
      });
      if (connectionType == "custom"){
        selectedConfig = ServerConfig(
              idServer: idCtrl.text.trim(),
              relayServer: relayCtrl.text.trim(),
              apiServer: apiCtrl.text.trim(),
              key: keyCtrl.text.trim());
      }
      bind.mainSetOption(key: "connection-type", value: connectionType);
      bool ret = await setServerConfig(
          null,
          errMsgs,
          selectedConfig);
      setState(() {
        isInProgress = false;
      });
      return ret;
    }

    Widget buildField(
        String label, TextEditingController controller, String errorMsg,
        {String? Function(String?)? validator, bool autofocus = false}) {
      if (isDesktop || isWeb) {
        return Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                enabled: connectionType == "custom",
                controller: controller,
                decoration: InputDecoration(
                  errorText: errorMsg.isEmpty ? null : errorMsg,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                validator: validator,
                autofocus: autofocus,
              ).workaroundFreezeLinuxMint(),
            ),
          ],
        );
      }

      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorMsg.isEmpty ? null : errorMsg,
        ),
        validator: validator,
      ).workaroundFreezeLinuxMint();
    }

    void updateController() {
        idCtrl.text = selectedConfig.idServer;
        relayCtrl.text = selectedConfig.relayServer;
        apiCtrl.text = selectedConfig.apiServer;
        keyCtrl.text = selectedConfig.key;
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(translate('ID/Relay Server'))),
          // ...ServerConfigImportExportWidgets(controllers, errMsgs), // taken out temporarily for ui 
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Form(
          child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildField(translate('ID Server'), idCtrl, idServerMsg.value,
                      autofocus: true),
                  SizedBox(height: 8),
                  if (!isIOS && !isWeb) ...[
                    buildField(translate('Relay Server'), relayCtrl,
                        relayServerMsg.value,
                        ),
                    SizedBox(height: 8),
                  ],
                  buildField(
                    translate('API Server'),
                    apiCtrl,
                    apiServerMsg.value,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (!(v.startsWith('http://') ||
                            v.startsWith("https://"))) {
                          return translate("invalid_http");
                        }
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  buildField('Key', keyCtrl, ''),

                ////// Addition starts
                
                  SizedBox(height: 16),
                  Align( 
                    alignment: Alignment.centerLeft, 
                    child: Text("Connected Server Type")
                  ),
                  SizedBox(height: 8),
                  ListTile(
                      title: const Text('Internal'),
                      enabled: false,
                      leading: Radio<String>(
                        value: "internal",
                        groupValue: connectionType,
                        onChanged: bind.mainGetOptionSync(key: "internal-id-server") != "" ? (String? value) {
                          setState(() {
                            connectionType = value!;
                            if (value == "internal") {
                              selectedConfig = internal;
                              updateController();
                            }
                          });
                        } : null ,
                      ),
                    ),
                    ListTile(
                      title: const Text('External'),
                      enabled: false,
                      leading: Radio<String>(
                        value: "external",
                        groupValue: connectionType,
                        onChanged: (String? value) {
                          setState(() {
                            connectionType = value!;
                            if (value == "external") {
                              selectedConfig = external;
                              updateController();
                            }
                          });
                        },
                      ),
                    ), 
                    ListTile(
                      title: const Text('Custom'),

                      leading: Radio<String>(
                        value: "custom",
                        groupValue: connectionType,
                        onChanged: (String? value) {
                          setState(() {

                            connectionType = value!;
                            if (bind.mainGetOptionSync(key: "connection-type") == "custom") {
                              // Do nothing if already custom
                              idCtrl.text = bind.mainGetOptionSync(key: "custom-rendezvous-server");
                              relayCtrl.text = bind.mainGetOptionSync(key: "relay-server");
                              apiCtrl.text = bind.mainGetOptionSync(key: "api-server");
                              keyCtrl.text = bind.mainGetOptionSync(key: "key");
                              return;
                            }

                            
                            if (value == "custom") {
                              // Clear all text fields
                              idCtrl.clear();
                              relayCtrl.clear();
                              apiCtrl.clear();
                              keyCtrl.clear();
                            }
                          });
                        },
                      ),
                    ), 
                ////// Addition ends

                  if (isInProgress)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              )),
        ),
      ),
      actions: [
        dialogButton('Cancel', onPressed: () {
          close();
        }, isOutline: true),
        dialogButton(
          'OK',
          onPressed: () async {
            if (await submit()) {
              close();
              showToast(translate('Successful'));
              upSetState?.call(() {});
            } else {
              showToast(translate('Failed'));
            }
          },
        ),
      ],
    );
  });
}

void setPrivacyModeDialog(
  OverlayDialogManager dialogManager,
  List<TToggleMenu> privacyModeList,
  RxString privacyModeState,
) async {
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('Privacy mode')),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: privacyModeList
              .map((value) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: value.child,
                    value: value.value,
                    onChanged: value.onChanged,
                  ))
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}
