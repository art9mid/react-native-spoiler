package com.margelo.nitro.spoiler

import android.content.Context
import android.graphics.Color
import android.view.View
import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip

@Keep
@DoNotStrip
class HybridNitroSpoiler(context: Context) : HybridNitroSpoilerSpec() {

  private val spoilerView = SpoilerView(context)

  override val view: View
    get() = spoilerView

  override var isOn: Boolean
    get() = spoilerView.isOn
    set(value) {
      spoilerView.isOn = value
    }

  override fun reveal(x: Double, y: Double): Boolean {
    if (!spoilerView.canReveal()) {
      return false
    }
    val density = spoilerView.resources.displayMetrics.density
    // hybrid methods are called from the JS thread; views need the main thread
    spoilerView.post {
      spoilerView.reveal(x.toFloat() * density, y.toFloat() * density)
    }
    return true
  }

  override fun touch(x: Double, y: Double) {
    val density = spoilerView.resources.displayMetrics.density
    spoilerView.post {
      spoilerView.touch(x.toFloat() * density, y.toFloat() * density)
    }
  }

  override fun release() {
    spoilerView.post {
      spoilerView.release()
    }
  }

  override var color: String? = null
    set(value) {
      field = value
      if (value != null) {
        spoilerView.particleColor = try {
          Color.parseColor(value)
        } catch (e: IllegalArgumentException) {
          Color.BLACK
        }
      }
    }

  override var managesContentAlpha: Boolean? = false
    set(value) {
      field = value
      spoilerView.managesContentAlpha = value ?: false
    }
}
