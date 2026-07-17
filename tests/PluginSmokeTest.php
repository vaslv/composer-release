<?php

declare(strict_types=1);

namespace Vaslv\Release\Tests;

use Composer\Plugin\Capability\CommandProvider as CommandProviderCapability;
use PHPUnit\Framework\TestCase;
use Vaslv\Release\CommandProvider;
use Vaslv\Release\Plugin;
use Vaslv\Release\ReleaseCommand;

final class PluginSmokeTest extends TestCase
{
    public function testComposerJsonPointsAtRealPluginClass(): void
    {
        $json = json_decode((string) file_get_contents(dirname(__DIR__) . '/composer.json'), true);

        self::assertIsArray($json);
        self::assertArrayHasKey('extra', $json);
        $extra = $json['extra'];
        self::assertIsArray($extra);
        self::assertArrayHasKey('class', $extra);
        self::assertSame(Plugin::class, $extra['class']);
        self::assertTrue(class_exists(Plugin::class));
    }

    public function testCapabilitiesWireCommandProvider(): void
    {
        $capabilities = (new Plugin())->getCapabilities();

        self::assertSame(CommandProvider::class, $capabilities[CommandProviderCapability::class]);
    }

    public function testReleaseCommandIsRegistered(): void
    {
        $commands = (new CommandProvider())->getCommands();

        self::assertCount(1, $commands);
        self::assertInstanceOf(ReleaseCommand::class, $commands[0]);
        self::assertSame('release', $commands[0]->getName());
    }

    public function testReleaseScriptShippedAndExecutable(): void
    {
        $script = dirname(__DIR__) . '/bin/release';

        self::assertFileExists($script);
        self::assertTrue(is_executable($script));
    }
}
