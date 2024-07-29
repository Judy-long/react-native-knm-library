package com.reactlibrary.utils;

import android.annotation.TargetApi;
import android.app.Activity;
import android.app.ActivityManager;
import android.app.Fragment;
import android.app.Service;
import android.content.Context;
import android.os.Build;
import android.widget.ImageView;

import java.lang.ref.WeakReference;
import java.util.List;

/**
 * Created by chen on 2018/3/27.
 */

public class ContextHolder<T> extends WeakReference<T> {
    public ContextHolder(T r) {
        super(r);
    }

    public boolean isAlive() {
        T ref = get();
        if (ref == null) {
            return false;
        } else {
            if (ref instanceof Service)
                return isServiceAlive((Service) ref);
            if (ref instanceof Activity)
                return isActivityAlive((Activity) ref);
            if (ref instanceof Fragment)
                return isFragmentAlive((Fragment) ref);
            if (ref instanceof Fragment)
                return isV4FragmentAlive((Fragment) ref);
            if (ref instanceof ImageView)
                return isImageAlive((ImageView) ref);
        }
        return true;
    }

    boolean isServiceAlive(Service candidate) {
        if (candidate == null)
            return false;
        ActivityManager manager = (ActivityManager) candidate.getSystemService(Context.ACTIVITY_SERVICE);
        List<ActivityManager.RunningServiceInfo> services = manager.getRunningServices(Integer.MAX_VALUE);
        if (services == null)
            return false;
        for (ActivityManager.RunningServiceInfo service : services) {
            if (candidate.getClass().getName().equals(service.service.getClassName())) {
                return true;
            }
        }
        return false;
    }

    boolean isActivityAlive(Activity a) {
        if (a == null)
            return false;
        if (a.isFinishing())
            return false;
        return true;
    }

    @TargetApi(Build.VERSION_CODES.HONEYCOMB_MR2)
    boolean isFragmentAlive(Fragment fragment) {
        boolean ret = isActivityAlive(fragment.getActivity());
        if (!ret)
            return false;
        if (fragment.isDetached())
            return false;
        return true;
    }

    boolean isV4FragmentAlive(Fragment fragment) {
        boolean ret = isActivityAlive(fragment.getActivity());
        if (!ret)
            return false;
        if (fragment.isDetached())
            return false;
        return true;
    }

    boolean isImageAlive(ImageView imageView) {
        Context context = imageView.getContext();
        if (context instanceof Service)
            return isServiceAlive((Service) context);
        if (context instanceof Activity)
            return isActivityAlive((Activity) context);
        return true;
    }
}
