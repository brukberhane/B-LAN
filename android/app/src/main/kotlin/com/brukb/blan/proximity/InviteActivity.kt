package com.brukb.blan.proximity

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Bottom-sheet invite. Foreground invites use the Flutter sheet instead;
 * this activity is the background / lock-screen path. Relays Accept/Decline
 * to [InviteBus]. No secrets here — nick, 6-digit code, and intent lines.
 */
class InviteActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val nick = intent.getStringExtra("nick") ?: "Unknown peer"
        val code = intent.getStringExtra("code") ?: "------"
        val lines = intent.getStringArrayExtra("lines") ?: emptyArray()

        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        window.setGravity(Gravity.BOTTOM)

        val sheet = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(20), dp(24), dp(28))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadii = floatArrayOf(
                    dp(28).toFloat(), dp(28).toFloat(),
                    dp(28).toFloat(), dp(28).toFloat(),
                    0f, 0f, 0f, 0f,
                )
            }
        }
        sheet.addView(
            TextView(this).apply {
                text = "Invite from $nick"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
                setTextColor(Color.BLACK)
                setPadding(0, 0, 0, dp(8))
            },
        )
        sheet.addView(
            TextView(this).apply {
                text = buildString {
                    append("Code: $code")
                    for (line in lines) {
                        append("\n")
                        append(line)
                    }
                }
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(Color.DKGRAY)
                setPadding(0, 0, 0, dp(16))
            },
        )
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }
        actions.addView(
            Button(this).apply {
                text = "Decline"
                setOnClickListener {
                    InviteBus.decline()
                    finish()
                }
            },
        )
        actions.addView(
            Button(this).apply {
                text = "Accept"
                setOnClickListener {
                    InviteBus.accept()
                    finish()
                }
            },
        )
        sheet.addView(actions)
        setContentView(sheet)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        InviteBus.decline()
        super.onBackPressed()
    }
}
