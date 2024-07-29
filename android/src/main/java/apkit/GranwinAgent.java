package apkit;

import android.app.Application;
import android.bluetooth.BluetoothGatt;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Handler;
import android.os.Message;
import android.text.TextUtils;

import com.google.gson.Gson;
import com.google.gson.JsonParseException;
import com.google.gson.JsonParser;
import com.google.gson.JsonSyntaxException;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.SocketException;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

import apkit.ble.BleManager;
import apkit.ble.callback.BleGattCallback;
import apkit.ble.callback.BleNotifyCallback;
import apkit.ble.callback.BleScanCallback;
import apkit.ble.callback.BleWriteCallback;
import apkit.ble.data.BleDevice;
import apkit.ble.exception.BleException;
import apkit.ble.scan.BleScanRuleConfig;
import apkit.data.GranwinCode;
import apkit.entity.ADStructBean;
import apkit.entity.SetDeviceNetworkResultEntity;
import apkit.manager.WifiAutoConnectManager;
import apkit.utils.AwsUtils;
import apkit.utils.CommonUtils;
import apkit.utils.DesUtil;
import apkit.utils.LogFileOperationUtils;
import apkit.utils.LogUtil;
import apkit.utils.buffer.ReadBuffer;
import apkit.utils.buffer.WriteBuffer;

public class GranwinAgent {

    public final String TAG = "GranwinAgent";
    public static Context mContext;
    public Context configContext;

    public String wifiSsid;
    public String wifiPassword;
    public String deviceHot;
    public String devicePassword;

    private WifiManager wifiManager = null;
    WifiAutoConnectManager manager;

    //NetworkConnectChangedReceiver networkConnectChangedReceiver;
    SetDeviceNetworkResultEntity setDeviceNetworkResultEntity;

    public ConnectDeviceListener connectDeviceListener;
    public SetDeviceNetworkListener setDeviceNetworkListener;

    private String SET_NETWORK_HOST = "10.10.100.254";
    private int SET_NETWORK_PORT = 9091;

    public final int CONNECT_DEVICE_SSID = 0x01;
    public final int SET_DEVICE_NETWORK = 0x02;
    public final int RECEIVE_DEVICE_MSG = 0x03;
    public final int CONNECT_WIFI = 0x04;

    public int connectDeviceSsidCurTime = 0;
    //连接设备热点总次数
    public final int CONNECT_DEVICE_SSID_TIMES = 15;
    //每10秒发起一次连接设备热点
    public final int CONNECT_DEVICE_SSID_INTERVAL_TIME = 5000;

    public int connectWifiCurTime = 0;
    public final int CONNECT_WIFI_TIMES = 15;
    public final int CONNECT_WIFI_INTERVAL_TIME = 5000;

    public int configNetworkCurTime = 0;
    //配网总次数
    public final int CONFIG_NETWORK_TIMES = 10;
    //每5秒发起一次配网
    public final int CONFIG_NETWORK_INTERVAL_TIME = 8000;

    private boolean isWaitConnectWifi = false;
    private boolean isReceiveConfigNetworkResult = false;

    private Handler mHandler;

    //蓝牙配网
    public static UUID SERVICE_UUID = UUID.fromString("0000ff01-0000-1000-8000-00805f9b34fb");
    public static UUID WRITE_CHARACTERISTIC_UUID = UUID.fromString("0000ff03-0000-1000-8000-00805f9b34fb");
    public static UUID NOTIFY_CHARACTERISTIC_UUID = UUID.fromString("0000ff02-0000-1000-8000-00805f9b34fb");
    //蓝牙本地
    public static UUID LOCAL_SERVICE_UUID = UUID.fromString("0000ee01-0000-1000-8000-00805f9b34fb");
    public static UUID LOCAL_NOTIFY_CHARACTERISTIC_UUID = UUID.fromString("0000ee02-0000-1000-8000-00805f9b34fb");
    public static UUID LOCAL_WRITE_CHARACTERISTIC_UUID = UUID.fromString("0000ee03-0000-1000-8000-00805f9b34fb");
    //蓝牙查询服务
    public static UUID QUERY_SERVICE_UUID = UUID.fromString("0000cc01-0000-1000-8000-00805f9b34fb");
    public static UUID QUERY_NOTIFY_CHARACTERISTIC_UUID = UUID.fromString("0000cc02-0000-1000-8000-00805f9b34fb");
    public static UUID QUERY_WRITE_CHARACTERISTIC_UUID = UUID.fromString("0000cc03-0000-1000-8000-00805f9b34fb");

    public String configURL = "";

    private String allRetData = "";
    private BleDevice curBleDevice;

    private byte[] bleData;
    private byte[] orginalBleData;
    private int bleDataID;
    private int bLESendDataAllStep;
    private int bLESendDataCurStep;
    private int receiveBleDataLength;
    private int receiveBleDataID;
    private int receiveBleDataPackageNum;

    //数据是否加密
    private boolean isEncryption = true;
    public static String encryptionKey = "gwin0801";
    private String nowWifi;
    private String nowBle = "41";
    private boolean isScan = false;//是否扫描到设备
    private boolean bleWriteFail = false;//蓝牙发包失败

    private void initHandler() {
        mHandler = new Handler() {
            @Override
            public void handleMessage(Message msg) {
                super.handleMessage(msg);
                switch (msg.what) {
                    case CONNECT_DEVICE_SSID:
                        connectDeviceSsid();
                        connectDeviceSsidCurTime++;
                        break;
                    case CONNECT_WIFI:
                        connectWifi();
                        connectWifiCurTime++;
                        break;
                    case SET_DEVICE_NETWORK:
                        configNetwork();
                        configNetworkCurTime++;
                        break;
                    case RECEIVE_DEVICE_MSG:
                        try {
                            LogUtil.d("receive device info->" + (String) msg.obj);
                            String result = (String) msg.obj;
                            if (isEncryption) {
                                try {
//                                    result = DesUtil.decrypt(result, Charset.forName("UTF-8"), encryptionKey);
//                                    result = DesUtil.encrypt(result,Charset.forName("UTF-8"),nowWifi);
//                                    result =new String(DesUtil.parseHexStr2Byte(result));
                                    result = DesUtil.xorDecrypt(result, Charset.forName("UTF-8"), nowWifi);
                                } catch (Exception e1) {
                                    e1.printStackTrace();
                                }
                                LogUtil.d("解密后：" + result);
                                result = result.substring(result.indexOf("{"), result.indexOf("}") + 1);
                                LogUtil.d("处理后：" + result);
                            }
                            setDeviceNetworkResultEntity = new Gson().fromJson(result, SetDeviceNetworkResultEntity.class);
                            if (TextUtils.isEmpty(setDeviceNetworkResultEntity.getMID())) {
                                setDeviceNetworkResultEntity.setMID(setDeviceNetworkResultEntity.getMAC());
                            }

                            mHandler.removeCallbacksAndMessages(null);

                            //startConnectWifi();
                            //10秒后设备热点消失,手机才会切换到之前记录的网络下
                            mHandler.postDelayed(new Runnable() {
                                @Override
                                public void run() {
                                    if (setDeviceNetworkListener != null) {
                                        setDeviceNetworkListener.onConnectSuccess(setDeviceNetworkResultEntity);
                                        mHandler.removeCallbacksAndMessages(null);
                                    }
                                    isReceiveConfigNetworkResult = false;
                                }
                            }, 10000);
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                        break;
                }
            }
        };
    }

    /**
     * 是否打开数据加密
     *
     * @param encryption
     */
    public void setEncryption(boolean encryption) {
        isEncryption = encryption;
    }

    public void setEncryptionKey(String encryptionKey) {
        this.encryptionKey = encryptionKey;
    }

    private GranwinAgent() {

    }

    /**
     * 获取GranwinAgent 的全局唯一实例
     *
     * @return
     */
    public static GranwinAgent getInstance() {
        return SingletonFactory.instance;
    }

    /* 此处使用一个内部类来维护单例 */
    private static class SingletonFactory {
        private static GranwinAgent instance = new GranwinAgent();
    }

    public void start(Context mContext) {
        this.mContext = mContext;

        //初始化wifi工具
        wifiManager = (WifiManager) mContext.getSystemService(Context.WIFI_SERVICE);
        manager = new WifiAutoConnectManager(wifiManager, mContext);
        initHandler();
        BleManager.getInstance().init((Application) mContext);
        BleManager.getInstance()
                .enableLog(true)
                .setReConnectCount(5, 5000)
                .setConnectOverTime(60000)
                .setOperateTimeout(5000);

        LogFileOperationUtils.init(mContext);

        /*byte[] data = new byte[]{0x01, 0x01, 0x01, 0x7B, 0x22, 0x43, 0x49, 0x44, 0x22, 0x3A, 0x33, 0x30, 0x30, 0x30, 0x36, 0x2C, 0x22, 0x52, 0x43, 0x22};
        String result = null;
        try {
            result = new String(subByte(data, 3, data.length - 3), "UTF-8");
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }
        LogUtil.d("接收到设备发送的部分数据为：" + result);*/

       /* WriteBuffer checkBuffer = new WriteBuffer(11);
        checkBuffer.writeByte(0x55);
        checkBuffer.writeByte(0xAA);
        checkBuffer.writeByte(0x01);
        checkBuffer.writeByte(0x0E);
        checkBuffer.writeByte(0x00);
        checkBuffer.writeByte(0x45);
        checkBuffer.writeByte(0x00);
        checkBuffer.writeByte(0x00);
        checkBuffer.writeByte(0x00);
        checkBuffer.writeByte(0xf9);
        checkBuffer.writeByte(0xd5);
        int check = 0;
        for (int i = 0; i < checkBuffer.array().length; i++) {
            check += checkBuffer.array()[i];
        }
        LogUtil.d(check+"");*/

        /*LinkedHashMap<String, Object> dataMap = new LinkedHashMap<>();
        dataMap.put("CID", 30005);
        dataMap.put("URL", "https://oghafnxkic.execute-api.us-west-2.amazonaws.com/Prod/device/certificate/get");
        LinkedHashMap<String, Object> plMap = new LinkedHashMap<>();
        plMap.put("Password", "linglingsan303");
        plMap.put("SSID", "Xiaomi_3084");
        dataMap.put("PL", plMap);

        orginalBleData = (new Gson().toJson(dataMap)).getBytes();

        String data = new Gson().toJson(dataMap);
        LogUtil.d("data：" + data);
        Charset CHARSET = Charset.forName("UTF-8");

        //待加密内容
        String encryptResult = DesUtil.encrypt(data, CHARSET, encryptionKey);

        LogUtil.d("加密后的结果：" + encryptResult.toLowerCase());

        try {
            bleData = encryptResult.getBytes("UTF-8");
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }

        LogUtil.d(CommonUtils.getHexBinString(bleData));

        WriteBuffer writeBuffer = new WriteBuffer(13);
        writeBuffer.writeByte(0x55);
        writeBuffer.writeByte(0xAA);
        writeBuffer.writeByte(0x01);
        writeBuffer.writeByte(0x0E);
        writeBuffer.writeShort(bleData.length);
        writeBuffer.writeShort(1);
        writeBuffer.writeByte(bleData.length % 17 == 0 ? bleData.length / 17 : bleData.length / 17 + 1);
        writeBuffer.writeBytes(CRC16Util.getParamCRC(orginalBleData));

        WriteBuffer checkBuffer = new WriteBuffer(11);
        checkBuffer.writeByte(0x55);
        checkBuffer.writeByte(0xAA);
        checkBuffer.writeByte(0x01);
        checkBuffer.writeByte(0x0E);
        checkBuffer.writeShort(bleData.length);
        checkBuffer.writeShort(1);
        checkBuffer.writeByte(bleData.length % 17 == 0 ? bleData.length / 17 : bleData.length / 17 + 1);
        checkBuffer.writeBytes(CRC16Util.getParamCRC(orginalBleData));
        int check = 0;
        for (int i = 0; i < checkBuffer.array().length; i++) {
            check += checkBuffer.array()[i];
        }

        writeBuffer.writeByte(check);
        writeBuffer.writeByte(0xFE);

        LogUtil.d("crc->" + CommonUtils.getHexBinString(CRC16Util.getParamCRC(orginalBleData)));
        LogUtil.d("准备发送的蓝牙数据长度为->" + bleData.length);
        LogUtil.d("蓝牙数据信息->" + CommonUtils.getHexBinString(writeBuffer.array()));

        List<byte[]> dataList = new ArrayList<>();
        int allPackageNum = bleData.length % 17 == 0 ? bleData.length / 17 : bleData.length / 17 + 1;
        for (int i = 0; i < allPackageNum; i++) {
            dataList.add(subByte(bleData, i * 17, bleData.length >= (i * 17 + 17) ? 17 : bleData.length - i * 17));
        }
        for (int i = 0; i < dataList.size(); i++) {
            WriteBuffer writeBuffer2 = new WriteBuffer(dataList.get(i).length + 3);
            writeBuffer2.writeShort(1);
            writeBuffer2.writeByte(i + 1);
            writeBuffer2.writeBytes(dataList.get(i));

            LogUtil.d("sendEffectiveData->" + CommonUtils.getHexBinString(writeBuffer2.array()));
        }*/
    }

    public void setConfigURL(String url) {
        if (TextUtils.isEmpty(url)) {
            return;
        }
        configURL = url;
    }


    /**
     * 连接设备热点
     *
     * @param bleDeviceName 设备发出来的蓝牙名称
     */
    public int connectDeviceByBle2(final String bleDeviceName,
                                   final String imac,
                                   final ConnectDeviceListener connectDeviceListener) {
        this.connectDeviceListener = connectDeviceListener;
        boolean isAutoConnect = false;
        isScan = false;

        BleScanRuleConfig scanRuleConfig = new BleScanRuleConfig.Builder()
                .setAutoConnect(isAutoConnect)      // 连接时的autoConnect参数，可选，默认false
                .setScanTimeOut(30000)              // 扫描超时时间，可选，默认10秒
                .setDeviceName(true, bleDeviceName)
                .build();
        BleManager.getInstance().initScanRule(scanRuleConfig);

        BleManager.getInstance().scan(new BleScanCallback() {
            @Override
            public void onScanStarted(boolean success) {
                if (success) {
                    LogUtil.d("开启扫描成功");
                } else {
                    LogUtil.d("开启扫描失败");
                    // Toast.makeText(mContext, "蓝牙没有开启，尝试wifi配置", Toast.LENGTH_SHORT).show();
                    if (connectDeviceListener != null)
                        connectDeviceListener.onConnectFail("ble not open");
                }
            }

            @Override
            public void onLeScan(BleDevice bleDevice) {
                super.onLeScan(bleDevice);
                if (bleDevice == null) {
                    return;
                }
                String deviceName = bleDevice.getName();

                if (bleDevice == null || deviceName == null) {
                    return;
                }
                if (isScan) {
                    return;
                }
                if(!TextUtils.isEmpty(bleDevice.getMac())) {
                    if (deviceName.contains(bleDeviceName) && bleDevice.getMac().equals(imac)) {
                        isScan = true;
                        connectSpecifiedBle(bleDevice, connectDeviceListener);
                    } else {
                        if (bleDevice.getMac() != null)
                            LogUtil.d("扫描到其他设备->" + deviceName + "," + bleDevice.getMac());
                    }
                }
            }

            @Override
            public void onScanning(BleDevice bleDevice) {

            }

            @Override
            public void onScanFinished(List<BleDevice> scanResultList) {
                if (curBleDevice == null) {
                    LogUtil.d("onScanFinished,not device");
                    if (connectDeviceListener != null)
                        connectDeviceListener.onConnectFail("onScanFinished,not device");
                }
            }
        });

        return GranwinCode.SUCCEED;
    }

    /**
     * 连接设备热点
     *
     * @param bleDeviceName 设备发出来的蓝牙名称
     */
    public int connectDeviceByBle(final String bleDeviceName,
                                  final ConnectDeviceListener connectDeviceListener) {
        this.connectDeviceListener = connectDeviceListener;
        boolean isAutoConnect = false;
        isScan = false;

        BleScanRuleConfig scanRuleConfig = new BleScanRuleConfig.Builder()
                .setAutoConnect(isAutoConnect)      // 连接时的autoConnect参数，可选，默认false
                .setScanTimeOut(30000)              // 扫描超时时间，可选，默认10秒
                .setDeviceName(true, bleDeviceName)
                .build();
        BleManager.getInstance().initScanRule(scanRuleConfig);

        BleManager.getInstance().scan(new BleScanCallback() {
            @Override
            public void onScanStarted(boolean success) {
                if (success) {
                    LogUtil.d("开启扫描成功");
                } else {
                    LogUtil.d("开启扫描失败");
                    // Toast.makeText(mContext, "蓝牙没有开启，尝试wifi配置", Toast.LENGTH_SHORT).show();
                    if (connectDeviceListener != null)
                        connectDeviceListener.onConnectFail("ble not open");
                }
            }

            @Override
            public void onLeScan(BleDevice bleDevice) {
                super.onLeScan(bleDevice);
                if (bleDevice == null) {
                    return;
                }
                String deviceName = bleDevice.getName();

                if (bleDevice == null || deviceName == null) {
                    return;
                }
                if (isScan) {
                    return;
                }
                if (deviceName.contains(bleDeviceName)) {
                    isScan = true;
                    connectSpecifiedBle(bleDevice, connectDeviceListener);
                } else {
                    if (bleDevice.getMac() != null)
                        LogUtil.d("扫描到其他设备->" + deviceName + "," + bleDevice.getMac());
                }
            }

            @Override
            public void onScanning(BleDevice bleDevice) {

            }

            @Override
            public void onScanFinished(List<BleDevice> scanResultList) {
                if (curBleDevice == null) {
                    LogUtil.d("onScanFinished,not device");
                    if (connectDeviceListener != null)
                        connectDeviceListener.onConnectFail("onScanFinished,not device");
                }
            }
        });

        return GranwinCode.SUCCEED;
    }

    /**
     * 连接指定蓝牙
     *
     * @param bleDevice 蓝牙设备
     */
    public void connectSpecifiedBle(BleDevice bleDevice, final ConnectDeviceListener connectDeviceListener) {
        this.connectDeviceListener = connectDeviceListener;
        LogUtil.d("描到设备->" + bleDevice.getMac());
        curBleDevice = bleDevice;
        BleManager.getInstance().cancelScan();
        //先断开
        BleManager.getInstance().disconnectAllDevice();
        BleManager.getInstance().connect(bleDevice, new BleGattCallback() {
            @Override
            public void onStartConnect() {
                LogUtil.d("onStartConnect");
            }

            @Override
            public void onConnectFail(BleDevice bleDevice, BleException exception) {
                LogUtil.d("onConnectFail");
                if (connectDeviceListener != null)
                    connectDeviceListener.onConnectFail(exception.getDescription());
            }

            @Override
            public void onConnectSuccess(BleDevice bleDevice, BluetoothGatt gatt, int status) {
                LogUtil.d("onConnectSuccess");
                curBleDevice = bleDevice;
//                nowBle = bleDevice.getMac().substring(bleDevice.getMac().length()-5,bleDevice.getMac().length()-3);
                String bleDeviceMac = DesUtil.toHex(bleDevice.getScanRecord());
                for (int i = 0; i < bleDevice.getScanRecord().length; i++) {
                    int index = Integer.parseInt(bleDeviceMac.substring(0, 2), 16);
                    if (index == 0) break;
                    if (index * 2 + 2 > bleDevice.getScanRecord().length) break;
                    ADStructBean temp = new ADStructBean(bleDeviceMac.substring(0, 2), bleDeviceMac.substring(2, 4),
                            bleDeviceMac.substring(4, index * 2 + 2));
                    if (temp.getType().toLowerCase().startsWith("ff") && temp.getContent().length() > 8) {
                        nowBle = temp.getContent().substring(temp.getContent().length() - 8, temp.getContent().length() - 6);
                    }
                    String delete = bleDeviceMac.substring(0, index * 2 + 2);
                    bleDeviceMac = bleDeviceMac.substring(delete.length());
                }
                LogUtil.d("nowBle：" + nowBle);
                if (nowBle == null) return;
                openNotify();
            }

            @Override
            public void onDisConnected(boolean isActiveDisConnected, BleDevice device, BluetoothGatt gatt, int status) {
                LogUtil.d("onDisConnected");
                curBleDevice = null;
            }
        });
    }

    private void openNotify() {
        BleManager.getInstance().notify(
                curBleDevice,
                SERVICE_UUID.toString(),
                NOTIFY_CHARACTERISTIC_UUID.toString(),
                new BleNotifyCallback() {

                    @Override
                    public void onNotifySuccess() {
                        LogUtil.d("onNotifySuccess success");
                        if (connectDeviceListener != null)
                            connectDeviceListener.onConnectSuccess();
                    }

                    @Override
                    public void onNotifyFailure(BleException exception) {
                        LogUtil.d("onNotifyFailure fail," + exception.getDescription());
                        if (connectDeviceListener != null)
                            connectDeviceListener.onConnectFail(exception.getDescription());
                    }

                    @Override
                    public void onCharacteristicChanged(byte[] data) {
                        LogUtil.d("onCharacteristicChanged," + CommonUtils.getHexBinString(data));
                        try {
                            parseBLEDataStep(data);
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                });
    }

    /**
     * 连接设备热点
     *
     * @param deviceHot 设备发出来的热点 （必填）
     */
    public int connectDeviceHot(String deviceHot, String devicePassword,
                                final ConnectDeviceListener connectDeviceListener) {
        this.deviceHot = deviceHot;
        this.devicePassword = devicePassword;
        this.connectDeviceListener = connectDeviceListener;
        connectDeviceSsidCurTime = 0;
        isWaitConnectWifi = false;
        //registerReceiver();
        mHandler.sendEmptyMessage(CONNECT_DEVICE_SSID);
        return GranwinCode.SUCCEED;
    }

    public void setConfigContext(Context configContext) {
        this.configContext = configContext;
    }

    /**
     * 停止连接设备热点
     */
    public void stopConnectDeviceHot() {
        this.connectDeviceListener = null;
        //unRegisterReceiver();
        mHandler.removeMessages(CONNECT_DEVICE_SSID);
    }


    private void connectDeviceSsid() {
        String ssid = CommonUtils.getWIFISSID(mContext);
        nowWifi = ssid.substring(ssid.length() - 4, ssid.length() - 2);
        LogUtil.d("当前连接Wi-Fi:" + ssid + ",希望连接的wifi：" + deviceHot);
        if (!TextUtils.isEmpty(ssid) && ssid.trim().startsWith(deviceHot.trim())) {
            if (connectDeviceListener != null) {
                connectDeviceListener.onConnectSuccess();
                //unRegisterReceiver();
                mHandler.removeMessages(CONNECT_DEVICE_SSID);
            }
            stopConnectDeviceHot();
            return;
        }
        if (connectDeviceSsidCurTime >= CONNECT_DEVICE_SSID_TIMES) {
            //已达到重试次数
            if (connectDeviceListener != null) {
                connectDeviceListener.onConnectFail("");
            }
            return;
        }
        connectWifi(deviceHot, devicePassword, true);
        //指定时间进行重连
        mHandler.sendEmptyMessageDelayed(CONNECT_DEVICE_SSID, CONNECT_DEVICE_SSID_INTERVAL_TIME);
    }


    //-------------------- connect wifi -----------------------

    /**
     * 开始连接wifi
     */
    public int startConnectWifi() {
        //registerReceiver();
        isWaitConnectWifi = true;
        connectWifiCurTime = 0;
        mHandler.sendEmptyMessage(CONNECT_WIFI);
        return GranwinCode.SUCCEED;
    }

    /**
     * 停止连接wifi
     */
    public void stopConnectWifi() {
        // unRegisterReceiver();
        isWaitConnectWifi = false;
        mHandler.removeMessages(CONNECT_WIFI);
    }


    private void connectWifi() {
        String ssid = CommonUtils.getWIFISSID(mContext);
        LogUtil.d("当前连接Wi-Fi:" + ssid);
        if (!TextUtils.isEmpty(ssid) && ssid.equals(wifiSsid)) {
            LogUtil.d("wifi已切换成功");
            stopConnectWifi();
            if (setDeviceNetworkListener != null) {
                setDeviceNetworkListener.onConnectSuccess(setDeviceNetworkResultEntity);
                // unRegisterReceiver();
                mHandler.removeMessages(CONNECT_WIFI);
            }
            return;
        }
        if (connectWifiCurTime >= CONNECT_WIFI_TIMES) {
            //已达到重试次数
            if (setDeviceNetworkListener != null) {
                setDeviceNetworkListener.onConnectFail("已达到重试次数");
            }
            return;
        }

        connectWifi(wifiSsid, wifiPassword, false);
        //指定时间进行重连
        mHandler.sendEmptyMessageDelayed(CONNECT_WIFI, CONNECT_WIFI_INTERVAL_TIME);
    }

    //------------------connect wifi ----------------------

    private void configNetwork() {
        if (configNetworkCurTime >= CONFIG_NETWORK_TIMES) {
            //已达到重试次数
            stopSetDeviceNetwork();
            try {
                if (setDeviceNetworkListener != null) {
                    setDeviceNetworkListener.onConnectFail("");
                }
            } catch (Exception e) {

            }
            return;
        }

        LinkedHashMap<String, Object> dataMap = new LinkedHashMap<>();
        dataMap.put("CID", 30005);
        dataMap.put("URL", configURL);
        LinkedHashMap<String, Object> plMap = new LinkedHashMap<>();
        plMap.put("SSID", wifiSsid);
        plMap.put("Password", wifiPassword);
        dataMap.put("PL", plMap);

        String data = new Gson().toJson(dataMap);
        LogUtil.d("准备发送：" + data);

        try {
            if (isEncryption) {
                Charset CHARSET = Charset.forName("UTF-8");
                //待加密内容
                String encryptResult = DesUtil.xorEncrypt(data, CHARSET, nowWifi);

                LogUtil.d("加密后的结果：" + encryptResult);

                sendMessage(SET_NETWORK_HOST, SET_NETWORK_PORT, DesUtil.parseHexStr2Byte(encryptResult));
            } else {
                //不加密
                sendMessage(SET_NETWORK_HOST, SET_NETWORK_PORT, data.getBytes("UTF-8"));
            }
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }
        mHandler.sendEmptyMessageDelayed(SET_DEVICE_NETWORK, CONFIG_NETWORK_INTERVAL_TIME);
    }


    public interface ConnectDeviceListener {
        void onConnectSuccess();

        void onConnectFail(String var1);
    }

    /**
     * 通过ble配网
     *
     * @param wifiSSID     设备要连接的wifi SSID （必填）
     * @param wifiPassword 设备要连接的wifi 密码 （必填）
     * @param configURL    配置的URL （null则表示使用默认地址）
     */
    public int bleSetDeviceNetwork(String wifiSSID, String wifiPassword, String configURL, SetDeviceNetworkListener
            setDeviceNetworkListener) {
        bleDataID++;

        this.setDeviceNetworkListener = setDeviceNetworkListener;
        this.wifiSsid = wifiSSID;
        this.wifiPassword = wifiPassword;
        if (configURL != null)
            this.setConfigURL(configURL);

        LinkedHashMap<String, Object> dataMap = new LinkedHashMap<>();
        dataMap.put("CID", 30005);
        dataMap.put("TIMEZONE", "UTC+8");
        LinkedHashMap<String, Object> plMap = new LinkedHashMap<>();
        plMap.put("SSID", wifiSsid);
        plMap.put("Password", wifiPassword);
        dataMap.put("PL", plMap);
        dataMap.put("URL", this.configURL);
        orginalBleData = (new Gson().toJson(dataMap)).getBytes();

        if (isEncryption) {
            String data = new Gson().toJson(dataMap);
            Charset CHARSET = Charset.forName("UTF-8");

            //待加密内容
            String encryptResult = DesUtil.xorEncrypt(data, CHARSET, nowBle);
            LogUtil.d("加密后的结果：" + encryptResult.toLowerCase());
            bleData = CommonUtils.toBytes(encryptResult.toLowerCase());
        } else {
            bleData = (new Gson().toJson(dataMap)).getBytes();
            LogUtil.d("有效数据为:" + CommonUtils.getHexBinString(bleData));
        }
        //清空
        allRetData = "";

        //总步骤数
        bLESendDataAllStep = (bleData.length / 17) + 1;
        //这里需要分包发送数据
        bLESendDataCurStep = 1;
        parseBLEDataStep(bleData);
        return GranwinCode.SUCCEED;
    }

    public void parseBLEDataStep(byte[] data) {
        LogUtil.d("parseBLEDataStep,bLESendDataCurStep=" + bLESendDataCurStep + ",bleDataID=" + bleDataID);
        if (bLESendDataCurStep == 1) {
            sendEffectiveData();
            bLESendDataCurStep = 2;
        } else {
            //第二阶段主要是设备往app发数据
            ReadBuffer readBuffer2 = new ReadBuffer(data, 0);
            readBuffer2.readShort();
            receiveBleDataPackageNum++;
            int curIndex = readBuffer2.readByte();
            if (true) {
                String result = null;
                if (data.length > 2) {
                    result = CommonUtils.getHexBinString(subByte(data, 2, data.length - 2));
                }

                LogUtil.d("接收到设备发送的部分数据为：" + result);
                allRetData += result;
                //结束
                if (data.length < 20) {
                    result = allRetData;
                    LogUtil.d("正在解密：" + result);
                    if (isEncryption) {
                        try {
                            result = DesUtil.xorDecrypt(result, Charset.forName("UTF-8"), nowBle);
                        } catch (Exception e1) {
                            LogUtil.d("解密失败：" + e1.getMessage());
                        }
                        LogUtil.d("解密后：" + result);
                        result = result.substring(result.indexOf("{"), result.indexOf("}") + 1);
                        LogUtil.d("处理后：" + result);
                    }

                    setDeviceNetworkResultEntity = new Gson().fromJson(result, SetDeviceNetworkResultEntity.class);
                    if (TextUtils.isEmpty(setDeviceNetworkResultEntity.getMID())) {
                        setDeviceNetworkResultEntity.setMID(setDeviceNetworkResultEntity.getMAC());
                    }

                    if (setDeviceNetworkListener != null) {
                        setDeviceNetworkListener.onConnectSuccess(setDeviceNetworkResultEntity);
                    }
                    //清空
                    allRetData = "";
                    receiveBleDataPackageNum = 0;
                }

            }

        }
    }

    private void sendEffectiveData() {
        List<byte[]> dataList = new ArrayList<>();
        int allPackageNum = bleData.length % 18 == 0 ? bleData.length / 18 : bleData.length / 18 + 1;
        for (int i = 0; i < allPackageNum; i++) {
            dataList.add(subByte(bleData, i * 18, bleData.length >= (i * 18 + 18) ? 18 : bleData.length - i * 18));
        }
        int random1 = new Random().nextInt(255);
        //需要开启线程执行，sleep会阻塞主线程
        new Thread(() -> {
            boolean isSendEmpty = false; //最后一包长度为18 是否发送空包
            for (int i = 0; i < dataList.size(); i++) {
                if (bleWriteFail) break;
                WriteBuffer writeBuffer;
                writeBuffer = new WriteBuffer(dataList.get(i).length + 2);
                writeBuffer.writeByte(random1);
                writeBuffer.writeByte(i + 1);
                writeBuffer.writeBytes(dataList.get(i));

                LogUtil.d("sendEffectiveData->" + CommonUtils.getHexBinString(writeBuffer.array()));
                BleManager.getInstance().write(curBleDevice, String.valueOf(SERVICE_UUID), String.valueOf(WRITE_CHARACTERISTIC_UUID), writeBuffer.array(), true, new BleWriteCallback() {
                    @Override
                    public void onWriteSuccess(int current, int total, byte[] justWrite) {
                        LogUtil.d("sendEffectiveData->onWriteSuccess");
                    }

                    @Override
                    public void onWriteFailure(BleException exception) {
                        LogUtil.d("sendEffectiveData->onWriteFailure->" + exception.getDescription());
                        bleWriteFail = true;
                        if (connectDeviceListener != null)
                            connectDeviceListener.onConnectFail(exception.getDescription());
                    }
                });
                if (i == dataList.size() - 1) {
                    if (dataList.get(i).length == 18) {
                        isSendEmpty = true;
                    }
                }
                try {
                    Thread.sleep(250);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
            if (isSendEmpty) {
                WriteBuffer writeBuffer;
                writeBuffer = new WriteBuffer(2);
                writeBuffer.writeByte(random1);
                writeBuffer.writeByte(dataList.size() + 1);

                LogUtil.d("sendEffectiveData->" + CommonUtils.getHexBinString(writeBuffer.array()));
                BleManager.getInstance().write(curBleDevice, String.valueOf(SERVICE_UUID), String.valueOf(WRITE_CHARACTERISTIC_UUID), writeBuffer.array(), true, new BleWriteCallback() {
                    @Override
                    public void onWriteSuccess(int current, int total, byte[] justWrite) {
                        LogUtil.d("sendEffectiveData->onWriteSuccess");
                    }

                    @Override
                    public void onWriteFailure(BleException exception) {
                        LogUtil.d("sendEffectiveData->onWriteFailure->" + exception.getDescription());
                        if (connectDeviceListener != null)
                            connectDeviceListener.onConnectFail(exception.getDescription());
                    }
                });
            }
        }).start();
    }

    private byte[] subByte(byte[] b, int off, int length) {
        byte[] b1 = new byte[length];
        System.arraycopy(b, off, b1, 0, length);
        return b1;
    }

    /**
     * 配网
     *
     * @param wifiSSID     设备要连接的wifi SSID （必填）
     * @param wifiPassword 设备要连接的wifi 密码 （必填）
     */
    public int setDeviceNetwork(String wifiSSID, String wifiPassword, String configURL, SetDeviceNetworkListener
            setDeviceNetworkListener) {
        this.setDeviceNetworkListener = setDeviceNetworkListener;
        this.wifiSsid = wifiSSID;
        this.wifiPassword = wifiPassword;
        if (configURL != null)
            this.setConfigURL(configURL);

        configNetworkCurTime = 0;
        isReceiveConfigNetworkResult = true;

        try {
            socket = new DatagramSocket();
        } catch (SocketException e) {
            e.printStackTrace();
        }
        receiveMessage();
        configNetwork();

        return GranwinCode.SUCCEED;
    }

    /**
     * 取消配网
     */
    public void stopSetDeviceNetwork() {
        isReceiveConfigNetworkResult = false;
        mHandler.removeCallbacksAndMessages(null);
        this.setDeviceNetworkListener = null;

        try {
            socket.close();
        } catch (Exception e) {

        }
    }

    private DatagramSocket socket;
    private DatagramPacket packet;

    private void sendMessage(final String host, final int port, final byte[] message) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    InetAddress address = InetAddress.getByName(host);
                    DatagramPacket datagramPacket = new DatagramPacket(message, message.length, address, port);
                    socket.send(datagramPacket);
                } catch (Exception e) {
                    LogUtil.d("sendMessage->" + e.getMessage());
                    if (connectDeviceListener != null)
                        connectDeviceListener.onConnectFail(e.getMessage());
                }
            }
        }).start();
    }

    private void receiveMessage() {
        new Thread() {
            public void run() {
                byte[] receBuf = new byte[1024];
                packet = new DatagramPacket(receBuf, receBuf.length);
                while (isReceiveConfigNetworkResult) {
                    try {
                        socket.receive(packet);
//                        String result = new String(packet.getData(), 0, packet.getLength(), "utf-8");
                        String result = DesUtil.toHex(packet.getData());

                        LogUtil.d("receiveMessage->" + result);
//                        if (isJson(result)) {
                        Message message = new Message();
                        message.what = RECEIVE_DEVICE_MSG;
                        message.obj = result;
                        mHandler.sendMessage(message);
//                        }
                    } catch (IOException e) {
                        LogUtil.d("receiveMessage->" + e.getMessage());
                        e.printStackTrace();
                    }
                }
            }
        }.start();
    }

    public static boolean isJson(String json) {
        if (TextUtils.isEmpty(json)) {
            return false;
        }

        try {
            new JsonParser().parse(json);
            return true;
        } catch (JsonSyntaxException e) {
            return false;
        } catch (JsonParseException e) {
            return false;
        }
    }

    public interface SetDeviceNetworkListener {
        void onConnectSuccess(SetDeviceNetworkResultEntity setDeviceNetworkResultEntity);

        void onConnectFail(String var1);
    }

    private void connectWifi(String ssid, String password, boolean isConnectDeviceHot) {
        LogUtil.d("connectWifi-> ssid=" + ssid + ", password=" + password);
        //弹窗提示用户去连接wifi
//        connectManually(ssid, isConnectDeviceHot);
    }

    private String mTargetSSID;

    //---------------- AWS --------------------
    public void initAWSIotClient(Context context, String clientID, String mCustomerSpecificEndpoint,
                                 String token, String accountId, String identityPoolId, String mRegion) {

        AWSDisconnect();
        LogUtil.d("initAWSIotClient,\nclientID=" + clientID + "\nmCustomerSpecificEndpoint=" + mCustomerSpecificEndpoint
                + "\ntoken=" + token
                + "\naccountId=" + accountId
                + "\nidentityPoolId=" + identityPoolId
                + "\nmRegion=" + mRegion);
        AwsUtils.getInstance().initIoTClient(context, clientID, mCustomerSpecificEndpoint, token, accountId, identityPoolId, mRegion);
    }

    public void AWSDisconnect() {
        AwsUtils.getInstance().disConnect();
    }

    public void getAWSDeviceStatus(String mac) {
        AwsUtils.getInstance().getDeviceStatus(mac);
    }

    public void setAWSDeviceStatus(String account, String productKey, String mac, Map<String, Object> params) {
        AwsUtils.getInstance().setDeviceStatus(account, productKey, mac, params);
    }

    public void test() {
        AwsUtils.getInstance().test();
    }

    public void setAWSListener(AwsUtils.AWSListener awsListener) {
        AwsUtils.getInstance().setAwsListener(awsListener);
    }

    private AwsUtils.AWSListener awsListener;

    public BleDevice getCurBleDevice() {
        return curBleDevice;
    }

    public void Log(String msg) {
        LogUtil.d(msg);
    }
}
