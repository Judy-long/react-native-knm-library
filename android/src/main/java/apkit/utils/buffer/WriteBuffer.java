package apkit.utils.buffer;


/**
 * 写数据
 *
 * @author Liuxy
 * @2015年1月14日上午11:51:58 </br>
 * @explain
 */
@SuppressWarnings("unused")
public class WriteBuffer {
    // 当前的数据
    private byte[] buf;
    // 当前写入的索引
    private int index;

    /**
     * @param size 需要写入多大数据
     */
    public WriteBuffer(int size) {
        buf = new byte[size];
        index = 0;
    }

    public void addSize(int size) {
        byte[] addbyte = new byte[buf.length + size];
        System.arraycopy(buf, 0, addbyte, 0, buf.length);
        buf = addbyte;
    }


    public int size() {
        return buf.length;
    }

    /**
     * 写2个字节short
     *
     * @param srt
     */
    public void writeShort(short srt) {

        byte[] srtbyte = shortToByteArray(srt);
        writeBytes(srtbyte);
    }

    /**
     * 将16位的short转换成byte数组
     *
     * @param s short
     * @return byte[] 长度为2
     * 高位在前  低位在后
     */
    public static byte[] shortToByteArray(short s) {
//        byte[] targets = new byte[2];
//        targets[0] = (byte) (s & 0xff); // 获得低位字节
//        targets[1] = (byte) (s >>> 8);// 获得高位字节

        // for (int i = 0; i < 2; i++) {
        // int offset = (targets.length - 1 - i) * 8;
        // targets[i] = (byte) ((s >>> offset) & 0xff);
        // }

        byte[] targets = new byte[2];
        for (int i = 0; i < 2; i++) {
            int offset = (targets.length - 1 - i) * 8;
            targets[i] = (byte) ((s >>> offset) & 0xff);
        }
        return targets;
    }


    /**
     * 将32位整数转换成长度为4的byte数组
     *
     * @param i int
     * @return byte[]
     */
    public static byte[] intToByteArray(int i) {
        byte[] result = new byte[4];
        result[3] = (byte) ((i >> 24) & 0xFF);
        result[2] = (byte) ((i >> 16) & 0xFF);
        result[1] = (byte) ((i >> 8) & 0xFF);
        result[0] = (byte) (i & 0xFF);
        return result;
    }

    /**
     * 写2个字节short
     *
     * @param srt
     */
    public void writeShort(int srt) {
        writeShort((short) srt);
    }

    /**
     * 获取byte array
     *
     * @return
     */
    public byte[] array() {
        return buf;
    }

    public byte getIndex(int i) {
//        if (i<0||i>=buf.length){
//            return 0x00;
//        }
        return buf[i];
    }

    /**
     * 写4个字节int
     *
     * @param i
     */
    public void writeInt(int i) {
        byte[] srtbyte = intToByteArray(i);
        writeBytes(srtbyte);
    }

    /**
     * 写4个字节int
     *
     * @param i
     */
    public void writeInt(int i, int index) {
        byte[] srtbyte = intToByteArray(i);
        writeBytes(srtbyte, index);
    }

    /**
     * 写入byte[]
     *
     * @param data
     */
    public void writeBytes(byte[] data, int index) {
        int len = data.length;
        System.arraycopy(data, 0, buf, index, len);
        index += len;
    }

    /**
     * 写入byte[]
     *
     * @param data
     */
    public void writeBytes(byte[] data) {
        int len = data.length;
        System.arraycopy(data, 0, buf, index, len);
        index += len;
    }

    public void writeBytes(WriteBuffer data) {
        int len = data.size();
        System.arraycopy(data.buf, 0, buf, index, len);
        index += len;
    }

    /**
     * 返回当前写的索引值
     *
     * @return
     */
    public int getIndex() {
        return index;

    }

    public void setIndex(int index) {
        this.index = index;
    }

    /**
     * 写入1个字节的布尔
     *
     * @param b
     */
    public void writeBoolean(boolean b) {
        byte by = 0;
        if (b) {
            by = 0x01;
        }
        writeByte(by);
    }

    /**
     * 写入1个字节的byte
     *
     * @param b
     */
    public void writeByte(int b) {
        writeByte((byte) b);
    }

    public void writeByte(byte b) {
        buf[index] = b;
        index++;
    }
}
