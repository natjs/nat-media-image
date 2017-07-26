package com.nat.media_image;

import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.support.v4.view.ViewPager;
import android.support.v7.app.AppCompatActivity;
import android.view.View;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.nat.media_image.zoomimageview.ZoomImageView;
import com.squareup.picasso.Picasso;

import org.greenrobot.eventbus.EventBus;

import java.util.ArrayList;

/**
 * Created by xuqinchao on 17/2/7.
 * Copyright (c) 2017 Instapp. All rights reserved.
 */
public class ImagePreviewActivity extends AppCompatActivity {

    private ViewPager mViewPager;
    private LinearLayout mIndicator;
    private ImagePreviewAdapter mAdapter;
    private ArrayList<ZoomImageView> mDatas;
    private int mStartIndex;
    private String mStyle;
    private String[] mPaths;
    private TextView mTextView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_image_preview);

        Intent intent = getIntent();
        if (intent != null) {
            mPaths = intent.getStringArrayExtra("paths");
            mStyle = intent.getStringExtra("style");
            mStartIndex = intent.getIntExtra("current", 0);

            if (mPaths.length > 9 && mStyle.equals("dots")) {
                mStyle = "label";
            }
        }

        initView();
        setData();
    }

    private void initView() {
        mViewPager = (ViewPager) findViewById(R.id.viewpager);
        mIndicator = (LinearLayout) findViewById(R.id.ll_indicator);
        mAdapter = new ImagePreviewAdapter();
        mViewPager.setAdapter(mAdapter);
        mViewPager.setOnPageChangeListener(new ViewPager.OnPageChangeListener() {
            @Override
            public void onPageScrolled(int position, float positionOffset, int positionOffsetPixels) {

            }

            @Override
            public void onPageSelected(int position) {
                if (mStyle.equals("dots")) {
                    for (int i = 0; i < mIndicator.getChildCount(); i++) {
                        View view = mIndicator.getChildAt(i);
                        view.setEnabled(i == position);
                    }
                } else if (mStyle.equals("label")) {
                    mTextView.setText((position+1) + "-" + mAdapter.getCount());
                }

            }

            @Override
            public void onPageScrollStateChanged(int state) {

            }
        });
    }

    public void setData(){
        if (mPaths == null && mPaths.length == 0)ImagePreviewActivity.this.finish();

        mDatas = new ArrayList<>();
        for (int i = 0; i < mPaths.length; i++) {
            ZoomImageView zoomImageView = new ZoomImageView(this);
            mDatas.add(zoomImageView);

            if (mPaths[i].startsWith("http://") || mPaths[i].equals("https://")) {
                Picasso.with(this)
                        .load(mPaths[i])
                        .into(zoomImageView);
            } else if (mPaths[i].startsWith("R.mipmap") || mPaths[i].startsWith("R.drawable")) {
                Picasso.with(this).load(mPaths[i]).into(zoomImageView);
            } else {
//                Picasso.with(this).load(new File(mPaths[i])).into(zoomImageView);
                Bitmap bitmap = null;
                try {
                    bitmap = BitmapFactory.decodeFile(mPaths[i]);
                } catch (OutOfMemoryError error) {
                    error.printStackTrace();
                    BitmapFactory.Options options = new BitmapFactory.Options();
                    options.inSampleSize = 2;
                    bitmap = BitmapFactory.decodeFile(mPaths[i], options);
                }

                if (bitmap == null) {
                    EventBus.getDefault().post(new MessageEvent(Constant.MEDIA_SRC_NOT_SUPPORTED, ImageModule.PREVIEW));
                }
                zoomImageView.setImageBitmap(bitmap);
            }

            if (mStyle.equals("dots")) {
                ImageView indicator = new ImageView(this);
                indicator.setImageResource(R.drawable.indicator);
                LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams((int) Util.dp2px(this, 8), (int) Util.dp2px(this, 8));
                layoutParams.leftMargin = (int) Util.dp2px(this, 4);
                indicator.setLayoutParams(layoutParams);
                mIndicator.addView(indicator);
                indicator.setEnabled(i == mStartIndex);
                mIndicator.setVisibility(View.VISIBLE);
            }

            zoomImageView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    ImagePreviewActivity.this.finish();
                }
            });
        }

        if (mStyle.equals("label")) {
            mTextView = new TextView(this);
            mTextView.setText((mStartIndex + 1) + " / " + mPaths.length);
            mTextView.setTextColor(getResources().getColor(R.color.white));
            mTextView.setTextSize(14);
            mIndicator.addView(mTextView);
            mIndicator.setVisibility(View.VISIBLE);
        } else if (mStyle.equals("none")){
            mIndicator.setVisibility(View.GONE);
        }

        mAdapter.setData(mDatas);
        mViewPager.setCurrentItem(mStartIndex);
    }
}
