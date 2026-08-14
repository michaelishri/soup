package dev.michaelishri.soup

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Collections
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.michaelishri.soup/network_interfaces",
        ).setMethodCallHandler { call, result ->
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
}
