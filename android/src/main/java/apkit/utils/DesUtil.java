package apkit.utils;

import android.util.Log;

import java.nio.charset.Charset;
import java.util.Random;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.DESKeySpec;
import javax.crypto.spec.IvParameterSpec;

public class DesUtil {
    private static final char[] HEX_DIGITS_UPPER =
            {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
    private static final char[] HEX_DIGITS_LOWER =
            {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};

    //V3协议加密字典
    public static final int[] KEY_DICTIONARY = {0xE2, 0x67, 0x57, 0x84, 0x3F, 0x42, 0x3B, 0x58, 0xB0, 0xF1, 0xBC, 0xC2, 0x7B, 0xE4, 0xD1, 0x2A, 0x13, 0x64, 0xC3, 0xDB, 0xBD, 0xB0, 0xC6, 0x18, 0x8A, 0xED, 0x73, 0xBB, 0x3D, 0x98, 0x43, 0x92, 0xB0, 0xB3, 0x8C, 0x30, 0xB6, 0x9C, 0x11, 0xA1, 0xB7, 0x45, 0x89, 0xCF, 0x11, 0x17, 0x2F, 0xD3, 0x46, 0xB1, 0xB6, 0x8D, 0xE2, 0x04, 0x5D, 0x6A, 0x69, 0x18, 0xE2, 0x02, 0x32, 0x59, 0xB0, 0xA1, 0x33, 0xB2, 0xB6, 0x91, 0xC9, 0xAA, 0xB4, 0x9E, 0x9E, 0x71, 0xAF, 0x3A, 0x5E, 0xD0, 0xEF, 0xFE, 0x58, 0x93, 0x38, 0x1B, 0xA1, 0xFE, 0x11, 0x30, 0x6C, 0x6D, 0xE6, 0x07, 0x86, 0x93, 0x6D, 0x82, 0x0C, 0x36, 0x24, 0x00, 0x3D, 0x00, 0x29, 0xDB, 0x81, 0xD2, 0x77, 0xEF, 0x2A, 0xC9, 0x23, 0xF4, 0x50, 0x85, 0x55, 0x07, 0x92, 0x37, 0x18, 0x7C, 0xC7, 0xA5, 0x5F, 0x0B, 0xE7, 0xA1, 0x5F, 0x95, 0xC0, 0x8D, 0x23, 0x03, 0x81, 0x7E, 0x2D, 0x52, 0x32, 0xFE, 0x72, 0xB7, 0xDE, 0x01, 0xA3, 0x49, 0x79, 0x4B, 0x04, 0xB5, 0xB3, 0xC4, 0xC3, 0xC8, 0xB0, 0x71, 0x90, 0x2C, 0x6E, 0xB5, 0x0F, 0x4C, 0x13, 0x18, 0xE7, 0xBE, 0x68, 0xA1, 0x83, 0xAF, 0x2F, 0xC2, 0xBA, 0x40, 0x9C, 0x58, 0x25, 0x1A, 0x50, 0x35, 0x5A, 0xA5, 0x4E, 0xE4, 0x77, 0xF0, 0xFD, 0x90, 0xC0, 0x43, 0x6D, 0x0E, 0x26, 0x91, 0x8B, 0xBB, 0x65, 0xFA, 0xB3, 0xBF, 0x44, 0xD9, 0x2E, 0xA5, 0x78, 0xC6, 0x34, 0xAF, 0x6A, 0x5F, 0x03, 0x63, 0x4E, 0x10, 0xE2, 0xF8, 0xD9, 0x95, 0xE6, 0x83, 0x01, 0xCB, 0x39, 0x0B, 0x31, 0xD8, 0x5C, 0xF2, 0x83, 0xBD, 0x35, 0x4C, 0x5D, 0x98, 0x21, 0x12, 0x8A, 0x9C, 0xF6, 0x01, 0xE3, 0x51, 0xA7, 0x14, 0x13, 0xD1, 0xFD, 0xF3, 0x41, 0x68, 0x50, 0x02, 0x03, 0x94, 0x81, 0xA7, 0x72, 0xBB};

    /**
     * 加密 外部调用
     *
     * @param srcStr
     * @param charset
     * @param sKey
     * @return
     */

    public static String xorEncrypt(String srcStr, Charset charset, String sKey) {
        byte[] src = srcStr.getBytes(charset);
        String hexResult = "";
        try {
            int random = new Random().nextInt(255);
            int offset = random ^ Integer.parseInt(sKey, 16);
            for (int i = 0; i < src.length; i++) {
                if (offset >= KEY_DICTIONARY.length) {
                    offset = 0;
                }
                src[i] = (byte) (src[i] ^ KEY_DICTIONARY[offset]);
                offset++;
            }
            hexResult = leftPadString(Integer.toHexString(random), '0', 2) + parseByte2HexStr(src);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return hexResult.toLowerCase();
    }

    /**
     * 解密 外部调用
     *
     * @param hexStr
     * @param sKey
     * @return
     */

    public static String xorDecrypt(String hexStr, Charset charset, String sKey) throws Exception {
        String hex_random = hexStr.substring(0, 2);
        int random = Integer.parseInt(hex_random, 16);
        byte[] src = parseHexStr2Byte(hexStr.substring(2));
        int offset = random ^ Integer.parseInt(sKey, 16);
        for (int i = 0; i < src.length; i++) {
            if (offset >= KEY_DICTIONARY.length) {
                offset = 0;
            }
            src[i] = (byte) (src[i] ^ KEY_DICTIONARY[offset]);
            offset++;
        }
        LogUtil.d(CommonUtils.getHexBinString(src));
        return new String(src, charset);
    }

    /**
     * 加密 内部调用
     *
     * @param data
     * @param sKey
     * @return
     */

    public static byte[] encrypt(byte[] data, String sKey) {
        try {
            byte[] key = sKey.getBytes();
            // 初始化向量
            IvParameterSpec iv = new IvParameterSpec(key);
            DESKeySpec desKey = new DESKeySpec(key);
            // 创建一个密匙工厂，然后用它把DESKeySpec转换成securekey
            SecretKeyFactory keyFactory = SecretKeyFactory.getInstance("DES");
            SecretKey securekey = keyFactory.generateSecret(desKey);
            // Cipher对象实际完成加密操作
            Cipher cipher = Cipher.getInstance("DES/CBC/NoPadding");
            // 用密匙初始化Cipher对象
            cipher.init(Cipher.ENCRYPT_MODE, securekey, iv);
            // 现在，获取数据并加密
            // 正式执行加密操作
            return cipher.doFinal(data);
        } catch (Throwable e) {
            e.printStackTrace();
        }
        return null;
    }

    /**
     * 解密 外部调用
     *
     * @param hexStr
     * @param sKey
     * @return
     */

    public static String decrypt(String hexStr, Charset charset, String sKey) throws Exception {
        byte[] src = parseHexStr2Byte(hexStr);
        byte[] buf = decrypt(src, sKey);
        return new String(buf, charset);
    }

    /**
     * 解密 内部调用
     *
     * @param src
     * @param sKey
     * @return
     */

    public static byte[] decrypt(byte[] src, String sKey) throws Exception {
        byte[] key = sKey.getBytes();
        // 初始化向量
        IvParameterSpec iv = new IvParameterSpec(key);
        // 创建一个DESKeySpec对象
        DESKeySpec desKey = new DESKeySpec(key);
        // 创建一个密匙工厂
        SecretKeyFactory keyFactory = SecretKeyFactory.getInstance("DES");
        // 将DESKeySpec对象转换成SecretKey对象
        SecretKey securekey = keyFactory.generateSecret(desKey);
        // Cipher对象实际完成解密操作
        Cipher cipher = Cipher.getInstance("DES/CBC/NoPadding");
        // 用密匙初始化Cipher对象
        cipher.init(Cipher.DECRYPT_MODE, securekey, iv);
        // 真正开始解密操作
        return cipher.doFinal(src);
    }


    //crc加密
    public static int CRC_XModem(byte[] bytes) {
        int crc = 0x00;
        int polynomial = 0x1021;
        for (int index = 0; index < bytes.length; index++) {
            byte b = bytes[index];
            for (int i = 0; i < 8; i++) {
                boolean bit = ((b >> (7 - i) & 1) == 1);
                boolean c15 = ((crc >> 15 & 1) == 1);
                crc <<= 1;
                if (c15 ^ bit) {
                    crc ^= polynomial;
                }
            }
        }
        crc &= 0xffff;
        return crc;
    }

    /**
     * 位运算转换 int转byte
     *
     * @param intValue
     * @return
     */
    private static byte[] intToByte2(int intValue) {
        byte[] bytes = new byte[4];
        bytes[0] = (byte) (intValue >> 24);
        bytes[1] = (byte) (intValue >> 16);
        bytes[2] = (byte) (intValue >> 8);
        bytes[3] = (byte) (intValue);
        return bytes;
    }


    /**
     * 将二进制转换成16进制
     *
     * @param buf
     * @return
     */

    public static String parseByte2HexStr(byte buf[]) {
        StringBuffer sb = new StringBuffer();
        for (int i = 0; i < buf.length; i++) {
            String hex = Integer.toHexString(buf[i] & 0xFF);
            if (hex.length() == 1) {
                hex = '0' + hex;
            }
            sb.append(hex.toUpperCase());
        }
        return sb.toString();
    }

    /**
     * 在字符串的左边添加多个字符pad，直到字符串的长度达到length为止，如果原始长度已经大于length，直接返回源串
     *
     * @param str    源字符串
     * @param pad    新加的站位符，通常是空格或0等参数
     * @param length 目标长度
     * @return 长度大于或等于length的新字符串
     */
    public static String leftPadString(String str, char pad, int length) {
        if (str.length() >= length)
            return str;
        StringBuffer sb = new StringBuffer();
        while (sb.length() < length - str.length())
            sb.append(pad);
        sb.append(str);
        return sb.toString();
    }

    /**
     * 在字符串的右边添加多个字符pad，直到字符串的长度达到length为止，如果原始长度已经大于length，直接返回源串
     *
     * @param str    源字符串
     * @param pad    新加的站位符，通常是空格或0等参数
     * @param length 目标长度
     * @return 长度大于或等于length的新字符串
     */
    public static String rightPadString(String str, char pad, int length) {
        if (str.length() >= length)
            return str;
        StringBuffer sb = new StringBuffer(str);
        while (sb.length() < length)
            sb.append(pad);
        return sb.toString();
    }

    /**
     * 将16进制转换为二进制
     *
     * @param hexStr
     * @return
     */

    public static byte[] parseHexStr2Byte(String hexStr) {
        if (hexStr.length() < 1) return null;
        byte[] result = new byte[hexStr.length() / 2];
        for (int i = 0; i < hexStr.length() / 2; i++) {
            int high = Integer.parseInt(hexStr.substring(i * 2, i * 2 + 1), 16);
            int low = Integer.parseInt(hexStr.substring(i * 2 + 1, i * 2 + 2), 16);
            result[i] = (byte) (high * 16 + low);
        }
        return result;
    }


    /**
     * byte数组转化为16进制的String
     *
     * @param byteData byte[] 字节数组
     * @return String 把字节数组转换成可视字符串
     */
    public static String toHex(byte byteData[]) {
        return toHex(byteData, 0, byteData.length);
    }

    /**
     * 将字符串data按照encode转化为byte数组，然后转化为16进制的String
     *
     * @param data   源字符串
     * @param encode 字符编码
     * @return 把字节数组转换成可视字符串
     */
    public static String toHex(String data, String encode) {
        try {
            return toHex(data.getBytes(encode));
        } catch (Exception e) {
            Log.e(LogUtil.TAG, "toHex:" + data + ",encode:" + encode);
        }
        return "";
    }

    /**
     * byte转化为16进制的String
     *
     * @param b
     * @return 16进制的String
     */
    public static String toHex(byte b) {
        byte[] buf = {b};
        return toHex(buf);
    }

    final static char[] digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};

    /**
     * byte数组的部分字节转化为16进制的String
     *
     * @param byteData 待转换的byte数组
     * @param offset   开始位置
     * @param len      字节数
     * @return 16进制的String
     */
    public static String toHex(byte byteData[], int offset, int len) {
        char buf[] = new char[len * 2];
        int k = 0;
        for (int i = offset; i < len; i++) {
            buf[k++] = digits[((int) byteData[i] & 0xff) >> 4];
            buf[k++] = digits[((int) byteData[i] & 0xff) % 16];
        }
        return new String(buf);
    }
}