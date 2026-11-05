package com.orleu.common;

import java.util.Map;

public record ApiError(String code, String message, String correlationId, Map<String, String> fieldErrors) {}
