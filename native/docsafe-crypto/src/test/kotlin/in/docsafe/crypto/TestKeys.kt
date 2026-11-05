package `in`.docsafe.crypto

import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** Software keys standing in for Android Keystore keys in JVM tests. */
object TestKeys {
    fun aes(): SecretKey = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    fun hmac(): SecretKey = KeyGenerator.getInstance("HmacSHA256").generateKey()
    fun wrapper(key: SecretKey = aes()): KeyWrapper = AesGcmKeyWrapper { key }
    fun macFactory(key: SecretKey = hmac()): MacFactory = HmacSha256Factory { key }
}
