<?php

declare(strict_types=1);

namespace Vaslv\Release;

use Composer\Plugin\Capability\CommandProvider as CommandProviderCapability;

class CommandProvider implements CommandProviderCapability
{
    public function getCommands(): array
    {
        return [
            new ReleaseCommand(),
        ];
    }
}
