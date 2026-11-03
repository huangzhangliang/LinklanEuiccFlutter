package com.linklan.euicc.linklan_euicc

import android.Manifest
import android.content.Context
import android.os.Build
import androidx.annotation.RequiresPermission
import com.linklan.euicc.EuiccDevice
import com.linklan.euicc.EuiccResult
import com.linklan.euicc.LinklanLPA
import com.linklan.euicc.ProfileInfo
import com.linklan.euicc.ble.BleDevice
import com.linklan.euicc.ble.BleDeviceConnectionListener
import com.linklan.euicc.ble.BleScanCallback
import com.linklan.euicc.ble.BleUserAuthenticationListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

/** LinklanEuiccPlugin */
class LinklanEuiccPlugin :
    FlutterPlugin,
    MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var context: Context? = null

    // 跨线程读写,改用 ConcurrentHashMap 避免并发问题
    private val bleDeviceMap = ConcurrentHashMap<String, BleDevice>()
    private val euiccDeviceMap = ConcurrentHashMap<String, EuiccDevice>()

    // 复用一份作用域,不再每次 new CoroutineScope
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    // ============ FlutterPlugin ============

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {

        // BleUserAuthenticationListener.onPromptUserAuthentication 要求同步返回 String,
        // 必须 runBlocking 等待 Dart 侧回调,这点无法优化。
        LinklanLPA.userAuthenticationListener = object : BleUserAuthenticationListener {
            override fun onPromptUserAuthentication(address: String?): String = runBlocking {
                val deferred = CompletableDeferred<String>()
                mainScope.launch {
                    channel.invokeMethod(
                        "onUserAuthentication",
                        mapOf("address" to address),
                        object : Result {
                            override fun success(result: Any?) {
                                deferred.complete(result as? String ?: "")
                            }

                            override fun error(
                                errorCode: String,
                                errorMessage: String?,
                                errorDetails: Any?
                            ) {
                                deferred.complete("")
                            }

                            override fun notImplemented() {
                                deferred.complete("")
                            }
                        }
                    )
                }
                deferred.await()
            }
        }

        // fire-and-forget,直接用 2 参 invokeMethod,不需要 Result 回调
        LinklanLPA.bleDeviceConnectionListener = object : BleDeviceConnectionListener {
            override fun onStatusChange(address: String?, status: String) {
                channel.invokeMethod(
                    "onEuiccDeviceStatusChange",
                    mapOf("address" to address, "status" to status)
                )
            }
        }

        channel = MethodChannel(binding.binaryMessenger, "linklan_euicc")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // 取消作用域,避免插件 detach 后还有挂起的 IO 任务
        ioScope.coroutineContext[Job]?.cancel()
        mainScope.coroutineContext[Job]?.cancel()
        context = null
    }

    // ============ Helper ============

    /**
     * 在 IO 线程跑 [block],完成后切回主线程回调 [Result]。
     * block 抛出的任何异常都会被捕获并转成 result.error("ERROR", ...)。
     */
    private fun runOnIo(result: Result, block: suspend () -> Any?) {
        ioScope.launch {
            val payload: Any? = try {
                block()
            } catch (e: Throwable) {
                withContext(Dispatchers.Main) {
                    safeResult(result) { result.error("ERROR", e.message ?: e.toString(), null) }
                }
                return@launch
            }
            withContext(Dispatchers.Main) {
                safeResult(result) { result.success(payload) }
            }
        }
    }

    /** 包装 Result 调用,detach 后回调可能抛异常,这里静默吞掉 */
    private fun safeResult(result: Result, block: () -> Unit) {
        try {
            block()
        } catch (_: Throwable) {
            // 插件已 detach 或 Result 已被消费
        }
    }

    /** 主线程调用 invokeMethod(无 Result 回调) */
    private fun invokeOnMain(method: String, arguments: Any?) {
        mainScope.launch {
            channel.invokeMethod(method, arguments)
        }
    }

    private fun bleDevice(address: String?): BleDevice? =
        address?.let { bleDeviceMap[it] }

    private fun euiccDevice(address: String?): EuiccDevice? =
        address?.let { euiccDeviceMap[it] }

    // ============ MethodCallHandler ============

    @RequiresPermission(allOf = [Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT])
    override fun onMethodCall(call: MethodCall, result: Result) {

        when (call.method) {
            // ============ 基础方法 ============
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }

            "init" -> {
                val debug = call.argument<Boolean>("debug") ?: true
                context?.let { ctx ->
                    LinklanLPA.init(ctx, debug)
                    result.success(true)
                } ?: result.error("INIT_ERROR", "context is null", null)
            }

            // ============ 扫描相关 ============
            "startScan" -> {
                val callback = object : BleScanCallback {
                    override fun onDeviceFound(device: BleDevice) {
                        bleDeviceMap[device.address] = device
                        invokeOnMain("onDeviceFound", deviceToJson(device))
                    }

                    override fun onDeviceUpdated(device: BleDevice) {
                        invokeOnMain("onDeviceUpdated", deviceToJson(device))
                    }

                    override fun onScanStateChanged(isScanning: Boolean) {
                        invokeOnMain("onScanStateChanged", isScanning)
                    }

                    override fun onScanFailed(errorCode: Int, errorMsg: String) {
                        invokeOnMain(
                            "onScanFailed",
                            mapOf("errorCode" to errorCode, "errorMsg" to errorMsg)
                        )
                    }
                }
                LinklanLPA.startScan(callback)
                result.success(true)
            }

            "stopScan" -> {
                try {
                    LinklanLPA.stopScan()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("STOP_SCAN_ERROR", e.message, null)
                }
            }

            // ============ 设备连接 ============
            "connectDevice" -> {
                val device = bleDevice(call.argument("address"))
                if (device != null) {
                    runOnIo(result) {
                        val euiccResult = LinklanLPA.connectDevice(device)
                        if (euiccResult.code == 0) {
                            euiccResult.data?.address?.let { addr ->
                                euiccDeviceMap[addr] = euiccResult.data!!
                            }
                        }
                        euiccResultToJson(euiccResult)
                    }
                } else {
                    result.error("CONNECT_ERROR", "Device is null", null)
                }
            }

            "disconnectDevice" -> {
                LinklanLPA.disconnectDevice(euiccDevice(call.argument("address")))
                result.success(true)
            }

            "checkDeviceConnection" -> {
                result.success(
                    LinklanLPA.checkDeviceConnection(euiccDevice(call.argument("address")))
                )
            }

            // ============ 设备信息 ============
            "getDeviceInfo" -> {
                val device = euiccDevice(call.argument("address"))
                if (device != null) {
                    runOnIo(result) { euiccResultToJson(LinklanLPA.getDeviceInfo(device)) }
                } else {
                    result.error("DEVICE_ERROR", "Device is null", null)
                }
            }

            "resetDevice" -> {
                val device = euiccDevice(call.argument("address"))
                runOnIo(result) {
                    LinklanLPA.resetDevice(device)
                    true
                }
            }

            // ============ Profile 管理 ============
            "getProfileInfoList" -> {
                val device = euiccDevice(call.argument("address"))
                if (device != null) {
                    runOnIo(result) { euiccResultToJson(LinklanLPA.getProfileInfoList(device)) }
                } else {
                    result.error("PROFILE_ERROR", "Device is null", null)
                }
            }

            "enableProfile" -> {
                val device = euiccDevice(call.argument<String>("address"))
                if (device != null) {
                    val iccid = call.argument<String>("iccid")
                    runOnIo(result) { euiccResultToJson(LinklanLPA.enableProfile(device, iccid)) }
                } else {
                    result.error("PROFILE_ERROR", "Device is null", null)
                }
            }

            "disableProfile" -> {
                val device = euiccDevice(call.argument<String>("address"))
                if (device != null) {
                    val iccid = call.argument<String>("iccid")
                    runOnIo(result) { euiccResultToJson(LinklanLPA.disableProfile(device, iccid)) }
                } else {
                    result.error("PROFILE_ERROR", "Device is null", null)
                }
            }

            "deleteProfile" -> {
                val device = euiccDevice(call.argument<String>("address"))
                if (device != null) {
                    val iccid = call.argument<String>("iccid")
                    runOnIo(result) { euiccResultToJson(LinklanLPA.deleteProfile(device, iccid)) }
                } else {
                    result.error("PROFILE_ERROR", "Device is null", null)
                }
            }

            "setProfileNickname" -> {
                val device = euiccDevice(call.argument<String>("address"))
                if (device != null) {
                    val iccid = call.argument<String>("iccid")
                    val nickname = call.argument<String>("nickname")
                    runOnIo(result) { euiccResultToJson(LinklanLPA.setProfileNickname(device, iccid,nickname)) }
                } else {
                    result.error("PROFILE_ERROR", "Device is null", null)
                }
            }

            "downloadProfile" -> {
                val device = euiccDevice(call.argument<String>("address"))
                if (device != null) {
                    val activeCode = call.argument<String>("activeCode")
                    val confirmCode = call.argument<String>("confirmCode")
                    runOnIo(result) {
                        euiccResultToJson(LinklanLPA.downloadProfile(device, activeCode, confirmCode))
                    }
                } else {
                    result.error("DOWNLOAD_ERROR", "Device is null", null)
                }
            }

            // ============ APN 管理 ============
            "setAPN" -> {
                runOnIo(result) {
                    LinklanLPA.setAPN(
                        euiccDevice(call.argument("address")),
                        call.argument("apn"),
                        call.argument("userName"),
                        call.argument("userPass"),
                        call.argument("authType"),
                        call.argument("dialNum"),
                        call.argument("netType"),
                        call.argument("pdpType")
                    )
                    mainScope.launch {
                        result.success(true)
                    }
                }

            }

            "getAPN" -> {
                val device = euiccDevice(call.argument("address"))
                if (device != null) {
                    runOnIo(result) { euiccResultToJson(LinklanLPA.getAPN(device)) }
                } else {
                    result.error("APN_ERROR", "Device is null", null)
                }
            }

            // ============ APDU ============
            "setApdu" -> {
                val device = euiccDevice(call.argument<String>("address"))
                if (device != null) {
                    val checkPatch = call.argument<String>("checkPatch")
                    runOnIo(result) { euiccResultToJson(LinklanLPA.setApdu(device, checkPatch)) }
                } else {
                    result.error("APDU_ERROR", "Device is null", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    // ============ JSON 转换辅助方法 ============

    private fun deviceToJson(device: BleDevice) = mapOf(
        "address" to device.address,
        "name" to device.name,
        "advName" to device.advName,
        "model" to device.model,
        "rssi" to device.rssi,
        "serviceUuids" to (device.serviceUuids ?: emptyList<String>())
    )

    private fun euiccResultToJson(result: EuiccResult<*>): String {
        val json = JSONObject()
        json.put("code", result.code)
        json.put("msg", result.msg)
        json.put("title", result.title)
        json.put("info", result.info)

        result.data?.let { data ->
            when (data) {
                is List<*> -> if (data.isNotEmpty() && data.first() is ProfileInfo) {
                    @Suppress("UNCHECKED_CAST")
                    json.put(
                        "data",
                        (data as List<ProfileInfo>).map { profileToJson(it) }
                    )
                } else {
                    json.put("data", data)
                }
                is EuiccDevice -> json.put("data", euiccDeviceToJson(data))
                is String -> json.put("data", data)
                else -> json.put("data", data.toString())
            }
        }
        return json.toString()
    }

    private fun euiccDeviceToJson(e: EuiccDevice) = JSONObject().apply {
        put("address", e.address)
        put("eid", e.eid)
        put("imei", e.imei)
        put("sn", e.sn)
        put("model", e.model)
        put("deviceName", e.deviceName)
        put("name", e.name)
        put("advName", e.advName)
        put("vendor", e.vendor)
        put("freeVolatileMemory", e.freeVolatileMemory)
        put("freeNonVolatileMemory", e.freeNonVolatileMemory)
    }.toString()

    private fun profileToJson(p: ProfileInfo) = JSONObject().apply {
        put("iccid", p.iccid)
        put("profileName", p.profileName)
        put("state", p.state)
        put("profileClass", p.profileClass)
        put("mnc", p.mnc)
        put("mcc", p.mcc)
        put("imsi", p.imsi)
        put("nickname", p.nickname)
        put("serviceProviderName", p.serviceProviderName)
    }.toString()
}