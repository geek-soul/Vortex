package vortex.geek.com.vortex;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.view.PagerAdapter;
import android.support.v4.view.ViewPager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;

import com.tencent.bugly.crashreport.CrashReport;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private int[] mImgIds = new int[] { R.mipmap.welcome,
            R.mipmap.gohomepage};
    private List<View> mLaunchViews = new ArrayList<View>();
    private ViewPager mViewPager;
    private View view1,view2;
    private FrameLayout rgbPanle;



    private Button startBtn;

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

        InitView();
        setListener();




    }

    private void setListener() {
        startBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Intent intent = new Intent(MainActivity.this, CameraActivity.class);
                startActivity(intent);
               // MainActivity.this.finish();
            }
        });
    }

    private void InitView() {
        startBtn = (Button)view1.findViewById(R.id.show);

    }

    private void initData()
    {
        //for (int imgId : mImgIds)
        {
            //ImageView imageView = new ImageView(getApplicationContext());
            //imageView.setScaleType(ScaleType.CENTER_CROP);
            //imageView.setImageResource(imgId);

            LayoutInflater inflater=getLayoutInflater();
            view1 = inflater.inflate(R.layout.acttivty_welcome, null);
            view2 = inflater.inflate(R.layout.activty_gohomepage, null);
            mLaunchViews.add(view1);
            mLaunchViews.add(view2);

        }
    }



}
