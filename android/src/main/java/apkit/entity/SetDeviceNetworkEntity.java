package apkit.entity;

import java.io.Serializable;

public class SetDeviceNetworkEntity implements Serializable{
    private int CID;
    private SetDeviceNetworkInnerEntity PL;

    public int getCID() {
        return CID;
    }

    public void setCID(int CID) {
        this.CID = CID;
    }

    public SetDeviceNetworkInnerEntity getPL() {
        return PL;
    }

    public void setPL(SetDeviceNetworkInnerEntity PL) {
        this.PL = PL;
    }


}
