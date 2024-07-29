package com.reactlibrary;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.Nullable;

import com.amplifyframework.auth.AuthProvider;
import com.amplifyframework.core.Amplify;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableNativeMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.gson.Gson;
import com.reactlibrary.utils.LocationUtils;

import org.json.JSONObject;

import java.util.List;
import java.util.Map;

import apkit.GranwinAgent;
import apkit.entity.SetDeviceNetworkResultEntity;
import apkit.utils.AwsUtils;
import apkit.utils.LogUtil;

public class RNModule extends ReactContextBaseJavaModule {
    private WifiManager wifiManager;
    private ReactApplicationContext context;

    public RNModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;

        IntentFilter filter = new IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION);
        reactContext.registerReceiver(mReceiver, filter);
        wifiManager = (WifiManager) reactContext.getApplicationContext().getSystemService(Context.WIFI_SERVICE);

        GranwinAgent.getInstance().setAWSListener(new AwsUtils.AWSListener() {
            @Override
            public void onConnectStatusChange(String status) {
                //EventBus.getDefault().post(new AWSEvent("connect", status));
                WritableMap params = Arguments.createMap();
                params.putString("status", status);
                sendEvent(getReactApplicationContext(), "Granwin_AWS_status", params);
            }

            @Override
            public void onConnectFail(String message) {
                //EventBus.getDefault().post(new AWSEvent("connect", message));
                WritableMap params = Arguments.createMap();
                params.putString("status", "connect_fail");
                sendEvent(getReactApplicationContext(), "Granwin_AWS_status", params);
            }

            @Override
            public void onReceiveShadow(String mac, JSONObject jsonObject) {
                // EventBus.getDefault().post(new AWSEvent(mac, "shadow", jsonObject));
                WritableMap params = Arguments.createMap();
                params.putString("mac", mac);
                params.putString("value", jsonObject.toString());
                sendEvent(getReactApplicationContext(), "Granwin_AWS_shadow", params);
            }

            @Override
            public void onGranWinMessage(JSONObject jsonObject) {
                //固件升级会从这里发出去，记得过滤message为4
                WritableMap params = Arguments.createMap();
                params.putString("value", jsonObject.toString());
                sendEvent(getReactApplicationContext(), "Granwin_AWS_message", params);
            }
        });
    }

    private BroadcastReceiver mReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent.getAction().equals(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)) {
                List results = wifiManager.getScanResults();
                if (results != null && results.size() > 0) {
                    Gson gson = new Gson();
                    String jsonStr = gson.toJson(results);
                    WritableMap params = Arguments.createMap();
                    params.putBoolean("result", true);
                    params.putString("data", jsonStr);
                    sendEvent(getReactApplicationContext(), "BroadcastReceiver_Wifi", params);
                }
            }
        }
    };

    @Override
    public String getName() {
        return "RNModule";
    }

    public static void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap params) {
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(eventName, params);
    }

    /**
     * log
     */
    @ReactMethod
    public void log(String log) {
        GranwinAgent.getInstance().Log(log);
    }

    /**
     * 连接蓝牙设备
     */
    @ReactMethod
    public void connectBLEDevice(String deviceName,String mac, Callback callback) {
        LogUtil.d("--- 进入蓝牙配网模式 ---");
        //Granwin_BLE
        GranwinAgent.getInstance().connectDeviceByBle2(deviceName,mac, new GranwinAgent.ConnectDeviceListener() {
            @Override
            public void onConnectSuccess() {
                //蓝牙连接成功
                try {
                    callback.invoke("success");
                }catch (Exception e){

                }
            }

            @Override
            public void onConnectFail(String var1) {
                //蓝牙连接失败
                try {
                    callback.invoke("fail");
                }catch (Exception e){

                }
            }
        });
    }

    /**
     * 连接设备热点
     */
    @ReactMethod
    public void connectDeviceHot(String devHot, Callback callback) {
        LogUtil.d("--- 进入ap配网模式 ---");
        //Granwin_AP
        GranwinAgent.getInstance().connectDeviceHot(devHot, "12345678", new GranwinAgent.ConnectDeviceListener() {
            @Override
            public void onConnectSuccess() {
                callback.invoke("success");
            }

            @Override
            public void onConnectFail(String var1) {
                //连接设备热点失败，引导用户手动切换热点
                callback.invoke("fail");
            }
        });
    }

    @ReactMethod
    public void stopConnectDevice() {
        GranwinAgent.getInstance().stopConnectDeviceHot();
        GranwinAgent.getInstance().stopConnectWifi();
    }

    /**
     * 将路由器信息发送给连接上的设备
     *
     * @param isUseBLE 是否使用蓝牙方式
     * @param ssid     路由器ssid
     * @param password 路由器密码
     */
    @ReactMethod
    public void setDeviceNetwork(boolean isUseBLE, String ssid, String password, String url) {
        if (isUseBLE) {
            GranwinAgent.getInstance().bleSetDeviceNetwork(ssid, password, url, new GranwinAgent.SetDeviceNetworkListener() {
                @Override
                public void onConnectSuccess(SetDeviceNetworkResultEntity setDeviceNetworkResultEntity) {
                    LogUtil.d("配网成功,mac=" + setDeviceNetworkResultEntity.getMAC() + ",pk=" + setDeviceNetworkResultEntity.getPK());

                    WritableMap params = Arguments.createMap();
                    params.putString("way", "ble");
                    params.putString("status", "success");
                    params.putString("mac", setDeviceNetworkResultEntity.getMAC());
                    params.putString("pk", setDeviceNetworkResultEntity.getPK());
                    sendEvent(getReactApplicationContext(), "Granwin_SetDeviceNetwork", params);
                }

                @Override
                public void onConnectFail(String var1) {
                    LogUtil.d("配网失败," + var1);

                    WritableMap params = Arguments.createMap();
                    params.putString("way", "ble");
                    params.putString("status", "fail");
                    sendEvent(getReactApplicationContext(), "Granwin_SetDeviceNetwork", params);
                }
            });
        } else {
            GranwinAgent.getInstance().setDeviceNetwork(ssid, password, url, new GranwinAgent.SetDeviceNetworkListener() {
                @Override
                public void onConnectSuccess(SetDeviceNetworkResultEntity setDeviceNetworkResultEntity) {
                    LogUtil.d("配网成功,mac=" + setDeviceNetworkResultEntity.getMAC() + ",pk=" + setDeviceNetworkResultEntity.getPK());

                    WritableMap params = Arguments.createMap();
                    params.putString("way", "ap");
                    params.putString("status", "success");
                    params.putString("mac", setDeviceNetworkResultEntity.getMAC());
                    params.putString("pk", setDeviceNetworkResultEntity.getPK());
                    sendEvent(getReactApplicationContext(), "Granwin_SetDeviceNetwork", params);
                }

                @Override
                public void onConnectFail(String var1) {
                    LogUtil.d("配网失败," + var1);

                    WritableMap params = Arguments.createMap();
                    params.putString("way", "ap");
                    params.putString("status", "fail");
                    sendEvent(getReactApplicationContext(), "Granwin_SetDeviceNetwork", params);
                }
            });
        }
    }

    @ReactMethod
    public void stopSetDeviceNetwork() {
        GranwinAgent.getInstance().stopSetDeviceNetwork();
    }

    /**
     * aws登录
     */
    @ReactMethod
    public void loginAWS(String clientID, String mCustomerSpecificEndpoint, String token, String accountId, String identityPoolId, String mRegion) {
        GranwinAgent.getInstance().initAWSIotClient(context, clientID, mCustomerSpecificEndpoint, token, accountId, identityPoolId, mRegion);
    }

    /**
     * 查询设备状态  如果收到回复，会在Granwin_AWS_shadow回调
     */
    @ReactMethod
    public void queryDevStatus(String mac) {
        GranwinAgent.getInstance().getAWSDeviceStatus(mac);
    }

    /**
     * 查询设备状态  如果收到回复，会在Granwin_AWS_shadow回调
     * <p>
     * params例子：{Switch_light:true}
     */
    @ReactMethod
    public void setDevParams(String account, String pk, String mac, ReadableMap rnMap) {
        ReadableNativeMap newMap = (ReadableNativeMap) rnMap;
        Map map = newMap.toHashMap();
        GranwinAgent.getInstance().setAWSDeviceStatus(
                account,
                pk,
                mac,
                map);
    }

    /**
     * Facebook登录
     */
    @ReactMethod
    public void faceBookLogin() {
        Amplify.Auth.signInWithSocialWebUI(AuthProvider.facebook(), context.getCurrentActivity(),
                result -> {
                    Log.i("Amplify_faceBookLogin", result.toString());
                    sendThirdLoginResult(true, "facebook", result.toString());
                },
                error -> {
                    Log.e("Amplify_faceBookLoginE", error.toString());
                    sendThirdLoginResult(false, "facebook", error.toString());
                }
        );
    }

    /**
     * 谷歌登录
     */
    @ReactMethod
    public void googleLogin() {
        Amplify.Auth.signInWithSocialWebUI(AuthProvider.google(), context.getCurrentActivity(),
                result -> {
                    Log.i("Amplify_googleLogin", result.toString());
                    sendThirdLoginResult(true, "google", result.toString());
                },
                error -> {
                    Log.e("Amplify_googleLoginE", error.toString());
                    sendThirdLoginResult(false, "google", error.toString());
                }
        );
    }

    public void sendThirdLoginResult(boolean isSuccess, String platform, String result) {
        WritableMap params = Arguments.createMap();
        params.putBoolean("isSuccess", isSuccess);
        params.putString("platform", platform);
        params.putString("result", result);
        sendEvent(getReactApplicationContext(), "Third_Login_Result", params);
    }

    @ReactMethod
    public void isLocServiceEnable(Callback callback) {
        boolean isLocServiceEnable = LocationUtils.isLocServiceEnable(context);
        callback.invoke(isLocServiceEnable);
    }

    @ReactMethod
    public void openGps() {
        Intent intent = new Intent();
        intent.setAction(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
        context.getCurrentActivity().startActivity(intent);
    }

    @ReactMethod
    public void toWifiSetting() {
        Intent intent = new Intent();
        intent.setAction(Settings.ACTION_WIFI_SETTINGS);
        context.getCurrentActivity().startActivity(intent);
    }

    @ReactMethod
    public void toAppSetting() {
        context.getCurrentActivity().startActivity(new Intent(Settings.ACTION_SETTINGS));
    }


    /**
     * 扫描WiFi
     */
    @ReactMethod
    public void startScanWifi(Callback callback) {
        if (wifiManager == null) {
            callback.invoke(false);
            return;
        }
        boolean scanResult = wifiManager.startScan(); //最好检查下返回值，因为这个方法可能会调用失败
        callback.invoke(scanResult);
    }

    @ReactMethod
    public void getWifiList(Callback callback) {
        WritableMap params = Arguments.createMap();
        if (wifiManager != null) {
            Gson gson = new Gson();
            String jsonStr = gson.toJson(wifiManager.getScanResults());
            params.putBoolean("result", true);
            params.putString("data", jsonStr);
            callback.invoke(params);
        } else {
            params.putBoolean("result", false);
            callback.invoke(params);
        }
    }

    @ReactMethod
    public void buildVersionBigAndroid12(Callback callback) {
        //Android 版本大于等于 Android12时
        callback.invoke(Build.VERSION.SDK_INT >= Build.VERSION_CODES.S);
    }
}
