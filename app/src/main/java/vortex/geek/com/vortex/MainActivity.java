package vortex.geek.com.vortex;

import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.TextView;
import android.app.Activity;
import android.os.Bundle;
import android.support.v4.view.PagerAdapter;
import android.support.v4.view.ViewPager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity {

    private int[] mImgIds = new int[] { R.mipmap.welcome,
            R.mipmap.gohomepage};
    private List<View> mLaunchViews = new ArrayList<View>();
    private ViewPager mViewPager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        setContentView(R.layout.activity_main);
        initData();// init picture to image view.
        // Example of a call to a native method
        mViewPager = (ViewPager) findViewById(R.id.id_viewpager);

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
    // Example of a call to a native method
    //TextView tv = (TextView) findViewById(R.id.id_helloWord);
    //tv.setText(instance.stringFromJNI());
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


}
