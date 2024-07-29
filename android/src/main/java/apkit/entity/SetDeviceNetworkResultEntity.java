package apkit.entity;

public class SetDeviceNetworkResultEntity {
    private int CID;
    private int RC;
    private String PK = "999999999999999999";
    private String MID;
    private String PL;
    private String MAC;
    private String FVER;

    public String getFVER() {
        return FVER;
    }

    public void setFVER(String FVER) {
        this.FVER = FVER;
    }

    public String getPK() {
        return PK;
    }

    public void setPK(String PK) {
        this.PK = PK;
    }

    public String getMID() {
        return MID;
    }

    public void setMID(String MID) {
        this.MID = MID;
    }

    public int getCID() {
        return CID;
    }

    public void setCID(int CID) {
        this.CID = CID;
    }

    public int getRC() {
        return RC;
    }

    public void setRC(int RC) {
        this.RC = RC;
    }

    public String getMAC() {
        return MAC;
    }

    public void setMAC(String MAC) {
        this.MAC = MAC;
    }

    public String getPL() {
        return PL;
    }

    public void setPL(String PL) {
        this.PL = PL;
    }
}
