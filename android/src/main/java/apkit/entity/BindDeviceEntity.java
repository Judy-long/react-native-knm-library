package apkit.entity;

public class BindDeviceEntity {
    private String appId;
    private String appSecret;
    private String bDeviceName;
    private String bProductKey;
    private String username;

    public String getAppId() {
        return appId;
    }

    public void setAppId(String appId) {
        this.appId = appId;
    }

    public String getAppSecret() {
        return appSecret;
    }

    public void setAppSecret(String appSecret) {
        this.appSecret = appSecret;
    }

    public String getbDeviceName() {
        return bDeviceName;
    }

    public void setbDeviceName(String bDeviceName) {
        this.bDeviceName = bDeviceName;
    }

    public String getbProductKey() {
        return bProductKey;
    }

    public void setbProductKey(String bProductKey) {
        this.bProductKey = bProductKey;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }
}
