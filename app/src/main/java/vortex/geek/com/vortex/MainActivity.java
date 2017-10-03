package vortex.geek.com.vortex;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.support.v4.view.PagerAdapter;
import android.support.v4.view.ViewPager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.Toast;

import com.tencent.bugly.crashreport.CrashReport;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

import vortex.geek.com.vortex.core.CameraTextureView;

public class MainActivity extends Activity implements View.OnClickListener {

    private int[] mImgIds = new int[] { R.mipmap.welcome,
            R.mipmap.gohomepage};
    private List<View> mLaunchViews = new ArrayList<View>();
    private ViewPager mViewPager;

    private FrameLayout rgbPanle;


    private ImageView mCaptureImage;
    private CameraTextureView mCameraTextureView;

    private static final int REQUEST_CAMERA_PERMISSION = 1;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        CrashReport.initCrashReport(getApplicationContext(), "d74580cc42", true);

        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        setContentView(R.layout.activity_main);
        initData();// init picture to image view.
        // Example of a call to a native method
        mViewPager = (ViewPager) findViewById(R.id.id_viewpager);
        //CrashReport.testJavaCrash();
        mViewPager.setAdapter(new PagerAdapter()
        {
            @Override
            public Object instantiateItem(ViewGroup container, int position)
            {
                container.addView(mLaunchViews.get(position));
                return mLaunchViews.get(position);
            }

            @Override
            public void destroyItem(ViewGroup container, int position,
                                    Object object)
            {

                container.removeView(mLaunchViews.get(position));
            }

            @Override
            public boolean isViewFromObject(View view, Object object)
            {
                return view == object;
            }

            @Override
            public int getCount()
            {
                return mLaunchViews.size();
            }
        });

        NativeFFMPEGMethod instance = new NativeFFMPEGMethod();


        File mFile = new File(getExternalFilesDir(null), "pic.jpg");
        findViewById(R.id.picture).setOnClickListener(this);
        findViewById(R.id.info).setOnClickListener(this);

        mCaptureImage = (ImageView) findViewById(R.id.iv_capture_pic);
        mCameraTextureView = (CameraTextureView) findViewById(R.id.texture);

        //配置CameraTexture
        mCameraTextureView.setActivity(this);
        mCameraTextureView.setPicSaveFile(mFile);

    }

    private void initData()
    {
        //for (int imgId : mImgIds)
        {
            //ImageView imageView = new ImageView(getApplicationContext());
            //imageView.setScaleType(ScaleType.CENTER_CROP);
            //imageView.setImageResource(imgId);
            View view1,view2;
            LayoutInflater inflater=getLayoutInflater();
            view1 = inflater.inflate(R.layout.acttivty_welcome, null);
            view2 = inflater.inflate(R.layout.activty_gohomepage, null);
            mLaunchViews.add(view1);
            mLaunchViews.add(view2);

        }
    }


    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.picture: {
                mCameraTextureView.takePicture(new CameraTextureView.TackPhotoCallback() {
                    @Override
                    public void tackPhotoSuccess(String photoPath) {
                        showToast(photoPath);
                        mCaptureImage.setImageBitmap(BitmapFactory.decodeFile(photoPath));
                    }

                    @Override
                    public void tackPhotoError(Exception e) {
                        showToast(e.getMessage());
                    }
                });
                break;
            }
            case R.id.info: {
                new AlertDialog.Builder(this)
                        .setMessage(R.string.intro_message)
                        .setPositiveButton(android.R.string.ok, null)
                        .show();
                break;
            }
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestCameraPermission();
            return;
        }
        mCameraTextureView.onResume();
    }

    @Override
    protected void onPause() {
        super.onPause();
        mCameraTextureView.onPause();
    }


    private void requestCameraPermission() {
        if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA)) {
            ConfirmationDialog();
        } else {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.CAMERA},
                    REQUEST_CAMERA_PERMISSION);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        if (requestCode == REQUEST_CAMERA_PERMISSION) {
            if (grantResults.length != 1 || grantResults[0] != PackageManager.PERMISSION_GRANTED) {
                Toast.makeText(getApplicationContext(), R.string.request_permission, Toast.LENGTH_SHORT).show();
            } else {
                //执行相机初始化操作
                mCameraTextureView.onResume();
            }
        } else {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        }
    }

    private void ConfirmationDialog() {
        AlertDialog alertDialog = new AlertDialog.Builder(this)
                .setMessage(R.string.request_permission)
                .setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        ActivityCompat.requestPermissions(MainActivity.this,
                                new String[]{Manifest.permission.CAMERA},
                                REQUEST_CAMERA_PERMISSION);
                    }
                })
                .setNegativeButton(android.R.string.cancel,
                        new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface dialog, int which) {
                                Toast.makeText(getApplicationContext(), R.string.request_permission, Toast.LENGTH_SHORT).show();
                            }
                        })
                .create();
        alertDialog.show();
    }


    /**
     * Shows a {@link Toast} on the UI thread.
     *
     * @param text The message to show
     */
    private void showToast(final String text) {
        Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
    }



}
