<?php

use App\Jobs\TranscodeEpisode;
use Illuminate\Support\Facades\Bus;
use Tests\TestCase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
|
| The closure you provide to your test functions is always bound to a specific PHPUnit test
| case class. By default, that class is "PHPUnit\Framework\TestCase". Of course, you may
| need to change it using the "pest()" function to bind a different classes or traits.
|
*/

// Подключаем Laravel TestCase и для Feature, и для Unit:
// Unit-тесты используют config()/app() через бутстрап.
pest()->extend(TestCase::class)
    // ->use(Illuminate\Foundation\Testing\RefreshDatabase::class)
    ->in('Feature', 'Unit');

/*
 * Phase 2.7: глобально фейкуем TranscodeEpisode job, чтобы создание Episode
 * через factory не дёргало синхронный транскод-стаб (queue=sync в тестах).
 *
 * Тесты, которые проверяют сам job, вызывают (new TranscodeEpisode($id))->handle()
 * напрямую — это обходит Bus и работает как ожидается. Тесты, которые проверяют
 * dispatch через Observer, используют Bus::assertDispatched().
 */
uses()->beforeEach(function (): void {
    Bus::fake([TranscodeEpisode::class]);
})->in('Feature', 'Unit');

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
|
| When you're writing tests, you often need to check that values meet certain conditions. The
| "expect()" function gives you access to a set of "expectations" methods that you can use
| to assert different things. Of course, you may extend the Expectation API at any time.
|
*/

expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

/*
|--------------------------------------------------------------------------
| Functions
|--------------------------------------------------------------------------
|
| While Pest is very powerful out-of-the-box, you may have some testing code specific to your
| project that you don't want to repeat in every file. Here you can also expose helpers as
| global functions to help you to reduce the number of lines of code in your test files.
|
*/

function something()
{
    // ..
}
