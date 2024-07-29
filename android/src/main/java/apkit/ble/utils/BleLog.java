package apkit.ble.utils;


import android.util.Log;

import apkit.utils.LogUtil;

public final class BleLog {

    public static boolean isPrint = true;
    private static String defaultTag = "FastBle";

    public static void d(String msg) {
        if (isPrint && msg != null)
            Log.d(defaultTag, msg);
        LogUtil.d(msg);
    }

    public static void i(String msg) {
        if (isPrint && msg != null)
            Log.i(defaultTag, msg);
        LogUtil.d(msg);
    }

    public static void w(String msg) {
        if (isPrint && msg != null)
            Log.w(defaultTag, msg);
        LogUtil.d(msg);
    }

    public static void e(String msg) {
        if (isPrint && msg != null)
            Log.e(defaultTag, msg);
        LogUtil.d(msg);
    }

}
