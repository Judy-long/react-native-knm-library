package com.reactlibrary;

import android.bluetooth.BluetoothGatt;

import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import apkit.ble.BleManager;
import apkit.ble.callback.BleGattCallback;
import apkit.ble.callback.BleNotifyCallback;
import apkit.ble.callback.BleScanCallback;
import apkit.ble.callback.BleWriteCallback;
import apkit.ble.data.BleDevice;
import apkit.ble.exception.BleException;
import apkit.ble.scan.BleScanRuleConfig;
import apkit.utils.CommonUtils;
import apkit.utils.LogUtil;

class ParsedAd{
    byte flags;
    List<UUID> uuids=new ArrayList<>();
    String localName;
    byte[] ff;
}

public class RNBLEModule extends ReactContextBaseJavaModule {
    private ReactApplicationContext context;
    BleDevice curBleDevice;

    public static UUID SERVICE_UUID = UUID.fromString("0000ee01-0000-1000-8000-00805f9b34fb");
    public static UUID WRITE_CHARACTERISTIC_UUID = UUID.fromString("0000ee03-0000-1000-8000-00805f9b34fb");
    public static UUID NOTIFY_CHARACTERISTIC_UUID = UUID.fromString("0000ee02-0000-1000-8000-00805f9b34fb");

    public static UUID SERVICE_UUID2 = UUID.fromString("0000cc01-0000-1000-8000-00805f9b34fb");
    public static UUID WRITE_CHARACTERISTIC_UUID2 = UUID.fromString("0000cc03-0000-1000-8000-00805f9b34fb");

    private int bleDataID;

    //数据包的长度
    private int receiveBleDataLength;
    //数据包id
    private int receiveBleDataID;
    //数据包的当前index
    private int receiveBleDataPackageIndex;

    private String encryptionKey = "gwin0801";

    //缓存有效数据
    private List<byte[]> validData;

    public RNBLEModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;
    }

    @Override
    public String getName() {
        return "RNBLEModule";
    }

    public static void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap params) {
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(eventName, params);
    }

    public static ParsedAd parseData(byte[] adv_data) {
        ParsedAd parsedAd = new ParsedAd();
        ByteBuffer buffer = ByteBuffer.wrap(adv_data).order(ByteOrder.LITTLE_ENDIAN);
        while (buffer.remaining() > 2) {
            byte length = buffer.get();
            if (length == 0)
                break;

            byte type = buffer.get();
            length -= 1;
            switch (type) {
                case 0x01: // Flags
                    parsedAd.flags = buffer.get();
                    length--;
                    break;
                case 0x02: // Partial list of 16-bit UUIDs
                case 0x03: // Complete list of 16-bit UUIDs
                case 0x14: // List of 16-bit Service Solicitation UUIDs
                    while (length >= 2) {
                        parsedAd.uuids.add(UUID.fromString(String.format(
                                "%08x-0000-1000-8000-00805f9b34fb", buffer.getShort())));
                        length -= 2;
                    }
                    break;
                case 0x04: // Partial list of 32 bit service UUIDs
                case 0x05: // Complete list of 32 bit service UUIDs
                    while (length >= 4) {
                        parsedAd.uuids.add(UUID.fromString(String.format(
                                "%08x-0000-1000-8000-00805f9b34fb", buffer.getInt())));
                        length -= 4;
                    }
                    break;
                case 0x06: // Partial list of 128-bit UUIDs
                case 0x07: // Complete list of 128-bit UUIDs
                case 0x15: // List of 128-bit Service Solicitation UUIDs
                    while (length >= 16) {
                        long lsb = buffer.getLong();
                        long msb = buffer.getLong();
                        parsedAd.uuids.add(new UUID(msb, lsb));
                        length -= 16;
                    }
                    break;
                case 0x08: // Short local device name
                case 0x09: // Complete local device name
                    byte sb[] = new byte[length];
                    buffer.get(sb, 0, length);
                    length = 0;
                    parsedAd.localName = new String(sb).trim();
                    break;
                case (byte) 0xFF: // Manufacturer Specific Data
                    byte sb2[] = new byte[length];
                    buffer.get(sb2, 0, length);
                    length = 0;
                    parsedAd.ff =sb2;
                    break;
                default: // skip
                    break;
            }
            if (length > 0) {
                buffer.position(buffer.position() + length);
            }
        }
        return parsedAd;
    }

    /**
     * 扫描蓝牙设备
     */
    @ReactMethod
    public void scanDevices(String bleDeviceName, Callback callback) {
        LogUtil.d("RNBLEModule scanDevices, device name=" + bleDeviceName);
        BleScanRuleConfig scanRuleConfig = new BleScanRuleConfig.Builder()
                .setAutoConnect(false)      // 连接时的autoConnect参数，可选，默认false
                .setScanTimeOut(60000)              // 扫描超时时间，可选，默认10秒
                .setDeviceName(true, bleDeviceName)
                .build();
        BleManager.getInstance().initScanRule(scanRuleConfig);

        BleManager.getInstance().scan(new BleScanCallback() {
            @Override
            public void onScanStarted(boolean success) {
                if (success) {
                    LogUtil.d("RNBLEModule 开启扫描成功");
                    callback.invoke("success");
                } else {
                    LogUtil.d("RNBLEModule 开启扫描失败");
                    callback.invoke("fail");
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
                if (deviceName.contains(bleDeviceName)) {
                    LogUtil.d("RNBLEModule 描到符合要求的设备->" + bleDevice.getMac() + "---" + bleDevice.getName());

                    LogUtil.d("RNBLEModule getScanRecord->" + CommonUtils.getHexBinString(bleDevice.getScanRecord()));
                    WritableMap params = Arguments.createMap();
                    params.putString("mac", bleDevice.getMac());
                    params.putString("name", bleDevice.getName());
                    try {
                        ParsedAd parsedAd= parseData(bleDevice.getScanRecord());
                        params.putString("showMac", formatMac(CommonUtils.getHexBinString(subByte(parsedAd.ff,13, 6))));
                    } catch (Exception e) {

                    }
                    //目前只返回了mac地址给rn，有需求再修改
                    sendEvent(getReactApplicationContext(), "RNBLEModule_onScan", params);
                } else {
                    if (bleDevice.getMac() != null)
                        LogUtil.d("RNBLEModule 扫描到其他设备->" + deviceName + "," + bleDevice.getMac());
                }
            }

            @Override
            public void onScanning(BleDevice bleDevice) {

            }

            @Override
            public void onScanFinished(List<BleDevice> scanResultList) {
                LogUtil.d("RNBLEModule onScanFinished,not device");
            }
        });
    }

    private String formatMac(String mac) {
        String finalMac = "";
        finalMac += mac.substring(0, 2);
        finalMac += ":";
        finalMac += mac.substring(2, 4);
        finalMac += ":";
        finalMac += mac.substring(4, 6);
        finalMac += ":";
        finalMac += mac.substring(6, 8);
        finalMac += ":";
        finalMac += mac.substring(8, 10);
        finalMac += ":";
        finalMac += mac.substring(10, 12);
        return finalMac;
    }

    /**
     * 根据showMac连接蓝牙设备
     */
    @ReactMethod
    public void connectDeviceByShowMac(String bleDeviceName, String showMac, Callback callback) {
        LogUtil.d("RNBLEModule connectDevice, showMac=" + showMac);
        try {
            //先停止扫描
            BleManager.getInstance().cancelScan();
            //先断开
            BleManager.getInstance().disconnectAllDevice();
        }catch (Exception e){

        }

        BleScanRuleConfig scanRuleConfig = new BleScanRuleConfig.Builder()
                .setAutoConnect(false)      // 连接时的autoConnect参数，可选，默认false
                .setScanTimeOut(10000)              // 扫描超时时间，可选，默认10秒
                .setDeviceName(true, bleDeviceName)
                .build();
        BleManager.getInstance().initScanRule(scanRuleConfig);

        BleManager.getInstance().scan(new BleScanCallback() {
            @Override
            public void onScanStarted(boolean success) {
                if (success) {
                    LogUtil.d("RNBLEModule 开启扫描成功");
                } else {
                    WritableMap params = Arguments.createMap();
                    params.putString("status", "onConnectFail");
                    params.putString("exception", "蓝牙扫描失败");
                    sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);
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
                if (deviceName.contains(bleDeviceName)) {
                    LogUtil.d("RNBLEModule 描到符合要求的设备->" + bleDevice.getMac() + "---" + bleDevice.getName());
                    ParsedAd parsedAd= parseData(bleDevice.getScanRecord());
                    if (showMac.equals(formatMac(CommonUtils.getHexBinString(subByte(parsedAd.ff,13, 6))))) {
                        //先停止扫描
                        BleManager.getInstance().cancelScan();
                        BleManager.getInstance().connect(bleDevice.getMac(), new BleGattCallback() {
                            @Override
                            public void onStartConnect() {
                                LogUtil.d("RNBLEModule onStartConnect");

                                WritableMap params = Arguments.createMap();
                                params.putString("status", "onStartConnect");
                                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);
                            }

                            @Override
                            public void onConnectFail(BleDevice bleDevice, BleException exception) {
                                LogUtil.d("RNBLEModule onConnectFail");

                                WritableMap params = Arguments.createMap();
                                params.putString("status", "onConnectFail");
                                params.putString("exception", exception.toString());
                                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);
                            }

                            @Override
                            public void onConnectSuccess(BleDevice bleDevice, BluetoothGatt gatt, int status) {
                                LogUtil.d("RNBLEModule onConnectSuccess");

                                WritableMap params = Arguments.createMap();
                                params.putString("status", "onConnectSuccess");
                                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);

                                //缓存蓝牙设备实体
                                curBleDevice = bleDevice;

                                openNotify();
                            }

                            @Override
                            public void onDisConnected(boolean isActiveDisConnected, BleDevice device, BluetoothGatt gatt, int status) {
                                //连接中断
                                LogUtil.d("RNBLEModule onDisConnected");

                                WritableMap params = Arguments.createMap();
                                params.putString("status", "onDisConnected");
                                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);

                                //清除蓝牙设备实体
                                curBleDevice = null;
                            }
                        });
                    }
                }
            }

            @Override
            public void onScanning(BleDevice bleDevice) {

            }

            @Override
            public void onScanFinished(List<BleDevice> scanResultList) {
                LogUtil.d("RNBLEModule onScanFinished,not device");
            }
        });
    }

    /**
     * 根据mac地址连接蓝牙设备
     */
    @ReactMethod
    public void connectDevice(String mac, Callback callback) {
        LogUtil.d("RNBLEModule connectDevice, mac=" + mac);
        //先停止扫描
        BleManager.getInstance().cancelScan();
        //先断开
        BleManager.getInstance().disconnectAllDevice();
        BleManager.getInstance().connect(mac, new BleGattCallback() {
            @Override
            public void onStartConnect() {
                LogUtil.d("RNBLEModule onStartConnect");

                WritableMap params = Arguments.createMap();
                params.putString("status", "onStartConnect");
                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);
            }

            @Override
            public void onConnectFail(BleDevice bleDevice, BleException exception) {
                LogUtil.d("RNBLEModule onConnectFail");

                WritableMap params = Arguments.createMap();
                params.putString("status", "onConnectFail");
                params.putString("exception", exception.toString());
                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);
            }

            @Override
            public void onConnectSuccess(BleDevice bleDevice, BluetoothGatt gatt, int status) {
                LogUtil.d("RNBLEModule onConnectSuccess");

                WritableMap params = Arguments.createMap();
                params.putString("status", "onConnectSuccess");
                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);

                //缓存蓝牙设备实体
                curBleDevice = bleDevice;

                openNotify();
            }

            @Override
            public void onDisConnected(boolean isActiveDisConnected, BleDevice device, BluetoothGatt gatt, int status) {
                //连接中断
                LogUtil.d("RNBLEModule onDisConnected");

                WritableMap params = Arguments.createMap();
                params.putString("status", "onDisConnected");
                sendEvent(getReactApplicationContext(), "RNBLEModule_Connect_Status", params);

                //清除蓝牙设备实体
                curBleDevice = null;
            }
        });
    }


    /**
     * 暂停扫描
     */
    @ReactMethod
    public void stopScanDevice() {
        LogUtil.d("RNBLEModule ReactMethod");
        BleManager.getInstance().cancelScan();
    }

    /**
     * 断开当前连接的设备
     */
    @ReactMethod
    public void disConnectDevice() {
        LogUtil.d("RNBLEModule disConnectDevice");
       //if (curBleDevice != null)
        BleManager.getInstance().disconnectAllDevice();
    }

    /**
     * 发送加密后的结果 分多个包
     *
     * @param bleCode
     */
    @ReactMethod
    private void sendData(String bleCode) {
        LogUtil.d("RNBLEModule sendData=" + bleCode);
        BleManager.getInstance().write(curBleDevice, String.valueOf(SERVICE_UUID), String.valueOf(WRITE_CHARACTERISTIC_UUID), bleCode.getBytes(), true, new BleWriteCallback() {
            @Override
            public void onWriteSuccess(int current, int total, byte[] justWrite) {
                LogUtil.d("sendEffectiveData->onWriteSuccess");
            }

            @Override
            public void onWriteFailure(BleException exception) {
                LogUtil.d("sendEffectiveData->onWriteFailure->" + exception.getDescription());
            }
        });

        try {
            Thread.sleep(250);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    private byte[] subByte(byte[] b, int off, int length) {
        byte[] b1 = new byte[length];
        System.arraycopy(b, off, b1, 0, length);
        return b1;
    }

    /**
     * 打开notify
     */
    private void openNotify() {
        BleManager.getInstance().notify(
                curBleDevice,
                SERVICE_UUID.toString(),
                NOTIFY_CHARACTERISTIC_UUID.toString(),
                new BleNotifyCallback() {

                    @Override
                    public void onNotifySuccess() {
                        LogUtil.d("RNBLEModule onNotifySuccess success");

                        WritableMap params = Arguments.createMap();
                        params.putString("status", "onNotifySuccess");
                        sendEvent(getReactApplicationContext(), "RNBLEModule_Notify_Status", params);
                    }

                    @Override
                    public void onNotifyFailure(BleException exception) {
                        LogUtil.d("RNBLEModule onNotifyFailure fail," + exception.getDescription());

                        WritableMap params = Arguments.createMap();
                        params.putString("status", "onNotifyFailure");
                        params.putString("exception", exception.getDescription());
                        sendEvent(getReactApplicationContext(), "RNBLEModule_Notify_Status", params);
                    }

                    @Override
                    public void onCharacteristicChanged(byte[] data) {
                        LogUtil.d("RNBLEModule onCharacteristicChanged," + CommonUtils.getHexBinString(data));
                        if(CommonUtils.getHexBinString(data).equals("000102030405060708090A0B0C0D0E")){
                        //垃圾数据
                         LogUtil.d("RNBLEModule 垃圾数据");
                            return;
                        }
                        try {
                            parseBLEData(data);
                        } catch (Exception e) {
                        LogUtil.d("RNBLEModule catch (Exception e)");
                            e.printStackTrace();
                        }
                    }
                });
    }

    /**
     * 解析收到的蓝牙数据（加密）
     *
     * @param data
     */
    private void parseBLEData(byte[] data) {
        WritableMap params = Arguments.createMap();
        params.putString("data", CommonUtils.getHexBinString(data));
        sendEvent(getReactApplicationContext(), "RNBLEModule_Data", params);
    }
}
