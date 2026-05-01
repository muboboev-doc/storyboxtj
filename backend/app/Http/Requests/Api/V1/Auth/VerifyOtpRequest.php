<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Validation для POST /api/v1/auth/otp/verify.
 *
 * - phone — E.164
 * - code — ровно 6 цифр (как в Cache от OtpService)
 * - referral_code — опциональный, 8 alphanumeric uppercase
 *   (формат генерации в User::generateReferralCode)
 */
final class VerifyOtpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:/^\+[1-9]\d{1,14}$/'],
            'code' => ['required', 'string', 'regex:/^\d{6}$/'],
            'referral_code' => ['nullable', 'string', 'regex:/^[A-Z0-9]{8}$/'],
        ];
    }

    public function phone(): string
    {
        /** @var string */
        return $this->validated('phone');
    }

    public function code(): string
    {
        /** @var string */
        return $this->validated('code');
    }

    public function referralCode(): ?string
    {
        /** @var string|null */
        return $this->validated('referral_code');
    }
}
