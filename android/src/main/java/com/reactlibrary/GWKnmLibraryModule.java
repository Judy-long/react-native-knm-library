
package com.reactlibrary;

import android.util.Log;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;

public class GWKnmLibraryModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;

  public GWKnmLibraryModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return "GWKnmLibrary";
  }

  @ReactMethod
  public void test() {
    Log.d("cjh","cccddd");
  }
}