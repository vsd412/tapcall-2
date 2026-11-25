import 'package:flutter/widgets.dart';

/// Use the phone's language, including regional Chinese variants.
class Words {
  Words(BuildContext context) : locale = Localizations.localeOf(context);
  final Locale locale;

  String pick(String en, String traditional, String simplified) {
    if (locale.languageCode != 'zh') return en;
    return locale.scriptCode == 'Hant' ||
            ['HK', 'MO', 'TW'].contains(locale.countryCode)
        ? traditional
        : simplified;
  }

  String get connectBoard =>
      pick('Connect TapCall board', '連接 TapCall 控制板', '连接 TapCall 控制板');
  String get disconnectBoard => pick('Disconnect board', '中斷控制板連線', '断开控制板连接');
  String get noBoard => pick(
    'No TapCall board found. Power it on and try again.',
    '找不到控制板，請開啟電源後重試。',
    '找不到控制板，请打开电源后重试。',
  );
  String get boardError => pick(
    'Check Bluetooth and Nearby devices permission, then try again.',
    '請檢查藍牙和附近裝置權限後重試。',
    '请检查蓝牙和附近设备权限后重试。',
  );
  String get boardLost => pick(
    'Board disconnected. Reconnect in Manage contacts.',
    '控制板已中斷連線，可在管理聯絡人中重新連接。',
    '控制板已断开，可在管理联系人中重新连接。',
  );
  String get photo => pick('Choose a photo', '選擇相片', '选择照片');
  String get clearPhoto => pick('Remove photo', '移除相片', '移除照片');
  String get people => pick('My people', '我的聯絡人', '我的联系人');
  String get add => pick('Add a person', '新增聯絡人', '添加联系人');
  String get manage => pick('Manage contacts', '管理聯絡人', '管理联系人');
  String get edit => pick('Edit contact', '編輯聯絡人', '编辑联系人');
  String get name => pick('Name', '姓名', '姓名');
  String get phone => pick('WhatsApp number', 'WhatsApp 號碼', 'WhatsApp 号码');
  String get hint => pick(
    'Hong Kong: 8 digits. Elsewhere: include + and the country code.',
    '香港號碼請輸入八位數字。其他地區請加上 + 和國家代碼。',
    '香港号码请输入八位数字。其他地区请加上 + 和国家代码。',
  );
  String get invalid =>
      pick('Check the name and phone number.', '請檢查姓名和電話號碼。', '请检查姓名和电话号码。');
  String get save => pick('Save', '儲存', '保存');
  String get cancel => pick('Cancel', '取消', '取消');
  String get remove => pick('Remove contact', '移除聯絡人', '移除联系人');
  String get video =>
      pick('WhatsApp video call', 'WhatsApp 視像通話', 'WhatsApp 视频通话');
  String get openChat => pick('Open chat', '開啟對話', '打开聊天');
  String get enable => pick('Allow contact lookup', '允許查找聯絡人', '允许查找联系人');
  String get permission => pick(
    'TapCall can look up the video-call shortcut WhatsApp adds to a saved phone contact. You can also open the chat and tap the video button yourself.',
    'TapCall 可在手機聯絡人中查找 WhatsApp 視像通話捷徑。你也可以開啟對話，再按視像通話按鈕。',
    'TapCall 可在手机联系人中查找 WhatsApp 视频通话快捷方式。你也可以打开聊天，再点视频通话按钮。',
  );
  String get manual => pick(
    'No direct video shortcut was found for this number. Open the chat and tap the video camera in WhatsApp.',
    '找不到此號碼的視像通話捷徑。請開啟對話，再按 WhatsApp 的視像通話按鈕。',
    '找不到此号码的视频通话快捷方式。请打开聊天，再点 WhatsApp 的视频通话按钮。',
  );
  String get missing => pick(
    'Install and set up WhatsApp to call this person.',
    '請先安裝及設定 WhatsApp。',
    '请先安装并设置 WhatsApp。',
  );
  String get error =>
      pick('Something went wrong. Please try again.', '操作失敗，請重試。', '操作失败，请重试。');
  String get retry => pick('Try again', '重試', '重试');
  String get empty =>
      pick('Add someone you would like to call.', '加入你想致電的人。', '添加你想呼叫的人。');
}
