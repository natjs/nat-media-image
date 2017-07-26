package com.nat.media_image;

import android.support.v4.view.PagerAdapter;
import android.view.View;
import android.view.ViewGroup;
import com.nat.media_image.zoomimageview.ZoomImageView;
import java.util.ArrayList;


/**
 * Created by xuqinchao on 17/2/7.
 * Copyright (c) 2017 Instapp. All rights reserved.
 */

public class ImagePreviewAdapter extends PagerAdapter {

    private ArrayList<ZoomImageView> mDatas;

    @Override
    public int getCount() {
        return mDatas==null?0:mDatas.size();
    }

    @Override
    public boolean isViewFromObject(View view, Object object) {
        return view == object;
    }

    @Override
    public Object instantiateItem(ViewGroup container, int position) {
        ZoomImageView zoomImageView = mDatas.get(position);
        container.addView(zoomImageView);
        return zoomImageView;
    }

    @Override
    public void destroyItem(ViewGroup container, int position, Object object) {
        container.removeView((View) object);
    }

    public void setData(ArrayList<ZoomImageView> datas) {
        mDatas = datas;
        this.notifyDataSetChanged();
    }
}
