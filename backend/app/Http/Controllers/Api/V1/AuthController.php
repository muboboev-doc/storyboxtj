<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Requests\Api\V1\Auth\RequestOtpRequest;
use App\Services\Auth\OtpService;
use Illuminate\Http\JsonResponse;

/**
 * Auth endpoints для phone-OTP flow (Phase 1.3).
 *
 *   POST /api/v1/auth/otp/request   — запросить код
 *   POST /api/v1/auth/otp/verify    — Phase 1.5
 *   POST /api/v1/auth/social/...    — Phase 1+
 */
final class AuthController
{
    public function __construct(
        private readonly OtpService $otp,
    ) {}

    public function requestOtp(RequestOtpRequest $request): JsonResponse
    {
        $expiresAt = $this->otp->request($request->phone());

        return response()->json([
            'sent' => true,
            'expires_at' => $expiresAt->format(\DateTimeInterface::ATOM),
        ]);
    }
}
