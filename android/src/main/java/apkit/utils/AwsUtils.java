package apkit.utils;


import android.content.Context;
import android.util.Log;

import com.amazonaws.auth.CognitoCachingCredentialsProvider;
import com.amazonaws.mobileconnectors.iot.AWSIotMqttClientStatusCallback;
import com.amazonaws.mobileconnectors.iot.AWSIotMqttManager;
import com.amazonaws.mobileconnectors.iot.AWSIotMqttNewMessageCallback;
import com.amazonaws.mobileconnectors.iot.AWSIotMqttQos;
import com.amazonaws.mobileconnectors.iot.AWSIotMqttSubscriptionStatusCallback;
import com.amazonaws.regions.Regions;
import apkit.provider.GranwinAuthenticationProvider;

import org.json.JSONObject;

import java.io.UnsupportedEncodingException;
import java.util.Map;

public class AwsUtils {

    static final String LOG_TAG = AwsUtils.class.getCanonicalName();

    private boolean isConnectSuccess = false;
    private long connectSuccessTime = 0;

    private AWSIotMqttManager mqttManager;
    CognitoCachingCredentialsProvider credentialsProvider;

    private AwsUtils() {

    }

    public boolean isNeedToTimeCallApi() {
        if (isConnectSuccess) {
            if (System.currentTimeMillis() - connectSuccessTime < 10000) {
                //刚连接成功的10秒 依然需要轮询接口
                return true;
            } else {
                return false;
            }
        } else {
            return true;
        }
    }

    /**
     * 获取AwsUtils 的全局唯一实例
     *
     * @return
     */
    public static AwsUtils getInstance() {
        return SingletonFactory.instance;
    }

    /* 此处使用一个内部类来维护单例 */
    private static class SingletonFactory {
        private static AwsUtils instance = new AwsUtils();
    }

    private void connect(Context context, final String identityId, String token, String accountId, String identityPoolId, String mRegion, final AWSListener awsListener) {
        try {
            GranwinAuthenticationProvider developerProvider = new GranwinAuthenticationProvider(identityId, token, accountId, identityPoolId, mRegion);
            credentialsProvider = new CognitoCachingCredentialsProvider(context, developerProvider, Regions.fromName(mRegion));

            mqttManager.connect(credentialsProvider, new AWSIotMqttClientStatusCallback() {
                @Override
                public void onStatusChanged(final AWSIotMqttClientStatus status, final Throwable throwable) {
                    LogUtil.d("Status = " + String.valueOf(status));

                    if (String.valueOf(status).equals("Connected")) {
                        subscribe(identityId);
                    }else{
                        isConnectSuccess = false;
                    }
                    if (awsListener != null) awsListener.onConnectStatusChange(status.toString());
                }
            });
        } catch (final Exception e) {
            LogUtil.d("Connection error." + e);
            if (awsListener != null) awsListener.onConnectFail(e.getMessage());
        }
    }

    public void disConnect() {
        try {
            mqttManager.disconnect();
            credentialsProvider.clear();
            /*if (awsListener != null) {
                awsListener = null;
            }*/
        } catch (Exception e) {
            LogUtil.d("disConnect,exception=" + e.getMessage());
        }
    }

    private void subscribe(String clientId) {
        final String topic = "granwin/" + clientId + "/message";

        LogUtil.d("subscribe topic=" + topic);
        try {
            mqttManager.subscribeToTopic(topic, AWSIotMqttQos.QOS0, new AWSIotMqttSubscriptionStatusCallback() {
                @Override
                public void onSuccess() {
                    LogUtil.d("Subscribe Message Success,topic=" + topic);

                    connectSuccessTime = System.currentTimeMillis();
                    isConnectSuccess = true;
                }

                @Override
                public void onFailure(Throwable exception) {
                    LogUtil.d("Subscribe Message Error"+exception);

                    isConnectSuccess = false;
                }
            }, new AWSIotMqttNewMessageCallback() {
                @Override
                public void onMessageArrived(final String topic, final byte[] data) {

                    try {
                        String payload = new String(data, "UTF-8");
                        handleMessage(topic, payload);
                    } catch (UnsupportedEncodingException e) {
                        LogUtil.d("payload to string error"+e);
                    }
                }
            });
        } catch (Exception e) {
            LogUtil.d("Subscription Error"+ e);
        }
    }

    private void handleMessage(String topic, String payload) {
        try {
            JSONObject jsonMessage = new JSONObject(payload);
            Log.e(LOG_TAG, "handleConnectMessage->" + topic + "," + payload);
            if (topic.contains("/shadow/get/")) {
                //获取影子内容
                if (!jsonMessage.has("state")) {
                    return;
                }
                if (!jsonMessage.getJSONObject("state").has("reported")) {
                    return;
                }
                JSONObject desiredObject = jsonMessage.getJSONObject("state").getJSONObject("reported");
                String mac = topic.replaceAll("\\$aws/things/", "");
                mac = mac.replaceAll("/shadow/get/accepted", "");
                awsListener.onReceiveShadow(mac, desiredObject);
            } else if (topic.contains("/shadow/update")) {
                //影子内容更新
                if (!jsonMessage.has("state")) {
                    return;
                }
                if (!jsonMessage.getJSONObject("state").has("reported")) {
                    return;
                }
                if (jsonMessage.getJSONObject("state").has("reported")) {
                    JSONObject desiredObject = jsonMessage.getJSONObject("state").getJSONObject("reported");
                    String mac = topic.replaceAll("\\$aws/things/", "");
                    mac = mac.replaceAll("/shadow/update", "");
                    awsListener.onReceiveShadow(mac, desiredObject);
                }
            } else if (topic.contains("message")) {
                //消息更新
                if (!jsonMessage.has("messageType")) {
                    return;
                }
                if (awsListener != null) awsListener.onGranWinMessage(jsonMessage);
            } else {

            }
        } catch (Exception ex) {
            Log.e(LOG_TAG, "parse payload error", ex);
        }
    }

    public void getDeviceStatus(String mac) {
        String topic = "$aws/things/" + mac + "/shadow/get";
        try {
            mqttManager.publishString("", topic, AWSIotMqttQos.QOS0);
        } catch (Exception e) {
            Log.e(LOG_TAG, "Publish error.", e);
        }
        Log.i(LOG_TAG, "message sent: " + topic);
    }

    public void test() {
        String topic = "granwin/us-west-2:56f3bc98-39d1-4e65-ae56-12e64030eb9a/message";
        try {
            mqttManager.publishString("test", topic, AWSIotMqttQos.QOS0);
        } catch (Exception e) {
            Log.e(LOG_TAG, "Publish error.", e);
        }
        Log.i(LOG_TAG, "message sent: " + topic);
    }

    public void setDeviceStatus(String account, String productKey, String mac, Map<String, Object> params) {
        String topic = "$aws/things/" + mac + "/shadow/update";
        try {
            JSONObject desiredValue = new JSONObject();
            for (Map.Entry<String, Object> entry : params.entrySet()) {
                desiredValue.put(entry.getKey(), entry.getValue());
            }

            JSONObject desiredUserControlValue = new JSONObject();
            desiredUserControlValue.put("product_key", productKey);
            desiredUserControlValue.put("action_type", "1");
            desiredUserControlValue.put("action_type_name", "android");
            desiredUserControlValue.put("account", account);
            desiredValue.put("userControllerData", desiredUserControlValue);

            JSONObject stateValue = new JSONObject();
            stateValue.put("desired", desiredValue);
            JSONObject messageValue = new JSONObject();
            messageValue.put("state", stateValue);

            Log.i(LOG_TAG, topic + "->" + messageValue.toString());
            mqttManager.publishString(messageValue.toString(), topic, AWSIotMqttQos.QOS1);
        } catch (Exception ex) {
            Log.e(LOG_TAG, "create payload error", ex);
        }
    }

    public void initIoTClient(Context context, String clientID, String mCustomerSpecificEndpoint, String token, String accountId, String identityPoolId, String mRegion) {
        // MQTT Client
        mqttManager = new AWSIotMqttManager(clientID, mCustomerSpecificEndpoint);
        // Set keepalive to 10 seconds.  Will recognize disconnects more quickly but will also send
        // MQTT pings every 10 seconds.
        mqttManager.setKeepAlive(10);
        connect(context, clientID, token, accountId, identityPoolId, mRegion, awsListener);
    }

    public void setAwsListener(AWSListener awsListener) {
        this.awsListener = awsListener;
    }

    private AWSListener awsListener;


    public interface AWSListener {
        void onConnectStatusChange(String status);

        void onConnectFail(String message);

        void onReceiveShadow(String mac, JSONObject jsonObject);

        void onGranWinMessage(JSONObject jsonObject);
    }
}


