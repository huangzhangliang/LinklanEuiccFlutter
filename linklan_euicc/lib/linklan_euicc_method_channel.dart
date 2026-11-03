import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';


import 'dart:async';
import 'linklan_euicc_platform_interface.dart';

/// An implementation of [LinklanEuiccPlatform] that uses method channels.
class MethodChannelLinklanEuicc extends LinklanEuiccPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('linklan_euicc');

  // ============ 事件流控制器 ============
  final _onScanDeviceFoundController = StreamController<Map<String, dynamic>>.broadcast();
  final _onScanDeviceUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onScanStateChangedController = StreamController<bool>.broadcast();
  final _onScanFailedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onUserAuthenticationController = StreamController<Map<String, dynamic>>.broadcast();
  final _onEuiccDeviceStatusChangeController = StreamController<Map<String, dynamic>>.broadcast();

  MethodChannelLinklanEuicc() {
    // 设置方法通道的事件处理器
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  // ============ 事件流 ============
  @override
  Stream<Map<String, dynamic>> get onScanDeviceFound => _onScanDeviceFoundController.stream;

  @override
  Stream<Map<String, dynamic>> get onScanDeviceUpdated => _onScanDeviceUpdatedController.stream;

  @override
  Stream<bool> get onScanStateChanged => _onScanStateChangedController.stream;

  @override
  Stream<Map<String, dynamic>> get onScanFailed => _onScanFailedController.stream;

  @override
  Stream<Map<String, dynamic>> get onUserAuthentication => _onUserAuthenticationController.stream;

  @override
  Stream<Map<String, dynamic>> get onEuiccDeviceStatusChange => _onEuiccDeviceStatusChangeController.stream;

  static Completer<String?>? _authCompleter;

  // ============ 处理原生回调 ============
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        final device = Map<String, dynamic>.from(call.arguments);
        _onScanDeviceFoundController.add(device);
        break;
      case 'onDeviceUpdated':
        final device = Map<String, dynamic>.from(call.arguments);
        _onScanDeviceUpdatedController.add(device);
        break;
      case 'onScanStateChanged':
        final isScanning = call.arguments as bool;
        _onScanStateChangedController.add(isScanning);
        break;
      case 'onScanFailed':
        final data = Map<String, dynamic>.from(call.arguments);
        _onScanFailedController.add(data);
        break;
      case 'onUserAuthentication':
        final data = Map<String, dynamic>.from(call.arguments);
        _authCompleter = Completer<String?>();
        _onUserAuthenticationController.add(data);
        return await _authCompleter!.future;
      case 'onEuiccDeviceStatusChange':
        final data = Map<String, dynamic>.from(call.arguments);
        _onEuiccDeviceStatusChangeController.add(data);
        break;
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method not implemented: ${call.method}',
        );
    }
  }

  // ============ 基础方法 ============
  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool?> init({bool debug = true}) async {
    final result = await methodChannel.invokeMethod<bool>('init', {'debug': debug});
    return result;
  }

  // ============ 扫描相关 ============
  @override
  Future<bool?> startScan() async {
    final result = await methodChannel.invokeMethod<bool>('startScan');
    return result;
  }

  @override
  Future<bool?> stopScan() async {
    final result = await methodChannel.invokeMethod<bool>('stopScan');
    return result;
  }

  // ============ 设备连接 ============
  @override
  Future<String> connectDevice(String address) async {
    final result = await methodChannel.invokeMethod(
      'connectDevice',
      {'address': address},
    );
    return result;
  }

  @override
  Future<bool?> disconnectDevice(String address) async {
    final result = await methodChannel.invokeMethod<bool>(
      'disconnectDevice',
      {'address': address},
    );
    return result;
  }

  @override
  Future<bool?> checkDeviceConnection(String address) async {
    final result = await methodChannel.invokeMethod<bool>(
      'checkDeviceConnection',
      {'address': address},
    );
    return result;
  }

  // ============ 设备信息 ============
  @override
  Future<String> getDeviceInfo(String address) async {
    final result = await methodChannel.invokeMethod(
      'getDeviceInfo',
      {'address': address},
    );
    return result;
  }

  @override
  Future<bool?> resetDevice(String address) async {
    final result = await methodChannel.invokeMethod<bool>(
      'resetDevice',
      {'address': address},
    );
    return result;
  }

  // ============ Profile 管理 ============
  @override
  Future<String> getProfileInfoList(String address) async {
    final result = await methodChannel.invokeMethod(
      'getProfileInfoList',
      {'address': address},
    );
    return result;
  }

  @override
  Future<String> enableProfile(String address, String iccid) async {
    final result = await methodChannel.invokeMethod(
      'enableProfile',
      {'address': address, 'iccid': iccid},
    );
    return result;
  }

  @override
  Future<String> disableProfile(String address, String iccid) async {
    final result = await methodChannel.invokeMethod(
      'disableProfile',
      {'address': address, 'iccid': iccid},
    );
    return result;
  }

  @override
  Future<String> deleteProfile(String address, String iccid) async {
    final result = await methodChannel.invokeMethod(
      'deleteProfile',
      {'address': address, 'iccid': iccid},
    );
    return result;
  }

  @override
  Future<String> setProfileNickname(String address, String iccid,String nickname) async {
    final result = await methodChannel.invokeMethod(
      'setProfileNickname',
      {'address': address, 'iccid': iccid, 'nickname': nickname},
    );
    return result;
  }

  @override
  Future<String> downloadProfile(String address, String activeCode, String? confirmCode) async {
    final result = await methodChannel.invokeMethod(
      'downloadProfile',
      {'address': address, 'activeCode': activeCode, 'confirmCode': confirmCode},
    );
    return result;
  }

  // ============ APN 管理 ============
  @override
  Future<bool?> setAPN({
    required String address,
    required String apn,
    String? userName,
    String? userPass,
    String? authType,
    String? dialNum,
    String? netType,
    String? pdpType,
  }) async {
    final result = await methodChannel.invokeMethod<bool>(
      'setAPN',
      {
        'address': address,
        'apn': apn,
        'userName': userName,
        'userPass': userPass,
        'authType': authType,
        'dialNum': dialNum,
        'netType': netType,
        'pdpType': pdpType,
      },
    );
    return result;
  }

  @override
  Future<String> getAPN(String address) async {
    final result = await methodChannel.invokeMethod(
      'getAPN',
      {'address': address},
    );
    return result;
  }

  @override
  Future<void> setUserAuthentication(String? password) async {
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.complete(password);
    }
  }

  // ============ APDU ============
  @override
  Future<String> setApdu(String address, String checkPatch) async {
    final result = await methodChannel.invokeMethod(
      'setApdu',
      {'address': address, 'checkPatch': checkPatch},
    );
    return result;
  }

  // ============ 释放资源 ============
  void dispose() {
    _onScanDeviceFoundController.close();
    _onScanDeviceUpdatedController.close();
    _onScanStateChangedController.close();
    _onScanFailedController.close();
    _onUserAuthenticationController.close();
    _onEuiccDeviceStatusChangeController.close();
  }

}