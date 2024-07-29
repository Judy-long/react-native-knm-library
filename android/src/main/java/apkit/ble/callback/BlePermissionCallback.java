package apkit.ble.callback;

/**
 * Author : fyx
 * Time : On 2023/6/26 11:10
 * Description :
 */
public abstract class BlePermissionCallback {
    public abstract void onGrantSuccess();

    public abstract void onGrantFailure();

    public abstract void onGrantFailure2();
}
