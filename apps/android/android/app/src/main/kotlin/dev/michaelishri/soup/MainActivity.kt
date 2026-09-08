package dev.michaelishri.soup

import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val tvTextInput = TvTextInput(this)
    private var textInputChannel: MethodChannel? = null
    private var networkChannel: MethodChannel? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        // libtailscale lives for the Android process. Reuse its owning Dart
        // isolate when Back destroys/recreates the activity in that process.
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let {
            Log.i("SoupLifecycle", "Reusing Flutter engine")
            return it
        }
        Log.i("SoupLifecycle", "Creating Flutter engine")
        return FlutterEngine(context.applicationContext).also {
            cache.put(ENGINE_ID, it)
            it.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        }
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textInputChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.michaelishri.soup/tv_text_input",
        )
        textInputChannel?.setMethodCallHandler(tvTextInput)
        networkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.michaelishri.soup/network_interfaces",
        )
        networkChannel?.setMethodCallHandler { call, result ->
            if (call.method != "getNetworkInterfaces") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(networkInterfacesJson())
            } catch (error: Exception) {
                result.error("network_interfaces", error.message, null)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        Log.i("SoupLifecycle", "Detaching activity; retaining Flutter engine")
        tvTextInput.dismiss()
        textInputChannel?.setMethodCallHandler(null)
        networkChannel?.setMethodCallHandler(null)
        textInputChannel = null
        networkChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun networkInterfacesJson(): String {
        val output = JSONArray()
        for (networkInterface in Collections.list(NetworkInterface.getNetworkInterfaces())) {
            try {
                val addresses = JSONArray()
                for (interfaceAddress in networkInterface.interfaceAddresses) {
                    val address = interfaceAddress.address ?: continue
                    addresses.put(
                        JSONObject()
                            .put("ip", address.hostAddress)
                            .put("prefixLen", interfaceAddress.networkPrefixLength.toInt()),
                    )
                }
                output.put(
                    JSONObject()
                        .put("name", networkInterface.name)
                        .put("index", networkInterface.index)
                        .put("mtu", networkInterface.mtu)
                        .put("up", networkInterface.isUp)
                        .put("broadcast", networkInterface.supportsMulticast())
                        .put("loopback", networkInterface.isLoopback)
                        .put("pointToPoint", networkInterface.isPointToPoint)
                        .put("multicast", networkInterface.supportsMulticast())
                        .put("addrs", addresses),
                )
            } catch (_: Exception) {
                continue
            }
        }
        return output.toString()
    }

    companion object {
        private const val ENGINE_ID = "soup-process-engine"
    }
}
