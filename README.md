# LinklanLPA Flutter SDK 对接文档

## 目录

- [1. 概述](#1-概述)
- [2. 环境要求](#2-环境要求)
- [3. 集成配置](#3-集成配置)
- [4. 数据模型](#4-数据模型)
- [5. 事件流（Stream）](#5-事件流stream)
- [6. API 参考](#6-api-参考)
- [7. 完整对接示例](#8-完整对接示例)
- [8. 错误码说明](#9-错误码说明)
- [9. 注意事项](#10-注意事项)

---

## 1. 概述

LinklanLPA Flutter SDK 是 Linklan eSIM 管理能力的 Flutter 插件封装，通过 MethodChannel 与原生 Android/iOS SDK 通信，提供 BLE 设备扫描、连接、eSIM Profile 管理等功能。

**架构总览：**

```
Flutter (Dart)
  └── LinklanEuicc (静态 API)
       └── MethodChannel('linklan_euicc')
            ├── Android: LinklanEuiccPlugin (Kotlin)
            │    └── LinklanLPA SDK (AAR)
            └── iOS: LinklanEuiccPlugin (Swift)
                 └── LinklanLPA SDK (XCFramework)
```

**核心特性：**

- 跨平台：Android + iOS 双端统一 API
- 异步模式：Dart `Future<T>` + `Stream<T>`
- 事件驱动：扫描结果、连接状态等通过 Stream 推送
- 用户认证：Completer 机制实现 Flutter → 原生密码回传

---

## 2. 环境要求

| 项目 | 最低版本 |
|------|---------|
| Flutter | ≥ 3.3.0 |
| Dart SDK | ≥ 3.11.3 |
| Android minSdk | 24（Android 7.0） |
| iOS Deployment Target | 13.0 |
| Bluetooth | BLE 4.0+ |

---

## 3. 集成配置

### 3.1 添加依赖

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  linklan_euicc:
    git:
      url: https://github.com/huangzhangliang/LinklanEuiccFlutter.git
      path: linklan_euicc
```

执行：

```bash
flutter pub get
```

### 3.2 Android 配置

在 `build.gradle.kts` 中添加配置：

```
allprojects {
  repositories {
    maven { url = uri("https://jitpack.io") }
  }
}
```

### 3.3 iOS 配置

在 `ios/Runner/Info.plist` 中声明权限描述：

```xml
<!-- 蓝牙权限 -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限来连接 eSIM 设备</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>需要蓝牙权限来连接 eSIM 设备</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

### 3.4 导入

```dart
import 'package:linklan_euicc/linklan_euicc.dart';
```

---

## 4. 数据模型

### 4.1 BleDevice — BLE 扫描结果设备

| 字段 | 类型 | 说明 |
|------|------|------|
| `address` | `String` | 设备地址（Android 为 MAC，iOS 为 UUID） |
| `name` | `String` | 设备名称 |
| `model` | `String` | 设备型号标识 |
| `rssi` | `int` | 信号强度（dBm） |

**构造 & 反序列化：**

```dart
// 从 JSON 创建
final device = BleDevice.fromJson({
  'address': 'AA:BB:CC:DD:EE:FF',
  'name': 'Linklan-eSIM-001',
  'model': '',
  'rssi': -45,
});

// 转换为 JSON
final json = device.toJson();
```

### 4.2 EuiccDevice — 已连接设备信息

| 字段 | 类型 | 说明 |
|------|------|------|
| `eid` | `String` | eSIM 芯片唯一标识 |
| `imei` | `String?` | 设备 IMEI |
| `sn` | `String?` | 设备序列号 |
| `name` | `String?` | 设备名称 |
| `deviceName` | `String?` | 蓝牙广播名称 |
| `address` | `String?` | 蓝牙地址 |
| `vendor` | `String?` | 厂商标识 |
| `freeVolatileMemory` | `int?` | 可用易失性内存（KB） |
| `freeNonVolatileMemory` | `int?` | 可用非易失性内存（KB） |

```dart
final device = EuiccDevice.fromJson(json);
print('EID: ${device.eid}');
print('IMEI: ${device.imei}');
```

### 4.3 ProfileInfo — Profile 信息

| 字段 | 类型 | 说明 |
|------|------|------|
| `iccid` | `String` | ICCID（集成电路卡标识符） |
| `profileName` | `String` | Profile 名称 |
| `state` | `int` | 状态：`0` 禁用，`1` 启用 |
| `profileClass` | `int` | 类型：`0` 测试，`1` 运营，`2` 预置 |
| `mnc` | `String` | 移动网络码 |
| `mcc` | `String` | 移动国家码 |
| `imsi` | `String` | IMSI |
| `nickname` | `String` | Profile 昵称 |
| `serviceProviderName` | `String` | 运营商名称 |

### 4.4 EuiccResult\<T\> — 统一返回包装

| 字段 | 类型 | 说明 |
|------|------|------|
| `code` | `int` | 结果码：`0` 成功，`1` 失败 |
| `title` | `String?` | 错误标题 |
| `msg` | `String?` | 错误消息 |
| `info` | `String?` | 附加信息 |
| `data` | `T?` | 泛型数据 |

**便利属性：**

```dart
final result = await LinklanEuicc.connectDevice(address);
if (result.isSuccess) {
  print('连接成功: ${result.data}');
} else {
  print('连接失败: ${result.title} - ${result.msg}');
}
```

---

## 5. 事件流（Stream）

SDK 使用 Dart `Stream` 推送原生端事件，通过 `LinklanEuicc.onXxx` 获取。

### 5.1 onScanDeviceFound — 发现设备

```dart
LinklanEuicc.onScanDeviceFound.listen((BleDevice device) {
  print('发现设备: ${device.name} (${device.address}) RSSI: ${device.rssi}');
});
```

### 5.2 onScanDeviceUpdated — 设备更新

```dart
LinklanEuicc.onScanDeviceUpdated.listen((BleDevice device) {
  print('设备更新: ${device.name} RSSI: ${device.rssi}');
});
```

### 5.3 onScanStateChanged — 扫描状态变化

```dart
LinklanEuicc.onScanStateChanged.listen((bool isScanning) {
  print('扫描状态: ${isScanning ? "扫描中" : "已停止"}');
});
```

### 5.4 onScanFailed — 扫描失败

```dart
LinklanEuicc.onScanFailed.listen((Map<String, dynamic> error) {
  print('扫描失败: $error');
});
```

### 5.5 onUserAuthentication — 用户认证请求

原生端需要用户输入密码时触发。**必须监听此事件并调用 `setUserAuthentication()` 回传密码**，否则原生端会一直等待。

```dart
LinklanEuicc.onUserAuthentication.listen((Map<String, dynamic> data) {
  // data 包含认证类型等信息
  // 弹出密码输入框，用户输入后调用：
  LinklanEuicc.setUserAuthentication(userPassword);
});
```

### 5.6 onEuiccDeviceStatusChange — 设备状态变化

```dart
LinklanEuicc.onEuiccDeviceStatusChange.listen((Map<String, dynamic> status) {
  print('设备状态变化: $status');
});
```

### 5.7 事件流汇总

| 事件流 | 数据类型 | 触发时机 |
|--------|---------|---------|
| `onScanDeviceFound` | `BleDevice` | BLE 扫描发现新设备 |
| `onScanDeviceUpdated` | `BleDevice` | 已发现设备的信号值更新 |
| `onScanStateChanged` | `bool` | 扫描开始/停止 |
| `onScanFailed` | `Map<String, dynamic>` | 扫描出错 |
| `onUserAuthentication` | `Map<String, dynamic>` | 原生端请求用户认证 |
| `onEuiccDeviceStatusChange` | `Map<String, dynamic>` | 设备连接状态变化 |

---

## 6. API 参考

所有 API 均为 `LinklanEuicc` 类的静态方法，返回 `Future<T>`。

### 6.1 初始化

#### `init({bool debug = false})`

初始化 SDK。

```dart
static Future<bool?> init({bool debug = false})
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `debug` | `bool` | `false` | 是否开启调试日志 |

**返回值：** `Future<bool?>` — `true` 表示初始化成功。

```dart
final success = await LinklanEuicc.init(debug: true);
```

> **必须在调用其他 API 之前完成初始化**，建议放在 `main()` 或页面 `initState()` 中。

#### `getPlatformVersion()`

获取原生平台版本信息（调试用）。

```dart
static Future<String?> getPlatformVersion()
```

---

### 6.2 BLE 扫描

#### `startScan()`

开始扫描 BLE 设备。扫描结果通过 `onScanDeviceFound` 和 `onScanDeviceUpdated` 推送。

```dart
static Future<bool?> startScan()
```

```dart
LinklanEuicc.onScanDeviceFound.listen((device) {
  // 处理发现的设备
});
await LinklanEuicc.startScan();
```

#### `stopScan()`

停止扫描。

```dart
static Future<bool?> stopScan()
```

---

### 6.3 设备连接

#### `connectDevice(String address)`

连接指定 BLE 设备。

```dart
static Future<EuiccResult<EuiccDevice>> connectDevice(String address)
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `address` | `String` | 设备地址（来自 `BleDevice.address`） |

**返回值：** `Future<EuiccResult<EuiccDevice>>` — 成功时 `data` 包含设备信息。

```dart
final result = await LinklanEuicc.connectDevice(device.address);
if (result.isSuccess) {
  final eUiccDevice = result.data!;
  print('EID: ${eUiccDevice.eid}');
}
```

#### `disconnectDevice(String address)`

断开指定设备。

```dart
static Future<bool?> disconnectDevice(String address)
```

#### `checkDeviceConnection(String address)`

检查设备是否已连接。

```dart
static Future<bool?> checkDeviceConnection(String address)
```

**返回值：** `Future<bool?>` — `true` 表示已连接。

---

### 6.4 设备信息

#### `getDeviceInfo(String address)`

获取设备详细信息。

```dart
static Future<EuiccResult<EuiccDevice>> getDeviceInfo(String address)
```

```dart
final result = await LinklanEuicc.getDeviceInfo(address);
if (result.isSuccess) {
  final device = result.data!;
  print('EID: ${device.eid}');
  print('IMEI: ${device.imei}');
  print('可用内存: ${device.freeNonVolatileMemory} KB');
}
```

#### `resetDevice(String address)`

重置设备。清除设备上所有 Profile 并恢复出厂设置。

```dart
static Future<bool?> resetDevice(String address)
```

> **警告：** 此操作不可逆，将删除设备上所有 Profile。

---

### 6.5 Profile 管理

#### `getProfileInfoList(String address)`

获取设备上已安装的 Profile 列表。

```dart
static Future<EuiccResult<List<ProfileInfo>>> getProfileInfoList(String address)
```

```dart
final result = await LinklanEuicc.getProfileInfoList(address);
if (result.isSuccess) {
  final profiles = result.data!;
  for (final profile in profiles) {
    print('ICCID: ${profile.iccid}, 名称: ${profile.profileName}');
    print('状态: ${profile.state == 1 ? "启用" : "禁用"}');
    print('运营商: ${profile.serviceProviderName}');
  }
}
```

#### `downloadProfile(String address, String activeCode, {String? confirmCode})`

下载 Profile 到设备。

```dart
static Future<EuiccResult> downloadProfile(
  String address,
  String activeCode, {
  String? confirmCode,
})
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `address` | `String` | 设备地址 |
| `activeCode` | `String` | 激活码（由运营商提供） |
| `confirmCode` | `String?` | 确认码（可选，部分 Profile 需要） |

```dart
final result = await LinklanEuicc.downloadProfile(
  address,
  'L-ACTIVE-CODE-XXXXX',
);
if (result.isSuccess) {
  print('下载成功');
}
```

#### `enableProfile(String address, String iccid)`

启用指定 Profile。

```dart
static Future<EuiccResult> enableProfile(String address, String iccid)
```

```dart
final result = await LinklanEuicc.enableProfile(address, profile.iccid);
```

#### `disableProfile(String address, String iccid)`

禁用指定 Profile。

```dart
static Future<EuiccResult> disableProfile(String address, String iccid)
```

#### `deleteProfile(String address, String iccid)`

删除指定 Profile。

```dart
static Future<EuiccResult> deleteProfile(String address, String iccid)
```

> 删除后不可恢复，确认后再执行。

---

### 6.6 APN 管理

#### `setAPN({...})`

设置 APN 参数。

```dart
static Future<bool?> setAPN({
  required String address,
  required String apn,
  String? userName,
  String? userPass,
  String? authType,
  String? dialNum,
  String? netType,
  String? pdpType,
})
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `address` | `String` | 设备地址（必填） |
| `apn` | `String` | APN 名称（必填） |
| `userName` | `String?` | 用户名 |
| `userPass` | `String?` | 密码 |
| `authType` | `String?` | 认证类型（`PAP` / `CHAP`） |
| `dialNum` | `String?` | 拨号号码 |
| `netType` | `String?` | 网络类型 |
| `pdpType` | `String?` | PDP 类型（`IP` / `IPV6` / `IPV4V6`） |

```dart
final success = await LinklanEuicc.setAPN(
  address: address,
  apn: 'cmnet',
  userName: '',
  userPass: '',
  pdpType: 'IP',
);
```

#### `getAPN(String address)`

获取当前 APN 配置。

```dart
static Future<EuiccResult> getAPN(String address)
```

---

### 6.7 APDU 设置

#### `setApdu(String address, String checkPatch)`

设置 APDU 校验补丁。

```dart
static Future<EuiccResult> setApdu(String address, String checkPatch)
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `address` | `String` | 设备地址 |
| `checkPatch` | `String` | 校验补丁内容 |

---

### 6.8 用户认证

#### `setUserAuthentication(String? password)`

回传用户认证密码。**当监听到 `onUserAuthentication` 事件后调用此方法**，将用户输入的密码传回原生端。

```dart
static Future<void> setUserAuthentication(String? password)
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `password` | `String?` | 用户输入的密码，传 `null` 表示取消认证 |

**工作原理：**

```
原生端触发认证请求
       ↓
MethodChannel('onUserAuthentication')
       ↓
Flutter onUserAuthentication Stream 推送
       ↓
开发者监听到事件，弹出密码输入 UI
       ↓
用户输入密码
       ↓
调用 LinklanEuicc.setUserAuthentication(password)
       ↓
Completer 完成 → 密码通过 MethodChannel 回传原生端
       ↓
原生端继续执行操作
```

```dart
// 监听认证请求
LinklanEuicc.onUserAuthentication.listen((data) async {
  // 弹出密码输入对话框
  final password = await showPasswordDialog(context);
  // 回传密码
  await LinklanEuicc.setUserAuthentication(password);
});
```

---


## 7. 完整对接示例

```dart
import 'package:flutter/material.dart';
import 'package:linklan_euicc/linklan_euicc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 SDK
  final success = await LinklanEuicc.init(debug: true);
  print('SDK 初始化: $success');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<BleDevice> _devices = [];
  EuiccDevice? _connectedDevice;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  /// 注册事件监听
  void _setupEventListeners() {
    // 发现新设备
    LinklanEuicc.onScanDeviceFound.listen((device) {
      setState(() {
        final existing = _devices.indexWhere((d) => d.address == device.address);
        if (existing >= 0) {
          _devices[existing] = device;
        } else {
          _devices.add(device);
        }
      });
    });

    // 设备信号更新
    LinklanEuicc.onScanDeviceUpdated.listen((device) {
      setState(() {
        final index = _devices.indexWhere((d) => d.address == device.address);
        if (index >= 0) {
          _devices[index] = device;
        }
      });
    });

    // 扫描状态
    LinklanEuicc.onScanStateChanged.listen((isScanning) {
      setState(() => _isScanning = isScanning);
    });

    // 扫描失败
    LinklanEuicc.onScanFailed.listen((error) {
      print('扫描失败: $error');
    });

    // 用户认证请求
    LinklanEuicc.onUserAuthentication.listen((data) async {
      final password = await _showPasswordDialog();
      await LinklanEuicc.setUserAuthentication(password);
    });

    // 设备状态变化
    LinklanEuicc.onEuiccDeviceStatusChange.listen((status) {
      print('设备状态: $status');
    });
  }

  /// 开始扫描
  Future<void> _startScan() async {
    _devices.clear();
    await LinklanEuicc.startScan();
  }

  /// 停止扫描
  Future<void> _stopScan() async {
    await LinklanEuicc.stopScan();
  }

  /// 连接设备
  Future<void> _connectDevice(BleDevice device) async {
    await LinklanEuicc.stopScan();

    final result = await LinklanEuicc.connectDevice(device.address);
    if (result.isSuccess && result.data != null) {
      setState(() => _connectedDevice = result.data);
      print('连接成功: EID=${result.data!.eid}');
    } else {
      print('连接失败: ${result.title} - ${result.msg}');
    }
  }

  /// 下载 Profile
  Future<void> _downloadProfile(String activeCode) async {
    if (_connectedDevice == null) return;

    final result = await LinklanEuicc.downloadProfile(
      _connectedDevice!.address,
      activeCode,
    );
    print('下载结果: code=${result.code}, msg=${result.msg}');
  }

  /// 获取 Profile 列表
  Future<void> _getProfileList() async {
    if (_connectedDevice == null) return;

    final result = await LinklanEuicc.getProfileInfoList(
      _connectedDevice!.address,
    );
    if (result.isSuccess && result.data != null) {
      for (final profile in result.data!) {
        print('ICCID: ${profile.iccid}');
        print('  名称: ${profile.profileName}');
        print('  运营商: ${profile.serviceProviderName}');
        print('  状态: ${profile.state == 1 ? "启用" : "禁用"}');
      }
    }
  }

  /// 启用 Profile
  Future<void> _enableProfile(String iccid) async {
    if (_connectedDevice == null) return;

    final result = await LinklanEuicc.enableProfile(
      _connectedDevice!.address,
      iccid,
    );
    print('启用结果: code=${result.code}');
  }

  /// 断开连接
  Future<void> _disconnect() async {
    if (_connectedDevice == null) return;
    await LinklanEuicc.disconnectDevice(_connectedDevice!.address);
    setState(() => _connectedDevice = null);
  }

  Future<String?> _showPasswordDialog() async {
    // 实现密码输入对话框，返回用户输入的密码
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Linklan eSIM')),
        body: Column(
          children: [
            // 扫描控制按钮
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  child: const Text('开始扫描'),
                ),
                ElevatedButton(
                  onPressed: _isScanning ? _stopScan : null,
                  child: const Text('停止扫描'),
                ),
              ],
            ),
            // 设备列表
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text('${device.model} | ${device.address} | ${device.rssi}dBm'),
                    onTap: () => _connectDevice(device),
                  );
                },
              ),
            ),
            // 已连接设备操作
            if (_connectedDevice != null) ...[
              Text('已连接: ${_connectedDevice!.eid}'),
              ElevatedButton(
                onPressed: _getProfileList,
                child: const Text('获取 Profile 列表'),
              ),
              ElevatedButton(
                onPressed: () => _downloadProfile('YOUR_ACTIVE_CODE'),
                child: const Text('下载 Profile'),
              ),
              ElevatedButton(
                onPressed: _disconnect,
                child: const Text('断开连接'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## 8. 错误码说明

| code | 含义 | 说明 |
|------|------|------|
| `0` | 成功 | 操作成功完成 |
| `1` | 失败 | 操作失败，查看 `title` 和 `msg` 获取详细信息 |
| `-1` | 未知 | 结果 JSON 解析失败或原生端未返回 code |

**错误处理模式：**

```dart
final result = await LinklanEuicc.downloadProfile(address, activeCode);
if (result.isSuccess) {
  // 成功逻辑
} else {
  // 失败逻辑
  print('错误标题: ${result.title}');
  print('错误信息: ${result.msg}');
  print('附加信息: ${result.info}');
}
```

---

## 9. 注意事项

1. **初始化顺序** — 必须先调用 `LinklanEuicc.init()` 完成初始化，再调用其他 API。建议在 `main()` 函数中执行。

2. **异步调用** — 所有 API 返回 `Future<T>`，必须用 `await` 调用，不能在同步上下文中直接调用。

3. **事件流订阅** — `onScanDeviceFound` 等 Stream 是 `broadcast` 模式，支持多个监听器，但建议在 `initState` 中订阅、`dispose` 中取消订阅以避免内存泄漏。

4. **用户认证必须监听** — `onUserAuthentication` 事件触发后，必须调用 `setUserAuthentication(password)` 回传密码，否则原生端会一直阻塞等待。建议在应用启动时就注册监听。

5. **Android 运行时权限** — Android 6.0+ 需要动态申请位置权限和蓝牙权限，`AndroidManifest.xml` 声明只是第一步，代码中还需调用 `permission_handler` 等库动态请求。

6. **iOS 蓝牙状态** — iOS 上蓝牙关闭时扫描不会报错但无法发现设备，建议先检查 `flutter_blue` 或原生蓝牙状态。

7. **地址格式差异** — Android 设备地址为 MAC 格式（`AA:BB:CC:DD:EE:FF`），iOS 为 UUID 格式，不要硬编码地址，始终从 `BleDevice.address` 获取。

8. **扫描与连接互斥** — 连接设备前建议先调用 `stopScan()` 停止扫描，避免扫描和连接抢占蓝牙资源导致失败。


9. **Stream 生命周期** — `MethodChannelLinklanEuicc` 内部使用 `StreamController.broadcast()`，插件生命周期内有效。如需手动释放，调用 `dispose()` 关闭所有 StreamController。

10. **MethodChannel 名称** — 插件使用 MethodChannel 名称 `linklan_euicc`，如需自定义平台实现，可通过 `LinklanEuiccPlatform.instance = YourImpl()` 替换。

11. **跨平台一致性** — 同一 API 在 Android 和 iOS 上行为一致，但底层蓝牙地址格式不同，UI 层不应依赖具体地址格式。
