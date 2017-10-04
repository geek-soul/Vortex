package vortex.geek.com.vortex;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.view.View;
import android.widget.ImageView;
import android.widget.Toast;

import java.io.File;

import vortex.geek.com.vortex.core.CameraTextureView;

/**
 * Created by wangmingyong on 2017/10/4.
 */

public class CameraActivity extends Activity implements View.OnClickListener {


    private ImageView mCaptureImage;
    private CameraTextureView mCameraTextureView;

    private static final int REQUEST_CAMERA_PERMISSION = 1;
    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_camera2_basic);


        File mFile = new File(getExternalFilesDir(null), "pic.jpg");
        findViewById(R.id.picture).setOnClickListener(this);
        findViewById(R.id.info).setOnClickListener(this);

        mCaptureImage = (ImageView) findViewById(R.id.iv_capture_pic);
        mCameraTextureView = (CameraTextureView) findViewById(R.id.texture);

        //配置CameraTexture
        mCameraTextureView.setActivity(this);
        mCameraTextureView.setPicSaveFile(mFile);
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
                        ActivityCompat.requestPermissions(CameraActivity.this,
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


