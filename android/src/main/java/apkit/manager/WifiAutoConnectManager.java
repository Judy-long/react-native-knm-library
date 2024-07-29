package apkit.manager;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.NetworkSpecifier;
import android.net.wifi.ScanResult;
import android.net.wifi.SupplicantState;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiConfiguration.AuthAlgorithm;
import android.net.wifi.WifiConfiguration.KeyMgmt;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.net.wifi.WifiNetworkSpecifier;
import android.os.PatternMatcher;
import android.text.TextUtils;
import android.util.Log;

import apkit.utils.LogUtil;

import java.util.List;

public class WifiAutoConnectManager {

    private static final String TAG = WifiAutoConnectManager.class
            .getSimpleName();

    WifiManager wifiManager;
    Context mContext;

    // 定义几种加密方式，一种是WEP，一种是WPA，还有没有密码的情况
    public enum WifiCipherType {
        WIFICIPHER_WEP, WIFICIPHER_WPA, WIFICIPHER_NOPASS, WIFICIPHER_INVALID
    }

    // 构造函数
    public WifiAutoConnectManager(WifiManager wifiManager, Context mContext) {
        this.mContext = mContext;
        this.wifiManager = wifiManager;
    }

    // 提供一个外部接口，传入要连接的无线网
    public void connect(String ssid, String password, WifiCipherType type) {
        Thread thread = new Thread(new ConnectRunnable(ssid, password, type));
        thread.start();
    }

    // 查看以前是否也配置过这个网络
    private WifiConfiguration isExsits(String SSID) {
        List<WifiConfiguration> existingConfigs = wifiManager
                .getConfiguredNetworks();
        if (existingConfigs != null) {
            for (WifiConfiguration existingConfig : existingConfigs) {
                if (existingConfig.SSID != null) {
                    if (existingConfig.SSID.equals("\"" + SSID + "\"")) {
                        return existingConfig;
                    }
                }
            }
        }
        return null;
    }

    private WifiConfiguration createWifiInfo(String SSID, String Password,
                                             WifiCipherType Type) {
        WifiConfiguration config = new WifiConfiguration();
        config.allowedAuthAlgorithms.clear();
        config.allowedGroupCiphers.clear();
        config.allowedKeyManagement.clear();
        config.allowedPairwiseCiphers.clear();
        config.allowedProtocols.clear();
        config.SSID = "\"" + SSID + "\"";
        // config.SSID = SSID;
        // nopass
        if (Type == WifiCipherType.WIFICIPHER_NOPASS) {
            // config.wepKeys[0] = "";
            config.allowedKeyManagement.set(KeyMgmt.NONE);
            // config.wepTxKeyIndex = 0;
        }
        // wep
        if (Type == WifiCipherType.WIFICIPHER_WEP) {
            if (!TextUtils.isEmpty(Password)) {
                if (isHexWepKey(Password)) {
                    config.wepKeys[0] = Password;
                } else {
                    config.wepKeys[0] = "\"" + Password + "\"";
                }
            }
            config.allowedAuthAlgorithms.set(AuthAlgorithm.OPEN);
            config.allowedAuthAlgorithms.set(AuthAlgorithm.SHARED);
            config.allowedKeyManagement.set(KeyMgmt.NONE);
            config.wepTxKeyIndex = 0;
        }
        // wpa
        if (Type == WifiCipherType.WIFICIPHER_WPA) {
            config.preSharedKey = "\"" + Password + "\"";
            config.hiddenSSID = true;
            config.allowedAuthAlgorithms
                    .set(AuthAlgorithm.OPEN);
            config.allowedGroupCiphers.set(WifiConfiguration.GroupCipher.TKIP);
            config.allowedKeyManagement.set(KeyMgmt.WPA_PSK);
            config.allowedPairwiseCiphers
                    .set(WifiConfiguration.PairwiseCipher.TKIP);
            // 此处需要修改否则不能自动重联
            // config.allowedProtocols.set(WifiConfiguration.Protocol.WPA);
            config.allowedGroupCiphers.set(WifiConfiguration.GroupCipher.CCMP);
            config.allowedPairwiseCiphers
                    .set(WifiConfiguration.PairwiseCipher.CCMP);
            config.status = WifiConfiguration.Status.ENABLED;

        }
        return config;
    }

    // 打开wifi功能
    private boolean openWifi() {
        boolean bRet = true;
        if (!wifiManager.isWifiEnabled()) {
            bRet = wifiManager.setWifiEnabled(true);
        }
        return bRet;
    }

    // 关闭WIFI
    private void closeWifi() {
        if (wifiManager.isWifiEnabled()) {
            wifiManager.setWifiEnabled(false);
        }
    }

    class ConnectRunnable implements Runnable {
        private String ssid;

        private String password;

        private WifiCipherType type;

        public ConnectRunnable(String ssid, String password, WifiCipherType type) {
            this.ssid = ssid;
            this.password = password;
            this.type = type;
        }

        @Override
        public void run() {
            connectToWifi(mContext, ssid, password);

           /* // 打开wifi
            openWifi();
            // 开启wifi功能需要一段时间(我在手机上测试一般需要1-3秒左右)，所以要等到wifi
            // 状态变成WIFI_STATE_ENABLED的时候才能执行下面的语句
            while (wifiManager.getWifiState() == WifiManager.WIFI_STATE_ENABLING) {
                try {
                    // 为了避免程序一直while循环，让它睡个100毫秒检测……
                    Thread.sleep(100);

                } catch (InterruptedException ie) {
                    Log.i(TAG, ie.toString());
                }
            }

            //disable others
            *//*for (WifiConfiguration wifiConfiguration : wifiManager.getConfiguredNetworks()) {
                wifiManager.disableNetwork(wifiConfiguration.networkId);
            }*//*
             *//*
            WifiConfiguration tempConfig = isExsits(ssid);

            if (tempConfig != null) {
                boolean ret = wifiManager.removeNetwork(tempConfig.networkId);
                wifiManager.saveConfiguration();
                LogUtil.d("removeNetwork->" + ret);
            }
            WifiConfiguration wifiConfig = createWifiInfo(ssid, password, type);
            if (wifiConfig == null) {
                LogUtil.d("wifiConfig is null!");
                return;
            }
            int netID = wifiManager.addNetwork(wifiConfig);
            boolean enabled = wifiManager.enableNetwork(netID, true);
            boolean connected = wifiManager.reconnect();*//*
             *//*
            WifiAdmin wifiAdmin = new WifiAdmin(mContext);
            wifiAdmin.openWifi();
            wifiAdmin.addNetwork(wifiAdmin.CreateWifiInfo(ssid, password, 3));*//*

            WifiConfiguration tempConfig = isExsits(ssid);

            if (tempConfig != null) {
                boolean ret = wifiManager.removeNetwork(tempConfig.networkId);
                wifiManager.saveConfiguration();
                LogUtil.d("removeNetwork->" + ret);
            }
            WifiConfiguration wifiConfig = createWifiInfo(ssid, password, type);
            if (wifiConfig == null) {
                LogUtil.d("wifiConfig is null!");
                return;
            }
            int netID = wifiManager.addNetwork(wifiConfig);
            boolean enabled = wifiManager.enableNetwork(netID, true);
            boolean connected = wifiManager.reconnect();*/
        }
    }

    private static boolean isHexWepKey(String wepKey) {
        final int len = wepKey.length();

        // WEP-40, WEP-104, and some vendors using 256-bit WEP (WEP-232?)
        if (len != 10 && len != 26 && len != 58) {
            return false;
        }

        return isHex(wepKey);
    }

    private static boolean isHex(String key) {
        for (int i = key.length() - 1; i >= 0; i--) {
            final char c = key.charAt(i);
            if (!(c >= '0' && c <= '9' || c >= 'A' && c <= 'F' || c >= 'a'
                    && c <= 'f')) {
                return false;
            }
        }

        return true;
    }

    // 获取ssid的加密方式

    public static WifiCipherType getCipherType(Context context, String ssid) {
        WifiManager wifiManager = (WifiManager) context
                .getSystemService(Context.WIFI_SERVICE);

        List<ScanResult> list = wifiManager.getScanResults();

        for (ScanResult scResult : list) {

            if (!TextUtils.isEmpty(scResult.SSID) && scResult.SSID.equals(ssid)) {
                String capabilities = scResult.capabilities;
                // Log.i("hefeng","capabilities=" + capabilities);

                if (!TextUtils.isEmpty(capabilities)) {

                    if (capabilities.contains("WPA")
                            || capabilities.contains("wpa")) {
                        Log.i("hefeng", "wpa");
                        return WifiCipherType.WIFICIPHER_WPA;
                    } else if (capabilities.contains("WEP")
                            || capabilities.contains("wep")) {
                        Log.i("hefeng", "wep");
                        return WifiCipherType.WIFICIPHER_WEP;
                    } else {
                        Log.i("hefeng", "no");
                        return WifiCipherType.WIFICIPHER_NOPASS;
                    }
                }
            }
        }
        return WifiCipherType.WIFICIPHER_INVALID;
    }


    public static boolean connectToWifi(Context context, final String ssid, String password) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            NetworkSpecifier specifier =
                    new WifiNetworkSpecifier.Builder()
                            .setSsidPattern(new PatternMatcher(ssid, PatternMatcher.PATTERN_PREFIX))
                            .setWpa2Passphrase(password)
                            .setIsHiddenSsid(false)
                            .build();

            NetworkRequest request =
                    new NetworkRequest.Builder()
                            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                            .setNetworkSpecifier(specifier)
                            .build();

            final ConnectivityManager connectivityManager = (ConnectivityManager)
                    context.getSystemService(Context.CONNECTIVITY_SERVICE);

            ConnectivityManager.NetworkCallback networkCallback = new ConnectivityManager.NetworkCallback() {
                @Override
                public void onAvailable(Network network) {
                    super.onAvailable(network);
                    LogUtil.d("onAvailable");
                    connectivityManager.bindProcessToNetwork(network);
                }

                @Override
                public void onUnavailable() {
                    super.onUnavailable();
                    LogUtil.d("onUnavailable");
                    connectivityManager.unregisterNetworkCallback(this);
                }
            };
            connectivityManager.requestNetwork(request, networkCallback);
            // Release the request when done.
            // connectivityManager.unregisterNetworkCallback(networkCallback);
        } else {
            int networkId = -1;
            int c;

            final WifiManager wifiManager = (WifiManager) context.getSystemService(Context.WIFI_SERVICE);
            if (wifiManager == null) {
                LogUtil.e("No WiFi manager");
                return false;
            }

            List<WifiConfiguration> list;

            if (wifiManager.isWifiEnabled()) {
                list = wifiManager.getConfiguredNetworks();
            } else {
                if (!wifiManager.setWifiEnabled(true)) {
                    LogUtil.e("Enable WiFi failed");
                    return false;
                }
                c = 0;
                do {
                    try {
                        Thread.sleep(500);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                    list = wifiManager.getConfiguredNetworks();
                } while (list == null && ++c < 10);
            }

            if (list == null) {
                LogUtil.e("Could not get WiFi network list");
                return false;
            }

            for (WifiConfiguration i : list) {
                if (i.SSID != null && i.SSID.equals("\"" + ssid + "\"")) {
                    networkId = i.networkId;
                    break;
                }
            }

            WifiInfo info;
            if (networkId < 0) {
                WifiConfiguration conf = new WifiConfiguration();
                conf.SSID = "\"" + ssid + "\"";
                conf.preSharedKey = "\"" + password + "\"";
                networkId = wifiManager.addNetwork(conf);
                if (networkId < 0) {
                    LogUtil.e("New WiFi config failed");
                    return false;
                }
            } else {
                info = wifiManager.getConnectionInfo();
                if (info != null) {
                    if (info.getNetworkId() == networkId) {
                        LogUtil.d("Already connected to " + ssid);
                        return true;
                    }
                }
            }

            if (!wifiManager.disconnect()) {
                LogUtil.e("WiFi disconnect failed");
                return false;
            }

            if (!wifiManager.enableNetwork(networkId, true)) {
                LogUtil.e("Could not enable WiFi.");
                return false;
            }

            if (!wifiManager.reconnect()) {
                LogUtil.e("WiFi reconnect failed");
                return false;
            }

            c = 0;
            do {
                info = wifiManager.getConnectionInfo();
                if (info != null && info.getNetworkId() == networkId &&
                        info.getSupplicantState() == SupplicantState.COMPLETED && info.getIpAddress() != 0) {
                    LogUtil.e("Successfully connected to " + ssid + "," + info.getIpAddress());
                    return true;
                }
                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            } while (++c < 30);
            LogUtil.e("Failed to connect to " + ssid);
            return false;
        }
        return false;
    }
}
