package ke.co.jiranichama.securekeys

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

/**
 * A P-256 signing key in the Android keystore that can be used only after the owner's
 * fingerprint, face or phone PIN (JiraniChama proposal 6.7). The private key never leaves
 * the keystore; the app gets the public key, the key's attestation chain and signatures.
 *
 * Needs Android 11 (API 30): from there a key can require a fresh fingerprint OR the
 * phone's PIN for every signature. Older phones report unavailable and use SMS codes.
 */
class SecureKeysPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: FragmentActivity? = null
    private var appContext: android.content.Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "jirani_secure_keys")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }
    override fun onDetachedFromActivity() { activity = null }

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun b64(bytes: ByteArray) = Base64.encodeToString(bytes, Base64.NO_WRAP)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAvailable" -> result.success(isAvailable())
                "hasKey" -> result.success(keyStore().containsAlias(call.argument<String>("alias")))
                "deleteKey" -> {
                    keyStore().deleteEntry(call.argument<String>("alias"))
                    result.success(null)
                }
                "createKey" -> result.success(createKey(
                    call.argument<String>("alias")!!,
                    Base64.decode(call.argument<String>("challenge")!!, Base64.NO_WRAP)))
                "publicKey" -> {
                    val cert = keyStore().getCertificate(call.argument<String>("alias"))
                    result.success(cert?.publicKey?.encoded?.let { b64(it) })
                }
                "sign" -> sign(call, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("keystore", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun isAvailable(): Boolean {
        val ctx = appContext ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return BiometricManager.from(ctx).canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    private fun spec(alias: String, challenge: ByteArray, strongBox: Boolean): KeyGenParameterSpec {
        val b = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(true)
            .setAttestationChallenge(challenge)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Every signature needs a fresh fingerprint, face or phone PIN.
            b.setUserAuthenticationParameters(
                0, KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL)
        }
        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) b.setIsStrongBoxBacked(true)
        return b.build()
    }

    private fun createKey(alias: String, challenge: ByteArray): Map<String, Any> {
        val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        var strongBox = true
        try {
            kpg.initialize(spec(alias, challenge, true))
            kpg.generateKeyPair()
        } catch (e: StrongBoxUnavailableException) {
            strongBox = false
            kpg.initialize(spec(alias, challenge, false))
            kpg.generateKeyPair()
        } catch (e: java.security.ProviderException) {
            // Some phones throw a generic error instead of StrongBoxUnavailableException.
            strongBox = false
            kpg.initialize(spec(alias, challenge, false))
            kpg.generateKeyPair()
        }
        val chain = keyStore().getCertificateChain(alias)
        return mapOf(
            "publicKey" to b64(chain[0].publicKey.encoded),
            "chain" to chain.map { b64(it.encoded) },
            "strongBox" to strongBox,
        )
    }

    private fun sign(call: MethodCall, result: MethodChannel.Result) {
        val act = activity ?: return result.error("no_activity", "No screen to ask on", null)
        val alias = call.argument<String>("alias")!!
        val data = Base64.decode(call.argument<String>("data")!!, Base64.NO_WRAP)
        val key = keyStore().getKey(alias, null) as? PrivateKey
            ?: return result.error("no_key", "No signing key on this phone", null)
        val signature = Signature.getInstance("SHA256withECDSA").apply { initSign(key) }
        var answered = false
        val prompt = BiometricPrompt(act, ContextCompat.getMainExecutor(act),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                    if (answered) return
                    answered = true
                    try {
                        val s = r.cryptoObject!!.signature!!
                        s.update(data)
                        result.success(b64(s.sign()))
                    } catch (e: Exception) {
                        result.error("sign_failed", e.message, null)
                    }
                }

                override fun onAuthenticationError(code: Int, msg: CharSequence) {
                    if (answered) return
                    answered = true
                    result.error("cancelled", msg.toString(), code)
                }
            })
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(call.argument<String>("title") ?: "")
            .setSubtitle(call.argument<String>("subtitle") ?: "")
            .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            .build()
        prompt.authenticate(info, BiometricPrompt.CryptoObject(signature))
    }
}
