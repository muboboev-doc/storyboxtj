<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Validation для POST /api/v1/auth/otp/request.
 *
 * Phone должен быть E.164:
 *   - начинается с `+`
 *   - первая цифра 1-9 (нет leading zero после `+`)
 *   - до 14 цифр после `+`
 *
 * Без spaces, без скобок, без дефисов.
 */
final class RequestOtpRequest extends FormRequest
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
        ];
    }

    /** @return array<string, string> */
    public function messages(): array
    {
        return [
            'phone.regex' => 'Phone must be E.164 format (e.g., +992901234567).',
        ];
    }

    public function phone(): string
    {
        /** @var string */
        return $this->validated('phone');
    }
}
