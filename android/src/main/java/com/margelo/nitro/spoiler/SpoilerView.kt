package com.margelo.nitro.spoiler

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import java.util.Random
import kotlin.math.min

/**
 * Spoiler particle ("dust") effect, ported from Telegram-Android SpoilerEffect.
 * https://github.com/DrKLO/Telegram/blob/master/TMessagesProj/src/main/java/org/telegram/ui/Components/spoilers/SpoilerEffect.java
 *
 * Particles are stored as primitive arrays (structure-of-arrays) and rendered
 * with Canvas.drawPoints batched into one draw call per alpha bucket, matching
 * Telegram's approach. Animation is throttled to 30 FPS like Telegram.
 *
 * Per-particle alpha = base alpha (Telegram's 0.3/0.6/1.0 variety) × a
 * fade-in/fade-out envelope over the particle's life, quantized into
 * ALPHA_BUCKETS levels so rendering stays batched (mirrors the iOS
 * "valueOverLife" emitter behavior). When `isOn` turns false the effect
 * stops spawning and lets live particles decay instead of vanishing.
 */
class SpoilerView(context: Context) : View(context) {

  companion object {
    // Telegram SpoilerEffect.ALPHAS
    private val BASE_ALPHAS = floatArrayOf(0.3f, 0.6f, 1.0f)
    private const val ALPHA_BUCKETS = 8
    private const val FRAME_DELAY_MS = (1000 / 30 + 1).toLong()
    private const val PARTICLES_PER_DP2 = 0.07f
    private const val MAX_PARTICLES = 4000
    private const val MIN_LIFETIME_MS = 1000f
    private const val LIFETIME_RANGE_MS = 2000f
    private const val FADE_MS = 350f
  }

  private val density = context.resources.displayMetrics.density
  private val rand = Random()

  private val paints = Array(ALPHA_BUCKETS) { i ->
    Paint().apply {
      color = Color.BLACK
      alpha = ((i + 1) * 255 / ALPHA_BUCKETS)
      strokeWidth = 1.3f * density
      style = Paint.Style.STROKE
      strokeCap = Paint.Cap.ROUND
    }
  }

  // structure-of-arrays particle storage
  private val xs = FloatArray(MAX_PARTICLES)
  private val ys = FloatArray(MAX_PARTICLES)
  private val dirXs = FloatArray(MAX_PARTICLES)
  private val dirYs = FloatArray(MAX_PARTICLES)
  private val velocities = FloatArray(MAX_PARTICLES)
  private val times = FloatArray(MAX_PARTICLES)
  private val lifeTimes = FloatArray(MAX_PARTICLES)
  private val baseAlphas = FloatArray(MAX_PARTICLES)

  // per-bucket point buffers for batched drawPoints
  private val points = Array(ALPHA_BUCKETS) { FloatArray(MAX_PARTICLES * 2) }
  private val pointCounts = IntArray(ALPHA_BUCKETS)

  private var particleCount = 0
  private var lastFrameTime = 0L

  // reveal in progress: blast impulse + expanding cull circle from the tap
  private var revealStartTime = 0L
  private var revealX = 0f
  private var revealY = 0f

  // finger-play (iMessage invisible-ink style): dust is pushed away around
  // the finger while it touches the view
  private var fingerActive = false
  private var fingerX = 0f
  private var fingerY = 0f

  // native gesture tracking — no JS involvement per move
  private var touchStartX = 0f
  private var touchStartY = 0f
  private var didDrag = false
  private var lastDragEndTime = 0L

  // after a short hold, claim the gesture so a scrolling parent can't cancel
  // the finger-play; an instant swipe (< the delay) still scrolls normally
  private val holdClaimRunnable = Runnable {
    parent?.requestDisallowInterceptTouchEvent(true)
  }

  private val frameRunnable = Runnable { invalidate() }

  var isOn: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      if (value) {
        revealStartTime = 0L
        lastFrameTime = 0L
        animate().cancel()
        alpha = 1f
        seedParticles()
      }
      // on false: keep drawing — live particles decay over their remaining
      // lifetime instead of vanishing in a single frame (Telegram dissolve)
      invalidate()
    }

  /**
   * When enabled, the reveal also wipes the covered content in from the tap
   * point with a circular reveal on the sibling content view (outline clip —
   * React never writes it, so it can't be reset like alpha).
   */
  var managesContentAlpha: Boolean = false

  private fun contentSibling(): View? {
    val parent = parent as? android.view.ViewGroup ?: return null
    for (i in 0 until parent.childCount) {
      val child = parent.getChildAt(i)
      if (child !== this) return child
    }
    return null
  }

  /**
   * `true` when a reveal should proceed — `false` right after a finger-play
   * drag (a drag is play, not a tap).
   */
  fun canReveal(): Boolean =
    android.os.SystemClock.elapsedRealtime() - lastDragEndTime > 300

  /**
   * Telegram's tap reveal: particles get a blast impulse from the touch point,
   * an expanding circle culls them, and the content is wiped in from the same
   * point (mirrors the iOS fingerAttractor + mask wipe).
   */
  fun reveal(x: Float, y: Float) {
    if (particleCount == 0) return
    if (!canReveal()) return
    release()
    revealX = x
    revealY = y
    revealStartTime = android.os.SystemClock.elapsedRealtime()

    val maxDist = Math.max(width, height).toFloat()
    for (i in 0 until particleCount) {
      var dx = xs[i] - x
      var dy = ys[i] - y
      val dist = Math.hypot(dx.toDouble(), dy.toDouble()).toFloat()
      if (dist < 1f) {
        dx = 1f
        dy = 0f
      } else {
        dx /= dist
        dy /= dist
      }
      dirXs[i] = dx
      dirYs[i] = dy
      // stronger blast close to the finger, falls off with distance
      val strength = 1f - min(dist / maxDist, 1f)
      velocities[i] = (60f + 240f * strength) * density
    }

    // content circular reveal from the tap point
    if (managesContentAlpha) {
      contentSibling()?.let { content ->
        if (content.isAttachedToWindow) {
          val endRadius = Math.hypot(width.toDouble(), height.toDouble()).toFloat()
          android.view.ViewAnimationUtils
            .createCircularReveal(content, x.toInt(), y.toInt(), 0f, endRadius)
            .setDuration(550)
            .start()
        }
      }
    }
    invalidate()
  }

  fun touch(x: Float, y: Float) {
    if (!isOn) return
    fingerActive = true
    fingerX = x
    fingerY = y
    invalidate()
  }

  fun release() {
    fingerActive = false
  }

  // React Native dispatches JS touch events from the root view independently
  // of native consumption, so handling (and consuming) touches here does not
  // break a wrapping Pressable.
  @Suppress("ClickableViewAccessibility")
  override fun onTouchEvent(event: android.view.MotionEvent): Boolean {
    if (!isOn) return false
    when (event.actionMasked) {
      android.view.MotionEvent.ACTION_DOWN -> {
        touchStartX = event.x
        touchStartY = event.y
        didDrag = false
        postDelayed(holdClaimRunnable, 150)
        touch(event.x, event.y)
      }
      android.view.MotionEvent.ACTION_MOVE -> {
        if (!didDrag) {
          val dx = event.x - touchStartX
          val dy = event.y - touchStartY
          val slop = 10f * density
          if (dx * dx + dy * dy > slop * slop) {
            didDrag = true
          }
        }
        touch(event.x, event.y)
      }
      android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
        removeCallbacks(holdClaimRunnable)
        release()
        if (didDrag) {
          lastDragEndTime = android.os.SystemClock.elapsedRealtime()
        }
        didDrag = false
      }
    }
    return true
  }

  var particleColor: Int = Color.BLACK
    set(value) {
      if (field == value) return
      field = value
      for (i in paints.indices) {
        paints[i].color = value
        paints[i].alpha = ((i + 1) * 255 / ALPHA_BUCKETS)
      }
      invalidate()
    }

  init {
    setWillNotDraw(false)
  }

  private fun targetCount(): Int {
    val areaDp2 = width * height / (density * density)
    return min((areaDp2 * PARTICLES_PER_DP2).toInt(), MAX_PARTICLES)
  }

  private fun seedParticles() {
    particleCount = 0
    val target = targetCount()
    while (particleCount < target) {
      val i = particleCount++
      spawn(i)
      // stagger ages so the steady-state distribution is there on frame one
      times[i] = rand.nextFloat() * lifeTimes[i]
    }
  }

  private fun spawn(i: Int) {
    xs[i] = rand.nextFloat() * width
    ys[i] = rand.nextFloat() * height
    val angle = rand.nextFloat() * (Math.PI * 2).toFloat()
    dirXs[i] = Math.cos(angle.toDouble()).toFloat()
    dirYs[i] = Math.sin(angle.toDouble()).toFloat()
    // Telegram: velocity = 4 + rand * 6, applied as velocity * dt / 500 px
    velocities[i] = (4f + rand.nextFloat() * 6f) * density * 0.5f
    times[i] = 0f
    lifeTimes[i] = MIN_LIFETIME_MS + rand.nextFloat() * LIFETIME_RANGE_MS
    baseAlphas[i] = BASE_ALPHAS[rand.nextInt(BASE_ALPHAS.size)]
  }

  private fun removeParticle(i: Int) {
    val last = particleCount - 1
    if (i != last) {
      xs[i] = xs[last]
      ys[i] = ys[last]
      dirXs[i] = dirXs[last]
      dirYs[i] = dirYs[last]
      velocities[i] = velocities[last]
      times[i] = times[last]
      lifeTimes[i] = lifeTimes[last]
      baseAlphas[i] = baseAlphas[last]
    }
    particleCount = last
  }

  override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
    super.onSizeChanged(w, h, oldw, oldh)
    if (isOn) {
      seedParticles()
    }
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    removeCallbacks(frameRunnable)
    removeCallbacks(holdClaimRunnable)
    lastFrameTime = 0L
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    if (isOn || particleCount > 0) {
      invalidate()
    }
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    if (width == 0 || height == 0 || (!isOn && particleCount == 0)) {
      lastFrameTime = 0L
      return
    }

    val now = android.os.SystemClock.elapsedRealtime()
    val dt = if (lastFrameTime == 0L) {
      FRAME_DELAY_MS.toFloat()
    } else {
      min(now - lastFrameTime, 64L).toFloat()
    }
    lastFrameTime = now

    val w = width.toFloat()
    val h = height.toFloat()
    val revealing = revealStartTime != 0L
    val target = if (isOn && !revealing) targetCount() else 0
    val step = dt / 1000f

    // expanding cull circle (Telegram's mask wipe, ~550ms to cover the view)
    var revealRadiusSq = 0f
    if (revealing) {
      val progress = min((now - revealStartTime) / 550f, 1f)
      val revealRadius = (Math.hypot(w.toDouble(), h.toDouble()).toFloat() + 1f) * progress
      revealRadiusSq = revealRadius * revealRadius
    }

    for (b in pointCounts.indices) {
      pointCounts[b] = 0
    }

    var i = 0
    while (i < particleCount) {
      val time = times[i] + dt
      times[i] = time
      val life = lifeTimes[i]

      if (revealing) {
        val rdx = xs[i] - revealX
        val rdy = ys[i] - revealY
        if (rdx * rdx + rdy * rdy <= revealRadiusSq) {
          removeParticle(i)
          continue
        }
      }

      if (time >= life || xs[i] < 0 || xs[i] > w || ys[i] < 0 || ys[i] > h) {
        if (particleCount > target) {
          removeParticle(i)
          continue
        }
        spawn(i)
      } else {
        val v = velocities[i] * step
        xs[i] += dirXs[i] * v
        ys[i] += dirYs[i] * v

        if (fingerActive) {
          // repulsive field around the finger, displacing dust outward
          val fdx = xs[i] - fingerX
          val fdy = ys[i] - fingerY
          val fingerRadius = 90f * density
          val distSq = fdx * fdx + fdy * fdy
          if (distSq < fingerRadius * fingerRadius && distSq > 0.01f) {
            val dist = Math.sqrt(distSq.toDouble()).toFloat()
            val push = (1f - dist / fingerRadius) * 600f * density * step
            xs[i] += fdx / dist * push
            ys[i] += fdy / dist * push
          }
        }
      }

      // fade-in/fade-out envelope, quantized to keep drawPoints batched
      val envelope = min(min(times[i] / FADE_MS, 1f), (life - times[i]) / FADE_MS)
      val bucket = (baseAlphas[i] * envelope * ALPHA_BUCKETS).toInt()
      if (bucket > 0) {
        val b = min(bucket, ALPHA_BUCKETS) - 1
        val c = pointCounts[b]
        points[b][c] = xs[i]
        points[b][c + 1] = ys[i]
        pointCounts[b] = c + 2
      }
      i++
    }

    // grow towards target after a resize or restart
    while (particleCount < target) {
      spawn(particleCount)
      times[particleCount] = rand.nextFloat() * lifeTimes[particleCount]
      particleCount++
    }

    for (b in 0 until ALPHA_BUCKETS) {
      if (pointCounts[b] > 0) {
        canvas.drawPoints(points[b], 0, pointCounts[b], paints[b])
      }
    }

    removeCallbacks(frameRunnable)
    postDelayed(frameRunnable, FRAME_DELAY_MS)
  }
}
