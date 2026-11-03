import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'linklan_euicc_method_channel.dart';

abstract class LinklanEuiccPlatform extends PlatformInterface {
  LinklanEuiccPlatform() : super(token: _token);

  static final Object _token = Object();
  static LinklanEuiccPlatform _instance = MethodChannelLinklanEuicc();

  static LinklanEuiccPlatform get instance => _instance;

  static set instance(LinklanEuiccPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ============ 基础方法 ============
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<bool?> init({bool debug = true}) {
    throw UnimplementedError('init() has not been implemented.');
  }

  // ============ 扫描相关 ============
  Future<bool?> startScan() {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  Future<bool?> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  // ============ 设备连接 ============
  Future<String> connectDevice(String address) {
    throw UnimplementedError('connectDevice() has not been implemented.');
  }

  Future<bool?> disconnectDevice(String address) {
    throw UnimplementedError('disconnectDevice() has not been implemented.');
  }

  Future<bool?> checkDeviceConnection(String address) {
    throw UnimplementedError('checkDeviceConnection() has not been implemented.');
  }

  // ============ 设备信息 ============
  Future<String> getDeviceInfo(String address) {
    throw UnimplementedError('getDeviceInfo() has not been implemented.');
  }

  Future<bool?> resetDevice(String address) {
    throw UnimplementedError('resetDevice() has not been implemented.');
  }

  // ============ Profile 管理 ============
  Future<String> getProfileInfoList(String address) {
    throw UnimplementedError('getProfileInfoList() has not been implemented.');
  }

  Future<String> enableProfile(String address, String iccid) {
    throw UnimplementedError('enableProfile() has not been implemented.');
  }

  Future<String> disableProfile(String address, String iccid) {
    throw UnimplementedError('disableProfile() has not been implemented.');
  }

  Future<String> deleteProfile(String address, String iccid) {
    throw UnimplementedError('deleteProfile() has not been implemented.');
  }

  Future<String> setProfileNickname(String address, String iccid, String nickname) {
    throw UnimplementedError('setProfileNickname() has not been implemented.');
  }

  Future<String> downloadProfile(String address, String activeCode, String? confirmCode) {
    throw UnimplementedError('downloadProfile() has not been implemented.');
  }

  // ============ APN 管理 ============
  Future<bool?> setAPN({
    required String address,
    required String apn,
    String? userName,
    String? userPass,
    String? authType,
    String? dialNum,
    String? netType,
    String? pdpType,
  }) {
    throw UnimplementedError('setAPN() has not been implemented.');
  }

  Future<String> getAPN(String address) {
    throw UnimplementedError('getAPN() has not been implemented.');
  }


  Future<void> setUserAuthentication(String? password) {
    throw UnimplementedError('setUserAuthentication() has not been implemented.');
  }

  // ============ APDU ============
  Future<String> setApdu(String address, String checkPatch) {
    throw UnimplementedError('setApdu() has not been implemented.');
  }

  // ============ 事件流 ============
  Stream<Map<String, dynamic>> get onScanDeviceFound;
  Stream<Map<String, dynamic>> get onScanDeviceUpdated;
  Stream<bool> get onScanStateChanged;
  Stream<Map<String, dynamic>> get onScanFailed;
  Stream<Map<String, dynamic>> get onUserAuthentication;
  Stream<Map<String, dynamic>> get onEuiccDeviceStatusChange;
}