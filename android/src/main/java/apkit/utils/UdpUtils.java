package apkit.utils;

import android.util.Log;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;

public class UdpUtils {

    private static String TAG = "UdpUtils";

    /**
     * 发送upd广播包
     *
     * @param host
     * @param port
     * @param message
     */
    public static void sendMessage(final String host, final int port, final String message) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                DatagramSocket datagramSocket = null;
                try {
                    Log.d(TAG, "准备发送：" + message);
                    datagramSocket = new DatagramSocket();
                    datagramSocket.setBroadcast(true);
                    InetAddress address = InetAddress.getByName(host);
                    DatagramPacket datagramPacket = new DatagramPacket(message.getBytes(), message.length(), address, port);
                    datagramSocket.send(datagramPacket);
                } catch (Exception e) {
                    Log.d(TAG, e.toString());
                } finally {
                    if (datagramSocket != null) {
                        datagramSocket.close();
                    }
                }
            }
        }).start();
    }
}
