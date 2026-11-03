
import 'dart:convert';

import 'linklan_euicc_platform_interface.dart';

import 'dart:async';
import 'linklan_euicc_platform_interface.dart';

/// 设备信息
class BleDevice {
  final String address;
  final String name;
  final String? advName;
  final String model;
  final int rssi;
  final List serviceUuids;

  BleDevice({
    required this.address,
    required this.name,
    required this.advName,
    required this.model,
    required this.rssi,
    required this.serviceUuids,
  });

  factory BleDevice.fromJson(Map<String, dynamic> json) {
    return BleDevice(
      address: json['address'] as String? ?? '',
      name: json['name'] as String? ?? '',
      advName: json['advName'] as String?,
      model: json['model'] as String? ?? '',
      rssi: json['rssi'] as int? ?? 0,
      serviceUuids: json['serviceUuids'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'name': name,
      'advName': advName,
      'model': model,
      'rssi': rssi,
      'serviceUuids': serviceUuids,
    };
  }

  @override
  String toString() => 'BleDevice(address: $address, name: $name,  advName: $advName, model: $model, rssi: $rssi)';
}


/// 设备信息
class EuiccDevice {
  late String eid;
  String? imei;
  String? sn;
  String? name;
  String? advName;
  String? deviceName;
  String? address;
  String? vendor;
  int? freeVolatileMemory;
  int? freeNonVolatileMemory;

  EuiccDevice({
    required this.eid,
    this.imei,
    this.sn,
    this.name,
    this.advName,
    this.deviceName,
    this.address,
    this.vendor,
    this.freeVolatileMemory,
    this.freeNonVolatileMemory,
  });

  factory EuiccDevice.fromJson(Map<String, dynamic> json) {
    return EuiccDevice(
      eid: json['eid'] as String? ?? '',
      imei: json['imei'],
      sn: json['sn'],
      name: json['name'],
      advName: json['advName'],
      deviceName: json['deviceName'],
      address: json['address'],
      vendor: json['vendor'],
      freeVolatileMemory: json['freeVolatileMemory'],
      freeNonVolatileMemory: json['freeNonVolatileMemory'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eid': eid,
      'imei': imei,
      'sn': sn,
      'name': name,
      'advName': advName,
      'deviceName': deviceName,
      'address': address,
      'vendor': vendor,
      'freeVolatileMemory': freeVolatileMemory,
      'freeNonVolatileMemory': freeNonVolatileMemory,
    };
  }

  @override
  String toString() => 'EuiccDevice(EuiccDevice: $EuiccDevice, imei: $imei, sn: $sn, name: $name,  advName: $advName, deviceName: $deviceName, address: $address, vendor: $vendor, freeVolatileMemory: $freeVolatileMemory, freeNonVolatileMemory: $freeNonVolatileMemory)';
}

/// Profile 信息
class ProfileInfo {
  final String iccid;
  final String? profileName;
  final int state;
  final int profileClass;
  final String? mnc;
  final String? mcc;
  final String? imsi;
  final String? nickname;
  final String? serviceProviderName;

  ProfileInfo({
    required this.iccid,
    required this.profileName,
    required this.state,
    required this.profileClass,
    required this.mnc,
    required this.mcc,
    required this.imsi,
    required this.nickname,
    required this.serviceProviderName,
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    return ProfileInfo(
      iccid: json['iccid'] as String? ?? '',
      profileName: json['profileName'] as String?,
      state: json['state'] as int? ?? 0,
      profileClass: json['profileClass'] as int? ?? 0,
      mnc: json['mnc'] as String?,
      mcc: json['mcc'] as String?,
      imsi: json['imsi'] as String?,
      nickname: json['nickname'] as String?,
      serviceProviderName: json['serviceProviderName'] as String?,
    );
  }
}

/// EUICC 结果
class EuiccResult<T> {
  final int code;
  final String? title;
  final String? msg;
  final String? info;
  final T? data;

  EuiccResult({
    required this.code,
    this.msg,
    this.title,
    this.info,
    this.data,
  });

  bool get isSuccess => code == 0;

  factory EuiccResult.fromJson(Map<String, dynamic>? json, T Function(dynamic) fromJson) {
    return EuiccResult<T>(
      code: json?['code'] as int? ?? -1,
      msg: json?['msg'] as String?,
      info: json?['info'] as String?,
      title: json?['title'] as String?,
      data: json?['data'] != null ? fromJson(json?['data']) : null,
    );
  }
}

/// Linklan EUICC SDK
class LinklanEuicc {
  // ============ 事件流 ============

  /// 发现设备事件
  static Stream<BleDevice> get onScanDeviceFound {
    return LinklanEuiccPlatform.instance.onScanDeviceFound.map((json) {
      return BleDevice.fromJson(json);
    });
  }

  /// 设备更新事件
  static Stream<BleDevice> get onScanDeviceUpdated {
    return LinklanEuiccPlatform.instance.onScanDeviceUpdated.map((json) {
      return BleDevice.fromJson(json);
    });
  }

  /// 扫描状态变化
  static Stream<bool> get onScanStateChanged {
    return LinklanEuiccPlatform.instance.onScanStateChanged;
  }

  /// 扫描失败事件
  static Stream<Map<String, dynamic>> get onScanFailed {
    return LinklanEuiccPlatform.instance.onScanFailed;
  }

  /// 用户授权
  static Stream<Map<String, dynamic>> get onUserAuthentication {
    return LinklanEuiccPlatform.instance.onUserAuthentication;
  }

  /// EuiccDevice设备状态改变
  static Stream<Map<String, dynamic>> get onEuiccDeviceStatusChange {
    return LinklanEuiccPlatform.instance.onEuiccDeviceStatusChange;
  }


  // ============ 基础方法 ============

  /// 获取平台版本
  static Future<String?> getPlatformVersion() {
    return LinklanEuiccPlatform.instance.getPlatformVersion();
  }

  /// 初始化 SDK
  static Future<bool?> init({bool debug = false}) {
    return LinklanEuiccPlatform.instance.init(debug: debug);
  }

  // ============ 扫描相关 ============

  /// 开始扫描 BLE 设备
  static Future<bool?> startScan() {
    return LinklanEuiccPlatform.instance.startScan();
  }

  /// 停止扫描
  static Future<bool?> stopScan() {
    return LinklanEuiccPlatform.instance.stopScan();
  }

  // ============ 设备连接 ============

  /// 连接设备
  static Future<EuiccResult<EuiccDevice>> connectDevice(String address) async {
    var result = await LinklanEuiccPlatform.instance.connectDevice(address);
    return EuiccResult<EuiccDevice>.fromJson(jsonDecode(result),(data) {
      return EuiccDevice.fromJson(jsonDecode(data));
    });
  }

  /// 断开设备
  static Future<bool?> disconnectDevice(String address) {
    return LinklanEuiccPlatform.instance.disconnectDevice(address);
  }

  /// 检查设备连接状态
  static Future<bool?> checkDeviceConnection(String address) {
    return LinklanEuiccPlatform.instance.checkDeviceConnection(address);
  }

  // ============ 设备信息 ============

  /// 获取设备信息
  static Future<EuiccResult<EuiccDevice>> getDeviceInfo(String address) async {
    var result = await LinklanEuiccPlatform.instance.getDeviceInfo(address);
    return EuiccResult<EuiccDevice>.fromJson(jsonDecode(result),(data) {
      return EuiccDevice.fromJson(jsonDecode(data));
    });
  }

  /// 重置设备
  static Future<bool?> resetDevice(String address) {
    return LinklanEuiccPlatform.instance.resetDevice(address);
  }

  // ============ Profile 管理 ============

  /// 获取 Profile 列表
  static Future<EuiccResult<List<ProfileInfo>>> getProfileInfoList(String address) async {
    final result = await LinklanEuiccPlatform.instance.getProfileInfoList(address);
    return EuiccResult<List<ProfileInfo>>.fromJson(jsonDecode(result),(data) {
      List<ProfileInfo> profiles = [];
      (jsonDecode(data) as List).forEach((item){
        profiles.add(ProfileInfo.fromJson(item as Map<String, dynamic>));
      });
      return profiles;
    });
  }

  /// 启用 Profile
  static Future<EuiccResult> enableProfile(String address, String iccid) async {
    var result = await LinklanEuiccPlatform.instance.enableProfile(address, iccid);
    return EuiccResult.fromJson(jsonDecode(result),(data) {
      return data;
    });
  }

  /// 禁用 Profile
  static Future<EuiccResult> disableProfile(String address, String iccid) async {
    var result = await LinklanEuiccPlatform.instance.disableProfile(address, iccid);
    return EuiccResult.fromJson(jsonDecode(result),(data) {
      return data;
    });
  }

  /// 删除 Profile
  static  Future<EuiccResult> deleteProfile(String address, String iccid) async {
    var result = await LinklanEuiccPlatform.instance.deleteProfile(address, iccid);
    return EuiccResult.fromJson(jsonDecode(result),(data) {
      return data;
    });
  }

  /// 设置Profile昵称
  static  Future<EuiccResult> setProfileNickname(String address, String iccid, String nickname) async {
    var result = await LinklanEuiccPlatform.instance.setProfileNickname(address, iccid,nickname);
    return EuiccResult.fromJson(jsonDecode(result),(data) {
      return data;
    });
  }

  /// 下载 Profile
  static Future<EuiccResult> downloadProfile(String address, String activeCode, {String? confirmCode}) async {
    var result = await LinklanEuiccPlatform.instance.downloadProfile(address, activeCode, confirmCode);
    return EuiccResult.fromJson(jsonDecode(result),(data) {
      return data;
    });
  }

  // ============ APN 管理 ============

  /// 设置 APN
  static Future<bool?> setAPN({
    required String address,
    required String apn,
    String? userName,
    String? userPass,
    String? authType,
    String? dialNum,
    String? netType,
    String? pdpType,
  }) {
    return LinklanEuiccPlatform.instance.setAPN(
      address: address,
      apn: apn,
      userName: userName,
      userPass: userPass,
      authType: authType,
      dialNum: dialNum,
      netType: netType,
      pdpType: pdpType,
    );
  }

  /// 获取 APN
  static Future<EuiccResult> getAPN(String address) async {
    var result = await LinklanEuiccPlatform.instance.getAPN(address);
    return EuiccResult.fromJson(jsonDecode(result),(data) {
      return data;
    });
  }

  // ============ APDU ============

  /// 设置 APDU
  static  Future<EuiccResult> setApdu(String address, String checkPatch) async{
    var result = await LinklanEuiccPlatform.instance.setApdu(address, checkPatch);
    return EuiccResult.fromJson(jsonDecode(result),(data) {
      return data;
    });
  }

  static Future<void> setUserAuthentication(String? password) async{
    LinklanEuiccPlatform.instance.setUserAuthentication(password);
  }

}