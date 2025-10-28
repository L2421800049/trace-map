package com.example.myapp

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.tencent.lbssearch.HttpResponseListener
import com.tencent.lbssearch.TencentSearch
import com.tencent.lbssearch.`object`.param.CoordTypeEnum
import com.tencent.lbssearch.`object`.param.Geo2AddressParam
import com.tencent.lbssearch.`object`.result.Geo2AddressResultObject
import com.tencent.tencentmap.mapsdk.maps.model.LatLng
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.myapp/tencent_map_service"
    private val logTag = "TencentReverseGeocode"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var search: TencentSearch? = null
    private var currentKey: String? = null
    private var nativeReverseGeocodeAvailable = detectNativeReverseGeocodeSupport()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "reverseGeocode" -> handleReverseGeocode(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleReverseGeocode(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")
        val apiKey = call.argument<String>("apiKey")

        if (latitude == null || longitude == null || apiKey.isNullOrBlank()) {
            Log.w(
                logTag,
                "reverseGeocode missing args lat=$latitude lng=$longitude keyPresent=${!apiKey.isNullOrBlank()}",
            )
            result.error(
                "INVALID_ARGUMENTS",
                "latitude, longitude and apiKey are required",
                null,
            )
            return
        }

        Log.d(logTag, "reverseGeocode lat=$latitude lng=$longitude")

        if (!nativeReverseGeocodeAvailable) {
            Log.d(logTag, "Native reverse geocode disabled; skipping SDK attempt")
            postResult(result, null)
            return
        }

        if (search == null || currentKey != apiKey) {
            Log.d(logTag, "Creating TencentSearch for new key")
            try {
                search = TencentSearch(applicationContext, apiKey)
                currentKey = apiKey
            } catch (throwable: Throwable) {
                Log.e(
                    logTag,
                    "Failed to initialize TencentSearch",
                    throwable,
                )
                search = null
                currentKey = null
                nativeReverseGeocodeAvailable = false
            }
        }
        val tencentSearch = search
        if (tencentSearch == null) {
            Log.e(logTag, "TencentSearch unavailable after initialization; falling back")
            nativeReverseGeocodeAvailable = false
            postResult(result, null)
            return
        }

        val coordType = CoordTypeEnum.DEFAULT
        val param = Geo2AddressParam(LatLng(latitude, longitude)).apply {
            get_poi(false)
            coord_type(coordType)
        }

        Log.d(
            logTag,
            "Dispatching geo2address request coordType=$coordType",
        )

        tencentSearch.geo2address(
            param,
            object : HttpResponseListener<Geo2AddressResultObject> {
                override fun onSuccess(
                    status: Int,
                    response: Geo2AddressResultObject?,
                ) {
                    if (status != 0 || response == null) {
                        Log.w(
                            logTag,
                            "geo2address returned status=$status responseNull=${response == null}",
                        )
                        postResult(result, null)
                        return
                    }
                    val reverse = response.result
                    val formatted = reverse?.formatted_addresses?.recommend
                    val referenceFallback = reverse?.address_reference?.let { reference ->
                        listOf<String?>(
                            reference.landmark_l1?.title,
                            reference.landmark_l2?.title,
                            reference.town?.title,
                            reference.street?.title,
                            reference.street_number?.title,
                        ).firstOrNull { !it.isNullOrBlank() }
                    }
                    val address = when {
                        !formatted.isNullOrBlank() -> formatted
                        !reverse?.address.isNullOrBlank() -> reverse?.address
                        !referenceFallback.isNullOrBlank() -> referenceFallback
                        else -> null
                    }
                    val normalized = address?.trim()
                    Log.d(
                        logTag,
                        "geo2address success resolved=${normalized ?: "null"}",
                    )
                    postResult(
                        result,
                        if (normalized.isNullOrEmpty()) null else normalized,
                    )
                }

                override fun onFailure(
                    errorCode: Int,
                    errorMessage: String?,
                    throwable: Throwable?,
                ) {
                    Log.e(
                        logTag,
                        "geo2address failure code=$errorCode message=$errorMessage",
                        throwable,
                    )
                    nativeReverseGeocodeAvailable = false
                    postResult(result, null)
                }
            },
        )
    }

    private fun postResult(result: MethodChannel.Result, value: String?) {
        Log.d(logTag, "reverseGeocode result=$value")
        mainHandler.post { result.success(value) }
    }

    private fun detectNativeReverseGeocodeSupport(): Boolean {
        return try {
            Class.forName("com.tencent.lbssearch.TencentSearch")
            Class.forName("com.tencent.gaya.foundation.api.comps.tools.SDKFileFinder\$Companion")
            true
        } catch (throwable: Throwable) {
            Log.w(
                logTag,
                "Native reverse geocode dependencies unavailable, will use HTTP fallback only",
                throwable,
            )
            false
        }
    }

}
