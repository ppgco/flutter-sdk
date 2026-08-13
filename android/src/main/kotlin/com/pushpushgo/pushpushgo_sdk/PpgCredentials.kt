package com.pushpushgo.pushpushgo_sdk

/**
 * Credential format checks, mirroring the native SDK's own validation
 * (`com.pushpushgo.sdk.utils.StringValidationExtension`, which is internal to
 * that module and cannot be called from here).
 *
 * `PushPushGo.getInstance(...)` only validates credentials
 * while it builds the singleton — once an instance exists it returns
 * that instance untouched. Credentials passed to a later `initialize()` would
 * therefore be accepted without a check and persisted to SharedPreferences,
 * and the next cold start would rebuild the SDK from those values, throw during
 * validation, and take down `Application.onCreate`.
 */
internal object PpgCredentials {

    private val API_KEY_PATTERN =
        Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")

    private val PROJECT_ID_PATTERN = Regex("[a-z0-9]{24}")

    /** Description of what is wrong with the pair, or `null` when it is usable. */
    fun validationError(apiToken: String, projectId: String): String? = when {
        !API_KEY_PATTERN.matches(apiToken) ->
            "Invalid API key: `$apiToken`"
        !PROJECT_ID_PATTERN.matches(projectId) ->
            "Invalid project ID: `$projectId`"
        else -> null
    }
}
