package apkit.entity;

import java.io.Serializable;

public class SetDeviceNetworkInnerEntity implements Serializable{

    private String SSID;
    private String Password;

    public String getPassword() {
        return Password;
    }

    public void setPassword(String password) {
        Password = password;
    }

    public String getSSID() {
        return SSID;
    }

    public void setSSID(String SSID) {
        this.SSID = SSID;
    }
}