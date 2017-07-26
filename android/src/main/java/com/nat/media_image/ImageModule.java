package com.nat.media_image;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.ExifInterface;
import android.os.Build;
import android.os.Environment;
import android.text.TextUtils;

import com.nat.media_image.multi_image_selector.MultiImageSelector;
import com.nat.media_image.multi_image_selector.MultiImageSelectorActivity;
import com.squareup.okhttp.Callback;
import com.squareup.okhttp.OkHttpClient;
import com.squareup.okhttp.Request;
import com.squareup.okhttp.Response;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.List;


/**
 * Created by xuqinchao on 17/1/7.
 *  Copyright (c) 2017 Instapp. All rights reserved.
 */

public class ImageModule {

    public static final String PREVIEW = "image_preview";
    public ModuleResultListener mPreviewListener;

    private static volatile ImageModule instance = null;
    private Context mContext;
    private ImageModule(Context context){
        mContext = context;
        EventBus.getDefault().register(this);
    }

    public static ImageModule getInstance(Context context) {
        if (instance == null) {
            synchronized (ImageModule.class) {
                if (instance == null) {
                    instance = new ImageModule(context);
                }
            }
        }

        return instance;
    }

    public void pick(Activity activity, HashMap<String, Object> param){
        int limit = 9;
        boolean showCamera = false;

        // params
        if (param.containsKey("limit")) {
            limit = (int) param.get("limit");
            limit = (limit < 1) ? 1 : limit;
        }

        if (param.containsKey("showCamera")) {
            showCamera = (boolean) param.get("showCamera");
        }

        MultiImageSelector selector = MultiImageSelector.create(activity);

        selector.showCamera(showCamera);
        selector.count(limit);

        if (limit == 1) {
            selector.single();
        } else {
            selector.multi();
        }

        selector.start(activity, Constant.IMAGE_PICK_REQUEST_CODE);
    }

    public Object onPickActivityResult(int requestCode, int resultCode, Intent data){
        if (requestCode == Constant.IMAGE_PICK_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_CANCELED) {
                return null;
            }
            else if (resultCode != Activity.RESULT_OK) {
                return Util.getError(Constant.MEDIA_ABORTED, Constant.MEDIA_ABORTED_CODE);
            }

            List<String> path = data.getStringArrayListExtra(MultiImageSelectorActivity.EXTRA_RESULT);
            HashMap<String, List<String>> result = new HashMap<String, List<String>>();
            result.put("paths", path);
            return result;
        } else {
            return null;
        }
    }

    public void preview(String[] files, HashMap<String, Object> param, ModuleResultListener listener) {
        mPreviewListener = listener;

        int currentIndex = 0;
        String style = "dots";
        if (param.containsKey("current")) {
            currentIndex = (int) param.get("current");
        }
        if (param.containsKey("style")) {
            style = (String) param.get("style");
        }
        Intent intent = new Intent(mContext, ImagePreviewActivity.class);
        intent.putExtra("paths", files);
        intent.putExtra("style", style);
        intent.putExtra("current", currentIndex);
        mContext.startActivity(intent);
        listener.onResult(null);
    }

    public void info(final String path, final ModuleResultListener listener) {
        if (path.startsWith("http://") || path.startsWith("https://")) {
            OkHttpClient okHttpClient = new OkHttpClient();
            final Request request = new Request.Builder().url(path).build();
            okHttpClient.newCall(request).enqueue(new Callback() {

                @Override
                public void onResponse(Response response) throws IOException {
                    InputStream is = response.body().byteStream();

                    HashMap<String, Object> result = new HashMap<>();
                    BitmapFactory.Options options = new BitmapFactory.Options();
//                    options.inJustDecodeBounds = true;
                    Bitmap bitmap = BitmapFactory.decodeStream(is, null, options);
                    if (bitmap == null) {
                        listener.onResult(Util.getError(Constant.MEDIA_SRC_NOT_SUPPORTED, Constant.MEDIA_SRC_NOT_SUPPORTED_CODE));
                        return;
                    }
                    String outMimeType = options.outMimeType;

                    String type = getImageType(outMimeType);
                    if (type.equals("unknow")) {
                        result.put("type", type);
                        listener.onResult(result);
                    }

                    int outHeight = options.outHeight;
                    int outWidth = options.outWidth;
                    result.put("width", outWidth);
                    result.put("height", outHeight);
                    result.put("type", type);
                    listener.onResult(result);
                }

                @Override
                public void onFailure(Request request, IOException e) {
                    listener.onResult(Util.getError(Constant.MEDIA_NETWORK_ERROR, Constant.MEDIA_ABORTED_CODE));
                }
            });
        } else {
            HashMap<String, Object> result = new HashMap<>();
            BitmapFactory.Options options = new BitmapFactory.Options();
            Bitmap bitmap = null;
            boolean isSampleSize = false;
            try {
                bitmap = BitmapFactory.decodeFile(path, options);
            } catch (OutOfMemoryError error) {
                error.printStackTrace();
                options.inSampleSize = 2;
                isSampleSize = true;
                bitmap = BitmapFactory.decodeFile(path, options);
            }
            if (bitmap == null) {
                listener.onResult(Util.getError(Constant.MEDIA_SRC_NOT_SUPPORTED, Constant.MEDIA_SRC_NOT_SUPPORTED_CODE));
                return;
            }

            String outMimeType = options.outMimeType;

            String type = getImageType(outMimeType);
            if (type.equals("unknow")) {
                result.put("type", type);
                listener.onResult(result);
            }
            int outHeight = isSampleSize ? options.outHeight*2 : options.outHeight;
            int outWidth = isSampleSize ? options.outWidth*2 : options.outWidth;
            result.put("width", outWidth);
            result.put("height", outHeight);
            result.put("type", type);
            listener.onResult(result);
        }
    }

    public void exif(String path, final ModuleResultListener listener){
        if (path.startsWith("http://") || path.startsWith("https://")) {
            OkHttpClient okHttpClient = new OkHttpClient();
            final Request request = new Request.Builder().url(path).build();
            okHttpClient.newCall(request).enqueue(new Callback() {

                @Override
                public void onResponse(Response response){
                    try {
                        InputStream is = response.body().byteStream();

                        String str_time = new Date().getTime() + "";
                        File file = new File(Environment.getExternalStorageDirectory().getAbsolutePath() + "/" + str_time + ".jpg");
                        if (!file.exists()) file.createNewFile();
                        FileOutputStream fos = new FileOutputStream(file);
                        byte[] buffer = new byte[1024];
                        int len = 0;
                        while ((len = is.read(buffer)) != -1) {
                            fos.write(buffer, 0, len);
                        }
                        fos.flush();
                        is.close();
                        fos.close();

                        getPictureExif(file.getAbsolutePath(), listener);
                    } catch (Exception e) {
                        e.printStackTrace();
                        listener.onResult(Util.getError(Constant.MEDIA_NETWORK_ERROR, Constant.MEDIA_NETWORK_ERROR_CODE));
                    }
                }

                @Override
                public void onFailure(Request request, IOException e) {
                    listener.onResult(Util.getError(Constant.MEDIA_NETWORK_ERROR, Constant.MEDIA_NETWORK_ERROR_CODE));
                }
            });
        } else {
            getPictureExif(path, listener);
        }

    }

    private void getPictureExif(String path, ModuleResultListener listener) {
        HashMap<String, Object> result = new HashMap<>();

        try {
            ExifInterface exifInterface = new ExifInterface(path);
            //24以下
            String[] tags_str = {
                    ExifInterface.TAG_GPS_LATITUDE_REF,
                    ExifInterface.TAG_GPS_LONGITUDE_REF,
                    ExifInterface.TAG_GPS_PROCESSING_METHOD,
                    ExifInterface.TAG_IMAGE_WIDTH,
                    ExifInterface.TAG_IMAGE_LENGTH,
                    ExifInterface.TAG_MAKE,
                    ExifInterface.TAG_MODEL
            };
            String[] tags_double = {
                    ExifInterface.TAG_APERTURE,
                    ExifInterface.TAG_FLASH,
                    ExifInterface.TAG_FOCAL_LENGTH,
                    ExifInterface.TAG_GPS_ALTITUDE,
                    ExifInterface.TAG_GPS_ALTITUDE_REF,
                    ExifInterface.TAG_GPS_LONGITUDE,//格式     1/2
                    ExifInterface.TAG_GPS_LATITUDE,//格式     1/2
                    ExifInterface.TAG_IMAGE_LENGTH,
                    ExifInterface.TAG_IMAGE_WIDTH,
                    ExifInterface.TAG_ISO,
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.TAG_WHITE_BALANCE,
                    ExifInterface.TAG_EXPOSURE_TIME
            };
            HashMap<String, Object> exif_str = getExif_str(exifInterface, tags_str);
            result.putAll(exif_str);
            HashMap<String, Object> exif_double = getExif_double(exifInterface, tags_double);
            result.putAll(exif_double);

            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.M) {
                String[] tags_23 = {
                        ExifInterface.TAG_DATETIME_DIGITIZED,
                        ExifInterface.TAG_SUBSEC_TIME,
                        ExifInterface.TAG_SUBSEC_TIME_DIG,
                        ExifInterface.TAG_SUBSEC_TIME_ORIG
                };
                HashMap<String, Object> exif23 = getExif_str(exifInterface, tags_23);
                result.putAll(exif23);
            }

            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
                String[] tags_24_str = {
                        ExifInterface.TAG_ARTIST,
                        ExifInterface.TAG_CFA_PATTERN,
                        ExifInterface.TAG_COMPONENTS_CONFIGURATION,
                        ExifInterface.TAG_COPYRIGHT,
                        ExifInterface.TAG_DATETIME_ORIGINAL,
                        ExifInterface.TAG_DEVICE_SETTING_DESCRIPTION,
                        ExifInterface.TAG_EXIF_VERSION,
                        ExifInterface.TAG_FILE_SOURCE,
                        ExifInterface.TAG_FLASHPIX_VERSION,
                        ExifInterface.TAG_GPS_AREA_INFORMATION,
                        ExifInterface.TAG_GPS_DEST_BEARING_REF,
                        ExifInterface.TAG_GPS_DEST_DISTANCE_REF,
                        ExifInterface.TAG_GPS_DEST_LATITUDE_REF,
                        ExifInterface.TAG_GPS_DEST_LONGITUDE_REF,
                        ExifInterface.TAG_GPS_DOP,
                        ExifInterface.TAG_GPS_IMG_DIRECTION,
                        ExifInterface.TAG_GPS_IMG_DIRECTION_REF,
                        ExifInterface.TAG_GPS_MAP_DATUM,
                        ExifInterface.TAG_GPS_MEASURE_MODE,
                        ExifInterface.TAG_GPS_SATELLITES,
                        ExifInterface.TAG_GPS_SPEED_REF,
                        ExifInterface.TAG_GPS_STATUS,
                        ExifInterface.TAG_GPS_TRACK_REF,
                        ExifInterface.TAG_GPS_VERSION_ID,
                        ExifInterface.TAG_IMAGE_DESCRIPTION,
                        ExifInterface.TAG_IMAGE_UNIQUE_ID,
                        ExifInterface.TAG_INTEROPERABILITY_INDEX,
                        ExifInterface.TAG_MAKER_NOTE,
                        ExifInterface.TAG_OECF,
                        ExifInterface.TAG_RELATED_SOUND_FILE,
                        ExifInterface.TAG_SCENE_TYPE,
                        ExifInterface.TAG_SOFTWARE,
                        ExifInterface.TAG_SPATIAL_FREQUENCY_RESPONSE,
                        ExifInterface.TAG_SPECTRAL_SENSITIVITY,
                        ExifInterface.TAG_SUBSEC_TIME_DIGITIZED,
                        ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
                        ExifInterface.TAG_USER_COMMENT
                };

                String[] tags24_double = {
                        ExifInterface.TAG_APERTURE_VALUE,
                        ExifInterface.TAG_BITS_PER_SAMPLE,
                        ExifInterface.TAG_BRIGHTNESS_VALUE,
                        ExifInterface.TAG_COLOR_SPACE,
                        ExifInterface.TAG_COMPRESSED_BITS_PER_PIXEL,
                        ExifInterface.TAG_COMPRESSION,
                        ExifInterface.TAG_CONTRAST,
                        ExifInterface.TAG_CUSTOM_RENDERED,
                        ExifInterface.TAG_DIGITAL_ZOOM_RATIO,
                        ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
                        ExifInterface.TAG_EXPOSURE_INDEX,
                        ExifInterface.TAG_EXPOSURE_MODE,
                        ExifInterface.TAG_EXPOSURE_PROGRAM,
                        ExifInterface.TAG_FLASH_ENERGY,
                        ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
                        ExifInterface.TAG_FOCAL_PLANE_RESOLUTION_UNIT,
                        ExifInterface.TAG_FOCAL_PLANE_X_RESOLUTION,
                        ExifInterface.TAG_FOCAL_PLANE_Y_RESOLUTION,
                        ExifInterface.TAG_F_NUMBER,
                        ExifInterface.TAG_GAIN_CONTROL,
                        ExifInterface.TAG_GPS_DEST_BEARING,
                        ExifInterface.TAG_GPS_DEST_DISTANCE,
                        ExifInterface.TAG_GPS_DEST_LATITUDE,
                        ExifInterface.TAG_GPS_DEST_LONGITUDE,
                        ExifInterface.TAG_GPS_DIFFERENTIAL,
                        ExifInterface.TAG_GPS_SPEED,
                        ExifInterface.TAG_GPS_TRACK,
                        ExifInterface.TAG_ISO_SPEED_RATINGS,
                        ExifInterface.TAG_JPEG_INTERCHANGE_FORMAT,
                        ExifInterface.TAG_JPEG_INTERCHANGE_FORMAT_LENGTH,
                        ExifInterface.TAG_LIGHT_SOURCE,
                        ExifInterface.TAG_MAX_APERTURE_VALUE,
                        ExifInterface.TAG_METERING_MODE,
                        ExifInterface.TAG_PHOTOMETRIC_INTERPRETATION,
                        ExifInterface.TAG_PIXEL_X_DIMENSION,
                        ExifInterface.TAG_PIXEL_Y_DIMENSION,
                        ExifInterface.TAG_PLANAR_CONFIGURATION,
                        ExifInterface.TAG_PRIMARY_CHROMATICITIES,
                        ExifInterface.TAG_REFERENCE_BLACK_WHITE,
                        ExifInterface.TAG_RESOLUTION_UNIT,
                        ExifInterface.TAG_ROWS_PER_STRIP,
                        ExifInterface.TAG_SAMPLES_PER_PIXEL,
                        ExifInterface.TAG_SATURATION,
                        ExifInterface.TAG_SCENE_CAPTURE_TYPE,
                        ExifInterface.TAG_SENSING_METHOD,
                        ExifInterface.TAG_SHARPNESS,
                        ExifInterface.TAG_SHUTTER_SPEED_VALUE,
                        ExifInterface.TAG_STRIP_BYTE_COUNTS,
                        ExifInterface.TAG_STRIP_OFFSETS,
                        ExifInterface.TAG_SUBJECT_AREA,
                        ExifInterface.TAG_SUBJECT_DISTANCE,
                        ExifInterface.TAG_SUBJECT_DISTANCE_RANGE,
                        ExifInterface.TAG_SUBJECT_LOCATION,
                        ExifInterface.TAG_THUMBNAIL_IMAGE_LENGTH,
                        ExifInterface.TAG_THUMBNAIL_IMAGE_WIDTH,
                        ExifInterface.TAG_TRANSFER_FUNCTION,
                        ExifInterface.TAG_WHITE_POINT,
                        ExifInterface.TAG_X_RESOLUTION,
                        ExifInterface.TAG_Y_CB_CR_COEFFICIENTS,
                        ExifInterface.TAG_Y_CB_CR_POSITIONING,
                        ExifInterface.TAG_Y_CB_CR_SUB_SAMPLING,
                        ExifInterface.TAG_Y_RESOLUTION,
                };
                HashMap<String, Object> exif24_str = getExif_str(exifInterface, tags_24_str);
                result.putAll(exif24_str);
                HashMap<String, Object> exif24_double = getExif_double(exifInterface, tags24_double);
                result.putAll(exif24_double);
            }


            String TAG_DATETIME = exifInterface.getAttribute(ExifInterface.TAG_DATETIME);
            String TAG_GPS_TIMESTAMP = exifInterface.getAttribute(ExifInterface.TAG_GPS_TIMESTAMP);//    TAG_DATETIME2017:01:20 20:14:57TAG_GPS_TIMESTAMP12:14:56
            long dateTime = formatTime(TAG_DATETIME, "yy:mm:dd hh:mm:ss");
            long gpsDateTime = formatTime(TAG_GPS_TIMESTAMP, "hh:mm:ss");
            if (dateTime != 0) result.put(ExifInterface.TAG_DATETIME, dateTime);
            if (gpsDateTime != 0) result.put(ExifInterface.TAG_GPS_TIMESTAMP, TAG_GPS_TIMESTAMP);//暂时先用string
            listener.onResult(result);
        } catch (IOException e) {
            e.printStackTrace();
            listener.onResult(Util.getError(Constant.MEDIA_SRC_NOT_SUPPORTED, Constant.MEDIA_SRC_NOT_SUPPORTED_CODE));
        }
    }

    public String getImageType(String mimeType) {
        if (mimeType == null || !mimeType.startsWith("image")) {
            return "unknow";
        }

        if (mimeType.contains("png")) {
            return "png";
        }else if (mimeType.contains("jpeg")) {
            return "jpeg";
        }else if (mimeType.contains("webp")) {
            return "webp";
        }else if (mimeType.contains("gif")) {
            return "gif";
        }else if (mimeType.contains("bmp")) {
            return "bmp";
        } else if (mimeType.contains("ico")) {
            return "ico";
        } else {
            return "unknow";
        }
    }

    public HashMap<String, Object> getExif_str(ExifInterface exifInterface, String[] tags){
        HashMap<String, Object> result = new HashMap<>();
        for (String tag : tags) {
            String attribute = exifInterface.getAttribute(tag);
            if (!TextUtils.isEmpty(attribute)) {
                result.put(tag, attribute);
            }
        }
        return result;
    }

    public HashMap<String, Object> getExif_double(ExifInterface exifInterface, String[] tags){
        HashMap<String, Object> result = new HashMap<>();
        for (String tag : tags) {
            double attribute = exifInterface.getAttributeDouble(tag, 0.0);
            if (attribute != 0.0) {
                result.put(tag, attribute);
            }
        }
        return result;
    }

    public long formatTime(String date_str, String format_str) {

        if (date_str == null) return 0;
        try {
            SimpleDateFormat simpleDateFormat = new SimpleDateFormat(format_str);
            Date parse = null;
            parse = simpleDateFormat.parse(date_str);
            return parse.getTime();
        } catch (ParseException e) {
            e.printStackTrace();
        }
        return 0;
    }

    @Subscribe
    public void onMessageEvent(MessageEvent messageEvent) {
        if (messageEvent.mType.equals(PREVIEW) && mPreviewListener != null) {
            mPreviewListener.onResult(Util.getError(messageEvent.mMsg, 1));
        }
    }
}
