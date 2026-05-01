<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Requests\Api\V1\Auth\RequestOtpRequest;
use App\Http\Requests\Api\V1\Auth\VerifyOtpRequest;
use App\Http\Resources\Api\V1\UserResource;
use App\Http\Resources\Api\V1\WalletResource;
use App\Services\Auth\OtpService;
use Illuminate\Http\JsonResponse;

/**
 * Auth endpoints для phone-OTP flow.
 *
 *   POST /api/v1/auth/otp/request   — Phase 1.3
 *   POST /api/v1/auth/otp/verify    — Phase 1.5
 *   POST /api/v1/auth/social/...    — Phase 1.6+
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

    public function verifyOtp(VerifyOtpRequest $request): JsonResponse
    {
        $user = $this->otp->verify(
            phone: $request->phone(),
            code: $request->code(),
            referralCode: $request->referralCode(),
        );

        // Sanctum personal-access-token. Имя 'mobile' для last_used_at трекинга.
        $token = $user->createToken('mobile')->plainTextToken;

        // Eager load wallet (UserObserver гарантирует существование).
        $user->loadMissing('wallet');

        return response()->json([
            'user' => new UserResource($user),
            'wallet' => new WalletResource($user->wallet),
            'token' => $token,
            'token_type' => 'Bearer',
        ]);
    }
}
