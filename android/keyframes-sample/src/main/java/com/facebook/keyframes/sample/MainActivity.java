/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
package com.facebook.keyframes.sample;

import android.Manifest;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.os.Bundle;
import android.os.Environment;
import android.support.v4.app.ActivityCompat;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import com.facebook.keyframes.KeyframesDrawable;
import com.facebook.keyframes.deserializers.KFImageDeserializer;
import com.facebook.keyframes.model.KFImage;

import java.io.*;

public class MainActivity extends Activity {

  private static final String TAG = "KeyframesSample";

  private static final int TEST_CANVAS_SIZE_PX = 500;

  private KeyframesDrawable mLikeImageDrawable;

  private final IntentFilter mPreviewKeyframesAnimation = new IntentFilter("PreviewKeyframesAnimation");

  private BroadcastReceiver mPreviewRenderReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      Log.d(TAG, "received intent");

      String descriptorPath = intent.getStringExtra("descriptorPath");
      if (descriptorPath == null) {
        Log.e(TAG, "intent missing 'descriptorPath'");
        return;
      }

      requestPermission();
      InputStream descriptorJSON;
      try {
        descriptorJSON = new FileInputStream(descriptorPath);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
        return;
      }

      KFImage kfImage;
      try {
        kfImage = KFImageDeserializer.deserialize(descriptorJSON);
      } catch (IOException e) {
        e.printStackTrace();
        return;
      }
      setKFImage(kfImage);
    }

  };

  // Storage Permissions
  private static final int REQUEST_EXTERNAL_STORAGE = 1;
  private static final String[] PERMISSIONS_STORAGE = {
          Manifest.permission.READ_EXTERNAL_STORAGE,
          Manifest.permission.WRITE_EXTERNAL_STORAGE
  };

  private void requestPermission() {
    // Check if we have write permission
    int permission = ActivityCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE);

    if (permission != PackageManager.PERMISSION_GRANTED) {
      // We don't have permission so prompt the user
      ActivityCompat.requestPermissions(
              this,
              PERMISSIONS_STORAGE,
              REQUEST_EXTERNAL_STORAGE
      );
    }
  }

  private String dexOutputDir;
  private File dir;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_main);

    setKFImage(getSampleLike());

    View generateStillsButton = findViewById(R.id.dev_generate_stills_button);
    generateStillsButton.setVisibility(View.GONE);

    registerReceiver(mPreviewRenderReceiver, mPreviewKeyframesAnimation);
  }

  private void setKFImage(KFImage kfImage) {
    ImageView imageView = (ImageView) findViewById(R.id.sample_image_view);
    mLikeImageDrawable = new KeyframesDrawable(kfImage);
    imageView.setImageDrawable(mLikeImageDrawable);
    mLikeImageDrawable.startAnimation();
  }

  private KFImage getSampleLike() {
    InputStream stream = null;
    try {
      stream = getResources().getAssets().open("sample_anger_temp");
      KFImage likeImage = KFImageDeserializer.deserialize(stream);
      return likeImage;
    } catch (IOException e) {
      e.printStackTrace();
    } finally {
      if (stream != null) {
        try {
          stream.close();
        } catch (IOException e) {
        }
      }
    }
    return null;
  }

  @Override
  public void onPause() {
    mLikeImageDrawable.stopAnimationAtLoopEnd();
    unregisterReceiver(mPreviewRenderReceiver);
    super.onPause();
  }

  @Override
  public void onResume() {
    super.onResume();
    registerReceiver(mPreviewRenderReceiver, mPreviewKeyframesAnimation);
    mLikeImageDrawable.startAnimation();
  }

  /**
   * TODO TEMPORARY HACK! JUST GRABBING SNAPSHOTS!
   */
  public void generateNewTestStills(View view) {
    try {
      String storageDirectory =
          Environment.getExternalStorageDirectory().getAbsolutePath() + "/Keyframes";
      File storageDirFile = new File(storageDirectory);
      if (!storageDirFile.exists()) {
        storageDirFile.mkdir();
      }

      KFImage image = getSampleLike();
      int frameCount = image.getFrameCount();
      KeyframesDrawable drawable = new KeyframesDrawable(image);
      Bitmap bitmap =
          Bitmap.createBitmap(TEST_CANVAS_SIZE_PX, TEST_CANVAS_SIZE_PX, Bitmap.Config.ARGB_8888);
      Canvas canvas = new Canvas(bitmap);

      drawable.setBounds(0, 0, TEST_CANVAS_SIZE_PX, TEST_CANVAS_SIZE_PX);

      float step = .1f;
      for (float progress = 0; progress <= 1; progress += step) {
        canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);
        drawable.setFrameProgress(frameCount * progress);
        drawable.draw(canvas);

        File outputFile = new File(storageDirFile, "test_" + (int) (progress / step) + ".png");
        OutputStream outputStream = new FileOutputStream(outputFile);
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream);
        outputStream.flush();
        outputStream.close();
        Log.v("Keyframes Dev", "Test static image generated at: " + outputFile.getAbsolutePath());
      }
    } catch (Exception e) {

    }
  }
}
