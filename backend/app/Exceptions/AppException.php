<?php

declare(strict_types=1);

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

/**
 * Базовый класс для всех бизнес-ошибок (CLAUDE.md §5.2).
 *
 * Контракт error envelope (docs/openapi.yaml):
 *   { "error": { "code": "MACHINE_READABLE", "message": "Localized human text" } }
 *
 * Использование:
 *
 *   throw new AppException(
 *       code: 'INSUFFICIENT_COINS',
 *       message: 'Need 50, you have 30',
 *       statusCode: 402,
 *   );
 *
 * Handler автоматически рендерит как JSON через render() метод.
 *
 * **Note:** field называется `errorCode`, а не `code` — последнее конфликтует
 * с базовым `Exception::$code` (он не readonly).
 */
class AppException extends Exception
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $statusCode = 400,
        ?\Throwable $cause = null,
    ) {
        parent::__construct($message, 0, $cause);
    }

    public static function make(string $code, string $message, int $statusCode = 400): self
    {
        return new self(errorCode: $code, message: $message, statusCode: $statusCode);
    }

    public function render(): JsonResponse
    {
        return response()->json([
            'error' => [
                'code' => $this->errorCode,
                'message' => $this->getMessage(),
            ],
        ], $this->statusCode);
    }
}
